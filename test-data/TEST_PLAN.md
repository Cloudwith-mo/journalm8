# JOURNALM8 END-TO-END VALIDATION TEST PLAN

## OBJECTIVE
Validate the complete user journey from sign-up to OCR processing using real journal images, with NO backend shortcuts.

## TEST IMAGES
- IMG_0190_small2.jpg (handwritten journal page 1)
- IMG_0191_small2.jpg (handwritten journal page 2)
- IMG_0200_small2.jpg (handwritten journal page 3)

## INFRASTRUCTURE
- Region: us-east-1
- User Pool: us-east-1_bJcMC6yDw
- Client ID: 4d7p90ejov0chl7sohp4nv856j
- API Endpoint: https://iq1gf00t2a.execute-api.us-east-1.amazonaws.com
- Raw Bucket: journalm8-dev-raw-114743615542-us-east-1
- Processed Bucket: journalm8-dev-processed-114743615542-us-east-1

---

## PHASE 1: AUTHENTICATION (Real User Path)

### Test 1.1: Sign Up New User
**Method**: `aws cognito-idp sign-up` (public API)
**Input**: 
- Email: testuser-{timestamp}@example.com
- Password: TestPass123!

**Expected Result**: 
- User created successfully
- UserSub returned
- Status: UNCONFIRMED

**Evidence Required**:
- Command output showing UserSub
- HTTP 200 response

**Pass Criteria**: ✅ User created with valid UserSub

---

### Test 1.2: Confirm User Account
**Method**: `aws cognito-idp admin-confirm-sign-up`
**Note**: Using admin API for test automation. In production, user would receive email confirmation code.

**Expected Result**: 
- User status changed to CONFIRMED

**Evidence Required**:
- Successful confirmation response

**Pass Criteria**: ✅ User account confirmed

---

### Test 1.3: Sign In and Obtain Tokens
**Method**: `aws cognito-idp admin-initiate-auth` with ADMIN_NO_SRP_AUTH
**Input**: 
- Username: test email
- Password: test password

**Expected Result**: 
- IdToken received
- AccessToken received
- RefreshToken received

**Evidence Required**:
- Valid JWT tokens in response
- Tokens can be decoded to show user claims

**Pass Criteria**: ✅ Valid JWT tokens obtained

---

## PHASE 2: PRESIGNED URL REQUEST (Real User Path)

### Test 2.1: Request Presigned URL (Valid Token)
**Method**: `POST /uploads/presign` with Authorization header
**Input**: 
```json
{
  "filename": "IMG_0190_small2.jpg",
  "contentType": "image/jpeg"
}
```

**Expected Result**: 
- HTTP 200
- Response contains:
  - uploadUrl (presigned S3 URL)
  - entryId (UUID)
  - key (S3 object key with user path)
  - bucket name
  - expiresIn (900 seconds)

**Evidence Required**:
- Full response JSON
- Verify entryId is valid UUID
- Verify key follows pattern: users/{userSub}/raw/{entryId}/{filename}

**Pass Criteria**: ✅ Valid presigned URL returned with correct structure

---

### Test 2.2: Request Presigned URL (No Token)
**Method**: `POST /uploads/presign` WITHOUT Authorization header
**Input**: Same as 2.1

**Expected Result**: 
- HTTP 401 Unauthorized

**Evidence Required**:
- HTTP 401 response
- Error message indicating missing/invalid token

**Pass Criteria**: ✅ Request rejected with 401

---

### Test 2.3: Request Presigned URL (Unsupported Content Type)
**Method**: `POST /uploads/presign` with Authorization header
**Input**: 
```json
{
  "filename": "test.txt",
  "contentType": "text/plain"
}
```

**Expected Result**: 
- HTTP 400 Bad Request
- Error message listing allowed content types

**Evidence Required**:
- HTTP 400 response
- Error message: "Unsupported content type"

**Pass Criteria**: ✅ Request rejected with clear error message

---

## PHASE 3: UPLOAD VIA PRESIGNED URL (Real User Path)

### Test 3.1: Upload IMG_0190_small2.jpg
**Method**: `PUT {presignedUrl}` with image binary data
**Input**: 
- Content-Type: image/jpeg
- Body: IMG_0190_small2.jpg binary data

**Expected Result**: 
- HTTP 200 from S3
- ETag returned

**Evidence Required**:
- HTTP 200 response
- S3 upload confirmation

**Pass Criteria**: ✅ File uploaded successfully

---

### Test 3.2: Verify S3 Object Exists
**Method**: `aws s3 ls s3://{bucket}/{key}`

**Expected Result**: 
- Object exists at correct path
- Path follows pattern: users/{userSub}/raw/{entryId}/IMG_0190_small2.jpg

**Evidence Required**:
- S3 ls output showing object
- Object size matches uploaded file

**Pass Criteria**: ✅ Object exists at correct user-scoped path

---

### Test 3.3: Upload IMG_0191_small2.jpg
**Method**: Same as 3.1
**Pass Criteria**: ✅ File uploaded successfully

---

### Test 3.4: Upload IMG_0200_small2.jpg
**Method**: Same as 3.1
**Pass Criteria**: ✅ File uploaded successfully

---

## PHASE 4: AUTOMATIC PROCESSING (Real User Path)

### Test 4.1: Verify S3 Event Triggered Lambda
**Method**: Check CloudWatch Logs for start-ingestion Lambda
**Timing**: Within 5 seconds of upload

**Expected Result**: 
- Lambda invoked automatically by S3 event
- Log shows S3 event details
- Log shows entryId extracted from object key

**Evidence Required**:
- CloudWatch log entries
- Timestamp showing automatic trigger
- S3 event payload in logs

**Pass Criteria**: ✅ Lambda automatically invoked by S3 event

---

### Test 4.2: Verify DynamoDB Ingestion Job Created
**Method**: `aws dynamodb get-item` on ingestion_jobs table
**Key**: entryId from presigned URL response

**Expected Result**: 
- Record exists with entryId as partition key
- Status: PENDING or IN_PROGRESS
- userId matches authenticated user
- s3Key matches uploaded object key

**Evidence Required**:
- DynamoDB record JSON
- All required fields present

**Pass Criteria**: ✅ Ingestion job record created with correct data

---

### Test 4.3: Verify Step Functions Execution Started
**Method**: Check Step Functions execution history
**Filter**: By entryId or timestamp

**Expected Result**: 
- Execution started automatically
- Status: RUNNING or SUCCEEDED
- Input contains entryId and s3Key

**Evidence Required**:
- Execution ARN
- Execution status
- Input JSON

**Pass Criteria**: ✅ Step Functions execution started automatically

---

## PHASE 5: OCR PROCESSING (Real User Path)

### Test 5.1: Verify OCR Lambda Invoked
**Method**: Check CloudWatch Logs for ocr-document Lambda
**Timing**: Within Step Functions execution

**Expected Result**: 
- Lambda invoked by Step Functions
- Log shows Textract API call
- Log shows processing for correct entryId

**Evidence Required**:
- CloudWatch log entries
- Textract API call logs
- Processing completion logs

**Pass Criteria**: ✅ OCR Lambda executed for each image

---

### Test 5.2: Verify Processed Outputs in S3
**Method**: `aws s3 ls` on processed bucket
**Path**: users/{userSub}/processed/{entryId}/

**Expected Result**: 
- OCR output files exist
- Files include extracted text
- Files follow naming convention

**Evidence Required**:
- S3 ls output showing files
- File sizes > 0

**Pass Criteria**: ✅ Processed files created in correct location

---

### Test 5.3: Verify DynamoDB Journal Entry Created
**Method**: `aws dynamodb get-item` on journal_entries table
**Key**: entryId

**Expected Result**: 
- Record exists with entryId as partition key
- extractedText field contains OCR output
- userId matches authenticated user
- createdAt timestamp present

**Evidence Required**:
- DynamoDB record JSON
- extractedText field populated

**Pass Criteria**: ✅ Journal entry created with extracted text

---

### Test 5.4: Verify Ingestion Job Completed
**Method**: `aws dynamodb get-item` on ingestion_jobs table
**Key**: entryId

**Expected Result**: 
- Status: COMPLETED
- completedAt timestamp present
- No error fields

**Evidence Required**:
- Updated DynamoDB record
- Status = COMPLETED

**Pass Criteria**: ✅ Job marked as complete

---

## PHASE 6: OCR QUALITY ASSESSMENT (CRITICAL)

### Test 6.1: Extract OCR Text for IMG_0190_small2.jpg
**Method**: Download extracted text from DynamoDB or S3

**Expected Content** (from journal image):
- "Fear, doubt, & insecurity are all learned feelings & emotions..."
- "Told my mom how excited I was for upcoming interview..."
- "I was honestly so doubtful & disappointed, but hey - did my mother..."
- References to: confidence, over-prepared, Cloud & AI projects, books, journal

**Pass Criteria**: 
- ✅ Text is readable and coherent
- ✅ Key phrases are captured accurately
- ✅ Handwriting is recognized (not just gibberish)
- ✅ Accuracy > 85%

---

### Test 6.2: Extract OCR Text for IMG_0191_small2.jpg
**Method**: Same as 6.1

**Expected Content** (from journal image):
- "The heart is a vessel. Must be emptied before it can be filled..."
- "When I made the intention to improve my life, I focused on releasing & letting go..."
- "That begs the question - what can I still doing to feel 'good' & energy drink?"
- References to: smoking/drugs, social media, Allah, discipline, idols

**Pass Criteria**: 
- ✅ Text is readable and coherent
- ✅ Key phrases are captured accurately
- ✅ Handwriting is recognized
- ✅ Accuracy > 85%

---

### Test 6.3: Extract OCR Text for IMG_0200_small2.jpg
**Method**: Same as 6.1

**Expected Content** (from journal image):
- "The bigger challenge I'm experiencing is a stable income..."
- "Everything in this life is a sign. This dunya is a hologram..."
- "No event in my life is created without a purpose..."
- References to: freedom, trading, income security, Allah, Cloud Engineering, interviews

**Pass Criteria**: 
- ✅ Text is readable and coherent
- ✅ Key phrases are captured accurately
- ✅ Handwriting is recognized
- ✅ Accuracy > 85%

---

### Test 6.4: Overall OCR Quality Assessment
**Method**: Manual review of all extracted text

**Evaluation Criteria**:
1. Word-level accuracy (% of words correctly recognized)
2. Sentence coherence (can sentences be understood?)
3. Handwriting recognition quality
4. Special character handling (apostrophes, dashes, etc.)
5. Line break preservation
6. Usability for journal search/retrieval

**Pass Criteria**: 
- ✅ Overall accuracy > 85%
- ✅ Text is usable for journal app purposes
- ✅ No major sections completely missed
- ✅ Handwriting style handled well

---

## PHASE 7: NEGATIVE TESTS

### Test 7.1: Expired Presigned URL
**Method**: Wait 16 minutes, attempt upload with old URL

**Expected Result**: 
- HTTP 403 Forbidden from S3
- Error: Request has expired

**Pass Criteria**: ✅ Expired URL rejected

---

### Test 7.2: Duplicate Upload
**Method**: Upload same file twice with different presigned URLs

**Expected Result**: 
- Both uploads succeed
- Two separate entryIds created
- Two separate journal entries
- OR: Deduplication logic prevents duplicate

**Pass Criteria**: ✅ System handles without corruption

---

## FINAL CHECKLIST

### User Authentication
- [ ] Sign-up works via public API
- [ ] User confirmation works
- [ ] Sign-in returns valid tokens
- [ ] Invalid credentials rejected

### Presigned Upload Flow
- [ ] Authenticated request returns presigned URL
- [ ] Unauthenticated request rejected (401)
- [ ] Unsupported content type rejected (400)
- [ ] Presigned URL structure is correct

### Upload Execution
- [ ] All 3 images upload successfully
- [ ] S3 objects exist at correct paths
- [ ] User-scoped paths enforced

### Automatic Processing
- [ ] S3 event triggers Lambda automatically
- [ ] No manual intervention required
- [ ] Step Functions starts automatically
- [ ] Processing completes end-to-end

### OCR Processing
- [ ] OCR Lambda executes for each image
- [ ] Processed outputs created in S3
- [ ] DynamoDB records created correctly
- [ ] Ingestion jobs tracked properly

### OCR Quality (CRITICAL)
- [ ] IMG_0190_small2.jpg: Text extracted accurately
- [ ] IMG_0191_small2.jpg: Text extracted accurately
- [ ] IMG_0200_small2.jpg: Text extracted accurately
- [ ] Overall accuracy > 85%
- [ ] Text is usable for journal purposes

### Error Handling
- [ ] Invalid tokens rejected
- [ ] Unsupported files rejected
- [ ] Expired URLs rejected
- [ ] Failures logged properly

---

## GO / NO-GO DECISION CRITERIA

### GO (Safe to Continue Building)
- ✅ All authentication tests pass
- ✅ All presigned URL tests pass
- ✅ All uploads succeed
- ✅ Automatic processing works end-to-end
- ✅ OCR quality > 85% accuracy
- ✅ All DynamoDB records correct
- ✅ No manual intervention required
- ✅ Error handling works properly

### NO-GO (Stop and Fix)
- ❌ Any authentication test fails
- ❌ Presigned URL flow broken
- ❌ Uploads fail or require manual steps
- ❌ Processing requires manual triggers
- ❌ OCR quality < 85%
- ❌ DynamoDB records missing/incorrect
- ❌ Error handling broken
- ❌ User path requires backend shortcuts

---

## EXECUTION INSTRUCTIONS

1. Place test images in `/Users/muhammadadeyemi/journalm8/journalm8/test-data/`:
   - IMG_0190_small2.jpg
   - IMG_0191_small2.jpg
   - IMG_0200_small2.jpg

2. Run validation script:
   ```bash
   cd /Users/muhammadadeyemi/journalm8/journalm8/test-data
   chmod +x e2e-validation.sh
   ./e2e-validation.sh
   ```

3. Review OCR output files:
   - ocr_output_IMG_0190_small2.jpg.txt
   - ocr_output_IMG_0191_small2.jpg.txt
   - ocr_output_IMG_0200_small2.jpg.txt

4. Compare extracted text against actual journal images

5. Document any failures with:
   - Root cause analysis
   - Exact error messages
   - CloudWatch logs
   - Required fixes

6. Apply fixes and re-test

7. Make final GO / NO-GO decision
