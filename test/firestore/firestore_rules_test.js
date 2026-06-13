/**
 * test/firestore/firestore_rules_test.js
 * ENG Quest — Firestore Security Rules: JavaScript Test Suite
 *
 * Uses @firebase/rules-unit-testing v2.x (Firebase Emulator Suite).
 *
 * Setup:
 *   npm install --save-dev @firebase/rules-unit-testing firebase-admin
 *   firebase emulators:start --only firestore
 *
 * Run:
 *   node test/firestore/firestore_rules_test.js
 *   # or with mocha:
 *   npx mocha test/firestore/firestore_rules_test.js
 *
 * Requirements:
 *   - Firebase Emulator running on localhost:8080
 *   - firestore.rules file at repo root
 */

const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');
const fs = require('fs');
const path = require('path');

// ── Test configuration ────────────────────────────────────────────────────────

const PROJECT_ID = 'engquest-mvp';
const RULES_PATH = path.resolve(__dirname, '../../firestore.rules');

const UID_A = 'user-alice-001';
const UID_B = 'user-bob-002';

// ── Test environment setup ────────────────────────────────────────────────────

let testEnv;

async function setup() {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: fs.readFileSync(RULES_PATH, 'utf8'),
      host: 'localhost',
      port: 8080,
    },
  });
}

async function teardown() {
  if (testEnv) {
    await testEnv.cleanup();
  }
}

// ── Helper factories ─────────────────────────────────────────────────────────

function authAs(uid) {
  return testEnv.authenticatedContext(uid).firestore();
}

function unauth() {
  return testEnv.unauthenticatedContext().firestore();
}

// ── Test runner (minimal, no external test framework required) ───────────────

let passed = 0;
let failed = 0;

async function it(description, fn) {
  try {
    await fn();
    console.log(`  ✅ ${description}`);
    passed++;
  } catch (err) {
    console.error(`  ❌ ${description}`);
    console.error(`     ${err.message}`);
    failed++;
  }
}

async function describe(groupName, fn) {
  console.log(`\n${groupName}`);
  await fn();
}

// ── Tests ────────────────────────────────────────────────────────────────────

async function runTests() {
  await describe('1. Unauthenticated access → DENY all', async () => {
    await it('cannot read own profile (no auth)', async () => {
      const db = unauth();
      await assertFails(db.collection('users').doc(UID_A).collection('profile').doc('data').get());
    });

    await it('cannot write cards (no auth)', async () => {
      const db = unauth();
      await assertFails(
        db.collection('users').doc(UID_A).collection('cards').doc('eiken5_001').set({
          stability: 1.0,
          difficulty: 5.0,
          state: 'new',
          lapses: 0,
          repetitions: 0,
        })
      );
    });

    await it('cannot read vocabulary (no auth)', async () => {
      const db = unauth();
      await assertFails(db.collection('vocabulary').doc('eiken5_001').get());
    });
  });

  await describe('2. Cross-user access → DENY', async () => {
    await it('uid_B cannot read uid_A profile', async () => {
      const db = authAs(UID_B);
      await assertFails(db.collection('users').doc(UID_A).collection('profile').doc('data').get());
    });

    await it('uid_B cannot write uid_A cards', async () => {
      const db = authAs(UID_B);
      await assertFails(
        db.collection('users').doc(UID_A).collection('cards').doc('eiken5_001').set({
          stability: 1.0,
          state: 'new',
          lapses: 0,
          repetitions: 0,
        })
      );
    });

    await it('uid_B cannot read uid_A sessions', async () => {
      const db = authAs(UID_B);
      await assertFails(db.collection('users').doc(UID_A).collection('sessions').doc('2026-05-29').get());
    });
  });

  await describe('3. Own data access → ALLOW', async () => {
    await it('uid_A can read own profile', async () => {
      const db = authAs(UID_A);
      await assertSucceeds(db.collection('users').doc(UID_A).collection('profile').doc('data').get());
    });

    await it('uid_A can write valid profile', async () => {
      const db = authAs(UID_A);
      await assertSucceeds(
        db.collection('users').doc(UID_A).collection('profile').doc('data').set({
          totalXp: 150,
          level: 2,
          streak: 7,
        })
      );
    });

    await it('uid_A can write valid FSRS card', async () => {
      const db = authAs(UID_A);
      await assertSucceeds(
        db.collection('users').doc(UID_A).collection('cards').doc('eiken5_001').set({
          stability: 3.5,
          difficulty: 5.0,
          state: 'review',
          lapses: 0,
          repetitions: 3,
        })
      );
    });

    await it('uid_A can read own cards', async () => {
      const db = authAs(UID_A);
      await assertSucceeds(db.collection('users').doc(UID_A).collection('cards').doc('eiken5_001').get());
    });

    await it('uid_A can write valid session', async () => {
      const db = authAs(UID_A);
      await assertSucceeds(
        db.collection('users').doc(UID_A).collection('sessions').doc('2026-05-29').set({
          wordsPracticed: 10,
          minutes: 5,
          avgScore: 3.0,
        })
      );
    });
  });

  await describe('4. Profile validation → DENY invalid data', async () => {
    await it('rejects negative totalXp', async () => {
      const db = authAs(UID_A);
      await assertFails(
        db.collection('users').doc(UID_A).collection('profile').doc('data').set({ totalXp: -1 })
      );
    });

    await it('rejects totalXp > 999999', async () => {
      const db = authAs(UID_A);
      await assertFails(
        db.collection('users').doc(UID_A).collection('profile').doc('data').set({ totalXp: 1000000 })
      );
    });

    await it('rejects level = 0', async () => {
      const db = authAs(UID_A);
      await assertFails(
        db.collection('users').doc(UID_A).collection('profile').doc('data').set({ level: 0 })
      );
    });

    await it('rejects level > 100', async () => {
      const db = authAs(UID_A);
      await assertFails(
        db.collection('users').doc(UID_A).collection('profile').doc('data').set({ level: 101 })
      );
    });
  });

  await describe('5. Card validation → DENY invalid data', async () => {
    await it('rejects negative stability', async () => {
      const db = authAs(UID_A);
      await assertFails(
        db.collection('users').doc(UID_A).collection('cards').doc('eiken5_002').set({
          stability: -1.0,
          state: 'new',
          lapses: 0,
          repetitions: 0,
        })
      );
    });

    await it('rejects stability > 1000', async () => {
      const db = authAs(UID_A);
      await assertFails(
        db.collection('users').doc(UID_A).collection('cards').doc('eiken5_002').set({
          stability: 1001.0,
          state: 'new',
          lapses: 0,
          repetitions: 0,
        })
      );
    });

    await it('rejects invalid state string', async () => {
      const db = authAs(UID_A);
      await assertFails(
        db.collection('users').doc(UID_A).collection('cards').doc('eiken5_002').set({
          stability: 1.0,
          state: 'hacked',
          lapses: 0,
          repetitions: 0,
        })
      );
    });

    await it('rejects negative lapses', async () => {
      const db = authAs(UID_A);
      await assertFails(
        db.collection('users').doc(UID_A).collection('cards').doc('eiken5_002').set({
          stability: 1.0,
          state: 'new',
          lapses: -1,
          repetitions: 0,
        })
      );
    });
  });

  await describe('6. Session validation → DENY invalid data', async () => {
    await it('rejects wordsPracticed > 1000', async () => {
      const db = authAs(UID_A);
      await assertFails(
        db.collection('users').doc(UID_A).collection('sessions').doc('2026-05-29').set({
          wordsPracticed: 1001,
          minutes: 5,
          avgScore: 3.0,
        })
      );
    });

    await it('rejects minutes > 480', async () => {
      const db = authAs(UID_A);
      await assertFails(
        db.collection('users').doc(UID_A).collection('sessions').doc('2026-05-29').set({
          wordsPracticed: 10,
          minutes: 481,
          avgScore: 3.0,
        })
      );
    });

    await it('rejects avgScore > 4.0', async () => {
      const db = authAs(UID_A);
      await assertFails(
        db.collection('users').doc(UID_A).collection('sessions').doc('2026-05-29').set({
          wordsPracticed: 10,
          minutes: 5,
          avgScore: 4.1,
        })
      );
    });
  });

  await describe('7. Shared vocabulary → read ALLOW, write DENY', async () => {
    await it('uid_A can read vocabulary', async () => {
      const db = authAs(UID_A);
      await assertSucceeds(db.collection('vocabulary').doc('eiken5_001').get());
    });

    await it('uid_A CANNOT write vocabulary', async () => {
      const db = authAs(UID_A);
      await assertFails(
        db.collection('vocabulary').doc('eiken5_001').set({ word: 'hacked' })
      );
    });
  });

  await describe('8. Experiments → read ALLOW, write DENY', async () => {
    await it('uid_A can read experiments', async () => {
      const db = authAs(UID_A);
      await assertSucceeds(db.collection('experiments').doc('ab_battle_v1').get());
    });

    await it('uid_A CANNOT write experiments', async () => {
      const db = authAs(UID_A);
      await assertFails(
        db.collection('experiments').doc('ab_battle_v1').set({ variant: 'hacked' })
      );
    });
  });

  await describe('9. Unknown paths → DENY', async () => {
    await it('cannot read /admin/secret', async () => {
      const db = authAs(UID_A);
      await assertFails(db.collection('admin').doc('secret').get());
    });

    await it('cannot write /hack/data', async () => {
      const db = authAs(UID_A);
      await assertFails(
        db.collection('hack').doc('data').set({ stolen: true })
      );
    });
  });

  await describe('10. Link codes → no enumeration (COPPA isolation)', async () => {
    // The hole: `allow read` on link_codes also permits LIST, so any anon user
    // could enumerate every code + childUid, then self-assert a parent_link to
    // any child and read that child's data. Fix splits get (known code) from a
    // childUid-constrained list.
    await it('attacker CANNOT enumerate all link codes (unconstrained list)',
      async () => {
        const db = authAs(UID_B);
        await assertFails(db.collection('link_codes').get());
      });

    await it('attacker CANNOT list codes filtered to ANOTHER child', async () => {
      const db = authAs(UID_B);
      await assertFails(
        db.collection('link_codes').where('childUid', '==', UID_A).get()
      );
    });

    await it('a child CAN list ONLY their own codes (own-childUid cleanup)',
      async () => {
        const db = authAs(UID_A);
        await assertSucceeds(
          db.collection('link_codes').where('childUid', '==', UID_A).get()
        );
      });

    await it('a parent CAN get a code by its id (the redeem path)', async () => {
      const db = authAs(UID_B);
      await assertSucceeds(db.collection('link_codes').doc('123456').get());
    });

    await it('a child CAN create a code for their OWN uid', async () => {
      const db = authAs(UID_A);
      await assertSucceeds(
        db.collection('link_codes').doc('654321').set({ childUid: UID_A })
      );
    });

    await it('a user CANNOT create a code for ANOTHER child uid', async () => {
      const db = authAs(UID_B);
      await assertFails(
        db.collection('link_codes').doc('777777').set({ childUid: UID_A })
      );
    });
  });
}

// ── Main ──────────────────────────────────────────────────────────────────────

(async () => {
  console.log('ENG Quest — Firestore Security Rules Tests');
  console.log('==========================================');
  console.log(`Rules: ${RULES_PATH}`);
  console.log(`Project: ${PROJECT_ID}\n`);

  try {
    await setup();
    await runTests();
  } finally {
    await teardown();
  }

  console.log(`\n==========================================`);
  console.log(`Results: ${passed} passed, ${failed} failed`);

  if (failed > 0) {
    process.exit(1);
  }
})();
