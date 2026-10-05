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

const activity = (status = 'UPCOMING') => ({
  listId: 'packing-list', name: 'Beach Trip', type: 'Trip',
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
const completedCheck = type => ({
  type, startedAt: now, completedAt: later, status: 'COMPLETED',
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
async function seedActivity(status = 'UPCOMING') {
  await environment.withSecurityRulesDisabled(async context => {
    const db = context.firestore();
    await setDoc(activityRef(db), activity(status));
    await setDoc(activityItemRef(db, 'bottle'), activityItem());
  });
}
function client(uid = 'alice') {
  return environment.authenticatedContext(uid).firestore();
}
function transitionBatch(db, type) {
  const isBefore = type === 'BEFORE_ACTIVITY';
  const id = isBefore ? 'before_activity' : 'return';
  const next = isBefore ? 'ACTIVE' : 'COMPLETED';
  const batch = writeBatch(db);
  batch.set(checkRef(db, id), completedCheck(type));
  batch.set(checkItemRef(db, id, 'bottle'), checkedItem());
  batch.update(activityRef(db), { status: next, updatedAt: later });
  batch.delete(checkRef(db, isBefore ? 'draft_before_activity' : 'draft_return'));
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
  await assertSucceeds(setDoc(activityItemRef(alice, 'phone'), activityItem('phone', true)));
  await assertSucceeds(transitionBatch(alice, 'RETURN').commit());
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

test('v2 Item rules remain compatible, including owner-only access', async () => {
  const alice = client();
  const v2 = doc(alice, 'lakwatsa_v2_users/alice/items/bottle');
  await assertSucceeds(setDoc(v2, {
    name: 'Bottle', category: 'Other', quantity: 1, archived: false,
  }));
  await assertFails(deleteDoc(v2));
  await assertFails(getDoc(doc(client('bob'), 'lakwatsa_v2_users/alice/items/bottle')));
});
