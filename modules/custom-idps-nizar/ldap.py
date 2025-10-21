import logging
import os
import ssl
import json
import ldap3
from idp_modules import util
from aws_lambda_powertools import Tracer

tracer = Tracer()

logger = logging.getLogger(__name__)
logger.setLevel(util.get_log_level())


class LdapIdpModuleError(util.IdpModuleError):
    """Used to raise module-specific exceptions"""

    pass
secret_cache = {}
server_pool_cache = {}

@tracer.capture_method
def build_server_pool(provider_name, servers, port, use_ssl, tls):
    server_pool = util.fetch_cache(server_pool_cache, provider_name, 300)
    if server_pool is None: 
        logger.debug(f"Building server pool for {provider_name}")
        tracer.put_annotation(key="ldap_created_server_pool", value=True)
        server_list = []
        if type(servers) == str:
                server_list.append(servers) 
        elif type(servers) == set:
            server_list = list(servers)
        elif type(servers) == list:
            server_list = servers
        logger.debug(f"server_list: {server_list}")        
        server_pool = ldap3.ServerPool(pool_strategy=ldap3.ROUND_ROBIN, active=True, exhaust=True)
        for server in server_list:
            server_pool.add(
                ldap3.Server(host=server, port=port, use_ssl=use_ssl, tls=tls, connect_timeout=5)
            )
        util.set_cache(server_pool_cache, provider_name, server_pool)
    else:
        logger.debug(f"Using cached server pool for {provider_name}")
        tracer.put_annotation(key="ldap_created_server_pool", value=False)
    logger.debug(server_pool.servers)
    logger.debug(server_pool.active)
    
    
    
    return server_pool


@tracer.capture_method
def handle_auth(
    event,
    parsed_username,
    user_record,
    identity_provider_record,
    response_data,
    authn_method,
):
    logger.debug(f"User record: {user_record}")

    identity_provider_config = identity_provider_record["config"]
    ldap_server = identity_provider_config["server"]
    ldap_port = int(identity_provider_config.get("port", 636))
    ldap_ssl = identity_provider_config.get("ssl", True)
    ldap_ssl_verify = identity_provider_config.get("ssl_verify", True)
    ldap_ssl_ca_secret_arn = identity_provider_config.get(
        "ldap_ssl_ca_secret_arn", None
    )
    ldap_attributes = identity_provider_config.get("attributes", {})
    ldap_search_base = identity_provider_config["search_base"]
    ldap_service_account_secret_arn = identity_provider_config.get(
        "ldap_service_account_secret_arn", None
    )
    ldap_ignore_missing_attributes = identity_provider_config.get(
        "ignore_missing_attributes", False
    )
    ldap_ssl_ca = None

    ldap_allowed_groups = identity_provider_config.get("ldap_allowed_groups", None)

    # Add userAccountControl to list of attributes to retrieve from LDAP, to check account Status
    if ldap_service_account_secret_arn:
        ldap_attributes["userAccountControl"] = "userAccountControl"
    
    # Add memberOf and distinguishedName to list of attributes to retrieve from LDAP for retrieving group memberships
    if ldap_allowed_groups:
        ldap_attributes["memberOf"] = "memberOf"
        ldap_attributes["distinguishedName"] = "distinguishedName"

    ldap_attribute_query_list = []

    # If this is a password-based authentication flow, public keys must not be returned in the response to AWS Transfer Family, we it will be filtered out in the LDAP reques to avoid unnecessary retrieval.
    if authn_method == util.AuthenticationMethod.PASSWORD and "PublicKeys" in ldap_attributes: 
        ldap_attributes.pop("PublicKeys")

    for attribute in ldap_attributes:
        ldap_attribute_query_list.append(ldap_attributes[attribute])

    if ldap_ssl_ca_secret_arn:
        ldap_ssl_ca = util.fetch_secret_cache(secret_cache, ldap_ssl_ca_secret_arn)

    ldap_tls = ldap3.Tls(
        validate=ssl.CERT_NONE if not ldap_ssl_verify else ssl.CERT_REQUIRED,
        ca_certs_data=(
            ldap_ssl_ca if not ldap_ssl_ca is None and ldap_ssl_verify else None
        ),
    )
    
    server_pool = build_server_pool(identity_provider_record["provider"], ldap_server, ldap_port, ldap_ssl, ldap_tls)

    if authn_method == util.AuthenticationMethod.PASSWORD:
        if "domain" in identity_provider_config:
            ldap_domain = identity_provider_config["domain"]
            if "." in ldap_domain:
                domain_username = f"{parsed_username}@{ldap_domain}"
            else:
                domain_username = f"{ldap_domain}\{parsed_username}"
        else:
            domain_username = parsed_username

        ldap_connection = ldap3.Connection(
            server=server_pool,
            user=domain_username,
            password=event["password"]
        )
    elif authn_method == util.AuthenticationMethod.PUBLIC_KEY:
        from . import public_key

        if not ldap_service_account_secret_arn is None:
            logger.info(
                f"Public key auth and LDAP service account configured. Attempting to use service account to retrieve user details and verify account status."
            )
            service_account = json.loads(
                util.fetch_secret_cache(secret_cache, ldap_service_account_secret_arn)
            )
            if "domain" in identity_provider_config:
                ldap_domain = identity_provider_config["domain"]
                if "." in ldap_domain:
                    domain_username = f"{service_account['username']}@{ldap_domain}"
                else:
                    domain_username = f"{ldap_domain}\{service_account['username']}"

            else:
                domain_username = service_account["username"]

            ldap_connection = ldap3.Connection(
                server=server_pool,
                user=domain_username,
                password=service_account["password"]
            )

        else:
            logger.info(
                "No service account configured. Passing to public key auth module."
            )
            response_data = public_key.handle_auth(
                event=event,
                parsed_username=parsed_username,
                user_record=user_record,
                identity_provider_record=identity_provider_record,
                response_data=response_data,
                authn_method=authn_method,
            )
            return response_data
    else:
        raise LdapIdpModuleError(
            "LDAP module does not support this authentication method ({authn_method})."
        )

    logger.info(f"LDAP domain username: {domain_username}")
    logger.debug(f"ldap_connection: {ldap_connection}")
    logger.debug(f"Current Server: {server_pool.get_current_server(ldap_connection)}")
    logger.info("Attempting LDAP bind")

    bound = ldap_connection.bind()
    
    logger.info(f"LDAP bound: {bound}")

    if not bound:
        raise LdapIdpModuleError(
            f"Unable to perform LDAP bind with credentials provided. Failing auth. Result: {ldap_connection.result}; Last error: {ldap_connection.last_error}"
        )

    logger.info(f"whoami: {ldap_connection.extend.standard.who_am_i()}")
    logger.info(f"Checking user status")

    if len(ldap_attribute_query_list) > 0:
        logger.info(
            f"Attempting to retrieve LDAP attributes {ldap_attribute_query_list} for user {parsed_username} on base {ldap_search_base}"
        )
        ldap_connection.search(
            search_base=ldap_search_base,            
            search_filter=f"(|(&(objectClass=user)(uid={parsed_username}))(&(objectCategory=person)(sAMAccountName={parsed_username})))",
            search_scope=ldap3.SUBTREE,
            dereference_aliases=ldap3.DEREF_NEVER,
            attributes=ldap_attribute_query_list,
        )
        logger.debug(f"LDAP response: {ldap_connection.response}")
        search_response = [
            entry
            for entry in ldap_connection.response
            if entry["type"] == "searchResEntry"
        ]
        if len(search_response) < 1:
            raise LdapIdpModuleError(
                f"The LDAP search for user {parsed_username} returned no results. Enable debug logging and check LDAP response for more information."
            )
        if len(search_response) > 1:
            raise LdapIdpModuleError(
                f"The LDAP search for user {parsed_username} returned multiple results, which should not occur. Enable debug logging and check LDAP response for more information."
            )

    # Normalize empty values to simplify checking if a value is missing or empty
    ldap_resolved_attributes = {}
    for attribute in ldap_attributes:
        value = ldap_connection.response[0]["attributes"].get(
            ldap_attributes[attribute], None
        )
        if not value is None and (type(value) == int or len(value) > 0):
            ldap_resolved_attributes[attribute] = value
        else:
            ldap_resolved_attributes[attribute] = None
    logger.debug(f"Resolved LDAP attributes: {ldap_resolved_attributes}")

    if (
        authn_method == util.AuthenticationMethod.PUBLIC_KEY
        and not ldap_service_account_secret_arn is None
        and ldap_resolved_attributes.get("userAccountControl", None) is None
    ):
        raise LdapIdpModuleError(
            f"Unable to retrieve account status for user {parsed_username} to determine if it is locked or disabled. Verify the service account used has Read permission on user objects."
        )

    if not ldap_resolved_attributes.get("userAccountControl", None) is None:
        logger.debug(
            f"userAccountControl: {ldap_resolved_attributes['userAccountControl']}"
        )
        if ldap_resolved_attributes["userAccountControl"] & 2:
            raise LdapIdpModuleError(
                f"Account for user {parsed_username} is disabled. Failing authentication."
            )
        if ldap_resolved_attributes["userAccountControl"] & 16:
            raise LdapIdpModuleError(
                f"Account for user {parsed_username} is locked. Failing authentication."
            )
    
    if ldap_allowed_groups is not None:
        allowed_group = False
        logger.info(f"Checking if user is in allowed groups")
        member_of_list = ldap_resolved_attributes.get("memberOf", [])
        logger.debug (f"memberOf: {member_of_list}")
        for group in ldap_allowed_groups:
            if group in member_of_list:
                logger.info(f"User {parsed_username} is a member of the allowed group {group}.")
                allowed_group = True
            else:
                logger.debug(f"User {parsed_username} is not a member of the allowed group {group}.")
        
        if not allowed_group:
            logger.info(f"User {parsed_username} is not a direct member of any of the allowed groups {ldap_allowed_groups}. Checking nested groups in AD-based LDAP.")                
            user_dn = ldap_resolved_attributes.get("distinguishedName", None)
            logger.debug(f"Attempting to retrieve nested group memberships for user {user_dn}")
            ldap_connection.search(
                search_base=ldap_search_base,
                search_filter=f"(&(objectClass=group)(member:1.2.840.113556.1.4.1941:={user_dn}))",
                search_scope=ldap3.SUBTREE,
                dereference_aliases=ldap3.DEREF_NEVER,
            )
            logger.debug(f"LDAP response: {ldap_connection.response}")
            ad_groups = [
                entry.get('dn', '')
                for entry in ldap_connection.response
                if entry["type"] == "searchResEntry"
            ]
            logger.debug(f"Groups {ad_groups}")
            allowed_group = False 
            for group in ldap_allowed_groups:
                if group in ad_groups:
                    logger.info(f"User {parsed_username} is a member of the allowed group {group}.")
                    allowed_group = True 
                else:
                    logger.debug(f"User {parsed_username} is not a member of the allowed group {group}.")
            
        if not allowed_group:
            raise LdapIdpModuleError(
                f"User {parsed_username} is not a member of any group in ldap_allowed_groups."
            )
        
    if "Role" in ldap_attributes:
        if not ldap_resolved_attributes["Role"] is None:
            logger.info(
                f"Applying Role {ldap_resolved_attributes['Role']} from LDAP Attributes"
            )
            response_data["Role"] = ldap_resolved_attributes["Role"]
        elif ldap_ignore_missing_attributes:
            logger.warning(
                f"LDAP attribute {ldap_attributes['Role']} for 'Role' was empty of missing. Skipping."
            )
        else:
            raise LdapIdpModuleError(
                f"LDAP attribute {ldap_attributes['Role']} for property 'Role' was empty or missing. Enable debug logging adn check LDAP response. To ignore, use the ignore_missing_attributes setting in the identity provider config."
            )

    if "Policy" in ldap_attributes:
        if not ldap_resolved_attributes["Policy"] is None:
            logger.info("Applying Policy from LDAP Attributes")
            response_data["Policy"] = ldap_resolved_attributes["Policy"]
        elif ldap_ignore_missing_attributes:
            logger.warning(
                f"LDAP attribute {ldap_attributes['Policy']} for 'Policy' was empty of missing. Skipping."
            )
        else:
            raise LdapIdpModuleError(
                f"LDAP attribute {ldap_attributes['Policy']} for property 'Policy' was empty or missing. Enable debug logging adn check LDAP response. To ignore, use the ignore_missing_attributes setting in the identity provider config."
            )
        
    if "PublicKeys" in ldap_attributes:
        if not ldap_resolved_attributes["PublicKeys"] is None:
            logger.info("Applying PublicKeys from LDAP Attributes")
            response_data["PublicKeys"] = json.loads(ldap_resolved_attributes["PublicKeys"])
        elif ldap_ignore_missing_attributes:
            logger.warning(
                f"LDAP attribute {ldap_attributes['PublicKeys']} for 'PublicKeys' was empty of missing. Skipping."
            )
        else:
            raise LdapIdpModuleError(
                f"LDAP attribute {ldap_attributes['PublicKeys']} for property 'PublicKeys' was empty or missing. Enable debug logging adn check LDAP response. To ignore, use the ignore_missing_attributes setting in the identity provider config."
            )        

    if "Uid" in ldap_attributes and "Gid" in ldap_attributes:
        if (
            not ldap_resolved_attributes["Uid"] is None
            and not ldap_resolved_attributes["Gid"] is None
        ):
            logger.info(
                f"Applying PosixProfile {ldap_resolved_attributes['Uid']},{ldap_resolved_attributes['Gid']} from LDAP Attributes"
            )
            response_data.setdefault("PosixProfile", {})
            response_data["PosixProfile"]["Uid"] = ldap_resolved_attributes["Uid"]
            response_data["PosixProfile"]["Gid"] = ldap_resolved_attributes["Gid"]
        elif ldap_ignore_missing_attributes:
            logger.warning(
                f"LDAP attributes {ldap_attributes['Uid']} for 'Uid' and/or {ldap_attributes['Gid']} for 'Gid' were empty of missing. Skipping."
            )
        else:
            raise LdapIdpModuleError(
                f"LDAP attribute {ldap_attributes['Uid']} for 'Uid' and/or {ldap_attributes['Gid']}  for 'Gid' were empty or missing. Enable debug logging adn check LDAP response. To ignore, use the ignore_missing_attributes setting in the identity provider config."
            )
    ldap_connection.unbind()
    if authn_method == util.AuthenticationMethod.PUBLIC_KEY:
        response_data = public_key.handle_auth(
            event=event,
            parsed_username=parsed_username,
            user_record=user_record,
            identity_provider_record=identity_provider_record,
            response_data=response_data,
            authn_method=authn_method,
        )
    return response_data
