// What the security rules actually permit, run against the real rules file.
//
// These exist because two bugs reached production in one afternoon, both from
// rules that were deployed without being tested: creating an inspector wrote a
// document the admin was not allowed to write, and an admin could not save
// their own push token. Both were found by a person using the app. Both are
// asserted below.
//
// Run with:  npm test          (starts the emulator, runs this, shuts down)
//
// The emulator evaluates the same rules Firestore does, with a simulated
// signed-in user — which is the only way to check an authenticated write
// without placing a real order.

import { readFileSync } from "node:fs";
import { after, before, beforeEach, describe, it } from "node:test";
import assert from "node:assert/strict";

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import {
  addDoc,
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
} from "firebase/firestore";

const ADMIN = "admin-uid";
const SELLER = "seller-uid";
const OTHER = "other-seller-uid";
const INSPECTOR = "inspector-uid";

let testEnv;

/** Firestore as a given signed-in user, or signed out when uid is null. */
const as = (uid) =>
  uid === null
    ? testEnv.unauthenticatedContext().firestore()
    : testEnv.authenticatedContext(uid).firestore();

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: "french-mobiles-test",
    firestore: {
      rules: readFileSync("../firestore.rules", "utf8"),
      host: "127.0.0.1",
      port: 8080,
    },
  });
});

after(async () => {
  await testEnv?.cleanup();
});

/** Seeds documents with the rules switched off, as a starting state. */
async function seed(fn) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await fn(ctx.firestore());
  });
}

async function resetAndSeed() {
  await testEnv.clearFirestore();
  await seed(async (db) => {
    await setDoc(doc(db, "admins", ADMIN), { email: "admin@example.com" });
    await setDoc(doc(db, "inspectors", INSPECTOR), {
      name: "Ravi",
      email: "ravi@example.com",
      active: true,
    });
    await setDoc(doc(db, "users", SELLER), { name: "Seller" });
    await setDoc(doc(db, "brands", "apple"), { name: "apple" });
    await setDoc(doc(db, "deduction_rules", "battery_health"), { percent: 10 });

    await setDoc(doc(db, "orders", "order-1"), {
      userId: SELLER,
      status: "placed",
      brand: "Apple",
      modelName: "iPhone 11",
      finalPayout: 20000,
    });
    await setDoc(doc(db, "orders", "order-assigned"), {
      userId: SELLER,
      status: "agent_assigned",
      inspectorId: INSPECTOR,
      finalPayout: 20000,
      reference: "FM-4K7P2A",
    });
  });
}

describe("the catalogue is readable before anyone signs in", () => {
  // The app opens onto MainShell, not a login screen. An auth check here does
  // not restrict the catalogue, it empties the home screen — which is exactly
  // what happened to the second-hand listings on 2026-09-24.
  before(resetAndSeed);

  it("a visitor can read brands", async () => {
    await assertSucceeds(getDoc(doc(as(null), "brands", "apple")));
  });

  it("a visitor can read deduction rules", async () => {
    await assertSucceeds(
      getDoc(doc(as(null), "deduction_rules", "battery_health"))
    );
  });

  it("a visitor cannot write to the catalogue", async () => {
    await assertFails(setDoc(doc(as(null), "brands", "apple"), { name: "x" }));
  });

  it("a signed-in seller still cannot write to the catalogue", async () => {
    await assertFails(
      setDoc(doc(as(SELLER), "brands", "apple"), { name: "hacked" })
    );
  });

  it("an admin can", async () => {
    await assertSucceeds(
      setDoc(doc(as(ADMIN), "brands", "apple"), { name: "apple" })
    );
  });
});

describe("orders", () => {
  beforeEachReset();

  it("a seller reads their own order", async () => {
    await assertSucceeds(getDoc(doc(as(SELLER), "orders", "order-1")));
  });

  it("another seller cannot read it", async () => {
    await assertFails(getDoc(doc(as(OTHER), "orders", "order-1")));
  });

  it("a visitor cannot read it", async () => {
    await assertFails(getDoc(doc(as(null), "orders", "order-1")));
  });

  it("a seller can list their own orders", async () => {
    // The query the app actually runs on the orders screen.
    await assertSucceeds(
      getDocs(
        query(collection(as(SELLER), "orders"), where("userId", "==", SELLER))
      )
    );
  });

  it("a seller cannot list everyone's orders", async () => {
    await assertFails(getDocs(collection(as(SELLER), "orders")));
  });

  it("an assigned inspector reads the order", async () => {
    await assertSucceeds(
      getDoc(doc(as(INSPECTOR), "orders", "order-assigned"))
    );
  });

  it("an inspector cannot read an order that is not theirs", async () => {
    await assertFails(getDoc(doc(as(INSPECTOR), "orders", "order-1")));
  });

  it("an inspector can list the orders assigned to them", async () => {
    // Written as a plain field comparison in the rules for this reason: the
    // .get() form is not recognised by the query analyser and this fails.
    await assertSucceeds(
      getDocs(
        query(
          collection(as(INSPECTOR), "orders"),
          where("inspectorId", "==", INSPECTOR)
        )
      )
    );
  });

  it("an admin reads any order", async () => {
    await assertSucceeds(getDoc(doc(as(ADMIN), "orders", "order-1")));
  });
});

describe("placing an order", () => {
  beforeEachReset();

  const validOrder = {
    userId: SELLER,
    status: "placed",
    brand: "Apple",
    modelName: "iPhone 11",
    finalPayout: 20000,
  };

  it("a seller places their own order", async () => {
    // The write pickup_checkout_page.dart performs. If this fails, the app is
    // broken for every seller.
    await assertSucceeds(
      addDoc(collection(as(SELLER), "orders"), validOrder)
    );
  });

  it("a seller cannot place an order in someone else's name", async () => {
    await assertFails(
      addDoc(collection(as(SELLER), "orders"), {
        ...validOrder,
        userId: OTHER,
      })
    );
  });

  it("a seller cannot place an order already marked paid", async () => {
    await assertFails(
      addDoc(collection(as(SELLER), "orders"), {
        ...validOrder,
        status: "paid",
      })
    );
  });

  it("a seller cannot assign their own order to an inspector", async () => {
    await assertFails(
      addDoc(collection(as(SELLER), "orders"), {
        ...validOrder,
        inspectorId: INSPECTOR,
      })
    );
  });

  it("a visitor cannot place one at all", async () => {
    await assertFails(addDoc(collection(as(null), "orders"), validOrder));
  });
});

describe("moving an order along", () => {
  beforeEachReset();

  it("an admin changes the status", async () => {
    await assertSucceeds(
      updateDoc(doc(as(ADMIN), "orders", "order-1"), { status: "inspection" })
    );
  });

  it("an admin assigns an inspector", async () => {
    await assertSucceeds(
      updateDoc(doc(as(ADMIN), "orders", "order-1"), {
        inspectorId: INSPECTOR,
        inspectorName: "Ravi",
      })
    );
  });

  it("the assigned inspector changes the status", async () => {
    await assertSucceeds(
      updateDoc(doc(as(INSPECTOR), "orders", "order-assigned"), {
        status: "inspection",
        updatedAt: serverTimestamp(),
      })
    );
  });

  it("the assigned inspector cannot change the payout", async () => {
    // The reason the field list is pinned with hasOnly: without it an
    // inspector could rewrite what the seller gets paid on the way to
    // marking a pickup collected.
    await assertFails(
      updateDoc(doc(as(INSPECTOR), "orders", "order-assigned"), {
        status: "paid",
        finalPayout: 1,
      })
    );
  });

  it("an unassigned inspector cannot touch an order", async () => {
    await assertFails(
      updateDoc(doc(as(INSPECTOR), "orders", "order-1"), { status: "paid" })
    );
  });

  it("a seller cannot mark their own order paid", async () => {
    await assertFails(
      updateDoc(doc(as(SELLER), "orders", "order-1"), { status: "paid" })
    );
  });

  it("nobody deletes an order", async () => {
    // A financial record. Changing your mind is a status, not an erasure.
    await assertFails(deleteDoc(doc(as(ADMIN), "orders", "order-1")));
    await assertFails(deleteDoc(doc(as(SELLER), "orders", "order-1")));
  });
});

describe("people", () => {
  beforeEachReset();

  it("a seller reads and writes their own profile", async () => {
    await assertSucceeds(getDoc(doc(as(SELLER), "users", SELLER)));
    await assertSucceeds(
      setDoc(doc(as(SELLER), "users", SELLER), { name: "New Name" })
    );
  });

  it("a seller saves their own push token", async () => {
    await assertSucceeds(
      setDoc(
        doc(as(SELLER), "users", SELLER),
        { fcmTokens: ["token-1"] },
        { merge: true }
      )
    );
  });

  it("nobody reads someone else's profile", async () => {
    await assertFails(getDoc(doc(as(OTHER), "users", SELLER)));
  });

  it("an admin may read a profile but not rewrite it", async () => {
    await assertSucceeds(getDoc(doc(as(ADMIN), "users", SELLER)));
    // REGRESSION: this write is what broke inspector creation. The panel used
    // to mirror a name onto users/{uid} while creating an inspector; the rules
    // refuse it, the error was reported, and a colleague who HAD been created
    // looked like a failure. The panel no longer attempts it.
    await assertFails(
      setDoc(doc(as(ADMIN), "users", SELLER), { name: "Renamed" })
    );
  });

  it("addresses belong to their owner", async () => {
    await assertSucceeds(
      setDoc(doc(as(SELLER), "users", SELLER, "addresses", "a1"), {
        label: "Home",
      })
    );
    await assertFails(
      getDoc(doc(as(OTHER), "users", SELLER, "addresses", "a1"))
    );
  });
});

describe("staff", () => {
  beforeEachReset();

  it("an admin creates an inspector", async () => {
    // The panel's actual write. Nothing else is written alongside it any more.
    await assertSucceeds(
      setDoc(doc(as(ADMIN), "inspectors", "new-inspector"), {
        name: "New",
        email: "new@example.com",
        active: true,
      })
    );
  });

  it("a seller cannot make themselves an inspector", async () => {
    await assertFails(
      setDoc(doc(as(SELLER), "inspectors", SELLER), { name: "Me" })
    );
  });

  it("a seller cannot make themselves an admin", async () => {
    // Membership is the gate, so this is the one that matters most.
    await assertFails(
      setDoc(doc(as(SELLER), "admins", SELLER), { email: "me@example.com" })
    );
  });

  it("an admin cannot add another admin from the browser either", async () => {
    await assertFails(
      setDoc(doc(as(ADMIN), "admins", "someone-else"), { email: "x@y.com" })
    );
  });

  it("an admin saves their own push token", async () => {
    // REGRESSION: admins/{uid} was `allow write: if false`, which also blocked
    // this — so the panel could not receive the new-order notification it
    // exists to show.
    await assertSucceeds(
      updateDoc(doc(as(ADMIN), "admins", ADMIN), {
        fcmTokens: ["browser-token"],
      })
    );
  });

  it("an admin cannot smuggle other fields in with the token", async () => {
    await assertFails(
      updateDoc(doc(as(ADMIN), "admins", ADMIN), {
        fcmTokens: ["t"],
        role: "superuser",
      })
    );
  });

  it("an inspector saves their own push token", async () => {
    await assertSucceeds(
      updateDoc(doc(as(INSPECTOR), "inspectors", INSPECTOR), {
        fcmTokens: ["browser-token"],
      })
    );
  });

  it("an inspector cannot rename themselves or reactivate", async () => {
    await assertFails(
      updateDoc(doc(as(INSPECTOR), "inspectors", INSPECTOR), {
        name: "Promoted",
      })
    );
  });

  it("an inspector cannot read another inspector", async () => {
    await assertFails(getDoc(doc(as(INSPECTOR), "inspectors", "someone-else")));
  });
});


describe("what an inspector found at the door", () => {
  // The app tells sellers "the final amount is confirmed when the agent
  // inspects the phone at pickup". These assertions are what makes that
  // promise keepable without letting staff quietly rewrite an agreed price.
  beforeEachReset();

  const finding = (extra = {}) => ({
    inspection: {
      confirmedPayout: 20000,
      quotedPayout: 20000,
      inspectorId: INSPECTOR,
      at: serverTimestamp(),
      ...extra,
    },
    status: "inspection",
    updatedAt: serverTimestamp(),
  });

  it("confirming the quoted amount needs no explanation", async () => {
    await assertSucceeds(
      updateDoc(doc(as(INSPECTOR), "orders", "order-assigned"), finding())
    );
  });

  it("lowering it requires a reason", async () => {
    await assertFails(
      updateDoc(
        doc(as(INSPECTOR), "orders", "order-assigned"),
        finding({ confirmedPayout: 12000 })
      )
    );
  });

  it("a real reason is accepted", async () => {
    await assertSucceeds(
      updateDoc(
        doc(as(INSPECTOR), "orders", "order-assigned"),
        finding({
          confirmedPayout: 12000,
          reason: "Screen scratch is deeper than declared",
        })
      )
    );
  });

  it("a token reason is not", async () => {
    // Ten characters is a low bar, and still stops "ok" and ".".
    await assertFails(
      updateDoc(
        doc(as(INSPECTOR), "orders", "order-assigned"),
        finding({ confirmedPayout: 12000, reason: "bad" })
      )
    );
  });

  it("the quote itself cannot be rewritten", async () => {
    // The distinction the whole design rests on: an inspector disputes the
    // agreed figure, they do not edit it.
    await assertFails(
      updateDoc(doc(as(INSPECTOR), "orders", "order-assigned"), {
        finalPayout: 1,
      })
    );
  });

  it("a finding cannot be filed under a colleague's name", async () => {
    await assertFails(
      updateDoc(
        doc(as(INSPECTOR), "orders", "order-assigned"),
        finding({ inspectorId: "someone-else" })
      )
    );
  });

  it("the timestamp cannot be backdated", async () => {
    await assertFails(
      updateDoc(doc(as(INSPECTOR), "orders", "order-assigned"), {
        inspection: {
          confirmedPayout: 20000,
          inspectorId: INSPECTOR,
          at: new Date("2020-01-01"),
        },
        updatedAt: serverTimestamp(),
      })
    );
  });

  it("the quoted figure recorded must be the real one", async () => {
    // Otherwise a finding could claim the quote was lower than it was, making
    // a reduction look like a confirmation.
    await assertFails(
      updateDoc(
        doc(as(INSPECTOR), "orders", "order-assigned"),
        finding({ confirmedPayout: 5000, quotedPayout: 5000, reason: "Looks much worse in person" })
      )
    );
  });

  it("no extra fields can ride along inside the finding", async () => {
    await assertFails(
      updateDoc(
        doc(as(INSPECTOR), "orders", "order-assigned"),
        finding({ adminOverride: true })
      )
    );
  });

  it("an unassigned inspector cannot record anything", async () => {
    await assertFails(
      updateDoc(doc(as(INSPECTOR), "orders", "order-1"), finding())
    );
  });

  it("a seller cannot record a finding on their own order", async () => {
    await assertFails(
      updateDoc(doc(as(SELLER), "orders", "order-1"), {
        inspection: {
          confirmedPayout: 99999,
          inspectorId: SELLER,
          at: serverTimestamp(),
        },
      })
    );
  });

  it("an admin can record one without the same ceremony", async () => {
    // Admins are trusted by every other rule here; pretending otherwise would
    // be theatre, and they are the ones who resolve a dispute.
    await assertSucceeds(
      updateDoc(doc(as(ADMIN), "orders", "order-assigned"), {
        inspection: { confirmedPayout: 15000, reason: "Agreed by phone" },
      })
    );
  });
});

describe("the wishlist", () => {
  beforeEachReset();

  it("belongs to its owner", async () => {
    await assertSucceeds(
      setDoc(doc(as(SELLER), "wishlist", SELLER, "items", "i1"), { id: "x" })
    );
    await assertFails(
      getDoc(doc(as(OTHER), "wishlist", SELLER, "items", "i1"))
    );
  });
});

describe("anything not named in the rules", () => {
  beforeEachReset();

  it("is denied, even to an admin", async () => {
    // The point of listing collections explicitly: a new one added later is
    // closed until somebody decides otherwise.
    await assertFails(
      setDoc(doc(as(ADMIN), "some_new_collection", "x"), { a: 1 })
    );
    await assertFails(getDoc(doc(as(null), "some_new_collection", "x")));
  });
});

/** Re-seeds before EVERY test in the enclosing describe.
 *
 * `before` rather than `beforeEach` was a real bug here, not a style choice:
 * "an admin assigns an inspector" left its assignment on order-1, so the later
 * "an unassigned inspector cannot touch an order" was testing an inspector who
 * by then was assigned, and passed for the wrong reason. Shared mutable state
 * between tests makes a suite agree with whatever the code does. */
function beforeEachReset() {
  beforeEach(resetAndSeed);
}

assert.ok(true);
