import logging
import os
import json
import urllib
import re
import urllib3
from idp_modules import util
from aws_lambda_powertools import Tracer

tracer = Tracer()



logger = logging.getLogger(__name__)
logger.setLevel(util.get_log_level())


http = urllib3.PoolManager()


class OktaIdpModuleError(util.IdpModuleError):
    """Used to raise module-specific exceptions"""

    pass


@tracer.capture_method
def okta_authenticate(url, username, password, mfa_token=None):
    headers = {"Accept": "application/json", "Content-Type": "application/json"}

    body = json.dumps({"username": username, "password": password})

    primary_response: urllib3.HTTPResponse = http.request(
        method="POST", url=url, headers=headers, body=body
    )
    logger.debug(
        f"Okta API response: HTTP status code {primary_response.status}; Body: {primary_response.data.decode('utf-8')}"
    )

    if primary_response.status != 200:
        logger.error(
            f"Authentication failure: User: {username}; HTTP status code {primary_response.status}; Response: {primary_response.data.decode('utf-8')}"
        )
        raise OktaIdpModuleError(
            f"Authentication failure: User: {username}; Status code {primary_response.status}; Response: {primary_response.data.decode('utf-8')}"
        )

    primary_response_json = json.loads(primary_response.data)
    primary_response_status = primary_response_json.get("status", "<none>")
    primary_response_token = primary_response_json.get("stateToken", None)

    if primary_response_status == "SUCCESS":
        if not mfa_token is None:
            if primary_response_token is None:
                logger.error(
                    f"MFA token for user {username} was provided but no state token was returned in the Okta response. Verify MFA is enabled in Okta configuration or disable MFA in the IdP config."
                )
                raise OktaIdpModuleError(
                    f"Multi-factor authentication failed: Missing state token, check that Okta is configured for MFA or disable MFA in the IdP config."
                )
            else:
                logger.info("MFA token provided, will perform MFA.")
        else:
            logger.info(
                f"Authentication successful for {username} and MFA is not enabled, returning response."
            )
            return primary_response_json
    else:
        logger.warning(
            f"Authentication status was not SUCCESS for user {username}. Status returned: {primary_response_status}"
        )
        if primary_response_status == "MFA_REQUIRED":
            if not mfa_token is None:
                logger.info("MFA is required, will perform MFA")
            else:
                logger.error(
                    f"Okta indicated that MFA is required for this user {username} but no MFA token was provided. Verify that MFA has been enabled in the IdP config."
                )
                raise OktaIdpModuleError(
                    f"Multi-factor authentication failed: No MFA token was provided. Verify that MFA has been enabled in IdP config."
                )
        else:
            logger.error(
                f"Unexpected status response {primary_response_status}. Authentication was not considered successful for user {username}"
            )

    # If we've gotten to this point, MFA is required.
    mfa_factors = primary_response_json.get("_embedded", {}).get("factors", [])
    logger.debug(f"factors: {mfa_factors}")

    # Okta can return multiple factors, need to loop through them and try any that are token/TOTP based
    for mfa_factor in mfa_factors:
        if not "token" in mfa_factor.get("factorType", "").lower():
            continue
        mfa_body = json.dumps(
            {"stateToken": primary_response_token, "passCode": mfa_token}
        )
        mfa_url = mfa_factor.get("_links", {}).get("verify", {}).get("href", None)
        mfa_response = urllib3.HTTPResponse = http.request(
            method="POST", url=mfa_url, headers=headers, body=mfa_body
        )
        logger.debug(
            f"Okta MFA API response: HTTP status code {primary_response.status}; Body: {primary_response.data.decode('utf-8')}"
        )

        if mfa_response.status != 200:
            logger.warning(
                f"MFA failed for factor Id {mfa_factor.get('id', '')}; Type {mfa_factor.get('factorType', '')}; Provider {mfa_factor.get('provider', '')}"
            )
        else:
            mfa_response_status = primary_response_json.get("status", "<none>")
            if mfa_response_status == "SUCCESS":
                logger.warning(
                    f"MFA authentication status for was not SUCCESS for user {username}; factor Id {mfa_factor.get('id', '')}; Type {mfa_factor.get('factorType', '')}; Provider {mfa_factor.get('provider', '')}. Status returned: {mfa_response_status}. "
                )
            else:
                logger.info(
                    f"MFA authentication for username {username} was successful. Returning response."
                )
                return json.loads(mfa_response.data)

    # If we've not returned a response at this point, MFA has failed
    logger.error(
        f"Multi-factor authentication failed for user {username} after attempting all factors"
    )
    raise OktaIdpModuleError(
        f"Multi-factor authentication failed for user {username} after attempting all factors."
    )


@tracer.capture_method
def okta_token_exchange_oauth(url, session_token, client_id, redirect_uri):
    headers = {"Accept": "application/json", "Content-Type": "application/json"}
    logger.info(f"Authorization URL: {url}")
    fields = {
        "response_type": "id_token",
        "scope": "openid okta.users.read.self",
        "state": "authenticate",
        "nonce": "authenticatenonce",
        "prompt": "none",
        "client_id": f"{client_id}",
        "sessionToken": f"{session_token}",
        "redirect_uri": f"{redirect_uri}",
    }
    logger.debug(f"Request fields: {json.dumps(fields)}")
    token_exchange_response: urllib3.HTTPResponse = http.request(
        method="GET", url=url, fields=fields, headers=headers, body=None, redirect=False
    )
    logger.debug(
        f"Okta token exchange response: HTTP status code {token_exchange_response.status}; Body: {token_exchange_response.data.decode('utf-8')} Headers: {token_exchange_response.headers}"
    )

    if token_exchange_response.status != 302:
        logger.error(
            f"Session token exchange failure: HTTP status code {token_exchange_response.status}; Response: {token_exchange_response.data.decode('utf-8')} Headers: {token_exchange_response.headers}"
        )
        raise OktaIdpModuleError(
            f"Session token exchange failure: HTTP status code {token_exchange_response.status}; Response: {token_exchange_response.data.decode('utf-8')}"
        )

    parsed_redirect_query = urllib.parse.parse_qs(
        urllib3.util.parse_url(token_exchange_response.headers["location"]).query
    )

    if parsed_redirect_query.get("error", None) is not None:
        logger.error(
            f"Error obtaining session cookie from token exchange: {parsed_redirect_query.get('error', '')}: {parsed_redirect_query('error_description')}.  Session token exchange failure: HTTP status code {token_exchange_response.status}; Response: {token_exchange_response.data.decode('utf-8')} Headers: {token_exchange_response.headers}"
        )
        raise OktaIdpModuleError(
            f"Error obtaining session cookie from token exchange: {parsed_redirect_query.get('error', '')}: {parsed_redirect_query('error_description')}. Session token exchange failure: HTTP status code {token_exchange_response.status}; Response: {token_exchange_response.data.decode('utf-8')}"
        )

    logger.info("Parsing cookie from response")
    logger.debug(f"Cookies: {token_exchange_response.headers['set-cookie']}")
    sid = re.search(r"sid=.*?;", token_exchange_response.headers["set-cookie"])

    if sid is None:
        raise OktaIdpModuleError(
            f"Okta did not return a session cookie from the token exchange, unable to continue. Enable debug logging to review the HTTP response"
        )

    sid = sid.group(0)
    return sid


@tracer.capture_method
def okta_get_user(url, session_cookie):
    headers = {
        "Accept": "application/json",
        "Content-Type": "application/json",
        "Cookie": f"{session_cookie}",
    }
    logger.info(f"User URL: {url}")
    logger.debug(f"Headers: {headers}")
    user_info_response: urllib3.HTTPResponse = http.request(
        method="GET", url=url, headers=headers, body=None
    )
    logger.debug(
        f"Okta user API response: HTTP status code {user_info_response.status}; Body: {user_info_response.data.decode('utf-8')}; Headers: {user_info_response.headers}"
    )

    if user_info_response.status != 200:
        logger.error(
            f"Error retrieving user info: HTTP status code {user_info_response.status}; Response: {user_info_response.data.decode('utf-8')}"
        )
        raise OktaIdpModuleError(
            f"Error retrieving user info: HTTP status code {user_info_response.status}; Response: {user_info_response.data.decode('utf-8')}"
        )

    return json.loads(user_info_response.data)


# Not used, defined for future groups support
@tracer.capture_method
def okta_get_user_groups(url, session_cookie):
    headers = {
        "Accept": "application/json",
        "Content-Type": "application/json",
        "Cookie": f"{session_cookie}",
    }
    logger.info(f"Group URL: {url}")
    logger.debug(f"Headers: {headers}")
    user_groups_response: urllib3.HTTPResponse = http.request(
        method="GET", url=url, headers=headers, body=None
    )
    logger.debug(
        f"Okta API response: HTTP status code {user_groups_response.status}; Body: {user_groups_response.data.decode('utf-8')}; Headers: {user_groups_response.headers}"
    )

    if user_groups_response.status != 200:
        logger.error(
            f"Error retrieving group info: HTTP status code {user_groups_response.status}; Response: {user_groups_response.data.decode('utf-8')}"
        )
        raise OktaIdpModuleError(
            f"Error retrieving group info: HTTP status code {user_groups_response.status}; Response: {user_groups_response.data.decode('utf-8')}"
        )

    return json.loads(user_groups_response.data)


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

    if authn_method == util.AuthenticationMethod.PUBLIC_KEY:
        raise OktaIdpModuleError("This provider does not support public key auth.")

    user_record_config = user_record["config"]
    okta_domain = identity_provider_record["config"]["okta_domain"]
    okta_attributes = identity_provider_record["config"].get("attributes", {})
    okta_app_client_id = identity_provider_record["config"].get(
        "okta_app_client_id", None
    )
    okta_app_redirect_uri = identity_provider_record["config"].get(
        "okta_redirect_uri", "awstransfer:/callback"
    )
    okta_attributes = identity_provider_record["config"].get("attributes", {})
    okta_mfa = identity_provider_record["config"].get("mfa", False)
    okta_mfa_token_length = int(
        identity_provider_record["config"].get("mfa_token_length", 6)
    )
    okta_attributes = identity_provider_record["config"].get("attributes", {})
    okta_ignore_missing_attributes = identity_provider_record["config"].get(
        "ignore_missing_attributes", False
    )

    password = event["password"]

    okta_auth_url = f"https://{okta_domain}/api/v1/authn"
    okta_token_url = f"https://{okta_domain}/oauth2/v1/authorize"
    okta_user_profile_url = f"https://{okta_domain}/api/v1/users/me"
    okta_user_groups_url = f"https://{okta_domain}/api/v1/users/me/groups"

    if okta_mfa:
        logger.info(
            f"MFA enabled, extracting token code from last {okta_mfa_token_length} characters of provided password."
        )
        mfa_token = password[-okta_mfa_token_length:]
        password = password[:-okta_mfa_token_length]
    else:
        mfa_token = None

    logger.info(f"Attempting authentication with Okta API Server {okta_auth_url}")
    okta_auth_response = okta_authenticate(
        url=okta_auth_url,
        username=parsed_username,
        password=password,
        mfa_token=mfa_token,
    )
    okta_session_token = okta_auth_response["sessionToken"]

    if okta_attributes:
        logger.info(
            f"Attributes specified in identity provider configuration, setting up request to Okta."
        )
        if okta_app_client_id is None:
            raise OktaIdpModuleError(
                f"The identity provider configuration contains attributes to resolve from Okta, but okta_app_client_id is not in the identity_provider configuration. This MUST be set in order to retrieve the Okta application's client id and secret for querying user profile attributes. Please review documentation."
            )
        logger.info("Fetching Okta session cookie")
        session_cookie = okta_token_exchange_oauth(
            okta_token_url,
            okta_session_token,
            okta_app_client_id,
            okta_app_redirect_uri,
        )
        logger.info("Fetching user profile")
        okta_user_profile = okta_get_user(okta_user_profile_url, session_cookie).get(
            "profile", {}
        )
        logger.debug(f"user profile: {okta_user_profile}")

    logger.info(f"Resolving mapped attributes")
    # Normalize empty values to simplify checking if a value is missing or empty
    okta_resolved_attributes = {}
    for attribute in okta_attributes:
        value = okta_user_profile.get(okta_attributes[attribute], None)
        if not value is None and (type(value) == int or len(value) > 0):
            okta_resolved_attributes[attribute] = value
        else:
            okta_resolved_attributes[attribute] = None
    logger.debug(f"Resolved Okta user profile attributes: {okta_resolved_attributes}")

    if "Role" in okta_attributes:
        if not okta_resolved_attributes["Role"] is None:
            logger.info(
                f"Applying Role {okta_resolved_attributes['Role']} from Okta user profile attributes"
            )
            response_data["Role"] = okta_resolved_attributes["Role"]
        elif okta_ignore_missing_attributes:
            logger.warning(
                f"Okta user profile attribute '{okta_attributes['Role']}' for 'Role' was empty of missing. Skipping."
            )
        else:
            raise OktaIdpModuleError(
                f"Okta user profile attribute '{okta_attributes['Role']}' for property 'Role' was empty or missing. Enable debug logging adn check LDAP response. To ignore, use the ignore_missing_attributes setting in the identity provider config."
            )

    if "Policy" in okta_attributes:
        if not okta_resolved_attributes["Policy"] is None:
            logger.info("Applying Policy from Okta user profile attributes")
            response_data["Policy"] = okta_resolved_attributes["Policy"]
        elif okta_ignore_missing_attributes:
            logger.warning(
                f"Okta user profile attribute '{okta_attributes['Policy']}' for 'Policy' was empty of missing. Skipping."
            )
        else:
            raise OktaIdpModuleError(
                f"Okta user profile attribute '{okta_attributes['Policy']}' for property 'Policy' was empty or missing. Enable debug logging adn check LDAP response. To ignore, use the ignore_missing_attributes setting in the identity provider config."
            )

    if "Uid" in okta_attributes and "Gid" in okta_attributes:
        if (
            not okta_resolved_attributes["Uid"] is None
            and not okta_resolved_attributes["Gid"] is None
        ):
            logger.info(
                f"Applying PosixProfile {okta_attributes['Uid']},{okta_resolved_attributes['Gid']} from Okta user profile attributes"
            )
            response_data.setdefault("PosixProfile", {})
            response_data["PosixProfile"]["Uid"] = okta_resolved_attributes["Uid"]
            response_data["PosixProfile"]["Gid"] = okta_resolved_attributes["Gid"]
        elif okta_ignore_missing_attributes:
            logger.warning(
                f"Okta user profile attributes '{okta_attributes['Uid']}' for 'Uid' and/or '{okta_attributes['Gid']}' for 'Gid' were empty of missing. Skipping."
            )
        else:
            raise OktaIdpModuleError(
                f"Okta user profile attribute '{okta_attributes['Uid']}' for 'Uid' and/or '{okta_attributes['Gid']}'  for 'Gid' were empty or missing. Enable debug logging adn check LDAP response. To ignore, use the ignore_missing_attributes setting in the identity provider config."
            )

    return response_data
