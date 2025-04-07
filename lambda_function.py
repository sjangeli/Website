import boto3
import json

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('MyTable')

def lambda_handler(event, context):
    # Check if 'httpMethod' exists in the event
    if 'httpMethod' not in event:
        return {
            "statusCode": 400,
            "headers": {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE",
                "Access-Control-Allow-Headers": "Content-Type",
            },
            "body": json.dumps({
                "message": "Bad Request: Missing 'httpMethod' in the event object."
            })
        }

    # Handle CORS preflight requests
    if event['httpMethod'] == 'OPTIONS':
        return {
            "statusCode": 200,
            "headers": {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE",
                "Access-Control-Allow-Headers": "Content-Type",
            },
        }

    try:
        # Get the current record count from DynamoDB
        get_response = table.get_item(Key={'id': '0'})
        print(f"Response from DynamoDb: {get_response}")
        
        if 'Item' not in get_response:
            return {
                "statusCode": 404,
                "headers": {
                    "Access-Control-Allow-Origin": "*",
                    "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE",
                    "Access-Control-Allow-Headers": "Content-Type",
                },
                "body": json.dumps({
                    "message": "Record not found",
                })
            }
        
        current_record_count = get_response['Item']['count']
        print(f"Current record count: {current_record_count}")
        
        # Update the record count
        updated_record_count = current_record_count + 1
        print(f"Updated record count: {updated_record_count}")
        put_response = table.put_item(Item={'id': '0', 'count': updated_record_count})
        print(f"Response from DynamoDb: {put_response}")
        
        # Return success response
        response = {
            "statusCode": 200,
            "headers": {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "GET, OPTIONS",
                "Access-Control-Allow-Headers": "Content-Type,Authorization",
            },
            "body": json.dumps({
                "message": "Record updated successfully",
                "current_count": str(current_record_count),
                "updated_count": str(updated_record_count)
            })
        }
        print(f"Response: {response}")
        return response

    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            "statusCode": 500,
            "headers": {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE",
                "Access-Control-Allow-Headers": "Content-Type",
            },
            "body": json.dumps({
                "message": "Internal server error",
                "error": str(e)
            })
        }