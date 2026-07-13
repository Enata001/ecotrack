const { onCall, HttpsError } = require("firebase-functions/v2/https");
const {
  onDocumentCreated,
  onDocumentUpdated,
} = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { getFirestore, FieldValue, Timestamp } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { getAuth } = require("firebase-admin/auth");
const { getStorage } = require("firebase-admin/storage");
const { initializeApp } = require("firebase-admin/app");

initializeApp();
const db = getFirestore();

const NEARBY_RADIUS_METERS = 5000;
const APPROACH_RADIUS_METERS = 300;

/// Platform-specific config that makes a push arrive as a heads-up /
/// pop-up notification instead of quietly landing in the shade:
/// - Android: "high" priority + our max-importance channel id.
/// - iOS: "apns-priority: 10" (immediate) + a sound, which is required
///   for the banner to show while the device is locked/backgrounded.
/// Every call to getMessaging().send / sendEachForMulticast should spread
/// this in, alongside the notification/data payload.
function popupDeliveryConfig() {
  return {
    android: {
      priority: "high",
      notification: {
        channelId: "high_importance_channel",
        priority: "max",
        sound: "default",
      },
    },
    apns: {
      headers: { "apns-priority": "10" },
      payload: {
        aps: { sound: "default", "content-available": 1 },
      },
    },
  };
}

/// Fetches the given user's stored FCM token and sends a push if present.
/// Silently no-ops if the user has no token (notifications disabled, or
/// they never registered one) — callers don't need to check first.
async function sendPushToUid(uid, { title, body, data }) {
  if (!uid) return;
  const userDoc = await db.collection("users").doc(uid).get();
  const token = userDoc.data()?.fcmToken;
  if (!token) return;

  await getMessaging().send({
    token,
    notification: { title, body },
    data,
    ...popupDeliveryConfig(),
  });
}

function distanceMeters(a, b) {
  const R = 6371000;
  const toRad = (deg) => (deg * Math.PI) / 180;
  const dLat = toRad(b.latitude - a.latitude);
  const dLng = toRad(b.longitude - a.longitude);
  const lat1 = toRad(a.latitude);
  const lat2 = toRad(b.latitude);

  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(h));
}

exports.onRequestCreated = onDocumentCreated(
  "wasteRequests/{requestId}",
  async (event) => {
    const request = event.data.data();
    const requestLocation = request.location;

    const collectorsSnap = await db
      .collection("collectors")
      .where("isAvailable", "==", true)
      .get();

    const tokens = [];
    collectorsSnap.forEach((doc) => {
      const collector = doc.data();
      if (!collector.currentLocation || !collector.fcmToken) return;
      const dist = distanceMeters(requestLocation, collector.currentLocation);
      if (dist <= NEARBY_RADIUS_METERS) tokens.push(collector.fcmToken);
    });

    if (tokens.length === 0) return;

    await getMessaging().sendEachForMulticast({
      tokens,
      notification: {
        title: "New pickup request nearby",
        body: "A waste pickup request is available near you.",
      },
      data: { requestId: event.params.requestId, type: "request_created" },
      ...popupDeliveryConfig(),
    });
  }
);

exports.acceptRequest = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in required.");

  const requestId = request.data.requestId;
  if (!requestId) throw new HttpsError("invalid-argument", "requestId is required.");

  const requestRef = db.collection("wasteRequests").doc(requestId);
  const collectorRef = db.collection("collectors").doc(uid);

  await db.runTransaction(async (tx) => {
    const requestDoc = await tx.get(requestRef);
    if (!requestDoc.exists) {
      throw new HttpsError("not-found", "Request no longer exists.");
    }
    if (requestDoc.data().status !== "pending") {
      throw new HttpsError("already-exists", "Already taken.");
    }

    tx.update(requestRef, {
      status: "accepted",
      collectorId: uid,
    });

    tx.set(
      collectorRef,
      { activeRequestIds: FieldValue.arrayUnion(requestId) },
      { merge: true }
    );
  });

  const requestDoc = await requestRef.get();
  const userId = requestDoc.data().userId;
  await sendPushToUid(userId, {
    title: "Request accepted",
    body: "A collector has accepted your pickup request.",
    data: { requestId, type: "request_accepted" },
  });

  return { success: true };
});

exports.declineRequest = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in required.");

  const requestId = request.data.requestId;
  if (!requestId) throw new HttpsError("invalid-argument", "requestId is required.");

  await db.collection("wasteRequests").doc(requestId).update({
    declinedByCollectorIds: FieldValue.arrayUnion(uid),
  });

  return { success: true };
});

exports.cancelRequest = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in required.");

  const requestId = request.data.requestId;
  if (!requestId) throw new HttpsError("invalid-argument", "requestId is required.");

  const requestRef = db.collection("wasteRequests").doc(requestId);
  let cancelledCollectorId = null;

  await db.runTransaction(async (tx) => {
    const requestDoc = await tx.get(requestRef);
    if (!requestDoc.exists) {
      throw new HttpsError("not-found", "Request no longer exists.");
    }
    const data = requestDoc.data();
    if (data.userId !== uid) {
      throw new HttpsError("permission-denied", "Not your request.");
    }
    if (data.status !== "pending" && data.status !== "accepted") {
      throw new HttpsError(
        "failed-precondition",
        "Only pending or accepted requests can be cancelled."
      );
    }

    tx.update(requestRef, { status: "cancelled" });

    if (data.collectorId) {
      cancelledCollectorId = data.collectorId;
      tx.set(
        db.collection("collectors").doc(data.collectorId),
        { activeRequestIds: FieldValue.arrayRemove(requestId) },
        { merge: true }
      );
    }
  });

  if (cancelledCollectorId) {
    await sendPushToUid(cancelledCollectorId, {
      title: "Pickup cancelled",
      body: "The user cancelled this pickup request.",
      data: { requestId, type: "request_cancelled" },
    });
  }

  return { success: true };
});

exports.startEnroute = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in required.");

  const requestId = request.data.requestId;
  if (!requestId) throw new HttpsError("invalid-argument", "requestId is required.");

  const requestRef = db.collection("wasteRequests").doc(requestId);
  let notifyUserId = null;

  await db.runTransaction(async (tx) => {
    const requestDoc = await tx.get(requestRef);
    if (!requestDoc.exists) {
      throw new HttpsError("not-found", "Request no longer exists.");
    }
    const data = requestDoc.data();
    if (data.collectorId !== uid) {
      throw new HttpsError("permission-denied", "Not assigned to this request.");
    }
    if (data.status !== "accepted") {
      throw new HttpsError(
        "failed-precondition",
        "Request must be accepted before starting the trip."
      );
    }
    tx.update(requestRef, { status: "enroute" });
    notifyUserId = data.userId;
  });

  await sendPushToUid(notifyUserId, {
    title: "Collector on the way",
    body: "Your collector has started heading to you.",
    data: { requestId, type: "collector_enroute" },
  });

  return { success: true };
});

exports.markArrived = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in required.");

  const requestId = request.data.requestId;
  if (!requestId) throw new HttpsError("invalid-argument", "requestId is required.");

  const requestRef = db.collection("wasteRequests").doc(requestId);
  let notifyUserId = null;

  await db.runTransaction(async (tx) => {
    const requestDoc = await tx.get(requestRef);
    if (!requestDoc.exists) {
      throw new HttpsError("not-found", "Request no longer exists.");
    }
    const data = requestDoc.data();
    if (data.collectorId !== uid) {
      throw new HttpsError("permission-denied", "Not assigned to this request.");
    }
    if (data.status !== "enroute") {
      throw new HttpsError(
        "failed-precondition",
        "Trip must be started before marking arrival."
      );
    }
    tx.update(requestRef, { arrivedAt: FieldValue.serverTimestamp() });
    notifyUserId = data.userId;
  });

  await sendPushToUid(notifyUserId, {
    title: "Collector has arrived",
    body: "Your collector is here for the pickup.",
    data: { requestId, type: "collector_arrived" },
  });

  return { success: true };
});

exports.completePickup = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in required.");

  const { requestId, weightKg, wasteType } = request.data;
  if (!requestId || weightKg == null || !wasteType) {
    throw new HttpsError("invalid-argument", "Missing required fields.");
  }

  const requestRef = db.collection("wasteRequests").doc(requestId);
  const collectorRef = db.collection("collectors").doc(uid);
  const receiptRef = db.collection("receipts").doc();

  const impactScore = computeImpactScore(weightKg, wasteType);

  await db.runTransaction(async (tx) => {
    const requestDoc = await tx.get(requestRef);
    if (!requestDoc.exists) {
      throw new HttpsError("not-found", "Request no longer exists.");
    }
    if (requestDoc.data().collectorId !== uid) {
      throw new HttpsError("permission-denied", "Not assigned to this request.");
    }

    tx.update(requestRef, {
      status: "completed",
      completedAt: FieldValue.serverTimestamp(),
    });

    tx.set(
      collectorRef,
      { activeRequestIds: FieldValue.arrayRemove(requestId) },
      { merge: true }
    );

    tx.set(receiptRef, {
      requestId,
      weightKg,
      wasteType,
      impactScore,
      timestamp: FieldValue.serverTimestamp(),
    });
  });

  const requestDoc = await requestRef.get();
  const userId = requestDoc.data().userId;
  const [userDoc, collectorDoc] = await Promise.all([
    db.collection("users").doc(userId).get(),
    db.collection("users").doc(uid).get(),
  ]);

  const notifications = [];
  if (userDoc.data()?.fcmToken) {
    notifications.push(
      getMessaging().send({
        token: userDoc.data().fcmToken,
        notification: {
          title: "Pickup completed",
          body: `Your receipt is ready. Impact score: ${impactScore}.`,
        },
        data: { requestId, type: "pickup_completed" },
        ...popupDeliveryConfig(),
      })
    );
  }
  if (collectorDoc.data()?.fcmToken) {
    notifications.push(
      getMessaging().send({
        token: collectorDoc.data().fcmToken,
        notification: {
          title: "Pickup logged",
          body: "Pickup marked as completed.",
        },
        data: { requestId, type: "pickup_completed" },
        ...popupDeliveryConfig(),
      })
    );
  }
  await Promise.allSettled(notifications);

  return { success: true, impactScore };
});

/// Rates the other party on a completed pickup — a user rating their
/// collector, or a collector rating the user. Enforces exactly one rating
/// per side per request, and atomically folds the new star count into the
/// rated account's running average (stored as ratingSum/ratingCount so the
/// average can be recomputed exactly, rather than drifting from repeated
/// incremental averaging).
exports.submitRating = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in required.");

  const { requestId, stars, comment } = request.data;
  if (!requestId || typeof stars !== "number" || stars < 1 || stars > 5) {
    throw new HttpsError(
      "invalid-argument",
      "A requestId and a 1-5 star rating are required."
    );
  }

  const requestRef = db.collection("wasteRequests").doc(requestId);

  await db.runTransaction(async (tx) => {
    // All reads must happen before any writes in a Firestore transaction.
    const requestDoc = await tx.get(requestRef);
    if (!requestDoc.exists) {
      throw new HttpsError("not-found", "Request no longer exists.");
    }
    const data = requestDoc.data();
    if (data.status !== "completed") {
      throw new HttpsError(
        "failed-precondition",
        "Only completed pickups can be rated."
      );
    }

    let ratedUserId;
    let raterRole;
    if (data.userId === uid) {
      if (data.ratedByUser) {
        throw new HttpsError("already-exists", "Already rated.");
      }
      ratedUserId = data.collectorId;
      raterRole = "user";
    } else if (data.collectorId === uid) {
      if (data.ratedByCollector) {
        throw new HttpsError("already-exists", "Already rated.");
      }
      ratedUserId = data.userId;
      raterRole = "collector";
    } else {
      throw new HttpsError("permission-denied", "You weren't part of this pickup.");
    }

    const ratedUserRef = db.collection("users").doc(ratedUserId);
    const ratedUserDoc = await tx.get(ratedUserRef);
    const ratedUserData = ratedUserDoc.data() || {};
    const prevCount = ratedUserData.ratingCount ?? 0;
    // Back-fill ratingSum from the existing displayed average the first
    // time a rating lands on an account created before this feature.
    const prevSum =
      ratedUserData.ratingSum ?? (ratedUserData.rating ?? 5) * prevCount;

    // From here on: writes only.
    tx.update(requestRef, {
      [raterRole === "user" ? "ratedByUser" : "ratedByCollector"]: true,
    });

    const ratingRef = db.collection("ratings").doc();
    tx.set(ratingRef, {
      requestId,
      raterId: uid,
      raterRole,
      ratedUserId,
      stars,
      comment: comment || null,
      createdAt: FieldValue.serverTimestamp(),
    });

    const newCount = prevCount + 1;
    const newSum = prevSum + stars;
    tx.update(ratedUserRef, {
      ratingSum: newSum,
      ratingCount: newCount,
      rating: Math.round((newSum / newCount) * 10) / 10,
    });
  });

  return { success: true };
});

/// Turns due scheduled pickups into real requests. Creating a document in
/// wasteRequests here fires onRequestCreated exactly as if a user had
/// tapped "Request pickup" themselves, so nearby collectors get notified
/// through the same path — no separate notification logic needed.
exports.runScheduledPickups = onSchedule("every 60 minutes", async () => {
  const now = Timestamp.now();
  const dueSnap = await db
    .collection("scheduledPickups")
    .where("active", "==", true)
    .where("nextRunAt", "<=", now)
    .get();

  if (dueSnap.empty) return;

  const RECURRENCE_DAYS = { weekly: 7, biweekly: 14 };

  for (const doc of dueSnap.docs) {
    const schedule = doc.data();

    const requestRef = db.collection("wasteRequests").doc();
    await requestRef.set({
      userId: schedule.userId,
      collectorId: null,
      location: schedule.location,
      address: schedule.address || null,
      wasteTypes: schedule.wasteTypes,
      status: "pending",
      createdAt: FieldValue.serverTimestamp(),
      completedAt: null,
      arrivedAt: null,
      approachNotified: false,
      declinedByCollectorIds: [],
      contactPhone: schedule.contactPhone,
      photoUrl: schedule.photoUrl || null,
      ratedByUser: false,
      ratedByCollector: false,
      scheduledPickupId: doc.id,
    });

    await sendPushToUid(schedule.userId, {
      title: "Scheduled pickup started",
      body: "Your recurring pickup just went live — nearby collectors have been notified.",
      data: { requestId: requestRef.id, type: "schedule_activated" },
    });

    if (schedule.recurrence === "once") {
      await doc.ref.update({ active: false, lastRunAt: FieldValue.serverTimestamp() });
      continue;
    }

    let nextRunDate;
    if (schedule.recurrence === "monthly") {
      nextRunDate = schedule.nextRunAt.toDate();
      nextRunDate.setMonth(nextRunDate.getMonth() + 1);
    } else {
      const addDays = RECURRENCE_DAYS[schedule.recurrence] ?? 7;
      nextRunDate = new Date(
        schedule.nextRunAt.toDate().getTime() + addDays * 24 * 60 * 60 * 1000
      );
    }

    await doc.ref.update({
      nextRunAt: Timestamp.fromDate(nextRunDate),
      lastRunAt: FieldValue.serverTimestamp(),
    });
  }
});

function computeImpactScore(weightKg, wasteType) {
  const factors = {
    general: 0.1,
    recyclable: 0.6,
    organic: 0.3,
    electronic: 0.8,
    hazardous: 0.4,
    bulky: 0.2,
  };
  const factor = factors[wasteType] ?? 0.2;
  return Math.round(weightKg * factor * 100) / 100;
}

exports.optimizeRoute = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in required.");

  const { origin, stops } = request.data;
  if (!origin || !Array.isArray(stops) || stops.length === 0) {
    throw new HttpsError("invalid-argument", "origin and stops are required.");
  }

  const toPoint = (p) => ({ latitude: p.lat, longitude: p.lng, id: p.id });
  const originPoint = toPoint({ ...origin, id: null });

  const remaining = stops.map(toPoint);
  const orderedStopIds = [];
  const etaMinutes = {};
  let current = originPoint;
  let totalMinutes = 0;

  while (remaining.length > 0) {
    remaining.sort(
      (a, b) => distanceMeters(current, a) - distanceMeters(current, b)
    );
    const next = remaining.shift();
    const legMinutes = Math.max(1, Math.round(distanceMeters(current, next) / 400));
    totalMinutes += legMinutes;
    orderedStopIds.push(next.id);
    etaMinutes[next.id] = totalMinutes;
    current = next;
  }

  return { orderedStopIds, etaMinutes };
});

exports.onCollectorLocationUpdated = onDocumentUpdated(
  "collectors/{collectorId}",
  async (event) => {
    const after = event.data.after.data();

    if (!after.currentLocation) return;
    if (!after.activeRequestIds || after.activeRequestIds.length === 0) return;

    const collectorId = event.params.collectorId;

    const enrouteRequests = await db
      .collection("wasteRequests")
      .where("collectorId", "==", collectorId)
      .where("status", "==", "enroute")
      .where("approachNotified", "==", false)
      .get();

    if (enrouteRequests.empty) return;

    const notifications = [];
    for (const doc of enrouteRequests.docs) {
      const request = doc.data();
      const distance = distanceMeters(after.currentLocation, request.location);

      if (distance <= APPROACH_RADIUS_METERS) {
        notifications.push(
          (async () => {
            const userDoc = await db.collection("users").doc(request.userId).get();
            const userToken = userDoc.data()?.fcmToken;

            await doc.ref.update({ approachNotified: true });

            if (userToken) {
              await getMessaging().send({
                token: userToken,
                notification: {
                  title: "Your collector is almost there",
                  body: "Your collector is nearby and will arrive shortly.",
                },
                data: { requestId: doc.id, type: "collector_approaching" },
                ...popupDeliveryConfig(),
              });
            }
          })()
        );
      }
    }

    await Promise.allSettled(notifications);
  }
);

exports.deleteAccount = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in required.");

  const [asUser, asCollector] = await Promise.all([
    db
      .collection("wasteRequests")
      .where("userId", "==", uid)
      .where("status", "in", ["pending", "accepted", "enroute"])
      .limit(1)
      .get(),
    db
      .collection("wasteRequests")
      .where("collectorId", "==", uid)
      .where("status", "in", ["pending", "accepted", "enroute"])
      .limit(1)
      .get(),
  ]);

  if (!asUser.empty || !asCollector.empty) {
    throw new HttpsError(
      "failed-precondition",
      "You have an active pickup request. Cancel or complete it before deleting your account."
    );
  }

  const batch = db.batch();
  batch.delete(db.collection("users").doc(uid));
  batch.delete(db.collection("collectors").doc(uid));
  await batch.commit();

  try {
    await getStorage().bucket().file(`profile_photos/${uid}`).delete();
  } catch (_) {
    // No profile photo to clean up — not an error.
  }

  await getAuth().deleteUser(uid);

  return { success: true };
});