# Food Bridge Backend Worker

This is the free Render-compatible backend worker for volunteer matching.

It polls Firestore every 30 seconds and:

- assigns an online volunteer to `searching` donations;
- gives the volunteer 2 minutes to accept;
- retries another volunteer if the first one does not accept;
- keeps retrying until the donation expires;
- sends FCM notifications to volunteers and NGOs.

## Render setup

Create a second Render Web Service. Your existing ML server can keep running separately.

If your GitHub repo root is `hacksail_2`, use these settings:

- Root Directory: `food_bridge_ai/backend-worker`
- Build Command: `npm install`
- Start Command: `npm start`

If your GitHub repo root is already `food_bridge_ai`, use `backend-worker` as the Root Directory instead.

Add this environment variable:

- `FIREBASE_SERVICE_ACCOUNT_JSON`: the full JSON from a Firebase service account key.

Optional environment variables:

- `FIREBASE_PROJECT_ID`: `food-bridge-8a76e`
- `POLL_INTERVAL_MS`: `30000`

## Firebase service account

Firebase Console:

Project settings -> Service accounts -> Generate new private key

Paste the whole JSON into Render as `FIREBASE_SERVICE_ACCOUNT_JSON`.
Do not commit the JSON key file to git.

## Local test

```powershell
cd C:\Users\lalit\Documents\hacksail_2\food_bridge_ai\backend-worker
npm install
npm start
```

Then open:

```text
http://localhost:3000/health
```
