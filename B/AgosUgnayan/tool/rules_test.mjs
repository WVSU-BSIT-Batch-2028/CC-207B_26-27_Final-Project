// Checks the Firestore security rules for orders and stock against the
// local emulator (never the real project). Run after seeding:
//   node tool/seed_emulator.mjs
//   node tool/rules_test.mjs
// Each line says what we try, who tries it, and whether the rules allowed
// it as expected.

const project = 'demo-agosugnayan';
const auth = 'http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1';
const db = `http://127.0.0.1:8080/v1/projects/${project}/databases/(default)/documents`;

/** Logs in a demo user on the Auth emulator and returns id and token. */
async function login(email) {
  const res = await fetch(`${auth}/accounts:signInWithPassword?key=demo`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password: 'demo1234', returnSecureToken: true }),
  });
  const data = await res.json();
  return { id: data.localId, token: data.idToken };
}

function value(v) {
  if (v === null) return { nullValue: null };
  if (typeof v === 'number') return { doubleValue: v };
  if (typeof v === 'boolean') return { booleanValue: v };
  if (Array.isArray(v)) return { arrayValue: { values: v.map(value) } };
  if (typeof v === 'object') {
    const fields = {};
    for (const [k, x] of Object.entries(v)) fields[k] = value(x);
    return { mapValue: { fields } };
  }
  return { stringValue: String(v) };
}

/** One write in a commit; serverTime lists fields set to the server time. */
async function commit(user, path, fields, { create = false, serverTime = [] } = {}) {
  const write = {
    update: { name: `projects/${project}/databases/(default)/documents/${path}`, fields: value(fields).mapValue.fields },
    updateMask: create ? undefined : { fieldPaths: Object.keys(fields) },
    currentDocument: create ? { exists: false } : { exists: true },
    updateTransforms: serverTime.map((f) => ({ fieldPath: f, setToServerValue: 'REQUEST_TIME' })),
  };
  const res = await fetch(`${db}:commit`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${user.token}` },
    body: JSON.stringify({ writes: [write] }),
  });
  return res.ok;
}

async function read(user, path) {
  const res = await fetch(`${db}/${path}`, { headers: { Authorization: `Bearer ${user.token}` } });
  return res.ok;
}

let failures = 0;
function check(what, allowed, expected) {
  const ok = allowed === expected;
  if (!ok) failures++;
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${what}: ${allowed ? 'allowed' : 'blocked'}`);
}

const farmer = await login('farmer@demo.ph');
const buyer = await login('buyer@demo.ph');
const outsider = await login('buyer2@demo.ph');

const order = (o) => ({
  source: 'listing', listingId: 'demo0', farmerId: farmer.id, farmerName: 'Pedro Santos',
  buyerId: buyer.id, buyerName: 'Ana Reyes', participants: [buyer.id, farmer.id], chatId: 'c',
  crop: 'Tomato', title: '', unit: 'kg', qty: 2, price: 45, total: 90, note: '',
  status: 'pending', reservedUntil: null, ...o,
});
const create = (user, id, o) => commit(user, `orders/${id}`, order(o), { create: true, serverTime: ['createdAt', 'updatedAt'] });

check('Buyer reads own order', await read(buyer, 'orders/demoOrder1'), true);
check('Another buyer reads it', await read(outsider, 'orders/demoOrder1'), false);
check('Buyer creates a request to buy', await create(buyer, 't1', {}), true);
check('Buyer creates one with a wrong total', await create(buyer, 't2', { total: 10 }), false);
check('Buyer creates one already "reserved"', await create(buyer, 't3', { status: 'reserved' }), false);
check('Buyer creates one for another buyer', await create(outsider, 't4', {}), false);
check('Buyer creates an "offer"', await create(buyer, 't5', { source: 'offer', status: 'offered' }), false);
check('Farmer creates an offer', await create(farmer, 't6', { source: 'offer', status: 'offered', listingId: '' }), true);
check('Buyer accepts own request (only the farmer may)', await commit(buyer, 'orders/t1', { status: 'reserved' }), false);
check('Buyer changes the price', await commit(buyer, 'orders/t1', { price: 1, total: 2 }), false);
check('Buyer cancels own pending request', await commit(buyer, 'orders/t1', { status: 'cancelled' }), true);
check('Buyer accepts the farmer\'s offer', await commit(buyer, 'orders/t6', { status: 'reserved' }), true);
check('Farmer marks it as sold', await commit(farmer, 'orders/t6', { status: 'completed' }), true);
check('Outsider changes an order', await commit(outsider, 'orders/demoOrder2', { status: 'cancelled' }), false);
check('Buyer writes stock on a listing', await commit(buyer, 'listings/demo7', { reservations: [] }), false);
check('Buyer writes sold amount on a listing', await commit(buyer, 'listings/demo7', { soldQty: 0 }), false);
check('Farmer writes own listing stock', await commit(farmer, 'listings/demo7', { soldQty: 0 }), true);
check('Buyer saves a photo for the farmer\'s listing', await commit(buyer, 'listing_photos/demo7', { farmerId: buyer.id, data: 'x' }, { create: true }), false);

console.log(failures ? `\n${failures} check(s) failed.` : '\nAll rules checks passed.');
process.exit(failures ? 1 : 0);
