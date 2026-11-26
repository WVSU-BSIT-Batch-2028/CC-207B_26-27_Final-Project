# Usability review (Nielsen's 10 heuristics)

We checked every farmer and buyer workflow against Nielsen's 10 usability heuristics and changed the app where it fell short. Each row names the workflow, what we changed, and where it is in the code, so it can be shown during the code defense.

Workflows reviewed: log in / register, farmer Home, Add and edit a crop (with the AI assistant), My Crops, Buyer Demand, Prices, buyer Home, Market, listing details, Post a request, My Requests, Following, Messages and chat, Profile and Edit profile.

## 1. Visibility of system status

| Where | What the user now sees | File / widget |
|---|---|---|
| Every list | "Loading…" with a spinner, then "Showing 13-24 of 57" and "12 crops found" | `widgets/async_state_view.dart`, `widgets/list_tools.dart` (`PaginationBar`, `ListToolbar`) |
| Buttons that save | Spinner on the button and the button is disabled while saving | `widgets/loading_button.dart` |
| AI assistant | "Reading your note…" while Gemini works, then a blue "AI-generated" label | `widgets/ai_assistant_box.dart` |
| PSA import (admin) | "Getting PSA prices…", then "Saved 168 PSA prices (newest: Jun 2026)" | `screens/price_list_screen.dart` (`_importFromPsa`) |
| Navigation | Counts on tabs (open buyer requests for my crops, my open requests) | `screens/home_screen.dart`, `widgets/app_sidebar.dart` (`CountBadge`) |
| Messages | Green dot and bold text for unread chats; "You have 2 unread conversations" | `screens/inbox_screen.dart`, `models/chat.dart` (`isUnreadFor`) |
| Prices offline | Amber notice "Offline: showing prices saved on …" with Retry | `screens/price_list_screen.dart` (`_buildOfflineNote`) |

## 2. Match between the system and the real world

| Where | Change | File / widget |
|---|---|---|
| Crop listings | Words farmers use: "Sold out", "Put back on sale", "Post crop" | `screens/my_crops_screen.dart` |
| Requests | "Close request (found a farmer)" instead of a technical status | `screens/my_requests_screen.dart` |
| Prices | Every price says "PSA farmgate, Iloilo Province" and its month; ▲ up / ▼ down | `screens/price_list_screen.dart`, `widgets/price_mini_list.dart` |
| AI | Farmers can type in English, Hiligaynon or Filipino ("50 kilos kamatis") | `services/ai_service.dart` |
| Photos | Wikipedia photos say "Sample photo", so nobody thinks it's the farmer's harvest | `widgets/crop_image.dart` |

## 3. User control and freedom

| Where | Change | File / widget |
|---|---|---|
| My Crops | Mark as sold out, Remove, Restore and Delete forever all have Undo | `screens/my_crops_screen.dart` (`_setStatus`, `_delete`) |
| My Requests | Close and Reopen with Undo; Delete asks first and has Undo | `screens/my_requests_screen.dart` |
| Following | Unfollow has Undo | `screens/following_screen.dart` |
| Forms | Cancel button and "Discard changes?" on Back and Cancel | `screens/crop_form_screen.dart`, `request_form_screen.dart`, `edit_profile_screen.dart` (`PopScope`) |
| Filters | "Clear all filters" appears as soon as anything is filtered | `widgets/list_tools.dart` (`ListToolbar`) |

## 4. Consistency and standards

| Where | Change | File / widget |
|---|---|---|
| Every list page | Same layout and tools: heading, search, filters, sort, pages | `widgets/list_page.dart` (`ListPage`), `widgets/list_tools.dart` |
| Every form | Labels above fields, red * for required, grey "Optional" tag | `widgets/labeled_field.dart` |
| Colors and type | One theme from the website's design tokens | `utils/theme.dart` |
| Confirmations | One bottom sheet with clear buttons ("Delete" / "Cancel") | `widgets/confirm_dialog.dart` |
| Navigation | Same tabs in the same order on phone (bottom), tablet (rail) and laptop (sidebar) | `screens/home_screen.dart` |

## 5. Error prevention

| Where | Change | File / widget |
|---|---|---|
| Add crop | Price must be above ₱0 and below ₱10,000; quantity up to 100,000; harvest date required | `screens/crop_form_screen.dart` (`_priceValidator`, `_quantityValidator`) |
| Delete forever | Only offered in the Removed tab, and asks first | `screens/my_crops_screen.dart` |
| Double taps | Save buttons are disabled while saving | `widgets/loading_button.dart` |
| Pages | Changing a filter goes back to page 1, so nobody lands on an empty page | `utils/paging.dart` (`pageOf` keeps the page in range) |
| Admin | Importing PSA again updates prices instead of making duplicates | `services/price_service.dart` (`saveMany`) |

## 6. Recognition rather than recall

| Where | Change | File / widget |
|---|---|---|
| Add crop | The newest PSA price for the chosen crop is shown under the price field | `screens/crop_form_screen.dart` (`_priceHint`) |
| Lists | Active filters stay visible (selected chips, dropdown values, tab counts) | `widgets/chip_filter_row.dart`, `widgets/list_tools.dart` (`StatusTabs`) |
| Home | The first screen shows what needs attention: buyer requests for my crops, my latest crops | `screens/farmer_home_screen.dart`, `buyer_home_screen.dart` |
| Crops | Photos next to crop names make lists faster to scan | `widgets/crop_thumb.dart`, `widgets/crop_image.dart` |

## 7. Flexibility and efficiency of use

| Where | Change | File / widget |
|---|---|---|
| Search | Results update 300 ms after typing; Enter searches at once | `widgets/list_tools.dart` (`SearchBox`) |
| Sort | Every list can be sorted (price, newest, soonest, name, biggest change) | `widgets/list_tools.dart` (`SortMenu`) |
| AI assistant | "Fill in for me" fills the whole crop form from one sentence | `widgets/ai_assistant_box.dart` |
| Dashboards | Each tile and "See all" jumps straight to the right tab | `widgets/home_nav.dart` (`HomeNav`) |
| Demand | "Only crops I sell" in one tap | `screens/buyer_demand_screen.dart` |

## 8. Aesthetic and minimalist design

| Where | Change | File / widget |
|---|---|---|
| Prices | Removed the long caption; the source stays on each row | `screens/price_list_screen.dart` |
| Wide screens | More columns instead of wide empty margins; content up to 1200 px | `widgets/list_page.dart` (`sliverCardGrid`), `utils/theme.dart` |
| Login | Laptop login uses a split screen instead of a small form in empty space | `screens/login_screen.dart` (`_BrandPanel`) |
| Cards | Flat cards with thin borders, one accent color per meaning | `utils/theme.dart`, `widgets/section_card.dart`, `widgets/stat_tile.dart` |

## 9. Help users recognize, diagnose and recover from errors

| Where | Change | File / widget |
|---|---|---|
| Lists | Errors show a red icon, a friendly sentence and "Try again" | `widgets/async_state_view.dart` |
| Forms | Messages say what is wrong and how to fix it ("Enter a valid email, like name@example.com") | `utils/strings.dart`, `utils/validators.dart` |
| AI | If Gemini is busy, a red notice says so and the farmer fills the form by hand | `widgets/ai_assistant_box.dart`, `widgets/notice_box.dart` |
| Empty results | "No crops match your search and filters. Try fewer filters, or tap Clear all filters." | `screens/marketplace_screen.dart` and the other list screens |

## 10. Help and documentation

| Where | Change | File / widget |
|---|---|---|
| Main pages | "?" next to the title opens short tips for that page | `widgets/page_header.dart` (`help`, `showHelpSheet`) |
| Empty states | Say what to do next ("Tap Add crop to sell one.") | every list screen's `emptyMessage` |
| Forms | Help lines under fields ("Leave empty if you are open to offers.") | `widgets/labeled_field.dart` (`help`) |

## Responsive test

Every farmer and buyer tab was opened at four widths (with demo data on the local Firebase Emulator) and checked for overlaps, cut-off text and Flutter layout errors.

| Width | Layout | Pages checked | Result |
|---|---|---|---|
| 375 px (phone) | Logo bar on top, tabs at the bottom, 2-column crop grid | Home, Prices, My Crops, Demand, Messages, Market, Requests, Following | No layout errors. Fixed: price rows wrapped the source line (now one line), the Market town filter cut "All towns" |
| 768 px (tablet) | Icon rail on the left, 3-column crop grid | same | No layout errors |
| 1280 px (laptop) | Full sidebar with counts and user card, 4-column grid, two-column dashboards | same | No layout errors |
| 1440 px (wide) | Same as laptop; content stays 1200 px wide and centered | same | No layout errors |

## Update (Nov 23): 71 crops, AI descriptions, expired requests

| Heuristic | Change | File / widget |
|---|---|---|
| 1 Visibility of system status | Expired requests show an amber "Expired" badge and "(3 days ago)"; open ones due soon show "Expires today / tomorrow / 3 days left"; Home reminds the buyer; the Requests badge counts what needs attention | `widgets/request_card.dart`, `screens/buyer_home_screen.dart`, `screens/home_screen.dart` |
| 2 Match with the real world | Crops grouped like at a market (fruit vegetables, leafy, root crops, condiments, beans, fruits); local names work in search ("litsugas" finds Lettuce) | `utils/crop_catalog.dart`, `widgets/crop_picker.dart` |
| 3 User control and freedom | New date for an expired request has Undo; Close asks first and can be reopened | `screens/my_requests_screen.dart` |
| 5 Error prevention | "Needed by" can't be in the past; old prices are labeled "Older price" and never compared with far-away months; the AI asks before replacing the farmer's own description | `widgets/date_field.dart`, `widgets/price_change.dart`, `screens/crop_form_screen.dart` |
| 6 Recognition rather than recall | Crop photos in the picker and lists; category chips instead of 71 crop chips | `widgets/crop_picker.dart`, `widgets/chip_filter_row.dart` (`CategoryChipRow`) |
| 7 Flexibility and efficiency | "Generate crop description" writes a first draft; search the crop list instead of scrolling 71 names | `services/ai_service.dart`, `widgets/crop_picker.dart` |
| 9 Error recovery | Expired request details explain what happened and what to do; AI failure says the farmer can write their own | `screens/request_detail_screen.dart`, `screens/crop_form_screen.dart` |
| 10 Help | Help tips on Prices ("Older price") and My requests (Expired) | `screens/price_list_screen.dart`, `screens/my_requests_screen.dart` |

Checked on the emulator with the updated demo data at 375 and 1280 px: crop picker with search, Market with categories and new crops, Prices with "Older price", Add crop with the description button and its fallback, My requests Open / Expired / Closed, buyer Home reminder. No layout errors.

## Update (Nov 23): titles, photos, stock and orders

| Heuristic | Change | File / widget |
|---|---|---|
| 1 Visibility of system status | Available amount on every card and the listing page; "Only 3 kg left"; My Crops shows available / reserved / sold with a bar; order labels say whose turn it is ("Needs your answer", "Waiting for farmer"); the Orders badge counts what waits for me; chat cards update live | `widgets/stock_summary.dart`, `widgets/order_card.dart`, `screens/home_screen.dart` |
| 2 Match with the real world | Farmers can name their listing like their stall ("Juan's Food Stall") and show their own harvest photo; words like "Request to buy", "Hold 3 more days", "Mark as sold" | `screens/crop_form_screen.dart`, `widgets/order_card.dart` |
| 3 User control and freedom | Cancel a waiting request (buyer), cancel an offer or reservation (farmer), decline; Remove photo; buyers can "Ask to cancel" in the chat | `widgets/order_card.dart`, `widgets/photo_picker_field.dart` |
| 4 Consistency and standards | Orders uses the same list page, tabs, search, sort and pages as the other lists; one order card for the Orders screen and the chat | `screens/orders_screen.dart`, `widgets/list_tools.dart` |
| 5 Error prevention | You can't ask for more than is available; Accept re-checks stock and refuses ("Nothing is left of this crop to hold"); Edit can't set stock below sold + reserved; Mark sold out and Remove are blocked while stock is held; every irreversible step asks first; offers from a listing hold the stock so it is not sold twice | `widgets/request_to_buy_sheet.dart`, `services/order_service.dart`, `screens/my_crops_screen.dart` |
| 6 Recognition rather than recall | The real crop name stays under a custom title; "Marketplace" / "Private offer" labels; the total is shown while typing | `widgets/listing_card.dart`, `widgets/order_card.dart` |
| 7 Flexibility and efficiency | Offer a crop right in the chat without posting it; "Take from my listing" fills the unit and price | `widgets/offer_sheet.dart` |
| 8 Aesthetic and minimalist design | The phone's bottom bar keeps 5 tabs (Prices and Following open from Home); tab labels stay on one line | `screens/home_screen.dart`, `widgets/list_tools.dart` |
| 9 Error recovery | Clear messages when a photo is not a picture or too large, or when stock ran out | `utils/photo_compress.dart`, `services/order_service.dart` |
| 10 Help | Help tips on Orders explain Waiting, Reserved, expiry and private offers | `screens/orders_screen.dart` |

Checked on the emulator with the demo data at 375 and 1280 px:
- Add crop with a title and an uploaded photo.
- Market cards with titles and available amounts.
- Listing page with Request to buy (asking for more than is available is blocked).
- Orders as farmer and buyer: accept, refused over-reserve, mark sold, cancel.
- Chat order cards and the offer form: private, and from a listing.
- My Crops stock line.

No layout errors.

## Update (Nov 23): Prices for buyers

| Heuristic | Change | File / widget |
|---|---|---|
| 6 Recognition rather than recall | Buyers get the same Prices page as farmers, so they can compare PSA farmgate prices with farmers' asking prices before requesting or accepting an offer | `screens/home_screen.dart`, `screens/price_list_screen.dart` |
| 8 Aesthetic and minimalist design | On phones the bottom bar stays at 5 tabs; Prices opens from a Home tile ("PSA prices to compare") and the "All prices" link. On tablets and laptops it is in the menu | `screens/buyer_home_screen.dart` |
| 5 Error prevention | Buyers see the page read-only: the admin buttons (Get latest PSA prices, Load reference prices, Add price) only show for the admin | `screens/price_list_screen.dart` |

Checked as buyer@demo.ph on the emulator at 375 and 1280 px.

## Update (Nov 23): buyer AI assistant

| Heuristic | Change | File / widget |
|---|---|---|
| 1 Visibility of system status | "Looking it up…" while it works; "The assistant is busy right now" when the AI fails; a wait message between questions | `widgets/assistant_layer.dart` |
| 3 User control and freedom | Close and reopen without losing the chat; "New chat"; it never acts for the buyer (read-only) | `services/assistant_controller.dart` |
| 5 Error prevention | The numbers come from the app, not the AI; search only shows real listings with stock; the button hides on forms and sheets so it never covers their buttons | `utils/assistant_facts.dart` |
| 6 Recognition rather than recall | Suggested questions change with the page, and the assistant already knows the listing, price or order on screen | `services/assistant_controller.dart` (`suggestionsFor`) |
| 9 Error recovery | Without AI, the same facts and listing cards are still shown | `services/buyer_assistant_service.dart` |
| 10 Help | How-to answers come from a short FAQ of the app's real flows | `kAppFaq` |

Checked on the emulator (with the test AI) at 375 and 1280 px:
- the button above the phone tab bar and clear of the chat's message box;
- the panel layout;
- chips on Market, a listing and a chat;
- search results opening a listing;
- price check and offer total.

The fallback is covered by a widget test.

## Update (Nov 23): hybrid assistant

| Heuristic | Change | File / widget |
|---|---|---|
| 1 Visibility of system status | Every answer says where it comes from: "From AgosUgnayan", "AI suggestion", or "General answer, not from AgosUgnayan data" | `widgets/assistant_messages.dart` |
| 2 Match with the real world | Typos are understood ("hteprices", "prcie"); answers come in the buyer's language (English, Filipino or Hiligaynon); small talk is answered | `utils/assistant_facts.dart` |
| 5 Error prevention | App numbers only come from the app; with no data the AI must say so instead of guessing | `services/buyer_assistant_service.dart` |
| 6 Recognition rather than recall | "Top 5 vegetable prices", "cheapest fruit" and "compare tomato and cabbage" give ready lists; the welcome text says what to ask | `utils/assistant_rankings.dart` |
| 9 Error recovery | Unclear questions get a friendly answer instead of "I don't have that" | `services/buyer_assistant_service.dart` |
