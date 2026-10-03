import * as functions from 'firebase-functions';
import twilio from 'twilio';

export const sendSmsFallback = functions.https.onRequest(async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).send({ error: 'Method not allowed' });
    return;
  }

  const { toPhone, message, latitude, longitude } = req.body;
  if (!toPhone || !message) {
    res.status(400).send({ error: 'Missing toPhone or message body' });
    return;
  }

  const accountSid = process.env.TWILIO_ACCOUNT_SID;
  const authToken = process.env.TWILIO_AUTH_TOKEN;
  const fromPhone = process.env.TWILIO_PHONE_NUMBER;

  if (!accountSid || !authToken || !fromPhone) {
    functions.logger.error('Twilio credentials not configured in Cloud Functions secrets environment.');
    res.status(500).send({ error: 'Twilio server secrets unconfigured' });
    return;
  }

  try {
    const client = twilio(accountSid, authToken);
    const sms = await client.messages.create({
      body: `${message} Location: https://maps.google.com/?q=${latitude},${longitude}`,
      from: fromPhone,
      to: toPhone,
    });

    res.status(200).send({ success: true, messageSid: sms.sid });
  } catch (err: any) {
    functions.logger.error('Twilio SMS dispatch failure:', err);
    res.status(500).send({ error: err.message || 'SMS dispatch failed' });
  }
});
