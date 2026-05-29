/**
 * createWithdrawal – callable Cloud Function
 *
 * Atomically:
 *  1. Reads the user's current balance.
 *  2. Sums all pending/reserved withdrawal amounts.
 *  3. Rejects if (balance - pendingTotal) < requestedAmount.
 *  4. Writes the withdrawal doc with isReserved: true inside a transaction
 *     so no concurrent request can slip through.
 *
 * The admin approval flow should only update `status` to 'approved' and
 * trigger the actual bank transfer — the balance is already reserved here.
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Guard against double-initialisation when bundled with other functions.
if (!admin.apps.length) admin.initializeApp();

const db = admin.firestore();

exports.createWithdrawal = functions.https.onCall(async (data, context) => {
  // ── Auth check ──────────────────────────────────────────────────────────
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'You must be signed in to request a withdrawal.'
    );
  }

  const uid = context.auth.uid;
  const { amount, bank, accountNumber } = data;

  // ── Input validation ────────────────────────────────────────────────────
  if (typeof amount !== 'number' || amount <= 0) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Withdrawal amount must be a positive number.'
    );
  }
  if (!bank || !accountNumber) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Bank name and account number are required.'
    );
  }

  const userRef = db.collection('users').doc(uid);
  const withdrawalsRef = userRef.collection('withdrawals');

  // ── Atomic transaction ──────────────────────────────────────────────────
  await db.runTransaction(async (tx) => {
    // 1. Read current balance
    const userSnap = await tx.get(userRef);
    if (!userSnap.exists) {
      throw new functions.https.HttpsError('not-found', 'User not found.');
    }
    const balance = (userSnap.data().balance ?? 0);

    // 2. Sum all withdrawals that are pending or already reserved
    //    (i.e. not yet rejected/refunded)
    const pendingSnap = await tx.get(
      withdrawalsRef.where('status', 'in', ['pending', 'approved'])
    );
    const pendingTotal = pendingSnap.docs.reduce(
      (sum, d) => sum + (d.data().amount ?? 0),
      0
    );

    // 3. Check available balance
    const available = balance - pendingTotal;
    if (available < amount) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        `Insufficient balance. Available: ${available.toFixed(2)} ETB, ` +
        `Requested: ${amount.toFixed(2)} ETB.`
      );
    }

    // 4. Write the withdrawal document with isReserved: true
    const newRef = withdrawalsRef.doc();
    tx.set(newRef, {
      amount,
      bank,
      accountNumber,
      status: 'pending',
      isReserved: true,        // balance is reserved from this moment
      reservedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  return { success: true };
});
