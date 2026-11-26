// Fills the local Firebase Emulator with demo accounts and data, so the team
// can try every feature without a real Firebase project.
// Run (with the emulator already running): node tool/seed_emulator.mjs
// Demo logins (password for all: demo1234):
//   farmer@demo.ph (Pedro), buyer@demo.ph (Ana), admin@demo.ph (Admin)

const project = 'demo-agosugnayan';
const auth = 'http://127.0.0.1:9099';
const db = `http://127.0.0.1:8080/v1/projects/${project}/databases/(default)/documents`;
// "Bearer owner" lets this script skip the security rules (emulator only).
const headers = { 'Content-Type': 'application/json', Authorization: 'Bearer owner' };

/** Creates a login and returns its user id. */
async function createUser(email) {
  const res = await fetch(`${auth}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=demo-key`, {
    method: 'POST',
    headers,
    body: JSON.stringify({ email, password: 'demo1234', returnSecureToken: true }),
  });
  const data = await res.json();
  if (!data.localId) throw new Error(`Could not create ${email}: ${JSON.stringify(data)}`);
  return data.localId;
}

/** Turns a plain JS value into Firestore's REST format. */
function toFirestore(value) {
  if (value === null) return { nullValue: null };
  if (value instanceof Date) return { timestampValue: value.toISOString() };
  if (typeof value === 'number') return { doubleValue: value };
  if (typeof value === 'boolean') return { booleanValue: value };
  if (Array.isArray(value)) return { arrayValue: { values: value.map(toFirestore) } };
  if (typeof value === 'object') {
    const fields = {};
    for (const [k, v] of Object.entries(value)) fields[k] = toFirestore(v);
    return { mapValue: { fields } };
  }
  return { stringValue: String(value) };
}

/** Writes one document at path, e.g. "users/abc". */
async function setDoc(path, data) {
  const res = await fetch(`${db}/${path}`, {
    method: 'PATCH',
    headers,
    body: JSON.stringify(toFirestore(data).mapValue),
  });
  if (!res.ok) throw new Error(`Could not write ${path}: ${await res.text()}`);
}

const daysFromNow = (n) => new Date(Date.now() + n * 86400000);
const now = new Date();

const farmerId = await createUser('farmer@demo.ph');
const buyerId = await createUser('buyer@demo.ph');
const adminId = await createUser('admin@demo.ph');
const buyer2Id = await createUser('buyer2@demo.ph');

await setDoc(`users/${farmerId}`, { name: 'Pedro Santos', email: 'farmer@demo.ph', role: 'farmer', town: 'Leon', about: 'Vegetable farmer in Barangay Bucari.', createdAt: now });
await setDoc(`users/${buyerId}`, { name: 'Ana Reyes', email: 'buyer@demo.ph', role: 'buyer', town: 'Iloilo City', about: '', createdAt: now });
await setDoc(`users/${buyer2Id}`, { name: 'Liza Cruz', email: 'buyer2@demo.ph', role: 'buyer', town: 'Pototan', about: '', createdAt: now });
await setDoc(`users/${adminId}`, { name: 'Admin', email: 'admin@demo.ph', role: 'admin', town: 'Leon', about: '', createdAt: now });

const crops = [
  ['Tomato', 50, 'kg', 45], ['Eggplant', 30, 'kg', 55], ['Cabbage', 20, 'kg', 40],
  ['Ampalaya', 15, 'kg', 80], ['Kangkong', 40, 'bundle', 15],
  ['Lettuce', 10, 'kg', 240], ['Mango', 60, 'kg', 70],
  ['Pechay', 20, 'kg', 54.4, "Pedro's Food Stall"],
];
for (const [i, [crop, quantity, unit, price, title = '']] of crops.entries()) {
  await setDoc(`listings/demo${i}`, {
    farmerId, farmerName: 'Pedro Santos', crop, title, quantity, unit, price, town: 'Leon',
    harvestDate: daysFromNow(2), description: `Fresh ${crop.toLowerCase()} from Leon.`,
    aiAssisted: false, createdAt: new Date(Date.now() - i * 60000),
  });
}

await setDoc('requests/demo1', { buyerId, buyerName: 'Ana Reyes', crop: 'Tomato', quantity: 100, unit: 'kg', targetPrice: 42, town: 'Iloilo City', neededBy: daysFromNow(5), notes: 'For my carinderia, weekly order.', createdAt: now });
await setDoc('requests/demo2', { buyerId, buyerName: 'Ana Reyes', crop: 'Onion', quantity: 25, unit: 'kg', targetPrice: null, town: 'Iloilo City', neededBy: daysFromNow(10), notes: '', createdAt: now });
// To test request states: expires tomorrow, expired 3 days ago, closed by the buyer.
await setDoc('requests/demo3', { buyerId, buyerName: 'Ana Reyes', crop: 'Mango', quantity: 40, unit: 'kg', targetPrice: 60, town: 'Iloilo City', neededBy: daysFromNow(1), notes: 'Ripe, for a fruit stand.', createdAt: now });
await setDoc('requests/demo4', { buyerId, buyerName: 'Ana Reyes', crop: 'Lettuce', quantity: 5, unit: 'kg', targetPrice: 220, town: 'Iloilo City', neededBy: daysFromNow(-3), notes: 'For salads.', createdAt: daysFromNow(-10) });
await setDoc('requests/demo5', { buyerId, buyerName: 'Ana Reyes', crop: 'Cabbage', quantity: 30, unit: 'kg', targetPrice: null, town: 'Iloilo City', neededBy: daysFromNow(7), notes: '', closed: true, createdAt: daysFromNow(-5) });

// 12 months of prices for 4 crops, ending June 2026 at the team's PSA
// reference prices (PSA publishes a few months late, like the real data).
const base = { Tomato: 38.81, Eggplant: 39.13, Cabbage: 30.0, Onion: 50.0 };
for (let m = 11; m >= 0; m--) {
  const d = new Date(2026, 5 - m, 1);
  const month = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
  for (const [crop, price] of Object.entries(base)) {
    // June (m = 0) is exactly the reference price; earlier months vary a bit.
    const wobble = m === 0 ? 0 : Math.round(Math.sin(m + crop.length) * 600) / 100;
    await setDoc(`prices/${crop}_${month}`, { crop, month, price: price + wobble, enteredBy: adminId, enteredAt: now });
  }
}

// Orders (see docs/inventory-design.md). One chat between Ana and Pedro
// holds the order cards. Stock: Pechay (demo7) has 5 kg reserved for Ana;
// Eggplant (demo1) has 5 kg sold.
const chatId = [buyerId, farmerId].sort().join('_');
const order = (id, o) => setDoc(`orders/${id}`, {
  source: 'listing', farmerId, farmerName: 'Pedro Santos', buyerId, buyerName: 'Ana Reyes',
  participants: [buyerId, farmerId], chatId, title: '', unit: 'kg', note: '',
  total: Math.round(o.qty * o.price * 100) / 100, updatedAt: now, reservedUntil: null, ...o,
});
await order('demoOrder1', { listingId: 'demo7', crop: 'Pechay', title: "Pedro's Food Stall", qty: 5, price: 54.4, status: 'reserved', createdAt: daysFromNow(-1), reservedUntil: daysFromNow(2), note: 'Pickup Saturday morning.' });
await order('demoOrder2', { listingId: 'demo0', crop: 'Tomato', qty: 10, price: 45, status: 'pending', createdAt: daysFromNow(-0.1) });
await order('demoOrder3', { listingId: 'demo1', crop: 'Eggplant', qty: 5, price: 55, status: 'completed', createdAt: daysFromNow(-6) });
await order('demoOrder4', { listingId: 'demo2', crop: 'Cabbage', qty: 4, price: 40, status: 'pending', createdAt: daysFromNow(-4) }); // expired
await setDoc('listings/demo7', {
  farmerId, farmerName: 'Pedro Santos', crop: 'Pechay', title: "Pedro's Food Stall", quantity: 20, unit: 'kg', price: 54.4,
  town: 'Leon', harvestDate: daysFromNow(2), description: 'Fresh pechay from Leon.', aiAssisted: false,
  createdAt: new Date(Date.now() - 7 * 60000), soldQty: 0,
  reservations: [{ orderId: 'demoOrder1', qty: 5, until: daysFromNow(2) }],
});
await setDoc('listings/demo1', {
  farmerId, farmerName: 'Pedro Santos', crop: 'Eggplant', title: '', quantity: 30, unit: 'kg', price: 55,
  town: 'Leon', harvestDate: daysFromNow(2), description: 'Fresh eggplant from Leon.', aiAssisted: false,
  createdAt: new Date(Date.now() - 60000), soldQty: 5, reservations: [],
});
await setDoc(`chats/${chatId}`, {
  participants: [buyerId, farmerId], names: { [buyerId]: 'Ana Reyes', [farmerId]: 'Pedro Santos' },
  lastMessage: 'Request to buy: 10 kg of Tomato at ₱45.00/kg (₱450.00)', lastMessageAt: daysFromNow(-0.1), lastSenderId: buyerId,
});
const msg = (id, senderId, text, at, orderId) => setDoc(`chats/${chatId}/messages/${id}`, {
  senderId, text, createdAt: at, ...(orderId ? { type: 'order', orderId } : {}),
});
await msg('m1', buyerId, 'Hi! Is your pechay still available?', daysFromNow(-1.1));
await msg('m2', buyerId, 'Request to buy: 5 kg of Pechay at ₱54.40/kg (₱272.00)', daysFromNow(-1), 'demoOrder1');
await msg('m3', farmerId, 'Accepted: 5 kg of Pechay is held for you.', daysFromNow(-0.9));
await msg('m4', buyerId, 'Request to buy: 10 kg of Tomato at ₱45.00/kg (₱450.00)', daysFromNow(-0.1), 'demoOrder2');

console.log('Demo data ready. Log in as farmer@demo.ph, buyer@demo.ph, buyer2@demo.ph or admin@demo.ph (password demo1234).');
