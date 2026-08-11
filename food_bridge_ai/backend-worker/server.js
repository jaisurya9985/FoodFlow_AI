const express = require('express');
const { initializeApp, cert, applicationDefault, getApps } = require('firebase-admin/app');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

const PORT = Number(process.env.PORT || 3000);
const PROJECT_ID = process.env.FIREBASE_PROJECT_ID || 'food-bridge-8a76e';
const POLL_INTERVAL_MS = Number(process.env.POLL_INTERVAL_MS || 30000);
const ACCEPTANCE_WINDOW_MS = 2 * 60 * 1000;

let isRunning = false;
let lastRunAt = null;
let lastRunError = null;

function initializeFirebase() {
  if (getApps().length) return;

  const rawServiceAccount = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if (rawServiceAccount) {
    const serviceAccount = JSON.parse(rawServiceAccount);
    initializeApp({
      credential: cert(serviceAccount),
      projectId: serviceAccount.project_id || PROJECT_ID,
    });
    return;
  }

  initializeApp({
    credential: applicationDefault(),
    projectId: PROJECT_ID,
  });
}

initializeFirebase();
const db = getFirestore();

function expiryOf(data) {
  if (data.expiresAt?.toDate) return data.expiresAt.toDate();
  const created = data.createdAt?.toDate?.() ?? new Date();
  return new Date(created.getTime() + (Number(data.expiryMinutes) || 120) * 60000);
}

function distanceKm(a, b) {
  const rad = (value) => value * Math.PI / 180;
  const earthKm = 6371;
  const dLat = rad((b.lat || 0) - (a.lat || 0));
  const dLng = rad((b.lng || 0) - (a.lng || 0));
  const x = Math.sin(dLat / 2) ** 2
    + Math.cos(rad(a.lat || 0)) * Math.cos(rad(b.lat || 0)) * Math.sin(dLng / 2) ** 2;
  return earthKm * 2 * Math.atan2(Math.sqrt(x), Math.sqrt(1 - x));
}

async function notify(uid, title, body, data = {}) {
  if (!uid) return false;
  const user = await db.collection('users').doc(uid).get();
  const token = user.data()?.fcmToken;
  if (!token) return false;

  await getMessaging().send({
    token,
    notification: { title, body },
    data: Object.fromEntries(Object.entries(data).map(([key, value]) => [key, String(value)])),
  });
  return true;
}

async function assignNextVolunteer(donationRef) {
  const donationSnap = await donationRef.get();
  if (!donationSnap.exists) return false;

  const donation = donationSnap.data();
  if (donation.status !== 'searching' || expiryOf(donation) <= new Date()) return false;

  const attempted = new Set(donation.attemptedVolunteerIds || []);
  const volunteers = await db.collection('users')
    .where('role', '==', 'volunteer')
    .where('isAvailable', '==', true)
    .get();

  const pickup = donation.pickupLocation || { lat: 0, lng: 0 };
  const choices = volunteers.docs
    .filter((doc) => !attempted.has(doc.id))
    .map((doc) => ({ id: doc.id, ...doc.data() }))
    .sort((a, b) => {
      const da = a.location ? distanceKm(pickup, a.location) : Number.MAX_SAFE_INTEGER;
      const dbDist = b.location ? distanceKm(pickup, b.location) : Number.MAX_SAFE_INTEGER;
      return da - dbDist || (b.rating || 0) - (a.rating || 0);
    });

  if (!choices.length) return false;

  const volunteer = choices[0];
  const deadline = Timestamp.fromMillis(Date.now() + ACCEPTANCE_WINDOW_MS);
  let assigned = false;

  await db.runTransaction(async (tx) => {
    const fresh = await tx.get(donationRef);
    if (!fresh.exists) return;

    const data = fresh.data();
    if (data.status !== 'searching' || expiryOf(data) <= new Date()) return;

    tx.update(donationRef, {
      status: 'matched',
      assignedVolunteerId: volunteer.id,
      assignedVolunteerName: volunteer.name || 'Volunteer',
      attemptedVolunteerIds: FieldValue.arrayUnion(volunteer.id),
      assignmentDeadline: deadline,
      volunteerFoundNotifiedAt: FieldValue.delete(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    assigned = true;
  });

  if (!assigned) return false;

  await notify(
    volunteer.id,
    'New pickup request',
    'Accept within 2 minutes to take this delivery.',
    { donationId: donationRef.id },
  );

  if (donation.matchedNGOId) {
    await notify(
      donation.matchedNGOId,
      'Volunteer found',
      `${volunteer.name || 'A volunteer'} has 2 minutes to accept the pickup.`,
      { donationId: donationRef.id },
    );
    await donationRef.update({ volunteerFoundNotifiedAt: FieldValue.serverTimestamp() });
  }

  return true;
}

async function retryExpiredAssignments() {
  const matched = await db.collection('donations').where('status', '==', 'matched').get();
  const now = new Date();

  for (const doc of matched.docs) {
    const data = doc.data();
    const deadline = data.assignmentDeadline?.toDate?.();
    if (!deadline || deadline > now) continue;

    if (expiryOf(data) <= now) {
      await doc.ref.update({
        status: 'available',
        assignedVolunteerId: FieldValue.delete(),
        assignedVolunteerName: FieldValue.delete(),
        assignmentDeadline: FieldValue.delete(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      continue;
    }

    await doc.ref.update({
      status: 'searching',
      assignedVolunteerId: FieldValue.delete(),
      assignedVolunteerName: FieldValue.delete(),
      assignmentDeadline: FieldValue.delete(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    await assignNextVolunteer(doc.ref);
  }
}

async function assignWaitingDonations() {
  const waiting = await db.collection('donations').where('status', '==', 'searching').get();
  for (const donation of waiting.docs) {
    await assignNextVolunteer(donation.ref);
  }
}

async function notifyAcceptedDonations() {
  const accepted = await db.collection('donations').where('status', '==', 'accepted').get();

  for (const doc of accepted.docs) {
    const data = doc.data();
    if (!data.matchedNGOId || data.ngoAcceptanceNotifiedAt) continue;

    await notify(
      data.matchedNGOId,
      'Volunteer accepted',
      `${data.assignedVolunteerName || 'A volunteer'} is on the way.`,
      { donationId: doc.id },
    );
    await doc.ref.update({ ngoAcceptanceNotifiedAt: FieldValue.serverTimestamp() });
  }
}

async function runMatchingCycle() {
  if (isRunning) return;
  isRunning = true;

  try {
    await retryExpiredAssignments();
    await assignWaitingDonations();
    await notifyAcceptedDonations();
    lastRunAt = new Date().toISOString();
    lastRunError = null;
  } catch (error) {
    lastRunError = error.message || String(error);
    console.error('Matching cycle failed:', error);
  } finally {
    isRunning = false;
  }
}

const app = express();

app.get('/', (_req, res) => {
  res.json({
    ok: true,
    service: 'food-bridge-backend-worker',
    projectId: PROJECT_ID,
    pollIntervalMs: POLL_INTERVAL_MS,
    lastRunAt,
    lastRunError,
  });
});

app.get('/health', (_req, res) => {
  res.json({ ok: true, lastRunAt, lastRunError });
});

app.post('/run-once', express.json(), async (_req, res) => {
  await runMatchingCycle();
  res.json({ ok: !lastRunError, lastRunAt, lastRunError });
});

app.listen(PORT, () => {
  console.log(`Food Bridge backend worker listening on port ${PORT}`);
  runMatchingCycle();
  setInterval(runMatchingCycle, POLL_INTERVAL_MS);
});
