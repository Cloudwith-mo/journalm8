# JournalM8 UI - Setup & Testing Guide

## Quick Start

### 1. Install Dependencies
```bash
cd /Users/muhammadadeyemi/journalm8/journalm8/ui
npm install
```

### 2. Run Development Server
```bash
npm run dev
```

The UI will start at **http://localhost:5173** (Vite default port)

---

## Backend Configuration

The UI is pre-configured to connect to your AWS backend:

**Cognito User Pool:** `us-east-1_bJcMC6yDw`
**Client ID:** `4d7p90ejov0chl7sohp4nv856j`
**API Endpoint:** `https://iq1gf00t2a.execute-api.us-east-1.amazonaws.com`

### Test Credentials
- **Email:** `e2e_6576874@journalm8.local`
- **Password:** `TestPass123!`

If you need to create a new test user, you can sign up in the app (it creates a new Cognito user).

---

## Testing on Desktop Browser

### 1. Open in Browser
```
http://localhost:5173
```

### 2. Sign In
- Use test credentials above, or sign up with a new email
- On sign up, you'll be prompted to confirm with a code (check if AWS auto-confirms or use test email)

### 3. Upload Test Image
- Click "New Entry"
- Choose "Take Photo" or "Choose from Gallery"
- Select a journal image (or any image for testing)
- Wait for upload (progress bar shows)

### 4. Review OCR
- After upload, app polls for processing (2-second intervals)
- When ready, you'll see "Review & Edit Transcript" button
- Click to see OCR'd text

### 5. Save Transcript
- Edit the OCR text if needed
- Click "Save Entry"
- Entry appears in home list

---

## Testing on Mobile Phone

### Option A: Local Network (Same WiFi)

1. **Get Your Machine's IP:**
   ```bash
   ifconfig | grep "inet " | grep -v 127.0.0.1
   ```
   Look for your local IP (usually `192.168.x.x` or `10.0.x.x`)

2. **Update Vite Config to Expose:**
   Edit `ui/vite.config.js` and add:
   ```javascript
   export default {
     server: {
       host: '0.0.0.0',
       port: 5173,
     },
     // ... rest of config
   }
   ```

3. **Restart Dev Server:**
   ```bash
   npm run dev
   ```

4. **On Phone:**
   - Open browser (Safari on iOS, Chrome on Android)
   - Go to `http://YOUR_IP:5173`
   - Test the full workflow

### Option B: Tunnel (Works from Anywhere)

1. **Install ngrok:**
   ```bash
   brew install ngrok
   ```

2. **Start ngrok:**
   ```bash
   ngrok http 5173
   ```

3. **Use the ngrok URL:**
   - ngrok shows you a public URL like `https://abc123.ngrok.io`
   - Open that URL on your phone
   - Test the workflow

### Option C: Build & Deploy

For production testing:
```bash
npm run build
# Output goes to ui/dist/
# Deploy dist/ folder to AWS S3 + CloudFront or similar
```

---

## End-to-End Test Checklist

### Auth Flow
- [ ] Sign in with existing credentials works
- [ ] Sign up creates new account
- [ ] Token stored in localStorage
- [ ] Sign out clears token
- [ ] Returning to app keeps you logged in (if token exists)

### Upload Flow
- [ ] "New Entry" button shows upload screen
- [ ] "Take Photo" opens camera on mobile
- [ ] "Choose from Gallery" opens file picker
- [ ] Upload shows progress bar
- [ ] Backend receives file in S3 (`journalm8-dev-raw-*`)
- [ ] Entry created in DynamoDB (`journal_entries` table)
- [ ] Step Functions state machine triggered

### Processing Flow
- [ ] EntryDetailScreen polls every 2 seconds
- [ ] Spinner shows while processing
- [ ] When Lambda completes OCR, `rawText` populated
- [ ] "Review & Edit Transcript" button appears

### Review Flow
- [ ] "Review & Edit Transcript" opens TranscriptReviewScreen
- [ ] Original OCR text shows on left
- [ ] Can edit in textarea
- [ ] "Save Entry" calls backend
- [ ] Entry updated in DynamoDB
- [ ] Returns to home

### Home List Flow
- [ ] Home screen loads on first auth
- [ ] Entries list populated with recent uploads
- [ ] Stats show correct totals
- [ ] Can click entry to view again
- [ ] Sign out button works

---

## Debugging

### Check Browser Console
1. Open DevTools (F12)
2. Check Console tab for errors
3. Check Network tab to see API calls

### Check API Calls
```bash
# Monitor CloudWatch logs
aws logs tail /aws/lambda/journalm8-dev-verify-ocr --follow
aws logs tail /aws/lambda/journalm8-dev-upload-handler --follow
```

### Common Issues

**"Sign in failed"**
- Check Cognito credentials are correct
- Verify User Pool exists and is enabled for USER_PASSWORD_AUTH
- Check if user exists in pool

**"Presign failed"**
- Verify presign endpoint exists: `POST /uploads/presign`
- Check S3 bucket permissions
- Look at API Gateway logs

**"Polling stuck on 'Processing...'"**
- Check Lambda logs for errors
- Verify DynamoDB table has entry
- Ensure Step Functions executed successfully
- Check S3 has raw image

**"Save failed"**
- Verify `/entries/{id}` PUT endpoint exists
- Check DynamoDB write permissions
- Look for Lambda errors

---

## Architecture Overview

```
Browser/Phone
    ↓
React App (localhost:5173)
    ↓
Cognito (User auth)
API Gateway (AWS)
    ├── POST /uploads/presign → Lambda → S3
    ├── GET /entries → Lambda → DynamoDB
    ├── GET /entries/{id} → Lambda → DynamoDB
    ├── PUT /entries/{id} → Lambda → DynamoDB
    └── Step Functions → Lambda (OCR) → DynamoDB
```

---

## File Structure

```
ui/
├── package.json          # Dependencies
├── vite.config.js        # Vite build config
├── tailwind.config.js    # Tailwind styles
├── postcss.config.js     # PostCSS setup
├── index.html            # HTML entry, PWA manifest link
├── public/
│   └── manifest.json     # PWA manifest for mobile install
├── src/
│   ├── main.jsx          # React root
│   ├── App.jsx           # Screen router
│   ├── index.css         # Tailwind directives
│   ├── pages/
│   │   ├── AuthScreen.jsx           # Sign in/up
│   │   ├── HomeScreen.jsx           # Entry list
│   │   ├── UploadScreen.jsx         # Camera/gallery
│   │   ├── EntryDetailScreen.jsx    # Polling + OCR review
│   │   └── TranscriptReviewScreen.jsx # Edit & save
│   └── services/
│       └── api.js        # Cognito + API calls
```

---

## Next Steps

1. **First Run:** `npm install && npm run dev`
2. **Desktop Test:** Open http://localhost:5173 and test sign-in
3. **Phone Test:** Use local network or ngrok to test on mobile
4. **Real Journal Image:** Once working, test with actual handwritten journal
5. **Monitor Logs:** Watch CloudWatch during upload to verify OCR processing

---

## Important Notes

- **Session Storage:** Token stored in `localStorage` - clear manually if needed
- **CORS:** Browser requests must include Authorization header (already done in api.js)
- **Phone Camera:** Only works on HTTPS or localhost (ngrok provides HTTPS)
- **File Size:** Large images may timeout - test with < 5MB first
- **Polling Timeout:** EntryDetailScreen polls for 30 seconds by default (adjust if needed)

