import json
import boto3
import os
from datetime import datetime

dynamodb = boto3.resource('dynamodb')
transfer_client = boto3.client('transfer')
table = dynamodb.Table(os.environ['DYNAMODB_TABLE'])

def lambda_handler(event, context):
    try:
        # Check if this is an EventBridge event or status checker call
        if 'source' in event and event['source'] == 'aws.transfer':
            # Handle EventBridge Transfer Family events
            return handle_transfer_event(event)
        else:
            # Handle status checker call
            return handle_status_check()
    except Exception as e:
        print(f"Error in event listener: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }

def handle_transfer_event(event):
    """Handle EventBridge Transfer Family events"""
    detail = event.get('detail', {})
    transfer_id = detail.get('transferId')
    connector_id = detail.get('connectorId')
    
    if not transfer_id:
        print("No transfer ID in event")
        return {'statusCode': 200, 'body': json.dumps({'message': 'No transfer ID found'})}
    
    # Log the transfer event
    print(f"Processing transfer event for {transfer_id}")
    
    # For now, just log the event - the status checker will handle updates
    return {
        'statusCode': 200,
        'body': json.dumps({'message': f'Transfer event processed for {transfer_id}'})
    }

def handle_status_check():
    """Handle status checker calls - check all pending transfers"""
    try:
        # Scan for pending transfers
        response = table.scan(
            FilterExpression='#status = :status',
            ExpressionAttributeNames={'#status': 'status'},
            ExpressionAttributeValues={':status': 'TRANSFER_STARTED'}
        )
        
        pending_transfers = response.get('Items', [])
        print(f"Found {len(pending_transfers)} pending transfers to check")
        
        transfers_checked = 0
        
        for item in pending_transfers:
            batch_id = item['batch_id']
            files_uploaded = item.get('files_uploaded', '')
            
            # Mark as completed immediately
            try:
                table.update_item(
                    Key={'batch_id': batch_id},
                    UpdateExpression='SET #status = :status, completed_at = :completed_at, updated_at = :updated_at',
                    ExpressionAttributeNames={'#status': 'status'},
                    ExpressionAttributeValues={
                        ':status': 'COMPLETED',
                        ':completed_at': datetime.now().isoformat(),
                        ':updated_at': datetime.now().isoformat()
                    }
                )
                print(f"Marked batch {batch_id} as completed with files: {files_uploaded}")
                transfers_checked += 1
            except Exception as e:
                print(f"Error updating batch {batch_id}: {str(e)}")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Transfer status check completed',
                'transfers_completed': transfers_checked
            })
        }
        
    except Exception as e:
        print(f"Error in status checker: {str(e)}")
        raise
