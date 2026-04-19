data "aws_caller_identity" "current" {}

# OpenSearch Serverless collection for vector storage
resource "aws_opensearchserverless_collection" "journal_kb" {
  name = "${var.project_name}-${var.environment}-journal"
  type = "VECTORSEARCH"
  tags = var.tags
}

# OpenSearch network security policy
resource "aws_opensearchserverless_security_policy" "journal_kb_network" {
  name        = "${var.project_name}-${var.environment}-journal-network"
  type        = "network"
  description = "Network policy for Knowledge Base collection"
  policy = jsonencode([
    {
      Rules = [
        {
          ResourceType = "collection"
          Resource     = ["collection/${aws_opensearchserverless_collection.journal_kb.name}"]
        }
      ]
      AllowFromPublic = true
    }
  ])
}

# OpenSearch encryption security policy
resource "aws_opensearchserverless_security_policy" "journal_kb_encryption" {
  name        = "${var.project_name}-${var.environment}-journal-encryption"
  type        = "encryption"
  description = "Encryption policy for Knowledge Base collection"
  policy = jsonencode({
    Rules = [
      {
        ResourceType = "collection"
        Resource     = ["collection/${aws_opensearchserverless_collection.journal_kb.name}"]
      }
    ]
    AWSOwnedKeyPolicy = "AlwaysUseOwnAWSManagedKey"
  })
}

# Data access policy for Bedrock
resource "aws_opensearchserverless_access_policy" "journal_kb_bedrock" {
  name = "${var.project_name}-${var.environment}-journal-bedrock"
  type = "data"
  policy = jsonencode([
    {
      Rules = [
        {
          ResourceType = "collection"
          Resource     = ["collection/${aws_opensearchserverless_collection.journal_kb.name}"]
          Permission = [
            "aoss:CreateIndex",
            "aoss:DescribeIndex",
            "aoss:ReadDocument",
            "aoss:WriteDocument",
            "aoss:UpdateIndex"
          ]
        },
        {
          ResourceType = "index"
          Resource     = ["index/${aws_opensearchserverless_collection.journal_kb.name}/*"]
          Permission = [
            "aoss:CreateIndex",
            "aoss:DescribeIndex",
            "aoss:ReadDocument",
            "aoss:WriteDocument",
            "aoss:UpdateIndex"
          ]
        }
      ]
      Principal = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/AmazonBedrockExecutionRoleForKnowledgeBase_*"
      ]
    }
  ])
}

# IAM role for Bedrock Knowledge Base
data "aws_iam_policy_document" "bedrock_kb_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["bedrock.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "bedrock_kb" {
  name               = "${var.project_name}-${var.environment}-bedrock-kb-role"
  assume_role_policy = data.aws_iam_policy_document.bedrock_kb_assume_role.json
  tags               = var.tags
}

# IAM policy for KB to access S3 and OpenSearch
data "aws_iam_policy_document" "bedrock_kb_inline" {
  statement {
    sid    = "AllowReadProcessedBucket"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket"
    ]
    resources = [
      var.processed_bucket_arn,
      "${var.processed_bucket_arn}/*"
    ]
  }

  statement {
    sid    = "AllowBedrockEmbeddings"
    effect = "Allow"
    actions = [
      "bedrock:InvokeModel"
    ]
    resources = [
      "arn:aws:bedrock:${var.aws_region}::foundation-model/amazon.titan-embed-text-v2:0"
    ]
  }

  statement {
    sid    = "AllowOpenSearchAccess"
    effect = "Allow"
    actions = [
      "aoss:APIAccessAll"
    ]
    resources = [
      "arn:aws:aoss:${var.aws_region}:${data.aws_caller_identity.current.account_id}:collection/${aws_opensearchserverless_collection.journal_kb.collection_id}"
    ]
  }
}

resource "aws_iam_role_policy" "bedrock_kb" {
  name   = "${var.project_name}-${var.environment}-bedrock-kb-inline"
  role   = aws_iam_role.bedrock_kb.id
  policy = data.aws_iam_policy_document.bedrock_kb_inline.json
}

# Bedrock Knowledge Base
resource "aws_bedrockagent_knowledge_base" "journal" {
  name            = "${var.project_name}-${var.environment}-journal"
  role_arn        = aws_iam_role.bedrock_kb.arn
  knowledge_base_configuration {
    type = "VECTOR"
    vector_knowledge_base_configuration {
      embedding_model_arn = "arn:aws:bedrock:${var.aws_region}::foundation-model/amazon.titan-embed-text-v2:0"
      embeddings_dimension = 1024
    }
  }

  storage_configuration {
    type = "OPENSEARCH_SERVERLESS"
    opensearch_serverless_configuration {
      collection_arn = aws_opensearchserverless_collection.journal_kb.arn
      vector_index_name = "journal-index"
      field_mapping {
        vector_field = "bedrock_kb_default_vector"
        text_field = "bedrock_kb_default_text"
        metadata_field = "bedrock_kb_default_metadata"
      }
    }
  }

  tags = var.tags

  depends_on = [
    aws_opensearchserverless_access_policy.journal_kb_bedrock
  ]
}

# Data source: S3 with clean.txt files
resource "aws_bedrockagentagent_data_source" "journal_processed" {
  knowledge_base_id = aws_bedrock_knowledge_base.journal.id
  name              = "${var.project_name}-${var.environment}-processed-documents"
  
  data_source_configuration {
    type = "S3"
    s3_configuration {
      bucket_arn = var.processed_bucket_arn
      inclusion_prefixes = ["users/"]
      
      # Include only clean.txt and clean.txt.metadata.json
      inclusion_patterns = [
        "*.txt",
        "*.txt.metadata.json"
      ]

      # Exclude OCR JSON files and other artifacts
      exclusion_patterns = [
        "*.json"
      ]
    }
  }

  tags = var.tags
}

# Initial ingestion job (optional - can trigger manually or via Lambda)
resource "aws_bedrock_ingestion_job" "journal_initial" {
  knowledge_base_id = aws_bedrock_knowledge_base.journal.id
  data_source_id    = aws_bedrock_data_source.journal_processed.id
  
  # Initial sync to index existing processed documents
  depends_on = [aws_bedrock_data_source.journal_processed]
}
