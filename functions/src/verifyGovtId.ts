import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

export const verifyGovtId = functions.https.onRequest(async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).send({ error: 'Method not allowed' });
    return;
  }

  const { uid, govtIdNumber, idType } = req.body;
  if (!uid || !govtIdNumber) {
    res.status(400).send({ error: 'Missing uid or govtIdNumber' });
    return;
  }

  functions.logger.info(`Verifying DigiLocker KYC for UID ${uid}, ID type: ${idType || 'Aadhaar'}`);

  // Simulated server-side DigiLocker API integration check
  const isVerified = govtIdNumber.length >= 10;

  if (isVerified) {
    await admin.firestore().collection('users').doc(uid).update({
      officialIdVerified: true,
      verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    res.status(200).send({ verified: true, uid: uid });
  } else {
    res.status(400).send({ verified: false, error: 'Invalid Government ID format' });
  }
});
