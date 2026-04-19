# MANUAL END-TO-END VALIDATION INSTRUCTIONS

## STEP 1: PREPARE TEST IMAGES

Save the three attached journal images to this directory:
```
/Users/muhammadadeyemi/journalm8/journalm8/test-data/
```

Files needed:
- IMG_0190_small2.jpg
- IMG_0191_small2.jpg
- IMG_0200_small2.jpg

Verify they are in place:
```bash
cd /Users/muhammadadeyemi/journalm8/journalm8/test-data
ls -lh *.jpg
```

---

## STEP 2: RUN AUTOMATED TEST SCRIPT

Make the script executable and run it:
```bash
chmod +x e2e-validation.sh
./e2e-validation.sh
```

The script will:
1. Create a new test user
2. Sign in and get tokens
3. Request presigned URLs for all 3 images
4. Upload all 3 images
5. Wait for automatic processing
6. Check DynamoDB records
7. Extract OCR text to files
8. Run negative tests

---

## STEP 3: REVIEW RESULTS

After the script completes, review the OCR output files:
```bash
cat ocr_output_IMG_0190_small2.jpg.txt
cat ocr_output_IMG_0191_small2.jpg.txt
cat ocr_output_IMG_0200_small2.jpg.txt
```

Compare the extracted text against the actual journal images to assess OCR quality.

---

## STEP 4: CHECK CLOUDWATCH LOGS (if needed)

If any step fails, check the Lambda logs:

### Start Ingestion Lambda:
```bash
aws logs tail /aws/lambda/journalm8-dev-start-ingestion --follow --region us-east-1
```

### OCR Lambda:
```bash
aws logs tail /aws/lambda/journalm8-dev-ocr-document --follow --region us-east-1
```

---

## STEP 5: CHECK STEP FUNCTIONS (if needed)

View recent executions:
```bash
aws stepfunctions list-executions \
  --state-machine-arn arn:aws:states:us-east-1:114743615542:stateMachine:journalm8-dev-journal-ingestion \
  --max-results 10 \
  --region us-east-1
```

Get execution details:
```bash
aws stepfunctions describe-execution \
  --execution-arn <EXECUTION_ARN> \
  --region us-east-1
```

---

## STEP 6: MANUAL VERIFICATION (if automated script fails)

If the automated script doesn't work, follow these manual steps:

### 6.1: Create Test User
```bash
TEST_EMAIL="testuser-$(date +%s)@example.com"
TEST_PASSWORD="TestPass123!"

aws cognito-idp sign-up \
  --region us-east-1 \
  --client-id 4d7p90ejov0chl7sohp4nv856j \
  --username $TEST_EMAIL \
  --password $TEST_PASSWORD \
  --user-attributes Name=email,Value=$TEST_EMAIL
```

### 6.2: Confirm User
```bash
aws cognito-idp admin-confirm-sign-up \
  --region us-east-1 \
  --user-pool-id us-east-1_bJcMC6yDw \
  --username $TEST_EMAIL
```

### 6.3: Sign In
```bash
AUTH_RESULT=$(aws cognito-idp admin-initiate-auth \
  --region us-east-1 \
  --user-pool-id us-east-1_bJcMC6yDw \
  --client-id 4d7p90ejov0chl7sohp4nv856j \
  --auth-flow ADMIN_NO_SRP_AUTH \
  --auth-parameters USERNAME=$TEST_EMAIL,PASSWORD=$TEST_PASSWORD)

ID_TOKEN=$(echo "$AUTH_RESULT" | jq -r '.AuthenticationResult.IdToken')
echo "ID Token: $ID_TOKEN"
```

### 6.4: Request Presigned URL
```bash
PRESIGN_RESPONSE=$(curl -X POST \
  "https://iq1gf00t2a.execute-api.us-east-1.amazonaws.com/uploads/presign" \
  -H "Authorization: Bearer $ID_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"filename":"IMG_0190_small2.jpg","contentType":"image/jpeg"}')

echo "$PRESIGN_RESPONSE" | jq .

UPLOAD_URL=$(echo "$PRESIGN_RESPONSE" | jq -r '.uploadUrl')
ENTRY_ID=$(echo "$PRESIGN_RESPONSE" | jq -r '.entryId')
OBJECT_KEY=$(echo "$PRESIGN_RESPONSE" | jq -r '.key')

echo "Upload URL: $UPLOAD_URL"
echo "Entry ID: $ENTRY_ID"
echo "Object Key: $OBJECT_KEY"
```

### 6.5: Upload Image
```bash
curl -X PUT "$UPLOAD_URL" \
  -H "Content-Type: image/jpeg" \
  --data-binary "@IMG_0190_small2.jpg" \
  -w "\nHTTP Status: %{http_code}\n"
```

### 6.6: Verify S3 Object
```bash
aws s3 ls "s3://journalm8-dev-raw-114743615542-us-east-1/$OBJECT_KEY"
```

### 6.7: Wait for Processing
```bash
echo "Waiting 60 seconds for processing..."
sleep 60
```

### 6.8: Check DynamoDB Ingestion Job
```bash
# First, get the jobId from CloudWatch logs or calculate it
# For now, we'll query by entryId using a scan (not efficient but works for testing)

aws dynamodb scan \
  --table-name journalm8-dev-ingestion-jobs \
  --filter-expression "entryId = :eid" \
  --expression-attribute-values "{\":eid\":{\"S\":\"$ENTRY_ID\"}}" \
  --region us-east-1
```

### 6.9: Check DynamoDB Journal Entry
```bash
# Get user sub from token
USER_SUB=$(echo "$ID_TOKEN" | cut -d'.' -f2 | base64 -d 2>/dev/null | jq -r '.sub')

aws dynamodb get-item \
  --table-name journalm8-dev-journal-entries \
  --key "{\"pk\":{\"S\":\"USER#$USER_SUB\"},\"sk\":{\"S\":\"ENTRY#$ENTRY_ID\"}}" \
  --region us-east-1
```

### 6.10: Download OCR Text
```bash
aws s3 cp "s3://journalm8-dev-processed-114743615542-us-east-1/users/$USER_SUB/processed/$ENTRY_ID/clean.txt" \
  ocr_output_IMG_0190_small2.jpg.txt

cat ocr_output_IMG_0190_small2.jpg.txt
```

---

## EXPECTED OCR CONTENT

### IMG_0190_small2.jpg should contain:
- "Fear, doubt, & insecurity are all learned feelings & emotions"
- "Told my mom how excited I was for upcoming interview"
- "I was honestly so doubtful & disappointed, but hey - did my mother"
- References to: confidence, over-prepared, Cloud & AI projects, books, journal
- "NOTHING - absolutely nothing - to lose"

### IMG_0191_small2.jpg should contain:
- "The heart is a vessel. Must be emptied before it can be filled"
- "When I made the intention to improve my life, I focused on releasing & letting go"
- "That begs the question - what can I still doing to feel 'good' & energy drink?"
- References to: smoking/drugs, social media, Allah, discipline, idols, worshipper

### IMG_0200_small2.jpg should contain:
- "The bigger challenge I'm experiencing is a stable income"
- "Everything in this life is a sign. This dunya is a hologram"
- "No event in my life is created without a purpose"
- References to: freedom, trading, income security, Allah, Cloud Engineering, interviews
- "My year look when graduating high school was: Two things define; yours Patience"

---

## OCR QUALITY ASSESSMENT CRITERIA

For each image, evaluate:

1. **Word Accuracy**: What % of words are correctly recognized?
2. **Sentence Coherence**: Can you understand the sentences?
3. **Handwriting Recognition**: Is the handwriting style handled well?
4. **Special Characters**: Are apostrophes, dashes, ampersands preserved?
5. **Line Breaks**: Are paragraphs and line breaks preserved?
6. **Overall Usability**: Is the text good enough for a journal app?

**PASS CRITERIA**: 
- Overall accuracy > 85%
- Text is readable and meaningful
- No major sections completely missed
- Usable for search and retrieval

**FAIL CRITERIA**:
- Accuracy < 85%
- Text is gibberish or unreadable
- Major sections missing
- Not usable for journal purposes

---

## TROUBLESHOOTING

### Issue: Presigned URL request returns 401
**Cause**: Token is invalid or expired
**Fix**: Re-authenticate and get a new token

### Issue: Upload fails with 403
**Cause**: Presigned URL expired (15 min timeout)
**Fix**: Request a new presigned URL

### Issue: No DynamoDB records after 60s
**Cause**: S3 event notification not configured or Lambda failed
**Fix**: 
1. Check S3 bucket event notifications
2. Check start-ingestion Lambda logs
3. Check Step Functions execution history

### Issue: OCR Lambda fails
**Cause**: Textract API error or permissions issue
**Fix**:
1. Check OCR Lambda logs
2. Verify Lambda has Textract permissions
3. Verify image format is supported

### Issue: No processed files in S3
**Cause**: OCR Lambda failed or didn't complete
**Fix**:
1. Check OCR Lambda logs
2. Check Step Functions execution status
3. Verify processed bucket permissions

---

## FINAL GO / NO-GO DECISION

After completing all tests, make the decision:

### ✅ GO (Safe to Continue)
- All authentication works
- Presigned URLs work
- Uploads succeed
- Automatic processing works
- OCR quality > 85%
- DynamoDB records correct
- No manual intervention needed

### ❌ NO-GO (Stop and Fix)
- Any authentication failures
- Presigned URL issues
- Upload failures
- Processing requires manual steps
- OCR quality < 85%
- Missing DynamoDB records
- Errors in logs

---

## NEXT STEPS AFTER VALIDATION

If GO:
- Document the working flow
- Proceed with frontend development
- Add monitoring and alerting

If NO-GO:
- Document all failures
- Fix root causes
- Re-run validation
- Do not proceed until all tests pass
