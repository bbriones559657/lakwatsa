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

const activity = (status = 'UPCOMING', itemCount = 1, itemRevision = 0) => ({
  listId: 'packing-list', name: 'Beach Trip', type: 'Trip',
  activityDate: now, startAt: now, endAt: later,
  reminderEnabled: false, reminderMinutes: 30,
  status, itemCount, itemRevision, createdAt: now, updatedAt: now,
});
const legacyActivity = (status = 'UPCOMING') => ({
  listId: 'packing-list', name: 'Legacy Trip', type: 'Trip',
  activityDate: now, startAt: now, endAt: later,
  reminderEnabled: false, reminderMinutes: 30,
  status, createdAt: now, updatedAt: now,
});
const activityItem = (itemId = 'bottle', addedDuringActivity = false) => ({
  itemId, itemName: itemId, category: 'Other', quantity: 1, icon: 'inventory',
  photoUrl: null, qrCode: null, addedDuringActivity, createdAt: now,
});
const draft = (checkType = 'BEFORE_ACTIVITY') => ({
  type: 'DRAFT', checkType, status: 'IN_PROGRESS',
  startedAt: now, foundMethods: { bottle: 'MANUAL' }, updatedAt: now,
});
const completedCheck = (type, itemCount = 1, itemRevision = 0) => ({
  type, startedAt: now, completedAt: later, status: 'COMPLETED',
  itemCount, itemRevision,
});
const checkedItem = (itemId = 'bottle') => ({
  activityItemId: itemId, status: 'FOUND', method: 'MANUAL', checkedAt: later,
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
    await setDoc(activityRef(db), activity(status, itemIds.length, itemRevision));
    for (const itemId of itemIds) {
      await setDoc(activityItemRef(db, itemId), activityItem(itemId));
    }
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
  batch.set(checkRef(db, id), completedCheck(type, itemIds.length, itemRevision));
  for (const itemId of itemIds) {
    batch.set(checkItemRef(db, id, itemId), checkedItem(itemId));
  }
  batch.update(activityRef(db), { status: next, updatedAt: later });
  batch.delete(checkRef(db, isBefore ? 'draft_before_activity' : 'draft_return'));
  return batch;
}

function trackedAddBatch(
  db, itemId, { fromCount, fromRevision, addedDuringActivity = false },
) {
  const batch = writeBatch(db);
  batch.update(activityRef(db), {
    itemCount: fromCount + 1,
    itemRevision: fromRevision + 1,
    itemMutationId: itemId,
    itemMutationType: 'ADD',
    updatedAt: later,
  });
  batch.set(activityItemRef(db, itemId), activityItem(itemId, addedDuringActivity));
  return batch;
}

function trackedRemoveBatch(db, itemId, { fromCount, fromRevision }) {
  const batch = writeBatch(db);
  batch.update(activityRef(db), {
    itemCount: fromCount - 1,
    itemRevision: fromRevision + 1,
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
  await assertSucceeds(setDoc(activityRef(alice), activity()));
  await assertFails(updateDoc(activityRef(alice), {status: 'COMPLETED'}));
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
    { fromCount: 1, fromRevision: 0, addedDuringActivity: true },
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
    { fromCount: 1, fromRevision: 0 },
  ).commit());

  const wrongUpcoming = trackedAddBatch(
    alice,
    'wrong-upcoming',
    { fromCount: 2, fromRevision: 1, addedDuringActivity: true },
  );
  await assertFails(wrongUpcoming.commit());

  await assertSucceeds(setDoc(checkRef(alice, 'draft_before_activity'), {
    ...draft(),
    foundMethods: { bottle: 'MANUAL', phone: 'QR' },
  }));
  const removeWithDraft = writeBatch(alice);
  removeWithDraft.update(checkRef(alice, 'draft_before_activity'), {
    foundMethods: { bottle: 'MANUAL' },
    updatedAt: later,
  });
  removeWithDraft.update(activityRef(alice), {
    itemCount: 1,
    itemRevision: 2,
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
    { fromCount: 1, fromRevision: 2, addedDuringActivity: true },
  ).commit());
  const wrongActive = trackedAddBatch(
    alice,
    'wrong-active',
    { fromCount: 2, fromRevision: 3, addedDuringActivity: false },
  );
  await assertFails(wrongActive.commit());
  await assertFails(trackedRemoveBatch(
    alice,
    'charger',
    { fromCount: 2, fromRevision: 3 },
  ).commit());

  await environment.withSecurityRulesDisabled(async context => {
    const admin = context.firestore();
    await updateDoc(activityRef(admin), { status: 'COMPLETED', updatedAt: later });
  });

  const completedAdd = trackedAddBatch(
    alice,
    'keys',
    { fromCount: 2, fromRevision: 3, addedDuringActivity: true },
  );
  await assertFails(completedAdd.commit());
  await assertFails(deleteDoc(activityItemRef(alice, 'bottle')));
});

test('Activity Item state cannot change without its matching child write', async () => {
  const alice = client();
  await seedActivity('UPCOMING');

  await assertFails(updateDoc(activityRef(alice), {
    itemCount: 2,
    itemRevision: 1,
    itemMutationId: 'phone',
    itemMutationType: 'ADD',
    updatedAt: later,
  }));
  await assertFails(setDoc(
    activityItemRef(alice, 'phone'),
    activityItem('phone'),
  ));
});

test('legacy Activity Item state can be initialized once before mutations', async () => {
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
  await assertSucceeds(updateDoc(activityRef(alice), {
    itemCount: 1,
    itemRevision: 0,
    updatedAt: later,
  }));
  await assertSucceeds(trackedAddBatch(
    alice,
    'phone',
    { fromCount: 1, fromRevision: 0 },
  ).commit());
  await assertFails(updateDoc(activityRef(alice), {
    itemCount: 3,
    itemRevision: 0,
    updatedAt: later,
  }));
});

test('stale concurrent removal cannot delete the last Activity Item', async () => {
  const alice = client();
  const initial = writeBatch(alice);
  initial.set(activityRef(alice), activity('UPCOMING', 2, 0));
  initial.set(activityItemRef(alice, 'bottle'), activityItem('bottle'));
  initial.set(activityItemRef(alice, 'phone'), activityItem('phone'));
  await assertSucceeds(initial.commit());

  await assertSucceeds(trackedRemoveBatch(
    alice,
    'phone',
    { fromCount: 2, fromRevision: 0 },
  ).commit());

  // Represents a second device trying to commit the state it saw before
  // the first removal. The parent revision/count no longer match.
  const staleRemoval = writeBatch(alice);
  staleRemoval.update(activityRef(alice), {
    itemCount: 1,
    itemRevision: 1,
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
  const initial = writeBatch(alice);
  initial.set(activityRef(alice), activity('UPCOMING', 2, 0));
  for (const id of initialIds) {
    initial.set(activityItemRef(alice, id), activityItem(id));
  }
  await assertSucceeds(initial.commit());

  await assertSucceeds(trackedAddBatch(
    alice,
    'keys',
    { fromCount: 2, fromRevision: 0 },
  ).commit());

  const stale = writeBatch(alice);
  stale.set(
    checkRef(alice, 'before_activity'),
    completedCheck('BEFORE_ACTIVITY', 2, 0),
  );
  for (const id of initialIds) {
    stale.set(checkItemRef(alice, 'before_activity', id), checkedItem(id));
  }
  stale.update(activityRef(alice), { status: 'ACTIVE', updatedAt: later });
  await assertFails(stale.commit());

  const currentIds = [...initialIds, 'keys'];
  const fresh = writeBatch(alice);
  fresh.set(
    checkRef(alice, 'before_activity'),
    completedCheck('BEFORE_ACTIVITY', 3, 1),
  );
  for (const id of currentIds) {
    fresh.set(checkItemRef(alice, 'before_activity', id), checkedItem(id));
  }
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
  const initial = writeBatch(alice);
  initial.set(activityRef(alice), activity('UPCOMING', firstItems.length, 0));
  for (const id of firstItems) {
    initial.set(activityItemRef(alice, id), activityItem(id));
  }
  await assertSucceeds(initial.commit());

  await assertSucceeds(setDoc(checkRef(alice, 'draft_before_activity'), {
    ...draft(),
    foundMethods: { bottle: 'MANUAL', phone: 'QR' },
  }));

  const before = writeBatch(alice);
  before.set(checkRef(alice, 'before_activity'), completedCheck('BEFORE_ACTIVITY', 3, 0));
  for (const id of firstItems) {
    before.set(checkItemRef(alice, 'before_activity', id),
      id === 'keys'
        ? { activityItemId: id, status: 'NOT_FOUND', method: null, checkedAt: null }
        : { activityItemId: id, status: 'FOUND', method: id === 'phone' ? 'QR' : 'MANUAL', checkedAt: later });
  }
  before.update(activityRef(alice), { status: 'ACTIVE', updatedAt: later });
  before.delete(checkRef(alice, 'draft_before_activity'));
  await assertSucceeds(before.commit());

  const savedBefore = await Promise.all(firstItems.map(id =>
    getDoc(checkItemRef(alice, 'before_activity', id))));
  assert.equal(savedBefore.length, 3);
  assert.equal(savedBefore.filter(row => row.data().status === 'FOUND').length, 2);

  await assertSucceeds(trackedAddBatch(
    alice,
    'charger',
    { fromCount: 3, fromRevision: 0, addedDuringActivity: true },
  ).commit());
  const returnItems = [...firstItems, 'charger'];
  await assertSucceeds(setDoc(checkRef(alice, 'draft_return'), {
    ...draft('RETURN'),
    foundMethods: Object.fromEntries(returnItems.map(id => [id, 'MANUAL'])),
  }));

  const returning = writeBatch(alice);
  returning.set(checkRef(alice, 'return'), completedCheck('RETURN', 4, 1));
  for (const id of returnItems) {
    returning.set(checkItemRef(alice, 'return', id), checkedItem(id));
  }
  returning.update(activityRef(alice), { status: 'COMPLETED', updatedAt: later });
  returning.delete(checkRef(alice, 'draft_return'));
  await assertSucceeds(returning.commit());

  const persistedBefore = await Promise.all(firstItems.map(id =>
    getDoc(checkItemRef(alice, 'before_activity', id))));
  const persistedReturn = await Promise.all(returnItems.map(id =>
    getDoc(checkItemRef(alice, 'return', id))));
  assert.equal(persistedBefore.filter(row => row.data().status === 'FOUND').length, 2);
  assert.equal(persistedBefore.length, 3);
  assert.equal(persistedReturn.filter(row => row.data().status === 'FOUND').length, 4);
  assert.equal(persistedReturn.length, 4);
  assert.equal((await getDoc(activityRef(alice))).data().status, 'COMPLETED');
});

test('twelve-Item Activity can finish both checks atomically', async () => {
  const alice = client();
  const itemIds = Array.from({ length: 12 }, (_, index) => `item-${index + 1}`);
  const initial = writeBatch(alice);
  initial.set(activityRef(alice), activity('UPCOMING', itemIds.length, 0));
  for (const id of itemIds) {
    initial.set(activityItemRef(alice, id), activityItem(id));
  }
  await assertSucceeds(initial.commit());

  for (const [type, nextStatus, draftId, checkId] of [
    ['BEFORE_ACTIVITY', 'ACTIVE', 'draft_before_activity', 'before_activity'],
    ['RETURN', 'COMPLETED', 'draft_return', 'return'],
  ]) {
    await assertSucceeds(setDoc(checkRef(alice, draftId), {
      ...draft(type),
      foundMethods: Object.fromEntries(itemIds.map(id => [id, 'MANUAL'])),
    }));
    const save = writeBatch(alice);
    save.set(checkRef(alice, checkId), completedCheck(type, itemIds.length, 0));
    for (const id of itemIds) {
      save.set(checkItemRef(alice, checkId, id), checkedItem(id));
    }
    save.update(activityRef(alice), { status: nextStatus, updatedAt: later });
    save.delete(checkRef(alice, draftId));
    await assertSucceeds(save.commit());
    assert.equal((await getDoc(activityRef(alice))).data().status, nextStatus);
    const rows = await Promise.all(itemIds.map(id => getDoc(checkItemRef(alice, checkId, id))));
    assert.equal(rows.filter(row => row.exists()).length, 12);
  }
});
