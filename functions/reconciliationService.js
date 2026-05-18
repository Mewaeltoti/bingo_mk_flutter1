const admin = require("firebase-admin");

if (!admin.apps.length) {
    admin.initializeApp();
}

/**
 * SMS Webhook - Receives forwarded banking SMS messages, parses them, 
 * and reconciles deposits.
 */
exports.smsWebhook = async (req, res) => {
    // 1. Verify API Token
    const authHeader = req.headers.authorization;
    const queryToken = req.query.token;

    // You should change this secret token to a strong password and set it in your SMS Forwarder app
    const expectedToken = "BingoEthioSharedSecretToken2026";

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

        // 2. Parse CBE or Telebirr notification
        const parsed = parseSmsNotification(sender, text);
        if (!parsed) {
            console.log("SMS does not match a Telebirr or CBE credit transaction template. Ignored.");
            return res.status(200).send("Ignored: Not a payment SMS");
        }

        const { amount, reference, bank } = parsed;
        console.log(`Parsed credit notification -> Bank: ${bank}, Amount: ${amount} ETB, Ref: ${reference}`);

        const db = admin.firestore();

        // 3. Match and reconcile atomically in a Firestore Transaction
        await db.runTransaction(async (transaction) => {
            // Check if this reference has already been matched
            const bankRef = db.collection("bank_notifications").doc(reference);
            const bankDoc = await transaction.get(bankRef);
            if (bankDoc.exists && bankDoc.data().status === "matched") {
                console.log(`Webhook: Notification for reference ${reference} has already been matched. Skipping duplicate processing.`);
                return;
            }

            // Search for a pending user deposit with this reference number
            const depositsSnapshot = await db.collectionGroup("deposits")
                .where("reference", "==", reference)
                .where("status", "==", "pending")
                .get();

            if (!depositsSnapshot.empty) {
                // Match found! Reconcile immediately
                const depositDoc = depositsSnapshot.docs[0];
                const depositData = depositDoc.data();
                const userRef = depositDoc.ref.parent.parent; // deposits is subcollection of users/{userId}

                // Verify amount matches
                if (Number(depositData.amount) === Number(amount)) {
                    console.log(`Match found! Auto-approving deposit for user: ${userRef.id}`);

                    // Update user deposit status
                    transaction.update(depositDoc.ref, {
                        status: "approved",
                        verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
                        matchedVia: "sms_webhook"
                    });

                    // Credit user's wallet
                    const userDoc = await transaction.get(userRef);
                    const currentBalance = userDoc.exists ? (userDoc.data().balance || 0) : 0;
                    transaction.update(userRef, { balance: currentBalance + Number(amount) });

                    // Save matched bank notification doc
                    transaction.set(bankRef, {
                        amount,
                        reference,
                        bank,
                        sender,
                        text,
                        status: "matched",
                        userId: userRef.id,
                        depositId: depositDoc.id,
                        createdAt: admin.firestore.FieldValue.serverTimestamp()
                    });
                } else {
                    console.warn(`Reference matched, but amounts differ! Expected ${depositData.amount}, Got ${amount}`);
                    // Save as unmatched notification with amount_mismatch flag for manual admin review
                    transaction.set(bankRef, {
                        amount,
                        reference,
                        bank,
                        sender,
                        text,
                        status: "amount_mismatch",
                        createdAt: admin.firestore.FieldValue.serverTimestamp()
                    });
                }
            } else {
                // NO PENDING USER DEPOSIT YET. Save bank notification as unmatched.
                // When the user submits the reference later, the deposit trigger will match it.
                if (!bankDoc.exists) {
                    transaction.set(bankRef, {
                        amount,
                        reference,
                        bank,
                        sender,
                        text,
                        status: "unmatched",
                        createdAt: admin.firestore.FieldValue.serverTimestamp()
                    });
                    console.log(`Saved unmatched bank notification for Ref: ${reference}`);
                } else {
                    console.log(`Bank notification for Ref: ${reference} already exists in database.`);
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
 * Triggered on user deposit document creation to check if bank SMS arrived first.
 */
exports.onDepositCreatedHandler = async (snap, context) => {
    const deposit = snap.data();
    const userId = context.params.userId;
    const depositId = context.params.depositId;
    const db = admin.firestore();

    const { reference, amount } = deposit;
    if (!reference) return null;

    try {
        // 1. Check for duplicates in approved deposits database-wide
        const existingApproved = await db.collectionGroup("deposits")
            .where("reference", "==", reference)
            .where("status", "==", "approved")
            .get();

        if (!existingApproved.empty) {
            console.warn(`Duplicate reference detected on creation: ${reference}. Rejecting.`);
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
                    // Already used reference in bank_notifications
                    transaction.update(snap.ref, {
                        status: "rejected",
                        rejectionReason: "This transaction reference has already been processed."
                    });
                    console.warn(`Attempted reuse of matched reference ${reference}. Rejected.`);
                    return;
                }

                if (bankData.status === "unmatched") {
                    // Check if amount matches
                    if (Number(bankData.amount) === Number(amount)) {
                        console.log(`Reconciled deposit on create! Auto-approving reference: ${reference}`);

                        // Update user deposit
                        transaction.update(snap.ref, {
                            status: "approved",
                            verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
                            matchedVia: "on_create_trigger"
                        });

                        // Update bank notification
                        transaction.update(bankRef, {
                            status: "matched",
                            userId: userId,
                            depositId: depositId
                        });

                        // Credit user wallet
                        const userRef = db.collection("users").doc(userId);
                        const userDoc = await transaction.get(userRef);
                        const currentBalance = userDoc.exists ? (userDoc.data().balance || 0) : 0;
                        transaction.update(userRef, { balance: currentBalance + Number(amount) });
                    } else {
                        console.warn(`Unmatched amount mismatch in onCreate! Bank: ${bankData.amount}, User: ${amount}`);
                        transaction.update(bankRef, { status: "amount_mismatch" });
                    }
                }
            }
        });
    } catch (error) {
        console.error("onDepositCreated reconciliation error:", error);
    }
    return null;
};

/**
 * Regex parser for Telebirr and CBE transaction confirmation messages.
 */
function parseSmsNotification(sender, text) {
    // Normalize spaces and casing
    const cleanText = text.replace(/\s+/g, ' ');
    const lowerSender = sender.toLowerCase();

    // 1. TELEBIRR PARSING
    // Standard template: "You have received 150.00 ETB from ... Ref: Trans.Ref: A1B2C3D4E5"
    if (lowerSender.includes("telebirr") || lowerSender.includes("802")) {
        const amountRegex = /(?:received|transferred)\s*([\d,.]+)\s*ETB/i;
        const refRegex = /(?:Ref|reference|Trans\.Ref):\s*([a-zA-Z0-9]+)/i;

        const amountMatch = cleanText.match(amountRegex);
        const refMatch = cleanText.match(refRegex);

        if (amountMatch && refMatch) {
            const amount = parseFloat(amountMatch[1].replace(/,/g, ''));
            const reference = refMatch[1].trim();
            return { amount, reference, bank: "Telebirr" };
        }
    }

    // 2. CBE PARSING
    // Handles CBE Mobile App: "Credited with ETB 1,100.00 ... Ref No FT26133721GP"
    // Handles CBE USSD: "You have received ETB 100.00 ... https://Mbreciept.cbe.com.et/FT26134ML0BQ-17643426"
    if (lowerSender.includes("cbe") || lowerSender.includes("cbebirr") || lowerSender.includes("1000")) {
        // Match deposit amount: "credited with ETB 1,100.00" or "received ETB 100.00"
        const amountRegex = /(?:credited\s+with|received|transfer\s+of)\s*(?:ETB)?\s*([\d,.]+)/i;
        const amountMatch = cleanText.match(amountRegex);

        // CBE reference numbers always start with FT followed by 10 alphanumeric characters (12 chars total).
        // This is robust enough to extract it from "Ref No FT...", "FT..." or inside the receipt URLs!
        const ftRegex = /(FT[A-Z0-9]{10})/i;
        const refMatch = cleanText.match(ftRegex);

        if (amountMatch && refMatch) {
            const amount = parseFloat(amountMatch[1].replace(/,/g, ''));
            const reference = refMatch[1].trim();
            return { amount, reference, bank: "CBE" };
        }
    }

    // 3. GENERIC FALLBACK
    const genericAmountRegex = /(?:ETB|Birr)\s*([\d,.]+)/i;
    const genericRefRegex = /(?:Ref|Txn|Reference):\s*([a-zA-Z0-9]+)/i;

    const gAmountMatch = cleanText.match(genericAmountRegex);
    const gRefMatch = cleanText.match(genericRefRegex);

    if (gAmountMatch && gRefMatch) {
        const amount = parseFloat(gAmountMatch[1].replace(/,/g, ''));
        const reference = gRefMatch[1].trim();
        return { amount, reference, bank: "Generic" };
    }

    return null;
}
