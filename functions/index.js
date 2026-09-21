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

exports.onOrderStatusChanged = onDocumentUpdated(
  { document: "orders/{orderId}" },
  async (event) => {
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

    const user = await admin.firestore().collection("users").doc(userId).get();
    const token = user.get("fcmToken");
    if (!token) {
      // Perfectly ordinary: the seller has not opened the app since
      // notifications were added, or declined the permission.
      logger.info("No token for user; nothing to send", { userId });
      return;
    }

    try {
      await admin.messaging().send({
        token,
        notification: message,
        data: {
          orderId: event.params.orderId,
          status: after.status,
        },
        android: {
          priority: "high",
          notification: {
            channelId: "order_updates",
            // Groups an order's updates into one thread rather than
            // stacking four separate notifications over a few days.
            tag: event.params.orderId,
          },
        },
      });
      logger.info("Notified seller", {
        orderId: event.params.orderId,
        status: after.status,
      });
    } catch (error) {
      // A token goes stale when the app is reinstalled or data cleared, and
      // "mismatched-credential" means it was minted by a *different* Firebase
      // project — which is true of every token saved before this app's
      // default project changed. All three are permanently dead for us, and
      // clearing the field makes the app mint a fresh one on next launch
      // instead of every later order retrying the same corpse.
      if (
        error.code === "messaging/registration-token-not-registered" ||
        error.code === "messaging/invalid-registration-token" ||
        error.code === "messaging/mismatched-credential"
      ) {
        await user.ref.update({
          fcmToken: admin.firestore.FieldValue.delete(),
        });
        logger.info("Dropped a stale token", { userId });
        return;
      }
      logger.error("Could not notify seller", {
        orderId: event.params.orderId,
        code: error.code,
        message: error.message,
      });
    }
  }
);
