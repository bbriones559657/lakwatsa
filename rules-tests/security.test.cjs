'use strict';
// Run with the Firestore Emulator, NOT against the production project.
const { before, after, beforeEach, test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const {
  doc, getDoc, setDoc, updateDoc, deleteDoc, writeBatch, Timestamp,
} = require('firebase/firestore');

let environment;
const now = Timestamp.fromDate(new Date('2026-10-05T08:00:00.000Z'));
const later = Timestamp.fromDate(new Date('2026-10-05T09:00:00.000Z'));
const base = 'users/alice/activities/trip';
const activityRef = db => doc(db, base);
const checkRef = (db, id) => doc(db, `${base}/checks/${id}`);
const checkItemRef = (db, id, itemId) => doc(db, `${base}/checks/${id}/items/${itemId}`);
const activityItemRef = (db, itemId) => doc(db, `${base}/items/${itemId}`);

const activityItem = (itemId = 'bottle', addedDuringActivity = false) => ({
  itemId, itemName: itemId, category: 'Other', quantity: 1, icon: 'inventory',
  photoUrl: null, qrCode: null, addedDuringActivity, createdAt: now,
});
const itemManifest = (itemIds, addedDuring = new Set()) => Object.fromEntries(
  itemIds.map(itemId => [
    itemId,
    activityItem(itemId, addedDuring.has(itemId)),
  ]),
);
const activity = (
  status = 'UPCOMING', itemIds = ['bottle'], itemRevision = 0,
) => ({
  listId: 'packing-list', name: 'Beach Trip', type: 'Trip',
  activityDate: now, startAt: now, endAt: later,
  reminderEnabled: false, reminderMinutes: 30,
  status,
  itemCount: itemIds.length,
  itemRevision,
  itemManifest: itemManifest(itemIds),
  createdAt: now,
  updatedAt: now,
});
const legacyActivity = (status = 'UPCOMING') => ({
  listId: 'packing-list', name: 'Legacy Trip', type: 'Trip',
  activityDate: now, startAt: now, endAt: later,
  reminderEnabled: false, reminderMinutes: 30,
  status, createdAt: now, updatedAt: now,
});
const draft = (
  checkType = 'BEFORE_ACTIVITY', itemRevision = 0,
  foundMethods = { bottle: 'MANUAL' },
) => ({
  type: 'DRAFT', checkType, status: 'IN_PROGRESS',
  startedAt: now, foundMethods, itemRevision, updatedAt: now,
});
const completedCheck = (
  type,
  itemIds = ['bottle'],
  itemRevision = 0,
  { manualItemIds = itemIds, qrItemIds = [], missingItemIds = [] } = {},
) => ({
  type, startedAt: now, completedAt: later, status: 'COMPLETED',
  itemCount: itemIds.length,
  itemRevision,
  itemIds,
  manualItemIds,
  qrItemIds,
  missingItemIds,
});
const checkedItem = (itemId = 'bottle', method = 'MANUAL') => ({
  activityItemId: itemId,
  status: method == null ? 'NOT_FOUND' : 'FOUND',
  method,
  checkedAt: method == null ? null : later,
});

before(async () => {
  environment = await initializeTestEnvironment({
    projectId: 'demo-lakwatsa-phase1d',
    firestore: {
      host: '127.0.0.1', port: 8080,
      rules: fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8'),
    },
  });
});
after(async () => {
  if (environment) await environment.cleanup();
});
beforeEach(async () => {
  await environment.clearFirestore();
});
async function seedActivity(status = 'UPCOMING', itemIds = ['bottle'], itemRevision = 0) {
  await environment.withSecurityRulesDisabled(async context => {
    const db = context.firestore();
    const seed = writeBatch(db);
    seed.set(activityRef(db), activity(status, itemIds, itemRevision));
    for (const itemId of itemIds) {
      seed.set(activityItemRef(db, itemId), activityItem(itemId));
    }
    await seed.commit();
  });
}
function client(uid = 'alice') {
  return environment.authenticatedContext(uid).firestore();
}
function transitionBatch(db, type, itemIds = ['bottle'], itemRevision = 0) {
  const isBefore = type === 'BEFORE_ACTIVITY';
  const id = isBefore ? 'before_activity' : 'return';
  const next = isBefore ? 'ACTIVE' : 'COMPLETED';
  const batch = writeBatch(db);
  batch.set(checkRef(db, id), completedCheck(type, itemIds, itemRevision));
  batch.update(activityRef(db), { status: next, updatedAt: later });
  batch.delete(checkRef(db, isBefore ? 'draft_before_activity' : 'draft_return'));
  return batch;
}

function trackedAddBatch(
  db, itemId, { fromItemIds, fromRevision, addedDuringActivity = false },
) {
  const addedDuring = new Set(addedDuringActivity ? [itemId] : []);
  const nextIds = [...fromItemIds, itemId];
  const nextManifest = itemManifest(fromItemIds);
  nextManifest[itemId] = activityItem(itemId, addedDuringActivity);
  const batch = writeBatch(db);
  batch.update(activityRef(db), {
    itemCount: nextIds.length,
    itemRevision: fromRevision + 1,
    itemManifest: nextManifest,
    itemMutationId: itemId,
    itemMutationType: 'ADD',
    updatedAt: later,
  });
  batch.set(activityItemRef(db, itemId), activityItem(itemId, addedDuring.has(itemId)));
  return batch;
}

function trackedRemoveBatch(db, itemId, { fromItemIds, fromRevision }) {
  const nextIds = fromItemIds.filter(id => id !== itemId);
  const batch = writeBatch(db);
  batch.update(activityRef(db), {
    itemCount: nextIds.length,
    itemRevision: fromRevision + 1,
    itemManifest: itemManifest(nextIds),
    itemMutationId: itemId,
    itemMutationType: 'REMOVE',
    updatedAt: later,
  });
  batch.delete(activityItemRef(db, itemId));
  return batch;
}

test('private Items and Lists are accessible to their owner only', async () => {
  const alice = client();
  const bob = client('bob');
  const anon = environment.unauthenticatedContext().firestore();
  const item = doc(alice, 'users/alice/items/bottle');
  await assertSucceeds(setDoc(item, { name: 'Bottle', category: 'Other' }));
  await assertSucceeds(getDoc(item));
  await assertFails(getDoc(doc(bob, 'users/alice/items/bottle')));
  await assertFails(getDoc(doc(anon, 'users/alice/items/bottle')));
  await assertSucceeds(setDoc(doc(alice, 'users/alice/lists/one'), {name: 'Camping'}));
  await assertFails(setDoc(doc(bob, 'users/alice/lists/two'), {name: 'Not yours'}));
});

test('new Activities must start UPCOMING and belong to the caller', async () => {
  const alice = client();
  await assertFails(setDoc(activityRef(alice), activity('COMPLETED')));
  await assertFails(setDoc(activityRef(client('bob')), activity()));
  const initial = writeBatch(alice);
  initial.set(activityRef(alice), activity());
  initial.set(activityItemRef(alice, 'bottle'), activityItem());
  await assertSucceeds(initial.commit());
  await assertFails(updateDoc(activityRef(alice), {status: 'COMPLETED'}));
});

test('Activity creation requires a non-empty authoritative Item manifest', async () => {
  const alice = client();
  const emptyManifest = { ...activity(), itemManifest: {} };
  await assertFails(setDoc(activityRef(alice), emptyManifest));

  const missingManifest = { ...activity() };
  delete missingManifest.itemManifest;
  await assertFails(setDoc(activityRef(alice), missingManifest));

  // A forged parent manifest alone cannot establish a real initial Item.
  await assertFails(setDoc(activityRef(alice), activity()));
  const malformed = writeBatch(alice);
  malformed.set(activityRef(alice), {
    ...activity(), itemManifest: { bottle: null },
  });
  malformed.set(activityItemRef(alice, 'bottle'), activityItem());
  await assertFails(malformed.commit());

  const forgedSecond = writeBatch(alice);
  forgedSecond.set(activityRef(alice), {
    ...activity('UPCOMING', ['bottle', 'phone']),
    itemManifest: { bottle: activityItem(), phone: null },
  });
  forgedSecond.set(activityItemRef(alice, 'bottle'), activityItem());
  await assertFails(forgedSecond.commit());
});

test('completed check requires a complete atomic result manifest', async () => {
  const alice = client();
  const itemIds = ['bottle', 'phone', 'keys'];
  await seedActivity('UPCOMING', itemIds, 0);

  const incomplete = writeBatch(alice);
  incomplete.set(
    checkRef(alice, 'before_activity'),
    completedCheck('BEFORE_ACTIVITY', itemIds, 0, {
      manualItemIds: ['bottle', 'phone'],
      qrItemIds: [],
      missingItemIds: [],
    }),
  );
  incomplete.update(activityRef(alice), { status: 'ACTIVE', updatedAt: later });
  await assertFails(incomplete.commit());

  // Completion is self-contained in the check document. Child result rows can
  // be absent without making History incomplete because the app reads this
  // verified manifest first.
  const complete = writeBatch(alice);
  complete.set(
    checkRef(alice, 'before_activity'),
    completedCheck('BEFORE_ACTIVITY', itemIds, 0, {
      manualItemIds: ['bottle', 'phone'],
      qrItemIds: [],
      missingItemIds: ['keys'],
    }),
  );
  complete.update(activityRef(alice), { status: 'ACTIVE', updatedAt: later });
  await assertSucceeds(complete.commit());
  const saved = (await getDoc(checkRef(alice, 'before_activity'))).data();
  assert.deepEqual(new Set(saved.itemIds), new Set(itemIds));
  assert.deepEqual(saved.missingItemIds, ['keys']);
});

test('drafts save while the matching check is active, but cannot forge history', async () => {
  await seedActivity();
  const alice = client();
  await assertSucceeds(setDoc(checkRef(alice, 'draft_before_activity'), draft()));
  assert.equal((await getDoc(checkRef(alice, 'draft_before_activity'))).data().foundMethods.bottle, 'MANUAL');
  await assertFails(setDoc(checkRef(alice, 'draft_return'), draft('RETURN')));
  await assertFails(setDoc(checkRef(alice, 'before_activity'), completedCheck('BEFORE_ACTIVITY')));
  await assertFails(deleteDoc(checkRef(alice, 'draft_before_activity')));
  await assertFails(setDoc(checkRef(client('bob'), 'draft_before_activity'), draft()));
});

test('Before completion must atomically create its check and advance status', async () => {
  await seedActivity();
  const alice = client();
  await assertSucceeds(setDoc(checkRef(alice, 'draft_before_activity'), draft()));
  await assertFails(updateDoc(activityRef(alice), {status: 'ACTIVE', updatedAt: later}));
  await assertSucceeds(transitionBatch(alice, 'BEFORE_ACTIVITY').commit());
  assert.equal((await getDoc(activityRef(alice))).data().status, 'ACTIVE');
  assert.equal((await getDoc(checkRef(alice, 'before_activity'))).data().type, 'BEFORE_ACTIVITY');
  assert.equal((await getDoc(checkRef(alice, 'draft_before_activity'))).exists(), false);
  await assertFails(updateDoc(checkRef(alice, 'before_activity'), {type: 'RETURN'}));
  await assertFails(deleteDoc(checkRef(alice, 'before_activity')));
  await assertFails(updateDoc(activityRef(alice), {status: 'UPCOMING'}));
  await assertFails(transitionBatch(alice, 'BEFORE_ACTIVITY').commit());
});

test('Return completion must be atomic and completed Activity is immutable', async () => {
  await seedActivity('ACTIVE');
  const alice = client();
  await assertSucceeds(setDoc(checkRef(alice, 'draft_return'), draft('RETURN')));
  await assertSucceeds(trackedAddBatch(
    alice,
    'phone',
    { fromItemIds: ['bottle'], fromRevision: 0, addedDuringActivity: true },
  ).commit());
  await assertSucceeds(transitionBatch(
    alice,
    'RETURN',
    ['bottle', 'phone'],
    1,
  ).commit());
  assert.equal((await getDoc(activityRef(alice))).data().status, 'COMPLETED');
  await assertFails(setDoc(checkRef(alice, 'draft_return'), draft('RETURN')));
  await assertFails(setDoc(activityItemRef(alice, 'keys'), activityItem('keys', true)));
  await assertFails(deleteDoc(activityRef(alice)));
  await assertFails(updateDoc(activityRef(alice), {name: 'Changed'}));
  await assertFails(setDoc(checkItemRef(alice, 'return', 'fake'), checkedItem('fake')));
});

test('Activity with its initial Items can be created as a single batch', async () => {
  const alice = client();
  const batch = writeBatch(alice);
  batch.set(activityRef(alice), activity());
  batch.set(activityItemRef(alice, 'bottle'), activityItem());
  await assertSucceeds(batch.commit());
});

test('a client can build a customized Activity through tracked Item additions', async () => {
  const alice = client();
  const initial = writeBatch(alice);
  initial.set(activityRef(alice), activity());
  initial.set(activityItemRef(alice, 'bottle'), activityItem());
  await assertSucceeds(initial.commit());

  await assertSucceeds(trackedAddBatch(
    alice, 'phone', { fromItemIds: ['bottle'], fromRevision: 0 },
  ).commit());
  await assertSucceeds(trackedAddBatch(
    alice, 'keys', { fromItemIds: ['bottle', 'phone'], fromRevision: 1 },
  ).commit());
  const current = (await getDoc(activityRef(alice))).data();
  assert.equal(current.itemCount, 3);
  assert.equal(current.itemRevision, 2);

  await assertSucceeds(transitionBatch(
    alice, 'BEFORE_ACTIVITY', ['bottle', 'phone', 'keys'], 2,
  ).commit());
  assert.equal((await getDoc(activityRef(alice))).data().status, 'ACTIVE');
});

test('Activity metadata edits are status-aware', async () => {
  const alice = client();
  const movedStart = Timestamp.fromDate(new Date('2026-10-06T10:00:00.000Z'));
  const movedEnd = Timestamp.fromDate(new Date('2026-10-06T12:00:00.000Z'));

  await seedActivity('UPCOMING');

  await assertSucceeds(updateDoc(activityRef(alice), {
    name: 'Updated Trip',
    activityDate: movedStart,
    startAt: movedStart,
    endAt: movedEnd,
    reminderEnabled: true,
    reminderMinutes: 60,
    updatedAt: later,
  }));
  await assertFails(updateDoc(activityRef(alice), {
    listId: 'different-list',
    updatedAt: later,
  }));

  await environment.withSecurityRulesDisabled(async context => {
    const admin = context.firestore();
    await updateDoc(activityRef(admin), { status: 'ACTIVE', updatedAt: later });
  });

  await assertSucceeds(updateDoc(activityRef(alice), {
    name: 'Updated While Active',
    endAt: movedEnd,
    reminderEnabled: false,
    reminderMinutes: 15,
    updatedAt: later,
  }));
  await assertFails(updateDoc(activityRef(alice), {
    startAt: now,
    updatedAt: later,
  }));
  await assertFails(updateDoc(activityRef(alice), {
    activityDate: now,
    updatedAt: later,
  }));
});

test('Activity Item management follows Activity status and timing', async () => {
  const alice = client();

  await seedActivity('UPCOMING');
  await assertSucceeds(trackedAddBatch(
    alice,
    'phone',
    { fromItemIds: ['bottle'], fromRevision: 0 },
  ).commit());

  const wrongUpcoming = trackedAddBatch(
    alice,
    'wrong-upcoming',
    { fromItemIds: ['bottle', 'phone'], fromRevision: 1, addedDuringActivity: true },
  );
  await assertFails(wrongUpcoming.commit());

  await assertSucceeds(setDoc(checkRef(alice, 'draft_before_activity'), {
    ...draft('BEFORE_ACTIVITY', 1),
    foundMethods: { bottle: 'MANUAL', phone: 'QR' },
  }));
  const removeWithDraft = writeBatch(alice);
  removeWithDraft.update(checkRef(alice, 'draft_before_activity'), {
    foundMethods: { bottle: 'MANUAL' },
    itemRevision: 2,
    updatedAt: later,
  });
  removeWithDraft.update(activityRef(alice), {
    itemCount: 1,
    itemRevision: 2,
    itemManifest: itemManifest(['bottle']),
    itemMutationId: 'phone',
    itemMutationType: 'REMOVE',
    updatedAt: later,
  });
  removeWithDraft.delete(activityItemRef(alice, 'phone'));
  await assertSucceeds(removeWithDraft.commit());

  // The sole remaining Item cannot be removed, even by a direct client write.
  await assertFails(deleteDoc(activityItemRef(alice, 'bottle')));

  await environment.withSecurityRulesDisabled(async context => {
    const admin = context.firestore();
    await updateDoc(activityRef(admin), { status: 'ACTIVE', updatedAt: later });
  });

  await assertSucceeds(trackedAddBatch(
    alice,
    'charger',
    { fromItemIds: ['bottle'], fromRevision: 2, addedDuringActivity: true },
  ).commit());
  const wrongActive = trackedAddBatch(
    alice,
    'wrong-active',
    { fromItemIds: ['bottle', 'charger'], fromRevision: 3, addedDuringActivity: false },
  );
  await assertFails(wrongActive.commit());
  await assertFails(trackedRemoveBatch(
    alice,
    'charger',
    { fromItemIds: ['bottle', 'charger'], fromRevision: 3 },
  ).commit());

  await environment.withSecurityRulesDisabled(async context => {
    const admin = context.firestore();
    await updateDoc(activityRef(admin), { status: 'COMPLETED', updatedAt: later });
  });

  const completedAdd = trackedAddBatch(
    alice,
    'keys',
    { fromItemIds: ['bottle', 'charger'], fromRevision: 3, addedDuringActivity: true },
  );
  await assertFails(completedAdd.commit());
  await assertFails(deleteDoc(activityItemRef(alice, 'bottle')));
});

test('stale draft save cannot restore a removed Item selection', async () => {
  const alice = client();
  await seedActivity('UPCOMING', ['bottle', 'phone'], 0);
  await assertSucceeds(setDoc(
    checkRef(alice, 'draft_before_activity'),
    draft('BEFORE_ACTIVITY', 0, { phone: 'MANUAL' }),
  ));

  const remove = writeBatch(alice);
  remove.update(checkRef(alice, 'draft_before_activity'), {
    foundMethods: {},
    itemRevision: 1,
    updatedAt: later,
  });
  remove.update(activityRef(alice), {
    itemCount: 1,
    itemRevision: 1,
    itemManifest: itemManifest(['bottle']),
    itemMutationId: 'phone',
    itemMutationType: 'REMOVE',
    updatedAt: later,
  });
  remove.delete(activityItemRef(alice, 'phone'));
  await assertSucceeds(remove.commit());

  await assertFails(updateDoc(checkRef(alice, 'draft_before_activity'), {
    foundMethods: { phone: 'MANUAL' },
    itemRevision: 1,
    updatedAt: later,
  }));
  assert.deepEqual(
    (await getDoc(checkRef(alice, 'draft_before_activity'))).data().foundMethods,
    {},
  );
});

test('Activity Item state cannot change without its matching child write', async () => {
  const alice = client();
  await seedActivity('UPCOMING');

  await assertFails(updateDoc(activityRef(alice), {
    itemCount: 2,
    itemRevision: 1,
    itemManifest: itemManifest(['bottle', 'phone']),
    itemMutationId: 'phone',
    itemMutationType: 'ADD',
    updatedAt: later,
  }));
  await assertFails(setDoc(
    activityItemRef(alice, 'phone'),
    activityItem('phone'),
  ));
});

test('legacy Activity Item state remains readable but cannot be forged by a client', async () => {
  const alice = client();
  await environment.withSecurityRulesDisabled(async context => {
    const admin = context.firestore();
    await setDoc(activityRef(admin), legacyActivity());
    await setDoc(activityItemRef(admin, 'bottle'), activityItem());
  });

  await assertFails(setDoc(
    activityItemRef(alice, 'phone'),
    activityItem('phone'),
  ));
  await assertFails(updateDoc(activityRef(alice), {
    itemCount: 1,
    itemRevision: 0,
    updatedAt: later,
  }));

  await assertSucceeds(updateDoc(activityRef(alice), {
    name: 'Readable Legacy Trip', updatedAt: later,
  }));

  await assertFails(updateDoc(activityRef(alice), {
    itemCount: 1,
    itemRevision: 0,
    itemManifest: itemManifest(['bottle']),
    updatedAt: later,
  }));
  await environment.withSecurityRulesDisabled(async context => {
    await updateDoc(activityRef(context.firestore()), {
      itemCount: 1, itemRevision: 0, updatedAt: later,
    });
  });

  await assertFails(updateDoc(activityRef(alice), {
    itemManifest: itemManifest(['bottle']),
    updatedAt: later,
  }));
  await assertFails(trackedAddBatch(
    alice, 'phone', { fromItemIds: ['bottle'], fromRevision: 0 },
  ).commit());
});

test('stale concurrent removal cannot delete the last Activity Item', async () => {
  const alice = client();
  await seedActivity('UPCOMING', ['bottle', 'phone']);

  await assertSucceeds(trackedRemoveBatch(
    alice,
    'phone',
    { fromItemIds: ['bottle', 'phone'], fromRevision: 0 },
  ).commit());

  // Represents a second device trying to commit the state it saw before
  // the first removal. The parent revision/count no longer match.
  const staleRemoval = writeBatch(alice);
  staleRemoval.update(activityRef(alice), {
    itemCount: 1,
    itemRevision: 1,
    itemManifest: itemManifest(['phone']),
    itemMutationId: 'bottle',
    itemMutationType: 'REMOVE',
    updatedAt: later,
  });
  staleRemoval.delete(activityItemRef(alice, 'bottle'));
  await assertFails(staleRemoval.commit());
  assert.equal((await getDoc(activityItemRef(alice, 'bottle'))).exists(), true);
});

test('stale check Item revision is rejected after the Item set changes', async () => {
  const alice = client();
  const initialIds = ['bottle', 'phone'];
  await seedActivity('UPCOMING', initialIds);

  await assertSucceeds(trackedAddBatch(
    alice,
    'keys',
    { fromItemIds: ['bottle', 'phone'], fromRevision: 0 },
  ).commit());

  const stale = writeBatch(alice);
  stale.set(
    checkRef(alice, 'before_activity'),
    completedCheck('BEFORE_ACTIVITY', initialIds, 0),
  );
  stale.update(activityRef(alice), { status: 'ACTIVE', updatedAt: later });
  await assertFails(stale.commit());

  const currentIds = [...initialIds, 'keys'];
  const fresh = writeBatch(alice);
  fresh.set(
    checkRef(alice, 'before_activity'),
    completedCheck('BEFORE_ACTIVITY', currentIds, 1),
  );
  fresh.update(activityRef(alice), { status: 'ACTIVE', updatedAt: later });
  await assertSucceeds(fresh.commit());
});

test('v2 Item rules remain compatible, including owner-only access', async () => {
  const alice = client();
  const v2 = doc(alice, 'lakwatsa_v2_users/alice/items/bottle');
  await assertSucceeds(setDoc(v2, {
    name: 'Bottle', category: 'Other', quantity: 1, archived: false,
  }));
  await assertFails(deleteDoc(v2));
  await assertFails(getDoc(doc(client('bob'), 'lakwatsa_v2_users/alice/items/bottle')));
});


test('three-Item Activity preserves Before history when a fourth Item is added for Return', async () => {
  const alice = client();
  const firstItems = ['bottle', 'phone', 'keys'];
  await seedActivity('UPCOMING', firstItems);

  await assertSucceeds(setDoc(checkRef(alice, 'draft_before_activity'), {
    ...draft(),
    foundMethods: { bottle: 'MANUAL', phone: 'QR' },
  }));

  const before = writeBatch(alice);
  before.set(
    checkRef(alice, 'before_activity'),
    completedCheck('BEFORE_ACTIVITY', firstItems, 0, {
      manualItemIds: ['bottle'],
      qrItemIds: ['phone'],
      missingItemIds: ['keys'],
    }),
  );
  before.update(activityRef(alice), { status: 'ACTIVE', updatedAt: later });
  before.delete(checkRef(alice, 'draft_before_activity'));
  await assertSucceeds(before.commit());

  const savedBefore = (await getDoc(checkRef(alice, 'before_activity'))).data();
  assert.equal(savedBefore.itemIds.length, 3);
  assert.equal(savedBefore.manualItemIds.length + savedBefore.qrItemIds.length, 2);
  assert.deepEqual(savedBefore.missingItemIds, ['keys']);

  await assertSucceeds(trackedAddBatch(
    alice,
    'charger',
    { fromItemIds: firstItems, fromRevision: 0, addedDuringActivity: true },
  ).commit());
  const returnItems = [...firstItems, 'charger'];
  await assertSucceeds(setDoc(checkRef(alice, 'draft_return'), {
    ...draft('RETURN', 1),
    foundMethods: Object.fromEntries(returnItems.map(id => [id, 'MANUAL'])),
  }));

  const returning = writeBatch(alice);
  returning.set(checkRef(alice, 'return'), completedCheck('RETURN', returnItems, 1));
  returning.update(activityRef(alice), { status: 'COMPLETED', updatedAt: later });
  returning.delete(checkRef(alice, 'draft_return'));
  await assertSucceeds(returning.commit());

  const persistedBefore = (await getDoc(checkRef(alice, 'before_activity'))).data();
  const persistedReturn = (await getDoc(checkRef(alice, 'return'))).data();
  assert.equal(persistedBefore.manualItemIds.length + persistedBefore.qrItemIds.length, 2);
  assert.equal(persistedBefore.itemIds.length, 3);
  assert.equal(persistedReturn.manualItemIds.length + persistedReturn.qrItemIds.length, 4);
  assert.equal(persistedReturn.itemIds.length, 4);
  assert.equal((await getDoc(activityRef(alice))).data().status, 'COMPLETED');
});

test('twelve-Item Activity can finish both checks atomically', async () => {
  const alice = client();
  const itemIds = Array.from({ length: 12 }, (_, index) => `item-${index + 1}`);
  await seedActivity('UPCOMING', itemIds);

  for (const [type, nextStatus, draftId, checkId] of [
    ['BEFORE_ACTIVITY', 'ACTIVE', 'draft_before_activity', 'before_activity'],
    ['RETURN', 'COMPLETED', 'draft_return', 'return'],
  ]) {
    await assertSucceeds(setDoc(checkRef(alice, draftId), {
      ...draft(type),
      foundMethods: Object.fromEntries(itemIds.map(id => [id, 'MANUAL'])),
    }));
    const save = writeBatch(alice);
    save.set(checkRef(alice, checkId), completedCheck(type, itemIds, 0));
    save.update(activityRef(alice), { status: nextStatus, updatedAt: later });
    save.delete(checkRef(alice, draftId));
    await assertSucceeds(save.commit());
    assert.equal((await getDoc(activityRef(alice))).data().status, nextStatus);
    const savedCheck = (await getDoc(checkRef(alice, checkId))).data();
    assert.equal(savedCheck.itemIds.length, 12);
    assert.equal(savedCheck.manualItemIds.length, 12);
  }
});

test('two-hundred Item Activity remains writable and checkable within rule limits', async () => {
  const alice = client();
  const itemIds = Array.from({ length: 200 }, (_, index) => `item-${index + 1}`);
  const firstIds = itemIds.slice(0, -1);
  const lastId = itemIds[itemIds.length - 1];
  await seedActivity('UPCOMING', firstIds);
  await assertSucceeds(trackedAddBatch(
    alice, lastId, { fromItemIds: firstIds, fromRevision: 0 },
  ).commit());
  await assertSucceeds(trackedRemoveBatch(
    alice, lastId, { fromItemIds: itemIds, fromRevision: 1 },
  ).commit());
  await assertSucceeds(trackedAddBatch(
    alice, lastId, { fromItemIds: firstIds, fromRevision: 2 },
  ).commit());

  await assertSucceeds(updateDoc(activityRef(alice), {
    name: 'Large Trip',
    updatedAt: later,
  }));

  const incomplete = writeBatch(alice);
  incomplete.set(checkRef(alice, 'before_activity'), completedCheck(
    'BEFORE_ACTIVITY', itemIds, 3,
    { manualItemIds: itemIds.slice(0, -1), qrItemIds: [], missingItemIds: [] },
  ));
  incomplete.update(activityRef(alice), { status: 'ACTIVE', updatedAt: later });
  await assertFails(incomplete.commit());

  await assertSucceeds(transitionBatch(alice, 'BEFORE_ACTIVITY', itemIds, 3).commit());
  const saved = (await getDoc(checkRef(alice, 'before_activity'))).data();
  assert.equal(saved.itemIds.length, 200);
  assert.equal((await getDoc(activityRef(alice))).data().status, 'ACTIVE');

  await assertSucceeds(transitionBatch(alice, 'RETURN', itemIds, 3).commit());
  assert.equal((await getDoc(checkRef(alice, 'return'))).data().itemIds.length, 200);
  assert.equal((await getDoc(activityRef(alice))).data().status, 'COMPLETED');
});
