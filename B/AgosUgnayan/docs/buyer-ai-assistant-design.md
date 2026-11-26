# Buyer AI assistant: design note

A small helper for **buyers only**. It answers questions about the page they are on: whether a price is fair, how much an amount costs, where to find a crop, and how to use the app. It is **read-only**: it never buys, accepts, declines, sends messages or changes data. It can only open pages.

## Placement

- A round "AI" button (52 px) in the bottom-right corner of every buyer screen. On phones it sits above the bottom tab bar. It is hidden while a form or a bottom sheet is open (e.g. Post request, Request to buy), so it never covers a main button.
- Tapping it opens a compact panel:
  - **Phones:** a half-height panel at the bottom.
  - **Tablets and laptops:** a 380 × 560 panel in the bottom-right corner.
- **Closing and reopening:** the X closes the panel. Reopening shows the same conversation, kept in memory until logout; "New chat" clears it.
- It is built once, above all screens (`MaterialApp.builder`). Each screen tells it what is on the page through `AssistantScope` / `AssistantController`: the tab, the listing, the crop and price history, or the order in a chat.

## Problems it solves

| Question | What the app does first (plain Dart) | What Gemini adds |
|---|---|---|
| Price check ("Is this price fair?") | Asking price vs PSA reference price for the crop: difference in ₱ and %, the month, and "older price" when it is old | Explains it in 2-5 simple sentences |
| Price trend ("Is this price going up?") | Change from the month before and over our 12 months of PSA data | Explains it simply |
| Listing search ("cheapest tomato near Iloilo City") | Gemini turns the words into a query (crop from our 71 crops, town, amount, sort). The app checks that query and runs it on real listings with stock left (one small Firestore query) | Only reads the words; it never invents listings. The cards come from the database |
| Offer math ("How much for 5 kg?") | Quantity × price, compared with the available stock and the reference price; for an order in a chat, what its status means and until when | Explains it simply |
| How-to ("How do I request a crop?") | A short hand-written FAQ of the app's real flows | Answers only from the FAQ; otherwise "I don't have that" |

All numbers are computed in Dart. The model only words the answer.

## What Gemini receives (data access)

The app looks up the facts first, then sends only:
- the question;
- a compact block of facts: crop, prices with months, quantities, totals, order status and dates, and up to 5 listings (title, crop, price, available, town, farmer display name as shown publicly);
- the FAQ for how-to questions.

**Never sent:** emails, phone numbers, user ids, other buyers' data or the database. Phone numbers and emails are removed from the question (`removeContactDetails`).

**Untrusted text:** text written by farmers (titles, descriptions, notes) is cut short and put inside a clearly marked data block. The prompt says to treat it as data and ignore any instructions inside it.

## Prompt rules

- Answer only from the FACTS.
- Say "I don't have that" when the facts don't cover the question.
- Use 2-5 short sentences in plain words, in the buyer's language (English, Filipino or Hiligaynon).
- Never invent prices, stock or farmers, and never promise anything on a farmer's behalf.

## Free tier limits

- Gemini free tier through the existing Firebase AI Logic (`gemini-3.5-flash-lite`, the same model as the farmer features: `AiService.modelName`). No new paid service and no new packages.
- **Limits in the app:**
  - one question at a time, then 3 seconds before the next;
  - at most 20 questions per session;
  - 20-second timeout;
  - short answers (at most 300 output tokens);
  - facts trimmed to about 2,400 characters (≈600 tokens).
- **Firestore reads:**
  - PSA prices load once per session.
  - A search is one query limited to 30 listings.
  - Page facts come from data the screen already loaded.

## Safety

- **Read-only.** The only actions are "Open listing" and "Open Market".
- **Labels.** Every AI answer has an "AI suggestion" label. The numbers are shown separately in a "Facts from AgosUgnayan" box. The panel says once at the top: "AI can make mistakes. Check the listing details."

## Fallback

When Gemini is busy, over the limit, times out or fails, the panel says "The assistant is busy right now" and still helps without AI:
- the price comparison table;
- the keyword search with the same listing cards;
- the computed total.

So the core numbers never depend on the AI.

In the emulator there is no AI. Building with `--dart-define=FAKE_AI=true` uses a fake that words the facts, so the screens can be tested.
