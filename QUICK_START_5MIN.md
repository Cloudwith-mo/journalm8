# QUICK START - Run & Test in 5 Minutes

## 1. Install & Run
```bash
cd /Users/muhammadadeyemi/journalm8/journalm8/ui
npm install
npm run dev
```

Open: **http://localhost:5173**

---

## 2. Sign In (Desktop)
- Email: `e2e_6576874@journalm8.local`
- Password: `TestPass123!`
- Click "Sign In"

**Expected:** Redirects to home screen with entry list

---

## 3. Upload Test Image
1. Click "New Entry"
2. Click "Choose from Gallery" (easier for desktop)
3. Select any image file (JPG or PNG)
4. Watch progress bar

**Expected:** 
- Upload completes
- Redirects to entry detail screen
- Shows spinning gear with "Processing your image..."

---

## 4. Wait for OCR Processing
- App polls every 2 seconds
- Lambda processes image in background
- May take 10-60 seconds depending on image size

**Expected:**
- Spinner disappears
- Shows "Review & Edit Transcript" button
- Raw text from image visible above button

---

## 5. Review & Save
1. Click "Review & Edit Transcript"
2. See original OCR on left, edit box on right
3. Make any edits (or leave as-is)
4. Click "Save Entry"

**Expected:**
- Success checkmark appears
- Returns to home
- Entry now shows in "Recent Entries" list

---

## 6. Verify in Home List
- Entry appears at top of list
- Shows creation date
- Status shows "✓ Processed"
- Stats updated (total count increased)

---

## Test on Mobile (Same WiFi)

### Edit vite.config.js
Add to server config:
```javascript
host: '0.0.0.0',
```

### Get your Mac IP
```bash
ifconfig | grep "inet " | grep -v 127.0.0.1
```
Look for `192.168.x.x` or `10.0.x.x`

### On Phone Browser
Open: `http://YOUR_IP:5173`

Same workflow as desktop, but with real camera option on upload.

---

## What Backend Calls Happen

### Sign In
```
POST https://cognito-idp.us-east-1.amazonaws.com/
  InitiateAuth request → Gets IdToken → Stores in localStorage
```

### Upload
```
POST https://iq1gf00t2a.execute-api.us-east-1.amazonaws.com/uploads/presign
  Returns: { uploadUrl, entryId }

PUT <presigned-s3-url>
  Uploads file to S3 bucket
```

### Processing
```
Every 2 seconds:
GET https://iq1gf00t2a.execute-api.us-east-1.amazonaws.com/entries/{entryId}
  Checks DynamoDB for rawText
  When available, stops polling
```

### Review & Save
```
PUT https://iq1gf00t2a.execute-api.us-east-1.amazonaws.com/entries/{entryId}
  Updates DynamoDB with correctedText
```

### Home List
```
GET https://iq1gf00t2a.execute-api.us-east-1.amazonaws.com/entries
  Returns all user's entries from DynamoDB
```

---

## Troubleshooting

### Sign In Says "Failed"
- Wrong credentials? Use test email above
- First time? Sign up instead
- Cognito not responding? Check AWS console

### Upload Says "Failed"  
- File too large? Try < 5MB
- Presign endpoint not found? Check API Gateway
- No S3 permissions? Check Lambda role

### Processing Stuck on Spinner
- Check CloudWatch logs for Lambda errors
- S3 bucket not triggering Step Functions?
- OCR Lambda taking too long?

### Can't Connect on Phone
- Same WiFi? Check IP with `ifconfig`
- Mobile browser can't reach? Try ngrok:
  ```bash
  brew install ngrok
  ngrok http 5173
  # Use the https://xxx.ngrok.io URL on phone
  ```

---

## Files Changed for Wiring

1. **ui/src/services/api.js** - Added 3 real API functions
2. **ui/src/pages/HomeScreen.jsx** - Added real entry loading
3. **ui/src/pages/EntryDetailScreen.jsx** - Wired polling to backend
4. **ui/src/pages/TranscriptReviewScreen.jsx** - Wired save to backend
5. **ui/src/App.jsx** - Cleaned up state management

All screens now call real backend endpoints.

---

## Success Criteria ✓

- [ ] Can sign in on desktop browser
- [ ] Can upload image
- [ ] Processing spinner appears
- [ ] OCR completes and shows text
- [ ] Can review and save transcript
- [ ] Entry appears in home list
- [ ] Can sign in on phone (same WiFi)
- [ ] Can upload from phone camera

