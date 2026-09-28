/**
 * Tells a seller when their order moves.
 *
 * Everything is in one project. `orders` and `users` live here, so the
 * Firestore trigger fires here; and the Android app's *default* Firebase app
 * is this project too, so the device's FCM token is minted here and can be
 * sent to directly.
 *
 * That was not always true. The app reads the owner's second-hand stock from
 * a separate project, fren-75087, and the default app used to point there —
 * which put the token in one project and the trigger in another, and a send
 * across that gap fails with SenderId mismatch. It was briefly bridged with a
 * service account. Swapping which project is the default removed the need:
 * see lib/firebase/second_hand_firebase.dart.
 *
 * Deploy with: firebase deploy --only functions
 */

const {
  onDocumentUpdated,
  onDocumentCreated,
} = require("firebase-functions/v2/firestore");
const { setGlobalOptions } = require("firebase-functions/v2");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

// asia-south1 matches the Firestore database's own location, which a v2
// Firestore trigger requires.
setGlobalOptions({ region: "asia-south1", maxInstances: 10 });

admin.initializeApp();

/**
 * What to say for each status.
 *
 * Every one of the four is covered, including a move *back* to "placed" —
 * that usually means something went wrong, and a seller finding out by
 * accident later is worse than being told plainly now.
 *
 * The strings must stay in step with lib/models/order_status.dart, which is
 * the list the app itself understands; anything not in here is not announced
 * rather than announced badly.
 */
function messageFor(status, order) {
  const device = [order.brand, order.modelName].filter(Boolean).join(" ") ||
    "your phone";

  switch (status) {
    case "agent_assigned":
      return {
        title: "An agent is on the way",
        body: `Someone has been assigned to collect ${device}. Keep it handy.`,
      };
    case "inspection":
      return {
        title: "Your phone is being checked",
        body: `The agent is inspecting ${device} now. The final amount is ` +
          `confirmed once that is done.`,
      };
    case "paid":
      return {
        title: "Payment sent",
        body: order.finalPayout
          ? `₹${order.finalPayout} is on its way for ${device}. Thank you.`
          : `Payment for ${device} is on its way. Thank you.`,
      };
    case "placed":
      return {
        title: "Your order has been reopened",
        body: `${device} has been put back to "order placed". We will be in ` +
          `touch shortly.`,
      };
    default:
      return null;
  }
}

/**
 * Every device this user has, oldest single-token field included.
 *
 * `fcmToken` was a single string before one account could have two handsets.
 * Reading both means a user who has not reopened the app since the change is
 * still reachable, and the app clears the old field the next time it writes.
 */
function tokensFor(user) {
  const many = user.get("fcmTokens");
  const one = user.get("fcmToken");
  const all = [
    ...(Array.isArray(many) ? many : []),
    ...(typeof one === "string" && one ? [one] : []),
  ];
  return [...new Set(all.filter((t) => typeof t === "string" && t))];
}

/**
 * Failures that will never succeed however often they are retried.
 *
 * "mismatched-credential" means the token was minted by a different Firebase
 * project, which is true of every token saved before this app's default
 * project changed.
 */
/** How long a failing notification is worth retrying. */
const RETRY_WINDOW_MS = 30 * 60 * 1000;

const PERMANENTLY_DEAD = new Set([
  "messaging/registration-token-not-registered",
  "messaging/invalid-registration-token",
  "messaging/invalid-argument",
  "messaging/mismatched-credential",
]);


// ---------------------------------------------------------------------------
// Staff notifications — admins and inspectors, on the web panel
// ---------------------------------------------------------------------------

/**
 * Sends one message to every device belonging to a set of staff documents,
 * and prunes the tokens that will never work again.
 *
 * Shared by the seller, admin and inspector paths because the awkward parts
 * are identical: a person has several devices, some of those tokens are dead,
 * and one dead token must not stop the others being tried.
 *
 * Returns how many actually went out, so the caller can decide whether a
 * retry would achieve anything.
 */
async function notifyStaff(docs, notification, data) {
  let delivered = 0;
  let failed = 0;

  await Promise.all(
    docs.map(async (snap) => {
      const tokens = tokensFor(snap);
      if (tokens.length === 0) return;

      const results = await Promise.allSettled(
        tokens.map((token) =>
          admin.messaging().send({
            token,
            notification,
            data,
            webpush: {
              notification: {
                ...notification,
                icon: "/icons/icon-192.png",
                badge: "/icons/icon-192.png",
                tag: data.orderId,
              },
              fcmOptions: { link: "/index.html" },
            },
          })
        )
      );

      const dead = [];
      results.forEach((r, i) => {
        if (r.status === "fulfilled") {
          delivered++;
        } else if (PERMANENTLY_DEAD.has(r.reason?.code)) {
          dead.push(tokens[i]);
        } else {
          failed++;
          logger.error("Staff notify failed", { code: r.reason?.code });
        }
      });

      if (dead.length > 0) {
        await snap.ref.update({
          fcmTokens: admin.firestore.FieldValue.arrayRemove(...dead),
        });
      }
    })
  );

  return { delivered, failed };
}

const money = (n) =>
  typeof n === "number" && Number.isFinite(n)
    ? `\u20b9${n.toLocaleString("en-IN")}`
    : null;

function deviceOf(order) {
  return [order.brand, order.modelName].filter(Boolean).join(" ") || "a phone";
}

// A short, speakable reference, minted here rather than in the app.
//
// The app used to generate one and check it was free with a query on `orders`.
// Proper security rules deny that query outright — a seller may read their own
// orders, not search everyone's — so it moved to the server, which can both
// check and write without the client being allowed to look.
//
// Crockford's base32 minus I, L, O and U: no character turns into another when
// read down a phone, which is the entire purpose.
const REF_ALPHABET = "0123456789ABCDEFGHJKMNPQRSTVWXYZ";

function referenceCandidate() {
  let out = "FM-";
  for (let i = 0; i < 6; i++) {
    out += REF_ALPHABET[Math.floor(Math.random() * REF_ALPHABET.length)];
  }
  return out;
}

/**
 * Gives an order a reference nothing else is using.
 *
 * Six characters collide sooner than the raw billion suggests, so each
 * candidate is checked. Gives up after a few tries rather than looping: an
 * order without a cosmetic identifier is a great deal better than an order
 * stuck in a retry.
 */
async function assignReference(orderId) {
  const orders = admin.firestore().collection("orders");
  for (let attempt = 0; attempt < 5; attempt++) {
    const candidate = referenceCandidate();
    const taken = await orders
      .where("reference", "==", candidate)
      .limit(1)
      .get();
    if (taken.empty) {
      await orders.doc(orderId).update({ reference: candidate });
      return candidate;
    }
  }
  logger.warn("Could not mint a reference", { orderId });
  return null;
}

/**
 * A new order has been placed — tell every admin.
 *
 * On create rather than update, because the seller pressing "place order" is
 * the moment somebody needs to act. Admins are notified as a group: there is
 * no assignment yet, and whoever sees it first picks it up.
 */
exports.onOrderPlaced = onDocumentCreated(
  { document: "orders/{orderId}", retry: true },
  async (event) => {
    const age = Date.now() - Date.parse(event.time);
    if (Number.isFinite(age) && age > RETRY_WINDOW_MS) {
      logger.warn("Giving up: new-order event too old", {
        orderId: event.params.orderId,
      });
      return;
    }

    const order = event.data?.data();
    if (!order) return;

    // Before notifying, so the admin's notification can carry it.
    const reference =
      order.reference || (await assignReference(event.params.orderId));

    const admins = await admin.firestore().collection("admins").get();
    if (admins.empty) {
      logger.info("No admins to notify");
      return;
    }

    const amount = money(order.finalPayout);
    const { delivered, failed } = await notifyStaff(
      admins.docs,
      {
        title: "New order placed",
        body: amount
          ? `${deviceOf(order)} for ${amount}. Assign an inspector.`
          : `${deviceOf(order)}. Assign an inspector.`,
      },
      {
        orderId: event.params.orderId,
        reference: reference || "",
        kind: "order_placed",
      }
    );

    logger.info("Told the admins", {
      orderId: event.params.orderId,
      delivered,
    });
    if (delivered === 0 && failed > 0) {
      throw new Error("No admin device could be reached");
    }
  }
);

/**
 * Tells an inspector a pickup is now theirs.
 *
 * Deliberately does not throw on failure. It is called from the status
 * trigger, and that function retries — so a failure here would re-run the
 * whole thing and send the seller a second status notification for a problem
 * that had nothing to do with them.
 */
async function notifyAssignedInspector(orderId, order) {
  try {
    const snap = await admin
      .firestore()
      .collection("inspectors")
      .doc(order.inspectorId)
      .get();
    if (!snap.exists) {
      logger.warn("Assigned to an inspector who does not exist", {
        orderId,
        inspectorId: order.inspectorId,
      });
      return;
    }

    const where = order.addressLabel || order.addressFullText || "";
    const { delivered } = await notifyStaff(
      [snap],
      {
        title: "A pickup is yours",
        body: where
          ? `${deviceOf(order)} — ${where}`
          : `${deviceOf(order)} has been assigned to you.`,
      },
      {
        orderId,
        reference: order.reference || "",
        kind: "assigned",
      }
    );
    logger.info("Told the inspector", { orderId, delivered });
  } catch (err) {
    logger.error("Could not notify the inspector", {
      orderId,
      message: err.message,
    });
  }
}

exports.onOrderStatusChanged = onDocumentUpdated(
  {
    document: "orders/{orderId}",
    // Without this a transient failure — a Firestore hiccup, a cold-start
    // timeout — loses the notification permanently, and nothing records that
    // the seller was never told. Re-running is safe: `tag` below collapses
    // repeats of an order into one notification on the handset, so the worst
    // a retry can do is replace a notification with an identical one.
    retry: true,
  },
  async (event) => {
    // Retries run for up to seven days. An order update is only worth
    // announcing while it is still news: telling someone on Tuesday that an
    // agent was assigned last Wednesday is worse than saying nothing, because
    // they will act on it. Past the window we give up quietly — returning
    // rather than throwing, so the platform stops retrying.
    const age = Date.now() - Date.parse(event.time);
    if (Number.isFinite(age) && age > RETRY_WINDOW_MS) {
      logger.warn("Giving up: event too old to be worth sending", {
        orderId: event.params.orderId,
        ageMinutes: Math.round(age / 60000),
      });
      return;
    }

    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (!before || !after) return;

    // An assignment is its own event, and independent of the status: an admin
    // can hand a pickup to someone without moving the order along. Handled
    // before the status check, which would otherwise return first and the
    // inspector would never hear.
    if (before.inspectorId !== after.inspectorId && after.inspectorId) {
      await notifyAssignedInspector(event.params.orderId, after);
    }

    // Every write to an order comes through here — a price correction, an
    // address edit, the app's own updatedAt bump. Only a genuine status
    // change is worth interrupting somebody for.
    if (before.status === after.status) return;

    const message = messageFor(after.status, after);
    if (!message) {
      logger.info("No message defined for status", { status: after.status });
      return;
    }

    const userId = after.userId;
    if (!userId) {
      logger.warn("Order has no userId; cannot notify", {
        orderId: event.params.orderId,
      });
      return;
    }

    const orderId = event.params.orderId;

    // Deliberately unguarded: a failure to read the user must reach the
    // platform so the retry policy above can run this again. Swallowing it
    // here would turn a recoverable blip into a silently lost notification.
    const user = await admin.firestore().collection("users").doc(userId).get();
    const tokens = tokensFor(user);

    if (tokens.length === 0) {
      // Perfectly ordinary: the seller has not opened the app since
      // notifications were added, or declined the permission.
      logger.info("No token for user; nothing to send", { userId });
      return;
    }

    const results = await Promise.allSettled(
      tokens.map((token) =>
        admin.messaging().send({
          token,
          notification: message,
          data: { orderId, status: after.status },
          android: {
            priority: "high",
            notification: {
              channelId: "order_updates",
              // Groups an order's updates into one thread rather than
              // stacking four separate notifications over a few days.
              tag: orderId,
            },
          },
        })
      )
    );

    const dead = [];
    let delivered = 0;
    let failed = 0;

    results.forEach((result, i) => {
      if (result.status === "fulfilled") {
        delivered++;
        return;
      }
      const code = result.reason?.code;
      if (PERMANENTLY_DEAD.has(code)) {
        dead.push(tokens[i]);
        return;
      }
      failed++;
      logger.error("Could not notify a device", { orderId, code });
    });

    if (dead.length > 0) {
      // Clearing them stops every later order retrying the same corpses, and
      // makes the app register a fresh token on next launch.
      await user.ref.update({
        fcmTokens: admin.firestore.FieldValue.arrayRemove(...dead),
      });
      logger.info("Dropped stale tokens", { userId, count: dead.length });
    }

    logger.info("Notified seller", {
      orderId,
      status: after.status,
      delivered,
      dropped: dead.length,
    });

    // One device failing for a reason that might pass is worth another go;
    // every device having a dead token is not, and was handled above.
    if (delivered === 0 && failed > 0) {
      throw new Error(`No device could be reached for order ${orderId}`);
    }
  }
);
