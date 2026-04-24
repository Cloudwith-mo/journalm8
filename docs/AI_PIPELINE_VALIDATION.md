# AI Pipeline Validation

**Date:** 2026-04-24  
**Commit range:** `09dd6d8` → `3d10f49`  
**Environment:** `dev` — `https://iq1gf00t2a.execute-api.us-east-1.amazonaws.com`  
**Test user:** `f4888488-60f1-7036-27f8-e58899c95154` (`e2e_6576874@journalm8.local`)  
**Model:** `us.anthropic.claude-3-5-haiku-20241022-v1:0`

---

## Validation Matrix

| Check | Status | Evidence |
|---|---|---|
| Auth / read path | ✅ PASS | Bearer token fix; GET /entries returns 200 |
| Seeded insight UI | ✅ PASS | AiInsightCard renders all 8 fields from manual seed |
| Save / update_transcript | ✅ PASS | CW log: `INFO: Queued enrichment for entry 6339aa73...` |
| Async enrich trigger | ✅ PASS | CW log: `INFO: Enriching entry 6339aa73...` in enrich_entry |
| Bedrock attempted | ✅ PASS | ThrottlingException after 4 retries — model IS called |
| FAILED state / retry UI | ✅ PASS | Home badge "AI failed — retry", retry button in detail screen |
| Retry endpoint | ✅ PASS | QUEUED → ENRICHING → FAILED cycle confirmed |
| Real Bedrock-generated insight | ⏳ BLOCKED | Rolling daily token quota — retry when quota clears |

---

## Architecture Confirmed

```
PUT /entries/{id}
  └─ update_transcript Lambda
       ├─ writes correctedText to S3
       ├─ sets reviewStatus=REVIEWED, aiStatus=QUEUED in DynamoDB
       └─ async invokes enrich_entry (InvocationType=Event)
            ├─ sets aiStatus=ENRICHING
            ├─ reads corrected transcript from S3
            ├─ calls Bedrock InvokeModel (claude-3-5-haiku)
            ├─ parses JSON insight schema
            ├─ writes INSIGHT#{entryId} to DynamoDB
            └─ sets aiStatus=COMPLETE / THROTTLED / FAILED

POST /entries/{id}/enrich
  └─ retry_enrich Lambda
       ├─ resets aiStatus=QUEUED
       └─ async invokes enrich_entry

GET /entries/{id}/insight
  └─ get_insight Lambda → returns INSIGHT# item
```

---

## Seeded Data Note

One INSIGHT# item was manually seeded for UI validation before real Bedrock
enrichment was possible (quota exhausted).

**Seeded item:**
- `pk`: `USER#f4888488-60f1-7036-27f8-e58899c95154`
- `sk`: `INSIGHT#4badde36-3dca-4c05-9418-da93190a94bf`
- `source`: `"manual_seed_validation"`

**Action required after real Bedrock succeeds:**  
Run enrichment on entry `4badde36-3dca-4c05-9418-da93190a94bf` via Retry AI
Analysis. The real INSIGHT# will overwrite the seeded item (same pk/sk). The
`source` field will change from `manual_seed_validation` to absent (model-generated).
Alternatively, manually delete the seeded item first.

---

## Validation Commands

### DynamoDB — Check ENTRY# item

```bash
aws dynamodb get-item \
  --table-name journalm8-dev-journal-entries \
  --key '{
    "pk":{"S":"USER#f4888488-60f1-7036-27f8-e58899c95154"},
    "sk":{"S":"ENTRY#<entryId>"}
  }' \
  --region us-east-1 \
  --query 'Item.{reviewStatus:reviewStatus.S, aiStatus:aiStatus.S, lastCorrectedAt:lastCorrectedAt.S, updatedAt:updatedAt.S, lastAnalyzedAt:lastAnalyzedAt.S}'
```

**Expected (after save + enrichment):**
```json
{
  "reviewStatus": "REVIEWED",
  "aiStatus": "COMPLETE",
  "lastCorrectedAt": "<iso timestamp>",
  "updatedAt": "<iso timestamp>",
  "lastAnalyzedAt": "<iso timestamp>"
}
```

### DynamoDB — Check INSIGHT# item

```bash
aws dynamodb get-item \
  --table-name journalm8-dev-journal-entries \
  --key '{
    "pk":{"S":"USER#f4888488-60f1-7036-27f8-e58899c95154"},
    "sk":{"S":"INSIGHT#<entryId>"}
  }' \
  --region us-east-1 \
  --query 'Item.{summary:summary.S, mood:mood.M.primary.S, themes:themes.L, keyInsights:keyInsights.L[0].S, modelId:modelId.S, createdAt:createdAt.S, source:source.S}'
```

**Expected fields:** `summary`, `mood.primary`, `themes[]`, `keyInsights[]`,
`reflectionQuestions[]`, `sentiment`, `modelId`, `createdAt`

### CloudWatch — update_transcript logs

```bash
LOG_STREAM=$(aws logs describe-log-streams \
  --log-group-name /aws/lambda/journalm8-dev-update-transcript \
  --order-by LastEventTime --descending \
  --region us-east-1 \
  --query 'logStreams[0].logStreamName' --output text)

aws logs get-log-events \
  --log-group-name /aws/lambda/journalm8-dev-update-transcript \
  --log-stream-name "$LOG_STREAM" \
  --region us-east-1 \
  --query 'events[*].message' --output text | tr '\t' '\n' | grep -v "^$"
```

**Expected line:** `INFO: Queued enrichment for entry <entryId>`

### CloudWatch — enrich_entry logs

```bash
LOG_STREAM=$(aws logs describe-log-streams \
  --log-group-name /aws/lambda/journalm8-dev-enrich-entry \
  --order-by LastEventTime --descending \
  --region us-east-1 \
  --query 'logStreams[0].logStreamName' --output text)

aws logs get-log-events \
  --log-group-name /aws/lambda/journalm8-dev-enrich-entry \
  --log-stream-name "$LOG_STREAM" \
  --region us-east-1 \
  --query 'events[*].message' --output text | tr '\t' '\n' | grep -v "^$"
```

**Expected lines (quota cleared):**
```
INFO: Enriching entry <entryId> for user <userSub>
INFO: Enrichment complete for entry <entryId>. Themes: [...]
```

**Expected lines (quota throttled):**
```
INFO: Enriching entry <entryId> for user <userSub>
ERROR: Bedrock invocation failed: ThrottlingException ... Too many tokens per day
```

### Test retry_enrich Lambda directly

```bash
aws lambda invoke \
  --function-name journalm8-dev-retry-enrich \
  --payload '{
    "requestContext":{"authorizer":{"jwt":{"claims":{"sub":"<userSub>"}}}},
    "pathParameters":{"entryId":"<entryId>"}
  }' \
  --cli-binary-format raw-in-base64-out \
  --region us-east-1 /tmp/retry_result.json && cat /tmp/retry_result.json
```

**Expected:** `{"statusCode": 200, ..., "aiStatus": "QUEUED"}`  
**Then:** DynamoDB shows `ENRICHING` within ~2s, then `COMPLETE` or `THROTTLED`/`FAILED`

---

## Remaining Steps

1. **Bedrock quota clears** → click "↺ Retry AI Analysis" on any `THROTTLED`/`FAILED` entry
2. Confirm cycle: `QUEUED → ENRICHING → COMPLETE`
3. Confirm `INSIGHT#<entryId>` created by model (not seeded)
4. Confirm `GET /entries/{entryId}/insight` returns 200 with model-generated content
5. Confirm UI auto-renders real AI Insight card
6. After 2–3 entries have `COMPLETE` insights, test **Weekly Reflection**:
   - POST `/agents/weekly-reflection/run`
   - Confirm `REFLECTION#WEEK#<weekId>` created in DynamoDB
   - Confirm UI renders weekly summary/themes/wins/struggles/questions
