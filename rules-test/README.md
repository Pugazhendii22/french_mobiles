# Security rules tests

Runs `../firestore.rules` against the Firestore emulator with simulated
signed-in users. This is the only way to check an authenticated write without
placing a real order.

```bash
cd rules-test
npm install
npm test
```

Needs **Java 21+** (firebase-tools refuses older). If the system JDK is older,
a userspace one works without root:

```bash
mkdir -p ~/.local/jdk && cd ~/.local/jdk
curl -sL -o jdk.tar.gz "https://api.adoptium.net/v3/binary/latest/21/ga/linux/x64/jdk/hotspot/normal/eclipse"
tar xzf jdk.tar.gz && rm jdk.tar.gz
export JAVA_HOME="$HOME/.local/jdk/jdk-21.0.12.1+1"
export PATH="$JAVA_HOME/bin:$PATH"
```

## Why this exists

Two bugs reached production in one afternoon, both from rules deployed without
being tested, and both found by a person using the app rather than by a check:

- Creating an inspector also wrote `users/{uid}`, which the rules refuse — an
  admin is not the person that document describes. The write threw, the error
  was reported, and a colleague who *had* been created looked like a failure.
- `admins/{uid}` was `allow write: if false`, which was right for membership but
  also blocked an admin saving their own web push token, so the panel could not
  receive the new-order notification it exists to show.

Both are asserted here now. The suite was checked against the broken rule to be
sure it fails when it should — a test that only ever passes proves nothing.

## What is covered

- The catalogue stays readable **signed out**. The app opens onto `MainShell`,
  not a login screen, so an auth check there does not restrict browsing, it
  empties the home screen. That is what happened to the second-hand listings on
  2026-09-24.
- Orders: who may read one, the exact queries the app and panel run, who may
  create one and with what status, and that an assigned inspector may change
  only `status` and `updatedAt` — not `finalPayout`.
- Staff: nobody may add themselves to `admins` or `inspectors`; both may save
  their own push token and nothing else alongside it.
- Profiles, addresses, wishlists: owner only.
- Any collection not named in the rules is denied, including to an admin.

## When editing the rules

Run this first. It is faster than deploying and a great deal faster than
finding out from somebody who cannot place an order.
