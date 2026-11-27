const { initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { FieldValue, getFirestore } = require("firebase-admin/firestore");
const { HttpsError, onCall } = require("firebase-functions/v2/https");

initializeApp();

async function requireAdmin(request, db) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in to manage accounts.");
  }

  const adminSnapshot = await db
    .collection("users")
    .doc(request.auth.uid)
    .get();
  if (adminSnapshot.data()?.role !== "admin") {
    throw new HttpsError("permission-denied", "Admin access is required.");
  }
}

exports.createUserAccount = onCall(
  { region: "us-central1" },
  async (request) => {
    const db = getFirestore();
    await requireAdmin(request, db);

    const fullName =
      typeof request.data?.fullName === "string"
        ? request.data.fullName.trim()
        : "";
    const email =
      typeof request.data?.email === "string"
        ? request.data.email.trim().toLowerCase()
        : "";
    const password = request.data?.password;
    const phone =
      typeof request.data?.phone === "string" ? request.data.phone.trim() : "";
    const role = request.data?.role;
    if (!fullName || !email || typeof password !== "string") {
      throw new HttpsError(
        "invalid-argument",
        "Name, email, and password are required.",
      );
    }
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
      throw new HttpsError("invalid-argument", "Enter a valid email address.");
    }
    if (password.length < 6) {
      throw new HttpsError(
        "invalid-argument",
        "Password must be at least 6 characters.",
      );
    }
    if (!["commuter", "driver", "admin"].includes(role)) {
      throw new HttpsError("invalid-argument", "The selected role is invalid.");
    }

    let userRecord;
    try {
      userRecord = await getAuth().createUser({
        email,
        password,
        displayName: fullName,
      });

      const batch = db.batch();
      batch.set(db.collection("users").doc(userRecord.uid), {
        uid: userRecord.uid,
        email,
        fullName,
        phone,
        role,
        activePlate: null,
        plates: [],
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      batch.set(db.collection("logs").doc(), {
        title: "Account created",
        description: `${fullName} (${email})`,
        actor: request.auth.token.email ?? request.auth.uid,
        actorUid: request.auth.uid,
        type: "Account",
        createdAt: FieldValue.serverTimestamp(),
      });
      await batch.commit();

      return { success: true, uid: userRecord.uid };
    } catch (error) {
      if (userRecord) {
        throw new HttpsError(
          "internal",
          "The Auth account may exist, but its Firestore profile could not be saved.",
        );
      }
      if (error instanceof HttpsError) {
        throw error;
      }
      if (error.code === "auth/email-already-exists") {
        throw new HttpsError("already-exists", "That email is already in use.");
      }
      if (error.code === "auth/invalid-password") {
        throw new HttpsError(
          "invalid-argument",
          "Password must be at least 6 characters.",
        );
      }
      throw new HttpsError("internal", "Unable to create the account.");
    }
  },
);

