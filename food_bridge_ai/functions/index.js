const { initializeApp, getApps } = require('firebase-admin/app');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { logger } = require('firebase-functions');

if (!getApps().length) initializeApp();
const db = getFirestore();
const ACCEPTANCE_WINDOW_MS = 2 * 60 * 1000;

function expiryOf(data) {
  if (data.expiresAt?.toDate) return data.expiresAt.toDate();
  const created = data.createdAt?.toDate?.() ?? new Date();
  return new Date(created.getTime() + (Number(data.expiryMinutes) || 120) * 60000);
}

function distanceKm(a, b) {
  const rad = (value) => value * Math.PI / 180;
  const earthKm = 6371;
  const dLat = rad(b.lat - a.lat);
  const dLng = rad(b.lng - a.lng);
  const x = Math.sin(dLat / 2) ** 2 + Math.cos(rad(a.lat)) * Math.cos(rad(b.lat)) * Math.sin(dLng / 2) ** 2;
  return earthKm * 2 * Math.atan2(Math.sqrt(x), Math.sqrt(1 - x));
}

async function notify(uid, title, body, data = {}) {
  const user = await db.collection('users').doc(uid).get();
  const token = user.data()?.fcmToken;
  if (!token) return;
  await getMessaging().send({
    token,
    notification: { title, body },
    data: Object.fromEntries(Object.entries(data).map(([key, value]) => [key, String(value)])),
  });
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
  await db.runTransaction(async (tx) => {
    const fresh = await tx.get(donationRef);
    const data = fresh.data();
    if (!fresh.exists || data.status !== 'searching' || expiryOf(data) <= new Date()) return;
    tx.update(donationRef, {
      status: 'matched',
      assignedVolunteerId: volunteer.id,
      assignedVolunteerName: volunteer.name || 'Volunteer',
      attemptedVolunteerIds: FieldValue.arrayUnion(volunteer.id),
      assignmentDeadline: deadline,
      updatedAt: FieldValue.serverTimestamp(),
    });
  });
  await notify(volunteer.id, 'New pickup request', 'Accept within 2 minutes to take this delivery.', { donationId: donationRef.id });
  if (donation.matchedNGOId) {
    await notify(
      donation.matchedNGOId,
      'Volunteer found',
      `${volunteer.name || 'A volunteer'} has 2 minutes to accept the pickup.`,
      { donationId: donationRef.id },
    );
  }
  return true;
}

exports.matchVolunteerWhenRequested = onDocumentWritten('donations/{donationId}', async (event) => {
  if (!event.data?.after.exists) return;
  const before = event.data.before.data() || {};
  const after = event.data.after.data();
  if (after.status === 'searching' && before.status !== 'searching') {
    await assignNextVolunteer(event.data.after.ref);
  }
  if (after.status === 'accepted' && before.status !== 'accepted' && after.matchedNGOId) {
    await notify(after.matchedNGOId, 'Volunteer accepted', `${after.assignedVolunteerName || 'A volunteer'} is on the way.`, { donationId: event.params.donationId });
  }
});

exports.matchWhenVolunteerComesOnline = onDocumentWritten('users/{userId}', async (event) => {
  if (!event.data?.after.exists) return;
  const before = event.data.before.data() || {};
  const after = event.data.after.data();
  if (after.role !== 'volunteer' || after.isAvailable !== true || before.isAvailable === true) return;
  const waiting = await db.collection('donations').where('status', '==', 'searching').get();
  for (const donation of waiting.docs) await assignNextVolunteer(donation.ref);
});

exports.retryExpiredAssignments = onSchedule('every 1 minutes', async () => {
  const matched = await db.collection('donations').where('status', '==', 'matched').get();
  const now = new Date();
  for (const doc of matched.docs) {
    const data = doc.data();
    const deadline = data.assignmentDeadline?.toDate?.();
    if (deadline && deadline <= now && expiryOf(data) > now) {
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
  logger.info('Volunteer-assignment retry finished');
});
