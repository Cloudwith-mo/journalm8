# QUICK START: Run End-to-End Validation

## Prerequisites

1. AWS CLI configured with credentials
2. `jq` installed (`brew install jq` on macOS)
3. `curl` available
4. Three journal images saved in this directory

## Step 1: Save Test Images

Place these three files in `/Users/muhammadadeyemi/journalm8/journalm8/test-data/`:
- `IMG_0190_small2.jpg`
- `IMG_0191_small2.jpg`
- `IMG_0200_small2.jpg`

## Step 2: Run Validation

```bash
cd /Users/muhammadadeyemi/journalm8/journalm8/test-data
./e2e-validation.sh
```

The script will:
1. Create a test user in Cognito
2. Sign in and get JWT tokens
3. Request presigned URLs for all 3 images
4. Upload all 3 images to S3
5. Wait for automatic processing
6. Verify DynamoDB records
7. Download OCR text
8. Run negative tests
9. Show PASS/FAIL summary

## Step 3: Check OCR Quality

```bash
./check-ocr-quality.sh
```

This will analyze the extracted OCR text and compare it against expected content.

## Step 4: Manual Review

Read the OCR output files:
```bash
cat ocr_output_IMG_0190_small2.jpg.txt
cat ocr_output_IMG_0191_small2.jpg.txt
cat ocr_output_IMG_0200_small2.jpg.txt
```

Compare the extracted text against the actual journal images.

## Step 5: Make Decision

### ✅ GO if:
- All tests passed
- OCR quality > 85%
- Text is readable and meaningful
- No manual intervention was needed

### ❌ NO-GO if:
- Any tests failed
- OCR quality < 85%
- Text is unreadable or gibberish
- Manual steps were required

## Troubleshooting

### If validation script fails:

1. **Check AWS credentials**:
   ```bash
   aws sts get-caller-identity
   ```

2. **Check infrastructure is deployed**:
   ```bash
   cd ../infra/envs/dev
   terraform output
   ```

3. **Check CloudWatch logs**:
   ```bash
   aws logs tail /aws/lambda/journalm8-dev-start-ingestion --follow
   aws logs tail /aws/lambda/journalm8-dev-ocr-document --follow
   ```

4. **Check Step Functions**:
   ```bash
   aws stepfunctions list-executions \
     --state-machine-arn arn:aws:states:us-east-1:114743615542:stateMachine:journalm8-dev-journal-ingestion \
     --max-results 5
   ```

5. **Manual testing**: See `MANUAL_TEST_INSTRUCTIONS.md`

## What Gets Tested

### ✅ Real User Paths
- Cognito public sign-up API
- Cognito public sign-in API
- Authenticated API Gateway requests
- Presigned S3 upload URLs
- Automatic S3 event notifications
- Automatic Lambda triggers
- Automatic Step Functions execution
- Automatic OCR processing
- DynamoDB record creation

### ❌ No Backend Shortcuts
- No direct S3 CLI uploads
- No direct Lambda invocations
- No manual Step Functions starts
- No direct DynamoDB writes
- No admin-only Cognito flows (except confirmation for testing)

## Expected Timeline

- Authentication: ~5 seconds
- Presigned URLs: ~3 seconds
- Uploads: ~5 seconds
- S3 event trigger: ~5-10 seconds
- OCR processing: ~30-60 seconds per image
- Total: ~2-3 minutes

## Output Files

After successful run:
- `ocr_output_IMG_0190_small2.jpg.txt` - Extracted text from first image
- `ocr_output_IMG_0191_small2.jpg.txt` - Extracted text from second image
- `ocr_output_IMG_0200_small2.jpg.txt` - Extracted text from third image

## Next Steps

### If GO:
1. Fill out `VALIDATION_REPORT_TEMPLATE.md`
2. Commit validation results
3. Proceed with frontend development
4. Set up monitoring and alerting

### If NO-GO:
1. Document all failures
2. Identify root causes
3. Fix issues in code/infrastructure
4. Re-run validation
5. Do not proceed until all tests pass

## Support

For detailed information:
- Full test plan: `TEST_PLAN.md`
- Manual testing: `MANUAL_TEST_INSTRUCTIONS.md`
- Report template: `VALIDATION_REPORT_TEMPLATE.md`
- Overview: `README.md`
