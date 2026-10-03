import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

export const onSosCreated = functions.firestore
  .document('sos_events/{eventId}')
  .onCreate(async (snapshot, context) => {
    const data = snapshot.data();
    if (!data || data.status !== 'countdown') return;

    const eventId = context.params.eventId;
    functions.logger.info(`SOS countdown initialized for event ${eventId}. Enqueuing fallback check...`);

    // In production, schedule a Cloud Task or delayed check.
    // For cloud function logic, write a scheduled task or check timeout.
    await admin.firestore().collection('sos_events').doc(eventId).update({
      serverVerificationEnqueued: true,
      enqueuedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });
