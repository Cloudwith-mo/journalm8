#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REGION="us-east-1"
USER_POOL_ID="us-east-1_bJcMC6yDw"
CLIENT_ID="4d7p90ejov0chl7sohp4nv856j"
API_ENDPOINT="https://iq1gf00t2a.execute-api.us-east-1.amazonaws.com"
RAW_BUCKET="journalm8-dev-raw-114743615542-us-east-1"
PROCESSED_BUCKET="journalm8-dev-processed-114743615542-us-east-1"
INGESTION_TABLE="journalm8-dev-ingestion-jobs"
JOURNAL_TABLE="journalm8-dev-journal-entries"

# Test user credentials
TEST_EMAIL="testuser-$(date +%s)@example.com"
TEST_PASSWORD="TestPass123!"

# Test results tracking
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

log_test() {
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo -e "${BLUE}[TEST $TOTAL_TESTS]${NC} $1"
}

log_pass() {
    PASSED_TESTS=$((PASSED_TESTS + 1))
    echo -e "${GREEN}✓ PASS:${NC} $1"
    echo ""
}

log_fail() {
    FAILED_TESTS=$((FAILED_TESTS + 1))
    echo -e "${RED}✗ FAIL:${NC} $1"
    echo -e "${RED}Details:${NC} $2"
    echo ""
}

log_info() {
    echo -e "${YELLOW}ℹ INFO:${NC} $1"
}

log_info() {
    echo -e "${YELLOW}ℹ INFO:${NC} $1"
}

echo "=========================================="
echo "  JOURNALM8 END-TO-END VALIDATION"
echo "=========================================="
echo ""
echo "Test User: $TEST_EMAIL"
echo "Region: $REGION"
echo "API: $API_ENDPOINT"
echo ""

# Check if images exist
log_info "Checking for test images..."
if [ ! -f "IMG_0190_small2.jpg" ] || [ ! -f "IMG_0191_small2.jpg" ] || [ ! -f "IMG_0200_small2.jpg" ]; then
    echo -e "${RED}ERROR: Test images not found!${NC}"
    echo "Please place the following files in this directory:"
    echo "  - IMG_0190_small2.jpg"
    echo "  - IMG_0191_small2.jpg"
    echo "  - IMG_0200_small2.jpg"
    exit 1
fi
log_pass "All test images found"

# ==========================================
# PHASE 1: AUTHENTICATION
# ==========================================
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}PHASE 1: AUTHENTICATION${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""

log_test "Sign up new user"
SIGNUP_RESULT=$(aws cognito-idp sign-up \
  --region $REGION \
  --client-id $CLIENT_ID \
  --username $TEST_EMAIL \
  --password $TEST_PASSWORD \
  --user-attributes Name=email,Value=$TEST_EMAIL 2>&1)

if [ $? -eq 0 ]; then
    USER_SUB=$(echo "$SIGNUP_RESULT" | jq -r '.UserSub')
    if [ "$USER_SUB" != "null" ] && [ -n "$USER_SUB" ]; then
        log_pass "User created with sub: $USER_SUB"
    else
        log_fail "User created but no UserSub returned" "$SIGNUP_RESULT"
    fi
else
    log_fail "Sign-up failed" "$SIGNUP_RESULT"
    exit 1
fi

log_test "Confirm user account"
CONFIRM_RESULT=$(aws cognito-idp admin-confirm-sign-up \
  --region $REGION \
  --user-pool-id $USER_POOL_ID \
  --username $TEST_EMAIL 2>&1)

if [ $? -eq 0 ]; then
    log_pass "User confirmed"
else
    log_fail "User confirmation failed" "$CONFIRM_RESULT"
    exit 1
fi

log_test "Sign in and obtain tokens"
AUTH_RESULT=$(aws cognito-idp admin-initiate-auth \
  --region $REGION \
  --user-pool-id $USER_POOL_ID \
  --client-id $CLIENT_ID \
  --auth-flow ADMIN_NO_SRP_AUTH \
  --auth-parameters USERNAME=$TEST_EMAIL,PASSWORD=$TEST_PASSWORD 2>&1)

if [ $? -eq 0 ]; then
    ID_TOKEN=$(echo "$AUTH_RESULT" | jq -r '.AuthenticationResult.IdToken')
    ACCESS_TOKEN=$(echo "$AUTH_RESULT" | jq -r '.AuthenticationResult.AccessToken')
    
    if [ "$ID_TOKEN" != "null" ] && [ -n "$ID_TOKEN" ]; then
        log_pass "Tokens obtained successfully"
        log_info "ID Token (first 50 chars): ${ID_TOKEN:0:50}..."
    else
        log_fail "Sign-in succeeded but no tokens returned" "$AUTH_RESULT"
        exit 1
    fi
else
    log_fail "Sign-in failed" "$AUTH_RESULT"
    exit 1
fi

# ==========================================
# PHASE 2: PRESIGNED URL REQUEST
# ==========================================
echo ""
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}PHASE 2: PRESIGNED URL REQUEST${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""

declare -a IMAGES=("IMG_0190_small2.jpg" "IMG_0191_small2.jpg" "IMG_0200_small2.jpg")
declare -A PRESIGNED_URLS
declare -A ENTRY_IDS
declare -A OBJECT_KEYS

for IMAGE in "${IMAGES[@]}"; do
  log_test "Request presigned URL for $IMAGE"
  
  PRESIGN_RESPONSE=$(curl -s -X POST \
    "$API_ENDPOINT/uploads/presign" \
    -H "Authorization: Bearer $ID_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"filename\":\"$IMAGE\",\"contentType\":\"image/jpeg\"}")
  
  UPLOAD_URL=$(echo "$PRESIGN_RESPONSE" | jq -r '.uploadUrl // empty')
  ENTRY_ID=$(echo "$PRESIGN_RESPONSE" | jq -r '.entryId // empty')
  OBJECT_KEY=$(echo "$PRESIGN_RESPONSE" | jq -r '.key // empty')
  
  if [ -n "$UPLOAD_URL" ] && [ "$UPLOAD_URL" != "null" ]; then
    PRESIGNED_URLS[$IMAGE]=$UPLOAD_URL
    ENTRY_IDS[$IMAGE]=$ENTRY_ID
    OBJECT_KEYS[$IMAGE]=$OBJECT_KEY
    log_pass "Presigned URL received for $IMAGE"
    log_info "Entry ID: $ENTRY_ID"
    log_info "Object Key: $OBJECT_KEY"
  else
    log_fail "No upload URL received for $IMAGE" "$PRESIGN_RESPONSE"
    exit 1
  fi
done

# ==========================================
# PHASE 3: UPLOAD VIA PRESIGNED URL
# ==========================================
echo ""
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}PHASE 3: UPLOAD VIA PRESIGNED URL${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""

for IMAGE in "${IMAGES[@]}"; do
  log_test "Upload $IMAGE via presigned URL"
  
  UPLOAD_RESULT=$(curl -s -w "\n%{http_code}" -X PUT \
    "${PRESIGNED_URLS[$IMAGE]}" \
    -H "Content-Type: image/jpeg" \
    --data-binary "@$IMAGE")
  
  HTTP_CODE=$(echo "$UPLOAD_RESULT" | tail -n1)
  
  if [ "$HTTP_CODE" == "200" ]; then
    log_pass "Upload successful for $IMAGE (HTTP 200)"
  else
    log_fail "Upload failed for $IMAGE (HTTP $HTTP_CODE)" "$UPLOAD_RESULT"
    exit 1
  fi
  
  log_test "Verify S3 object exists for $IMAGE"
  sleep 2
  
  S3_CHECK=$(aws s3 ls "s3://$RAW_BUCKET/${OBJECT_KEYS[$IMAGE]}" 2>&1)
  
  if [ $? -eq 0 ]; then
    log_pass "Object exists in S3: ${OBJECT_KEYS[$IMAGE]}"
  else
    log_fail "Object not found in S3" "$S3_CHECK"
  fi
done

# ==========================================
# PHASE 4: AUTOMATIC PROCESSING
# ==========================================
echo ""
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}PHASE 4: AUTOMATIC PROCESSING${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""

log_info "Waiting 30 seconds for S3 event triggers..."
sleep 30

for IMAGE in "${IMAGES[@]}"; do
  ENTRY_ID=${ENTRY_IDS[$IMAGE]}
  
  log_test "Check DynamoDB ingestion job for $IMAGE (entryId: $ENTRY_ID)"
  
  JOB_RECORD=$(aws dynamodb scan \
    --table-name $INGESTION_TABLE \
    --filter-expression "entryId = :eid" \
    --expression-attribute-values "{\": eid\":{\"S\":\"$ENTRY_ID\"}}" \
    --region $REGION 2>&1)
  
  if echo "$JOB_RECORD" | grep -q "Items" && [ $(echo "$JOB_RECORD" | jq '.Items | length') -gt 0 ]; then
    JOB_STATUS=$(echo "$JOB_RECORD" | jq -r '.Items[0].status.S // "UNKNOWN"')
    log_pass "Ingestion job record found for $IMAGE"
    log_info "Job Status: $JOB_STATUS"
  else
    log_fail "No ingestion job record found for $IMAGE" "$JOB_RECORD"
  fi
done

log_info "Waiting 60 seconds for OCR processing to complete..."
sleep 60

log_info "Waiting 60 seconds for OCR processing to complete..."
sleep 60

# ==========================================
# PHASE 5: DATA VALIDATION & OCR QUALITY
# ==========================================
echo ""
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}PHASE 5: DATA VALIDATION & OCR QUALITY${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""

for IMAGE in "${IMAGES[@]}"; do
  ENTRY_ID=${ENTRY_IDS[$IMAGE]}
  
  log_test "Check processed outputs for $IMAGE"
  
  PROCESSED_PREFIX="users/$USER_SUB/processed/$ENTRY_ID/"
  PROCESSED_FILES=$(aws s3 ls "s3://$PROCESSED_BUCKET/$PROCESSED_PREFIX" --recursive 2>&1)
  
  if [ $? -eq 0 ] && [ -n "$PROCESSED_FILES" ]; then
    log_pass "Processed files found for $IMAGE"
    echo "$PROCESSED_FILES" | sed 's/^/  /'
  else
    log_fail "No processed files found for $IMAGE" "$PROCESSED_FILES"
  fi
  
  log_test "Check DynamoDB journal entry for $IMAGE"
  
  JOURNAL_RECORD=$(aws dynamodb get-item \
    --region $REGION \
    --table-name $JOURNAL_TABLE \
    --key "{\"pk\":{\"S\":\"USER#$USER_SUB\"},\"sk\":{\"S\":\"ENTRY#$ENTRY_ID\"}}" \
    --output json 2>&1)
  
  if echo "$JOURNAL_RECORD" | grep -q "Item"; then
    log_pass "Journal entry record found for $IMAGE"
    
    # Download OCR text
    CLEAN_TEXT_KEY="users/$USER_SUB/processed/$ENTRY_ID/clean.txt"
    OUTPUT_FILE="ocr_output_${IMAGE}.txt"
    
    aws s3 cp "s3://$PROCESSED_BUCKET/$CLEAN_TEXT_KEY" "$OUTPUT_FILE" 2>&1 > /dev/null
    
    if [ -f "$OUTPUT_FILE" ]; then
      OCR_TEXT=$(cat "$OUTPUT_FILE")
      CHAR_COUNT=$(echo "$OCR_TEXT" | wc -c | tr -d ' ')
      LINE_COUNT=$(echo "$OCR_TEXT" | wc -l | tr -d ' ')
      
      log_pass "OCR text extracted for $IMAGE"
      log_info "Character count: $CHAR_COUNT"
      log_info "Line count: $LINE_COUNT"
      log_info "Output saved to: $OUTPUT_FILE"
      echo ""
      echo -e "${BLUE}First 300 characters:${NC}"
      echo "${OCR_TEXT:0:300}..."
      echo ""
    else
      log_fail "Could not download OCR text for $IMAGE" ""
    fi
  else
    log_fail "No journal entry record found for $IMAGE" "$JOURNAL_RECORD"
  fi
  echo ""
done

# ==========================================
# PHASE 6: NEGATIVE TESTS
# ==========================================
echo ""
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}PHASE 6: NEGATIVE TESTS${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""

log_test "Request presigned URL without token (should fail with 401)"
INVALID_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
  "$API_ENDPOINT/uploads/presign" \
  -H "Content-Type: application/json" \
  -d '{"filename":"test.jpg","contentType":"image/jpeg"}')

HTTP_CODE=$(echo "$INVALID_RESPONSE" | tail -n1)

if [ "$HTTP_CODE" == "401" ] || [ "$HTTP_CODE" == "403" ]; then
  log_pass "Unauthorized request correctly rejected (HTTP $HTTP_CODE)"
else
  log_fail "Expected 401/403, got HTTP $HTTP_CODE" "$INVALID_RESPONSE"
fi

log_test "Request presigned URL with unsupported content type (should fail with 400)"
UNSUPPORTED_RESPONSE=$(curl -s -X POST \
  "$API_ENDPOINT/uploads/presign" \
  -H "Authorization: Bearer $ID_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"filename":"test.txt","contentType":"text/plain"}')

if echo "$UNSUPPORTED_RESPONSE" | grep -qi "unsupported"; then
  log_pass "Unsupported content type correctly rejected"
else
  log_fail "Unsupported content type not rejected properly" "$UNSUPPORTED_RESPONSE"
fi

# ==========================================
# FINAL SUMMARY
# ==========================================
echo ""
echo "=========================================="
echo -e "${GREEN}  VALIDATION COMPLETE${NC}"
echo "=========================================="
echo ""
echo "Total Tests: $TOTAL_TESTS"
echo -e "${GREEN}Passed: $PASSED_TESTS${NC}"
echo -e "${RED}Failed: $FAILED_TESTS${NC}"
echo ""
echo "Test User: $TEST_EMAIL"
echo "User Sub: $USER_SUB"
echo ""
echo "OCR Output Files:"
for IMAGE in "${IMAGES[@]}"; do
  if [ -f "ocr_output_${IMAGE}.txt" ]; then
    echo -e "  ${GREEN}✓${NC} ocr_output_${IMAGE}.txt"
  else
    echo -e "  ${RED}✗${NC} ocr_output_${IMAGE}.txt (missing)"
  fi
done
echo ""

if [ $FAILED_TESTS -eq 0 ]; then
  echo -e "${GREEN}========================================${NC}"
  echo -e "${GREEN}  ✓ GO: All tests passed!${NC}"
  echo -e "${GREEN}========================================${NC}"
  echo ""
  echo "Next steps:"
  echo "1. Review OCR output files for quality"
  echo "2. Compare extracted text against actual journal images"
  echo "3. Verify OCR accuracy > 85%"
  echo "4. If OCR quality is good, proceed with frontend development"
  exit 0
else
  echo -e "${RED}========================================${NC}"
  echo -e "${RED}  ✗ NO-GO: $FAILED_TESTS test(s) failed${NC}"
  echo -e "${RED}========================================${NC}"
  echo ""
  echo "Action required:"
  echo "1. Review failed tests above"
  echo "2. Check CloudWatch logs for errors"
  echo "3. Fix root causes"
  echo "4. Re-run validation"
  echo "5. Do not proceed until all tests pass"
  exit 1
fi
