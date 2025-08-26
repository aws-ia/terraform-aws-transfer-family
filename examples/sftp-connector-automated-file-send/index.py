import boto3
import os
import json

def handler(event, context):
    transfer_client = boto3.client('transfer')
    
    source_bucket = event['detail']['bucket']['name']
    source_key = event['detail']['object']['key']
    
    response = transfer_client.start_file_transfer(
        ConnectorId=os.environ['CONNECTOR_ID'],
        SendFilePaths=[f'/{source_bucket}/{source_key}']
    )
    
    print(f'Transfer started: {response["TransferId"]}')
    
    return {
        'statusCode': 200,
        'body': json.dumps('Transfer initiated')
    }
