const { onCall, HttpsError } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');

if (!admin.apps.length) admin.initializeApp();

const db = admin.firestore();

exports.createWithdrawal = onCall({ cors: true }, async (request) => {
  // ── Auth check ────────────────────────────────────────────────────────
  if (!request.auth) {
    throw new HttpsError(
      'unauthenticated',
      'You must be signed in to request a withdrawal.'
    );
  }

  const uid = request.auth.uid;
  const { amount, bank, accountNumber } = request.data;

  // ── Input validation ──────────────────────────────────────────────────
  if (typeof amount !== 'number' || amount <= 0) {
    throw new HttpsError(
      'invalid-argument',
      'Withdrawal amount must be a positive number.'
    );
  }
  if (!bank || !accountNumber) {
    throw new HttpsError(
      'invalid-argument',
      'Bank name and account number are required.'
    );
  }

  const userRef = db.collection('users').doc(uid);
  const withdrawalsRef = userRef.collection('withdrawals');

  // ── Atomic transaction ────────────────────────────────────────────────
  await db.runTransaction(async (tx) => {
    const userSnap = await tx.get(userRef);
    if (!userSnap.exists) {
      throw new HttpsError('not-found', 'User not found.');
    }
    const balance = userSnap.data().balance ?? 0;

    const pendingSnap = await tx.get(
      withdrawalsRef.where('status', 'in', ['pending', 'approved'])
    );
    const pendingTotal = pendingSnap.docs.reduce(
      (sum, d) => sum + (d.data().amount ?? 0),
      0
    );

    const available = balance - pendingTotal;
    if (available < amount) {
      throw new HttpsError(
        'failed-precondition',
        `Insufficient balance. Available: ${available.toFixed(2)} ETB, ` +
        `Requested: ${amount.toFixed(2)} ETB.`
      );
    }

    const newRef = withdrawalsRef.doc();
    tx.set(newRef, {
      amount,
      bank,
      accountNumber,
      status: 'pending',
      isReserved: true,
      reservedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  return { success: true };
});