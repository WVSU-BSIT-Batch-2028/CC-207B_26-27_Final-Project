# Known limitations and planned features

## Known limitations
- **Market search, price filter, sorting and page numbers** work on the newest 100 crops for sale that match the crop and town filters (Firestore has no full-text search). Crop and town filters are part of the database query.
- **Buyer Demand** shows the 100 soonest open requests; search, filters, sorting and pages work on those.
- **Chat** loads the newest 50 messages of a conversation; older ones are not shown.
- **Following a listing** saves its title and price at that moment; if the farmer edits the price later, the Following list shows the old text until the buyer opens it.
- **Reference prices** come from PSA OpenSTAT when the admin taps "Get latest PSA prices"; they do not update by themselves. PSA publishes a few months late (in Nov 2026 the newest month was June 2026), so the app always shows the month next to each price.
- **Admin** can only add prices. Managing users and removing posts is done in the Firebase console.
- The **AI assistant** needs the real Firebase project with AI Logic turned on; it falls back to the manual form in the emulator.
- **App Check** is set to "Unenforced (monitoring only)" for Firebase AI Logic, because the app does not use App Check yet. Google will turn enforcement on automatically on January 21, 2027; after that the AI only works if we add App Check (reCAPTCHA for web) or unenforce it again.
- The **Gemini model** can be busy or retired by Google. When it does not answer within 20 seconds the farmer fills in the form by hand. To switch models, change `AiService.modelName` (we moved from `gemini-2.5-flash`, retired for new projects, to `gemini-3.5-flash`, then to `gemini-3.5-flash-lite`).
- **Crop catalog**: 71 crops in 6 categories live in `lib/utils/crop_catalog.dart`. Their PSA reference prices (from the team, mostly June 2026) are used whenever the database has no price for that crop and month. Prices older than the newest month are labeled "Older price" and keep their real month (e.g. Leeks, January 2025). The "Get latest PSA prices" import only knows the PSA tables of the first 10 crops; the other 61 use the catalog until an admin adds newer prices.
- **Banana blossom and Camote tops** share the Banana and Sweet potato photos, because Wikipedia has no separate photo for them.
- **Expired requests** are worked out from the date on the phone each time (the free Firebase plan has no server to change data at midnight). Reminders are inside the app only (Home notice, badge, "Expires tomorrow"); push or email reminders would need Cloud Functions on the paid Blaze plan.
- **Crop photos**: farmers can add their own photo. Without one, the crop shows a sample photo from Wikipedia, always labeled "Sample photo" with the photographer and license; offline, or if Wikipedia can't be reached, a green leaf placeholder shows instead. Sample photos are saved on the device for a week.
- **Farmers' photos are stored in Firestore, not Firebase Storage**, because Storage now needs the paid Blaze plan.
  - The app shrinks each photo on the device to at most 800 px (JPEG, aiming at 150 KB, refusing anything still over 300 KB).
  - It is saved in its own `listing_photos` document, because Firestore allows 1 MB per document.
  - So photos are smaller and less sharp than a full-size upload, and there is one photo per listing.
- **Stock and orders** (see `docs/inventory-design.md`): available = total − sold − holds that have not ended, worked out every time.
  - Holds and waiting requests or offers end by their date only (3 days); there is no server to change them at midnight.
  - An ended hold stops counting by itself, but the order shows "Reservation ended" until the farmer marks it sold, holds it 3 more days or cancels it.
  - Only the farmer's app writes stock, so a hold for an offer the buyer declined is freed when the farmer next opens Orders (or when its date passes).
- **No push or email notifications**: changes show inside the app as chat messages ("Accepted…", "Sold…") with the unread dot, live order cards and badges on Orders and Requests. Push (FCM) or email would need Cloud Functions, which need the paid Blaze plan.
- **Private offers** are only between the two people in the chat. A farmer can offer one crop per offer; several crops need several offers.
- **Orders screen** loads up to 200 of the user's newest orders.

- **Changing your name** in Edit profile does not rename crops, requests or chats you posted before; they keep the name they were posted with (the app says so on the Edit profile page).

- **Buyer AI assistant**:
  - It remembers the chat only until the buyer logs out or closes the app; there is no memory across sessions.
  - It allows 20 AI questions per session (then facts only), one at a time, 3 seconds apart.
  - Its words can be wrong; the numbers in the Facts box come from the app.
  - Trends only use the 12 months of PSA prices we have and do not predict prices.
  - It doesn't work in the emulator unless built with `FAKE_AI=true`.

- **Gemini free tier is per model and per project**:
  - `gemini-3.5-flash` allows only **20 requests per day for the whole project**, which is why all AI features now use `gemini-3.5-flash-lite`.
  - Lite's daily free limit is not shown in the app. If it is reached, every AI feature shows its friendly "busy" message and the app keeps working without AI:
    - the farmer fills in the form by hand;
    - the buyer assistant shows the facts only.
  - Usage can be checked in the Firebase console (AI Logic).

- **Buyer assistant general answers** (food, storage, small talk) come from Gemini's general knowledge.
  - They can be wrong, and they are labeled "General answer, not from AgosUgnayan data".
  - It remembers the last 6 messages of the current chat only.
  - 40 AI questions per session; after that, prices, search and totals still work without AI.
- **Gemini per-minute limit**: in our tests about 35 calls in 9 minutes caused one "quota exceeded" answer. A buyer asking every few seconds may briefly see "The assistant is busy right now"; app facts still show.

## Free-tier limits that matter

We only use free services. A class-sized test stays far below these limits, but they are good to know:

| Service | Free limit (Spark plan / free tier) | How the app stays under it |
|---|---|---|
| Cloud Firestore | 50,000 reads, 20,000 writes and 20,000 deletes per day; 1 GiB stored | Lists use limits and pages; the Market, Orders and chat use one live query each (not one per card); photos load only for cards on screen and stay in memory |
| Firebase Hosting | 10 GB stored, 360 MB downloaded per day | One small web build; crop photos are not hosted by us |
| Firebase Authentication | Free for email and password | Email and password only |
| Gemini (Firebase AI Logic, Gemini Developer API) | Free tier with per-minute and per-day request limits | Called only when a farmer taps a button; 20-second timeout and a fallback when it is busy |
| PSA OpenSTAT, Wikipedia | Free public APIs | PSA only when the admin taps the button; Wikipedia photos load lazily, 2 at a time, saved for 7 days |

**App Check**: Firebase AI Logic will enforce App Check from January 21, 2027. App Check with reCAPTCHA for the web is free if we need to turn it on.

## Removed from the web version on purpose
- Map view of sellers, and every map package and component.
- Language settings (Hiligaynon / Filipino); the app is English for now.
- Settings screen: replaced by the Profile page (the account button at the top right).
- Separate "Follow seller" and "Saved listings": replaced by one Following tab with Crop Listings and Farmers.

## Planned features
- Price alerts and notifications when a followed farmer posts a crop.
- Hiligaynon and Filipino translations.
- Importing PSA prices automatically every month (now the admin taps a button).
- Reporting and moderation tools for the admin.
