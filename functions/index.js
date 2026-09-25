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

const { onDocumentUpdated } = require("firebase-functions/v2/firestore");
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
