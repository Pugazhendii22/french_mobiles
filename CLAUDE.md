# french_mobiles

Flutter phone trade-in app, plus a companion web admin panel in `admin-panel/`
(its own git repository — ignored here).

## Skills

Invoke the `task-observer` skill before the first tool call of any session, and
before writing or proposing a plan. Its own description says matching alone
under-triggers, so this line is the activation layer that actually makes it
fire.

## Firebase: three apps, two projects

Read `lib/firebase/second_hand_firebase.dart` before touching any Firestore
call site. The short version:

- **`french-mobiles-marketplace`** is the **default** app and this app's own
  backend: `orders`, `users`, `brands`, `deduction_rules`. Also reachable as
  the named `catalogApp` (`catalogFirestore` / `catalogAuth`).
- **`fren-75087`** is the owner's *separate live product*, read-only here for
  `second_hand_mobiles` via `secondHandFirestore`. **Never migrate its data** —
  another product writes to it.

The default is the marketplace because `firebase_messaging` on Android binds to
the default app and cannot be pointed elsewhere; a token minted by one project
cannot be sent to from another. Do not "tidy" `catalogApp` away either —
`firebase_auth` persists a session per app *name*, so collapsing it would sign
out everyone once.

## Things that look like bugs and are not

- `brand_detail_page`, `variant_selection_page` and `device_evaluation_wizard`
  use `Firebase.app('catalogApp')`, which **throws** if the named app failed to
  init, while `catalogFirestore` falls back to the default. Keep each call site
  as it is.
- Home's default address is picked **in Dart**, not with a `where` clause:
  documents written before `isDefault` existed do not carry the field.
- `estimatedHealthFromCycles` in `battery_band.dart` is deliberately unused.
  Mileage is not condition — it once reported 49% for a cell the handset
  measured at 79%, a whole payout band lower. Do not wire it back in.

## Verification baseline

```
flutter analyze   # must stay at 0 issues under lib/ (third_party/ is vendored)
flutter test      # 491 pass, 0 failures. The suite is green — a red one is
                  # a regression, not the baseline. (widget_test.dart was the
                  # long-standing exception; it asserted text deleted in the
                  # redesign and booted the shell without Firebase. Rewritten.)
flutter build apk --debug
```

New assets in `assets/logos/` need `flutter clean`, not just `flutter pub get`
— the asset manifest is baked at build time.

## Firestore rules

`firestore.rules` is now per-collection and has no expiry. The shape is dictated
by one fact: **the app browses before anyone signs in** — `main.dart` opens onto
MainShell, not a login screen — so `brands`, `models`, `variants` and
`deduction_rules` must stay publicly readable. Requiring auth on those does not
restrict the catalogue, it empties the home screen. That is exactly what
happened to the second-hand listings when the other project added a blanket
`request.auth != null` on 2026-09-24.

Verified after deploy (unauthenticated, via the REST API):

```
brands / deduction_rules / models  -> 200   (browsing must work)
orders / users / admins / inspectors -> 403 (was wide open)
```

Two things to know before editing them:

- Order reads use `resource.data.inspectorId == request.auth.uid`, **not**
  `.get('inspectorId', '')`. Firestore must prove a *query* is allowed from its
  constraints alone and only recognises the direct form; the `.get()` variant
  makes the inspector's listener fail silently.
- An assigned inspector may update **only** `status`, `updatedAt` and
  `inspection`, pinned with `hasOnly`. `finalPayout` is deliberately out of
  reach: it is the quote the seller accepted, and an inspector who could edit it
  could rewrite the agreement rather than dispute it. Their finding sits beside
  it instead, carrying their own uid and a server timestamp, both enforced.
- The finding is only validated when it is actually being written. Requiring it
  unconditionally broke a plain status change, which has no finding to check —
  caught by `rules-test/` before it shipped.

## Security rules are tested

```
cd rules-test && npm test     # 54 assertions, needs Java 21+ (see its README)
```

Run this before touching `firestore.rules`. Two bugs reached production in one
afternoon from rules deployed without it: inspector creation reporting failure,
and admins unable to save their own push token.

An order's reference (`FM-XXXXXX`) is minted by `onOrderPlaced`, not the app.
Checking a candidate was free meant querying every order, which these rules
correctly refuse.

## Two figures for one order

`finalPayout` is the quote the seller accepted. `inspection.confirmedPayout` is
what the agent settled on at the door. **The settled one is what gets paid** —
read it through `payoutOf()` in `shared/services/order_payout.dart` rather than
reaching for `finalPayout` directly, which is how three screens once told
sellers they were getting more money than they were.
