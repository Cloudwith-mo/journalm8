import json
import os
import boto3
from typing import Dict, Any

bedrock_agent = boto3.client('bedrock-agent')

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Trigger Bedrock Knowledge Base ingestion when OCR processing completes.

    Args:
        event: SQS event containing OCR_COMPLETE messages
        context: Lambda context

    Returns:
        Dict with success status
    """
    knowledge_base_id = os.environ['KNOWLEDGE_BASE_ID']
    data_source_id = os.environ['DATA_SOURCE_ID']

    for record in event['Records']:
        try:
            # Parse the SQS message body
            message_body = json.loads(record['body'])
            print(f"Processing OCR complete event: {message_body}")

            # Extract document info from the message
            document_id = message_body.get('documentId')
            user_id = message_body.get('userId')

            if not document_id or not user_id:
                print(f"Missing documentId or userId in message: {message_body}")
                continue

            # Start ingestion job for the knowledge base
            response = bedrock_agent.start_ingestion_job(
                knowledgeBaseId=knowledge_base_id,
                dataSourceId=data_source_id,
                description=f"Sync document {document_id} for user {user_id}"
            )

            ingestion_job_id = response['ingestionJob']['ingestionJobId']
            print(f"Started ingestion job {ingestion_job_id} for document {document_id}")

        except Exception as e:
            print(f"Error processing record: {e}")
            # Continue processing other records even if one fails
            continue

    return {
        'statusCode': 200,
        'body': json.dumps('Knowledge base sync triggered successfully')
    }