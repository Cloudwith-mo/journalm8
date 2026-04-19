import json
import os
from datetime import datetime
from typing import Any, Dict, List, Optional

import boto3

bedrock_runtime = boto3.client("bedrock-runtime")

KNOWLEDGE_BASE_ID = os.environ["KNOWLEDGE_BASE_ID"]


def _extract_citations(response: Dict[str, Any]) -> List[Dict[str, Any]]:
    """Extract and format citations from RetrieveAndGenerate response."""
    citations = []
    
    retrieved_references = response.get("retrievedReferences", [])
    for idx, ref in enumerate(retrieved_references[:3]):  # Top 3
        source_uri = ref.get("location", {}).get("s3Location", {}).get("uri", "")
        metadata = ref.get("metadata", {})
        
        # Parse S3 URI to extract key
        s3_key = source_uri.replace("s3://", "").split("/", 1)[1] if "/" in source_uri else ""
        
        citation = {
            "index": idx + 1,
            "entryId": metadata.get("entryId"),
            "filename": metadata.get("filename"),
            "yearMonth": metadata.get("yearMonth"),
            "ocrConfidence": metadata.get("ocrConfidence"),
            "sourceS3Key": s3_key,
            "excerpt": ref.get("content", {}).get("text", "")[:200],  # First 200 chars
        }
        citations.append(citation)
    
    return citations


def _build_retrieval_filter(
    user_id: str,
    year_month: Optional[str] = None,
    min_ocr_confidence: Optional[float] = None,
) -> Dict[str, Any]:
    """Build Bedrock retrieval filter from parameters."""
    filters = [
        {
            "key": "userId",
            "value": user_id,
        }
    ]
    
    if year_month:
        filters.append({
            "key": "yearMonth",
            "value": year_month,
        })
    
    if min_ocr_confidence is not None:
        filters.append({
            "key": "ocrConfidence",
            "value": min_ocr_confidence,
            "operand": "gte",
        })
    
    return {
        "type": "DOCUMENT",
        "documentFilter": {
            "filters": filters,
        }
    } if len(filters) > 0 else {}


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    print(json.dumps(event))
    
    # Extract JWT claims from API Gateway authorizer
    authorizer = event.get("requestContext", {}).get("authorizer", {})
    user_id = authorizer.get("claims", {}).get("sub")
    
    if not user_id:
        return {
            "statusCode": 401,
            "body": json.dumps({"error": "Unauthorized: Missing user ID"}),
        }
    
    try:
        body = json.loads(event.get("body", "{}"))
    except json.JSONDecodeError:
        return {
            "statusCode": 400,
            "body": json.dumps({"error": "Invalid JSON body"}),
        }
    
    question = body.get("question", "").strip()
    if not question:
        return {
            "statusCode": 400,
            "body": json.dumps({"error": "Missing 'question' field"}),
        }
    
    year_month = body.get("yearMonth")  # Optional: "2026-03"
    min_ocr_confidence = body.get("minOcrConfidence")  # Optional: 0.7
    
    try:
        # Build retrieval filter
        retrieval_filter = _build_retrieval_filter(
            user_id=user_id,
            year_month=year_month,
            min_ocr_confidence=min_ocr_confidence,
        )
        
        # Call RetrieveAndGenerate
        response = bedrock_runtime.retrieve_and_generate(
            input={
                "text": question,
            },
            retrieveAndGenerateConfiguration={
                "type": "KNOWLEDGE_BASE",
                "knowledgeBaseConfiguration": {
                    "knowledgeBaseId": KNOWLEDGE_BASE_ID,
                    "modelArn": "arn:aws:bedrock:us-east-1::foundation-model/amazon.nova-lite-v1:0",
                    "retrievalConfiguration": {
                        "vectorSearchConfiguration": {
                            "numberOfResults": 5,
                            "overrideSearchType": "SEMANTIC",
                        },
                    },
                    "generationConfiguration": {
                        "additionalModelRequestFields": {
                            "max_tokens": 1024,
                        },
                    },
                    **({"retrievalFilter": retrieval_filter} if retrieval_filter else {}),
                },
            },
        )
        
        answer = response.get("output", {}).get("text", "")
        citations = _extract_citations(response)
        
        return {
            "statusCode": 200,
            "body": json.dumps({
                "answer": answer,
                "citations": citations,
                "userId": user_id,
                "filters": {
                    "yearMonth": year_month,
                    "minOcrConfidence": min_ocr_confidence,
                },
            }),
            "headers": {
                "Content-Type": "application/json",
            },
        }
    
    except Exception as exc:
        print(f"Error querying knowledge base: {exc}")
        return {
            "statusCode": 500,
            "body": json.dumps({"error": f"Knowledge base query failed: {str(exc)}"}),
        }
