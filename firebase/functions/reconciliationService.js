const admin = require("firebase-admin");

/**
 * SMS Webhook — receives forwarded banking SMS, parses them,
 * and auto-reconciles deposits.
 * Withdrawal logic has been intentionally removed from this service.
 * Withdrawals are approved manually by the admin (approve = deduct + mark done).
 */
exports.smsWebhook = async (req, res) => {
    const authHeader = req.headers.authorization;
    const queryToken = req.query.token;
    const expectedToken = process.env.WEBHOOK_SECRET;

    const hasValidHeader = authHeader === `Bearer ${expectedToken}`;
    const hasValidQuery = queryToken === expectedToken;

    if (!hasValidHeader && !hasValidQuery) {
        console.warn("Unauthorized SMS Webhook attempt blocked.");
        return res.status(401).send("Unauthorized: Invalid API Token");
    }

    const { sender, text } = req.body || {};
    if (!sender || !text) {
        return res.status(400).send("Bad Request: Missing sender or text");
    }

    try {
        console.log(`Received SMS from ${sender}: "${text}"`);

        const parsed = parseSmsNotification(sender, text);
        if (!parsed) {
            console.log("SMS does not match a Telebirr or CBE credit transaction template. Ignored.");
            return res.status(200).send("Ignored: Not a payment SMS");
        }

        const { amount, reference, bank } = parsed;
        console.log(`Parsed credit notification -> Bank: ${bank}, Amount: ${amount} ETB, Ref: ${reference}`);

        const db = admin.firestore();

        await db.runTransaction(async (transaction) => {
            const bankRef = db.collection("bank_notifications").doc(reference);
            const bankDoc = await transaction.get(bankRef);
            if (bankDoc.exists && bankDoc.data().status === "matched") {
                console.log(`Notification for reference ${reference} already matched. Skipping.`);
                return;
            }

            const depositsSnapshot = await db.collectionGroup("deposits")
                .where("reference", "==", reference)
                .where("status", "==", "pending")
                .get();

            if (!depositsSnapshot.empty) {
                const depositDoc = depositsSnapshot.docs[0];
                const depositData = depositDoc.data();
                const userRef = depositDoc.ref.parent.parent;

                if (Number(depositData.amount) === Number(amount)) {
                    console.log(`Match found! Auto-approving deposit for user: ${userRef.id}`);

                    transaction.update(depositDoc.ref, {
                        status: "approved",
                        verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
                        matchedVia: "sms_webhook"
                    });

                    const userDoc = await transaction.get(userRef);
                    const currentBalance = userDoc.exists ? (userDoc.data().balance || 0) : 0;
                    transaction.update(userRef, { balance: currentBalance + Number(amount) });

                    transaction.set(bankRef, {
                        amount, reference, bank, sender, text,
                        status: "matched",
                        userId: userRef.id,
                        depositId: depositDoc.id,
                        createdAt: admin.firestore.FieldValue.serverTimestamp()
                    });
                } else {
                    console.warn(`Reference matched but amounts differ! Expected ${depositData.amount}, Got ${amount}`);
                    transaction.set(bankRef, {
                        amount, reference, bank, sender, text,
                        status: "amount_mismatch",
                        createdAt: admin.firestore.FieldValue.serverTimestamp()
                    });
                }
            } else {
                if (!bankDoc.exists) {
                    transaction.set(bankRef, {
                        amount, reference, bank, sender, text,
                        status: "unmatched",
                        createdAt: admin.firestore.FieldValue.serverTimestamp()
                    });
                    console.log(`Saved unmatched bank notification for Ref: ${reference}`);
                }
            }
        });

        return res.status(200).send("Reconciliation completed");
    } catch (error) {
        console.error("SMS webhook error:", error);
        return res.status(500).send("Internal Server Error: " + error.message);
    }
};

/**
 * Triggered on deposit creation — checks if the bank SMS arrived first
 * and auto-approves if reference + amount match.
 */
exports.onDepositCreatedHandler = async (snap, context) => {
    const deposit = snap.data();
    const userId = context.params.userId;
    const depositId = context.params.depositId;
    const db = admin.firestore();

    const { reference, amount } = deposit;
    if (!reference) return null;

    try {
        const existingApproved = await db.collectionGroup("deposits")
            .where("reference", "==", reference)
            .where("status", "==", "approved")
            .get();

        if (!existingApproved.empty) {
            console.warn(`Duplicate reference detected: ${reference}. Rejecting.`);
            await snap.ref.update({
                status: "rejected",
                rejectionReason: "This reference number has already been used for a successful deposit."
            });
            return null;
        }

        await db.runTransaction(async (transaction) => {
            const bankRef = db.collection("bank_notifications").doc(reference);
            const bankDoc = await transaction.get(bankRef);

            if (bankDoc.exists) {
                const bankData = bankDoc.data();

                if (bankData.status === "matched") {
                    transaction.update(snap.ref, {
                        status: "rejected",
                        rejectionReason: "This transaction reference has already been processed."
                    });
                    console.warn(`Attempted reuse of matched reference ${reference}. Rejected.`);
                    return;
                }

                if (bankData.status === "unmatched") {
                    if (Number(bankData.amount) === Number(amount)) {
                        console.log(`Reconciled on create! Auto-approving reference: ${reference}`);

                        transaction.update(snap.ref, {
                            status: "approved",
                            verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
                            matchedVia: "on_create_trigger"
                        });

                        transaction.update(bankRef, {
                            status: "matched",
                            userId: userId,
                            depositId: depositId
                        });

                        const userRef = db.collection("users").doc(userId);
                        const userDoc = await transaction.get(userRef);
                        const currentBalance = userDoc.exists ? (userDoc.data().balance || 0) : 0;
                        transaction.update(userRef, { balance: currentBalance + Number(amount) });
                    } else {
                        console.warn(`Amount mismatch in onCreate! Bank: ${bankData.amount}, User: ${amount}`);
                        transaction.update(bankRef, { status: "amount_mismatch" });
                    }
                }
            } else {
                console.log(`Deposit ${depositId} for user ${userId} left PENDING — bank SMS for Ref: ${reference} not yet received.`);
            }
        });
    } catch (error) {
        console.error("onDepositCreated reconciliation error:", error);
    }
    return null;
};

/**
 * Triggered when a withdrawal document is created.
 *
 * Previous behaviour (REMOVED):
 *   - Reserved balance immediately on submit
 *   - Rejected if balance insufficient
 *   - onWithdrawalUpdated then refunded on rejection → caused double-credit bug
 *
 * New behaviour:
 *   - Balance is NOT touched on submit (Flutter already validated it)
 *   - Admin sees the pending request, pays the user manually, then calls
 *     approveWithdrawal() which deducts the balance once and marks it done
 *   - No rejection path — admin either approves or deletes the record
 */
exports.onWithdrawalCreatedHandler = async (snap, context) => {
    // Nothing to do — withdrawal just sits as 'pending' until admin approves.
    console.log(`Withdrawal created for user ${context.params.userId}, amount: ${snap.data().amount} ETB. Awaiting admin approval.`);
    return null;
};

/**
 * Called by the admin panel to approve a withdrawal.
 * Atomically deducts the balance and marks the withdrawal as approved.
 * This is the ONLY place the balance is ever deducted for a withdrawal.
 */
exports.approveWithdrawalHandler = async (request) => {
    const { userId, withdrawalId } = request.data;

    if (!request.auth || request.auth.token.admin !== true) {
        throw new Error("permission-denied: Admin only.");
    }

    if (!userId || !withdrawalId) {
        throw new Error("invalid-argument: userId and withdrawalId required.");
    }

    const db = admin.firestore();
    const withdrawalRef = db.collection("users").doc(userId).collection("withdrawals").doc(withdrawalId);
    const userRef = db.collection("users").doc(userId);

    try {
        await db.runTransaction(async (transaction) => {
            const withdrawalDoc = await transaction.get(withdrawalRef);
            if (!withdrawalDoc.exists) {
                throw new Error("not-found: Withdrawal does not exist.");
            }

            const withdrawal = withdrawalDoc.data();
            if (withdrawal.status !== "pending") {
                throw new Error(`already-processed: Withdrawal is already ${withdrawal.status}.`);
            }

            const amount = Number(withdrawal.amount);
            if (isNaN(amount) || amount <= 0) {
                throw new Error("invalid-argument: Invalid withdrawal amount.");
            }

            const userDoc = await transaction.get(userRef);
            if (!userDoc.exists) {
                throw new Error("not-found: User does not exist.");
            }

            const currentBalance = Number(userDoc.data().balance || 0);
            if (currentBalance < amount) {
                throw new Error(`failed-precondition: Insufficient balance. User has ${currentBalance} ETB, withdrawal is ${amount} ETB.`);
            }

            // Deduct balance and mark approved atomically
            transaction.update(userRef, { balance: currentBalance - amount });
            transaction.update(withdrawalRef, {
                status: "approved",
                verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            console.log(`Withdrawal ${withdrawalId} approved for user ${userId}. Deducted ${amount} ETB.`);
        });

        return { success: true };
    } catch (error) {
        console.error("approveWithdrawal error:", error);
        throw new Error(error.message);
    }
};

/**
 * Regex parser for Telebirr and CBE transaction confirmation messages.
 */
function parseSmsNotification(sender, text) {
    const cleanText = text.replace(/\s+/g, ' ');
    const lowerSender = sender.toLowerCase();

    // TELEBIRR
    if (lowerSender.includes("telebirr") || lowerSender.includes("802")) {
        const amountRegex = /(?:received|transferred)\s*([\d,.]+)\s*ETB/i;
        const refRegex = /(?:Ref|reference|Trans\.Ref):\s*([a-zA-Z0-9]+)/i;
        const amountMatch = cleanText.match(amountRegex);
        const refMatch = cleanText.match(refRegex);
        if (amountMatch && refMatch) {
            return {
                amount: parseFloat(amountMatch[1].replace(/,/g, '')),
                reference: refMatch[1].trim(),
                bank: "Telebirr"
            };
        }
    }

    // CBE
    if (lowerSender.includes("cbe") || lowerSender.includes("cbebirr") || lowerSender.includes("1000")) {
        const amountRegex = /(?:credited\s+with|received|transfer\s+of)\s*(?:ETB)?\s*([\d,.]+)/i;
        const ftRegex = /(FT[A-Z0-9]{10})/i;
        const amountMatch = cleanText.match(amountRegex);
        const refMatch = cleanText.match(ftRegex);
        if (amountMatch && refMatch) {
            return {
                amount: parseFloat(amountMatch[1].replace(/,/g, '')),
                reference: refMatch[1].trim(),
                bank: "CBE"
            };
        }
    }

    // GENERIC FALLBACK
    const genericAmountRegex = /(?:ETB|Birr)\s*([\d,.]+)/i;
    const genericRefRegex = /(?:Ref|Txn|Reference):\s*([a-zA-Z0-9]+)/i;
    const gAmountMatch = cleanText.match(genericAmountRegex);
    const gRefMatch = cleanText.match(genericRefRegex);
    if (gAmountMatch && gRefMatch) {
        return {
            amount: parseFloat(gAmountMatch[1].replace(/,/g, '')),
            reference: gRefMatch[1].trim(),
            bank: "Generic"
        };
    }

    return null;
}
