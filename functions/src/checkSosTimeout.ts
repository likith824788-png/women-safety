import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import twilio from 'twilio';

export const checkSosTimeout = functions.https.onRequest(async (req, res) => {
  const { eventId } = req.body;
  if (!eventId) {
    res.status(400).send({ error: 'Missing eventId parameter' });
    return;
  }

  const docRef = admin.firestore().collection('sos_events').doc(eventId);
  const doc = await docRef.get();

  if (!doc.exists) {
    res.status(404).send({ error: 'SOS event not found' });
    return;
  }

  const data = doc.data();
  if (data?.status === 'countdown') {
    // User never cancelled mid-countdown -> flip to sent and dispatch alerts
    await docRef.update({
      status: 'sent',
      escalatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // 1. Dispatch FCM Push Notifications to Guardians
    const recipientIds: string[] = data.notifiedContactIds || [];
    const payload = {
      notification: {
        title: '🚨 EMERGENCY SOS ALERT',
        body: `Immediate assistance requested at coordinates (${data.location?.latitude}, ${data.location?.longitude})`,
      },
      data: {
        eventId: eventId,
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
    };

    if (recipientIds.length > 0) {
      await admin.messaging().sendToTopic(`guardians_${data.uid}`, payload);
    }

    // 2. Dispatch Twilio SMS Fallback
    const accountSid = process.env.TWILIO_ACCOUNT_SID;
    const authToken = process.env.TWILIO_AUTH_TOKEN;
    const twilioNumber = process.env.TWILIO_PHONE_NUMBER;

    if (accountSid && authToken && twilioNumber) {
      const client = twilio(accountSid, authToken);
      const smsBody = `AEGIS SAFETY SOS ALERT: User ${data.uid} requires urgent help! Live Location: https://maps.google.com/?q=${data.location?.latitude},${data.location?.longitude}`;
      
      functions.logger.info(`Dispatching Twilio SMS fallback to guardians... ${smsBody}`);
      if (data.phone) {
        await client.messages.create({
          body: smsBody,
          from: twilioNumber,
          to: data.phone,
        });
      }
    }

    res.status(200).send({ success: true, status: 'sent' });
  } else {
    res.status(200).send({ success: true, status: data?.status });
  }
});
