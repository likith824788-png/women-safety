import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

export const onLocationPing = functions.firestore
  .document('location_pings/{uid}/pings/{pingId}')
  .onCreate(async (snapshot, context) => {
    const ping = snapshot.data();
    const uid = context.params.uid;

    if (!ping || !ping.geopoint) return;

    // Update latestPing field in active location_shares documents for this uid
    const activeShares = await admin
      .firestore()
      .collection('location_shares')
      .where('uid', '==', uid)
      .where('active', '==', true)
      .get();

    const batch = admin.firestore().batch();
    activeShares.docs.forEach((doc) => {
      batch.update(doc.ref, {
        latestPing: {
          geopoint: ping.geopoint,
          timestamp: ping.timestamp || admin.firestore.FieldValue.serverTimestamp(),
        },
      });
    });

    await batch.commit();
  });
