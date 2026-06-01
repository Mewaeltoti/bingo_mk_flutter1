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

    // Simple balance check — the trigger already deducts balance atomically
    // when it sets isReserved=true, so the live balance IS the available balance.
    // Do NOT subtract pending withdrawals here — they were already deducted
    // from balance by the trigger, so subtracting them again would
    // double-count and wrongly block legitimate withdrawals.
    if (balance < amount) {
      throw new HttpsError(
        'failed-precondition',
        `Insufficient balance. Available: ${balance.toFixed(2)} ETB, ` +
        `Requested: ${amount.toFixed(2)} ETB.`
      );
    }

    const newRef = withdrawalsRef.doc();
    tx.set(newRef, {
      amount,
      bank,
      accountNumber,
      status: 'pending',
      // isReserved starts FALSE — the onWithdrawalCreated trigger is the ONLY
      // place that sets it to true, and only after it has actually deducted the
      // balance.  If we wrote true here, a fast admin rejection would see
      // isReserved=true and trigger a refund BEFORE the balance was ever
      // deducted, crediting the user an extra amount (e.g. 100 → 150).
      isReserved: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  return { success: true };
});