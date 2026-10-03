import * as admin from 'firebase-admin';

if (!admin.apps.length) {
  admin.initializeApp();
}

export { onSosCreated } from './onSosCreated';
export { checkSosTimeout } from './checkSosTimeout';
export { onCompanionTripUpdate } from './onCompanionTripUpdate';
export { onLocationPing } from './onLocationPing';
export { sendSmsFallback } from './sendSmsFallback';
export { verifyGovtId } from './verifyGovtId';
