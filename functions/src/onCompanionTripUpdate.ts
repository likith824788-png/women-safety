import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

export const onCompanionTripUpdate = functions.firestore
  .document('companion_trips/{tripId}')
  .onUpdate(async (change, context) => {
    const newData = change.after.data();
    const previousData = change.before.data();

    if (!newData) return;

    if (newData.status === 'deviated' && previousData?.status !== 'deviated') {
      const tripId = context.params.tripId;
      functions.logger.warn(`Trip ${tripId} entered deviated state. Dispatching alert...`);

      // Push FCM warning notification to guardian topic
      await admin.messaging().sendToTopic(`guardians_${newData.uid}`, {
        notification: {
          title: '⚠️ Companion Route Deviation Alert',
          body: `Trip to ${newData.destination} detected off-route deviation. Monitoring active.`,
        },
        data: {
          tripId: tripId,
          type: 'companion_deviation',
        },
      });
    }
  });
