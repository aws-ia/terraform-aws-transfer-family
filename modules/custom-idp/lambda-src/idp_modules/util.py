import base64
import logging
import os
import datetime
import boto3
import random
from botocore.config import Config
from botocore.exceptions import ClientError
from enum import Enum

from aws_lambda_powertools import Tracer

tracer = Tracer()

@tracer.capture_method
def get_log_level():
    return logging.DEBUG if os.environ.get("LOGLEVEL", "INFO").upper() == "DEBUG" else logging.INFO

logger = logging.getLogger(__name__)
logger.setLevel(get_log_level())

boto3_config = Config(retries={"max_attempts": 5, "mode": "standard"}, connect_timeout=5)


class IdpModuleError(Exception):
    """Used to raise IdP module exceptions"""

    pass

class AuthenticationMethod(Enum):
    PASSWORD = 1
    PUBLIC_KEY = 2

@tracer.capture_method
def get_secret(secret_id):
    client = boto3.session.Session().client(
        service_name="secretsmanager", config=boto3_config
    )

    try:
        resp = client.get_secret_value(SecretId=secret_id)
        # Decrypts secret using the associated KMS CMK.
        # Depending on whether the secret is a string or binary, one of these fields will be populated.
        if "SecretString" in resp:
            logger.info("Found Secret String")
            return resp["SecretString"]
        else:
            logger.info("Found Binary Secret")
            return base64.b64decode(resp["SecretBinary"])
    except ClientError as err:
        logger.error(
            f'Error Talking to SecretsManager: {err.response["Error"]["Code"]}, Message: {str(err)}'
        )
        return None


@tracer.capture_method
def get_transfer_server_details(server_id):
    client = boto3.session.Session().client(
        service_name="transfer", config=boto3_config
    )

    try:
        resp = client.describe_server(ServerId=server_id)
        return resp
    except ClientError as err:
        logger.error(
            f'Error Talking to AWS Transfer API: {err.response["Error"]["Code"]}, Message: {str(err)}'
        )
        return None


@tracer.capture_method
def fetch_cache(cache, key, exp_time, jitter=120):
    if cache.get(key, None) is None or (
        datetime.datetime.now()
        - cache.get(key, {}).get("timestamp", datetime.datetime.fromtimestamp(0))
    ).seconds > exp_time + random.randint(0, jitter):
        logger.debug(f"Cache for {key} does not exist or is expired. Returning None")
        return None
    else:
        logger.debug(f"Using cached value for {key}")

    return cache[key]["value"]


@tracer.capture_method
def set_cache(cache, key, value):
    if cache is None:
        cache = {}
    logger.debug(f"Setting value for key {key} in cache")
    cache[key] = {
        "value": value,
        "timestamp": datetime.datetime.now(),
    }
    return cache


@tracer.capture_method
def fetch_secret_cache(secret_cache, secret_arn, exp_time=60):
    if fetch_cache(secret_cache, secret_arn, exp_time) is None:
        logger.info(f"Fetching secret {secret_arn}")
        set_cache(secret_cache, secret_arn, get_secret(secret_arn))
    return secret_cache[secret_arn]["value"]