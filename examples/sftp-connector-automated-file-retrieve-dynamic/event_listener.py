import json
import boto3
import os
import logging
from datetime import datetime

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    """
    Poll Transfer Family results and update DynamoDB status
    This function is triggered by EventBridge Scheduler to check transfer status
    """
    try:
        transfer_client = boto3.client('transfer')
        dynamodb = boto3.resource('dynamodb')
        
        table_name = os.environ.get('DYNAMODB_TABLE')
        if not table_name:
            logger.warning("DYNAMODB_TABLE environment variable not set")
            return {'statusCode': 200, 'body': 'DynamoDB not configured'}
        
        table = dynamodb.Table(table_name)
        
        # Get all pending transfers from DynamoDB
        response = table.scan(
            FilterExpression='#status IN (:started, :discovery)',
            ExpressionAttributeNames={'#status': 'status'},
            ExpressionAttributeValues={
                ':started': 'TRANSFER_STARTED',
                ':discovery': 'DISCOVERY_COMPLETED'
            }
        )
        
        pending_transfers = response.get('Items', [])
        logger.info(f"Found {len(pending_transfers)} pending transfers to check")
        
        for transfer in pending_transfers:
            batch_id = transfer['batch_id']
            transfer_id = transfer.get('transfer_id')
            connector_id = transfer.get('connector_id')
            
            if not transfer_id or not connector_id:
                logger.warning(f"Missing transfer_id or connector_id for batch {batch_id}")
                continue
            
            try:
                # Check transfer results
                results_response = transfer_client.list_file_transfer_results(
                    ConnectorId=connector_id,
                    TransferId=transfer_id
                )
                
                # Analyze results
                file_results = results_response.get('FileTransferResults', [])
                total_files = len(file_results)
                successful_files = [f for f in file_results if f.get('StatusCode') == 'COMPLETED']
                failed_files = [f for f in file_results if f.get('StatusCode') == 'FAILED']
                
                logger.info(f"Transfer {transfer_id}: {len(successful_files)} successful, {len(failed_files)} failed out of {total_files} total")
                
                # Determine overall status
                if len(failed_files) == 0 and len(successful_files) > 0:
                    new_status = 'COMPLETED'
                elif len(failed_files) > 0:
                    new_status = 'PARTIALLY_FAILED' if len(successful_files) > 0 else 'FAILED'
                else:
                    # Still in progress
                    continue
                
                # Update DynamoDB
                update_data = {
                    'status': new_status,
                    'updated_at': datetime.utcnow().isoformat(),
                    'completed_at': datetime.utcnow().isoformat(),
                    'files_successful': len(successful_files),
                    'files_failed': len(failed_files),
                    'files_total': total_files
                }
                
                # Add error details if any failures
                if failed_files:
                    error_messages = [f.get('Failure', {}).get('Message', 'Unknown error') for f in failed_files]
                    update_data['error_messages'] = error_messages
                
                # Update the batch record
                update_expression = 'SET ' + ', '.join([f'#{k} = :{k}' if k == 'status' else f'{k} = :{k}' for k in update_data.keys()])
                expression_values = {f':{k}': v for k, v in update_data.items()}
                expression_names = {'#status': 'status'} if 'status' in update_data else {}
                
                update_params = {
                    'Key': {'batch_id': batch_id},
                    'UpdateExpression': update_expression,
                    'ExpressionAttributeValues': expression_values
                }
                
                if expression_names:
                    update_params['ExpressionAttributeNames'] = expression_names
                
                table.update_item(**update_params)
                
                logger.info(f"Updated batch {batch_id} status to {new_status}")
                
            except Exception as e:
                logger.error(f"Error checking transfer {transfer_id}: {str(e)}")
                continue
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Transfer status check completed',
                'transfers_checked': len(pending_transfers)
            })
        }
        
    except Exception as e:
        logger.error(f"Error in status checker: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
