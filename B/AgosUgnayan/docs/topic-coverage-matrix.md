# Topic Coverage Matrix

Where each course topic appears in our code. Each feature owner checks their rows and can explain them.

| Topic | File | Class / widget | Short description |
|---|---|---|---|
| Value widgets | `lib/widgets/listing_card.dart` | `ListingCard`, `ListingGridCard`, `PriceText` (`Text.rich`, `Icon`) | A listing as a list row or a Market grid card, price in green with "/kg" |
| Value widgets | `lib/widgets/status_badge.dart` | `StatusBadge` | Open / Closed pill with text, not color alone |
| Value widgets | `lib/widgets/brand_app_bar.dart` | `AppLogo` (`Image.asset`) | The AgosUgnayan logo in the top bar and on Login |
| Value widgets | `lib/screens/price_detail_screen.dart` | `PriceDetailScreen` (`LineChart`) | 12-month price chart with fl_chart |
| Layout | `lib/widgets/responsive_body.dart` | `ResponsiveBody` (`Align` + `ConstrainedBox`) | Keeps pages a readable width on laptops; full width on phones |
| Layout | `lib/widgets/tab_page.dart` | `TabPage` (`Column`, `Expanded`) | Page heading on top, list below, for every main tab |
| Layout | `lib/screens/marketplace_screen.dart` | `_buildGrid` (`LayoutBuilder`, `SliverGrid`) | 2 to 4 crop cards per row depending on the screen width |
| Layout | `lib/screens/crop_form_screen.dart` | `CropFormScreen` (`ListView`, `Row`, `Expanded`) | Form fields stacked, quantity and unit side by side |
| Layout | `lib/widgets/async_state_view.dart` | `AsyncStateView`, `_Message` | `Column`, `Padding`, `SizedBox` for loading, error and empty states |
| Interaction | `lib/screens/following_screen.dart` | `FollowingScreen` (`StatusTabs`, `SearchBox`) | Crops / Farmers tabs with counts, search, Unfollow with Undo |
| Interaction | `lib/screens/marketplace_screen.dart` | `MarketplaceScreen` (`ChoiceChip`, `FilterDropdown`, min/max `TextField`, `SortMenu`) | Crop, town and price filters, debounced search, 4 sort orders |
| Interaction | `lib/screens/my_crops_screen.dart` | `MyCropsScreen` (`StatusTabs`, `PopupMenuButton`) | Active / Sold out / Removed tabs; mark sold out, remove, restore, delete forever, all with Undo |
| Interaction | `lib/widgets/confirm_dialog.dart` | `showConfirmDialog` (`showModalBottomSheet`) | Confirmation sheet before delete, log out and discarding a form |
| Interaction | `lib/screens/register_screen.dart` | `_RoleCard` (`InkWell`) | Tappable Farmer / Buyer cards |
| Interaction | `lib/utils/snackbars.dart` | `showMessage`, `showUndoMessage` | Feedback after every action, with Undo for deletes |
| Navigation | `lib/screens/home_screen.dart` | `HomeScreen` (`NavigationBar`, `NavigationRail`, `AppSidebar`, `IndexedStack`) | Role-based tabs: bottom bar on phones, icon rail on tablets, full sidebar with counts and user card on laptops |
| Navigation | `lib/widgets/home_nav.dart` | `HomeNav` (`InheritedWidget`) | Lets a dashboard's "See all" switch to another tab |
| Layout | `lib/screens/farmer_home_screen.dart`, `buyer_home_screen.dart` | `FarmerHomeScreen`, `BuyerHomeScreen` (`LayoutBuilder`, `StatGrid`, `SectionCard`) | Home dashboards: stats, buyer demand, prices, newest crops; two columns on wide screens |
| Navigation | `lib/screens/my_crops_screen.dart` | `_openForm` (`Navigator.push` with a result) | Opens the form and reloads when it returns `true` |
| Navigation | `lib/screens/profile_screen.dart` | `_logOut` (`pushAndRemoveUntil`) | Clears every screen after log out |
| Forms / validation | `lib/screens/register_screen.dart` | `RegisterScreen` | Name, email, password, confirm password, role, town, privacy consent |
| Forms / validation | `lib/screens/crop_form_screen.dart` | `CropFormScreen` (`PopScope`, `_quantityValidator`, `_priceValidator`) | Website-style listing form: required and optional fields, limits, PSA reference hint, "Discard changes?" on Back and Cancel |
| Forms / validation | `lib/screens/edit_profile_screen.dart` | `EditProfileScreen` (`PopScope`, `LabeledField`) | Edit name, town and about, validated, with "Discard changes?" |
| Persistence | `lib/services/auth_service.dart` | `AuthService.updateProfile` | Saves the profile and refreshes the logged-in user everywhere |
| Interaction | `lib/widgets/page_header.dart` | `PageHeader.help`, `showHelpSheet` | "?" next to page titles opens short tips for that page |
| Forms / validation | `lib/widgets/labeled_field.dart` | `LabeledField`, `RequiredNote` | Label above the field with a red star or an "Optional" tag |
| Forms / validation | `lib/utils/validators.dart` | `Validators` | Reusable validators with friendly messages, unit-tested |
| Async / API | `lib/utils/app_exception.dart` | `runSafely` | One try/catch with timeout around every Firebase call |
| Async / API | `lib/screens/marketplace_screen.dart` | `_load`, `_visible` | Firestore query (crop, town, newest 100), then search, min/max price, sort and pages of 12 that work together |
| Interaction | `lib/widgets/list_tools.dart` | `SearchBox` (300 ms debounce), `SortMenu`, `FilterDropdown`, `ListToolbar` ("Clear all filters"), `StatusTabs`, `PaginationBar` | One set of list tools on every list page |
| Layout | `lib/widgets/list_page.dart` | `ListPage` (`CustomScrollView`, `SliverGrid`, `SliverFillRemaining`) | Heading, toolbar, items and page numbers scroll together; grids on wide screens |
| Value widgets | `lib/utils/paging.dart` | `pageOf`, `PageSlice`, `matchesSearch` | "Showing 13-24 of 57" page math and word search, unit-tested |
| Persistence | `lib/services/listing_service.dart`, `request_service.dart`, `message_service.dart` | `setStatus`, `setClosed`, `markRead` | Sold out / removed crops, closed requests, read chats (unread dots) |
| Async / API | `lib/services/psa_service.dart` | `PsaService.fetchFarmgate` (`http` GET + POST, 30 s timeout) | Downloads Iloilo farmgate prices from the PSA OpenSTAT API and turns them into price records |
| Async / API | `lib/services/price_service.dart` | `PriceService.saveMany` (Firestore batch) | Saves the PSA prices; the same crop and month is updated, not duplicated |
| Async / API | `lib/services/crop_photo_service.dart` | `CropPhotoService.loadAll` (`http`, `shared_preferences`) | Sample crop photos from the Wikipedia API, saved for a week, offline fallback |
| Value widgets | `lib/widgets/crop_image.dart` | `CropImage`, `CropHero`, `CropAbout` (`Image.network`, `FutureBuilder`, `Stack`) | Photo over the placeholder, "Sample photo" label, credit and "About" text |
| Async / API | `lib/screens/chat_screen.dart` | `ChatScreen` (`StreamBuilder`) | Live messages from a Firestore stream |
| Async / API | `lib/widgets/async_state_view.dart` | `AsyncStateView` | Shared loading, empty, error (Try again) and data states |
| Persistence | `lib/services/listing_service.dart` | `ListingService` | Firestore create, read, update, delete and restore (Undo) |
| Persistence | `lib/services/price_service.dart` | `PriceService` | Firestore plus an offline copy in `shared_preferences` |
| AI | `lib/services/ai_service.dart` | `AiService.suggestListing` | Gemini via Firebase AI Logic, 20 s timeout, fallback message |
| AI | `lib/models/ai_listing_suggestion.dart` | `AiListingSuggestion.fromJsonText` | Keeps only valid AI values, drops the rest |
| AI | `lib/services/ai_service.dart`, `lib/utils/ai_text.dart` | `AiService.describeCrop`, `cleanCropDescription` | "Generate crop description": crop name only, cleaned to 300 characters, labeled, editable, with fallback |
| Value widgets | `lib/utils/crop_catalog.dart` | `CropInfo`, `CropCategory`, `kCropCatalog` | 71 crops in 6 categories with photo article, PSA price and month |
| Interaction | `lib/widgets/crop_picker.dart` | `CropPickerField`, `showCropPicker` (`showModalBottomSheet` / `Dialog`) | Searchable crop list grouped by category, sheet on phones, dialog on laptops |
| Value widgets | `lib/widgets/price_change.dart` | `PriceChangeText`, `OlderPriceTag` | ▲▼ change only against the month just before; "Older price" label |
| Async / API | `lib/models/buyer_request.dart` | `RequestStatus`, `statusAt`, `daysLeftAt` | Open / Expired / Closed worked out from the dates, unit-tested |
| AI | `lib/widgets/ai_assistant_box.dart` | `AiAssistantBox`, `AiGeneratedChip` | Note input, loading state, "AI-generated" label |
| Value widgets | `lib/models/listing.dart` | `Reservation`, `availableAt`, `reservedAt`, `StockState` | Available / reserved / sold worked out from the dates, unit-tested |
| Value widgets | `lib/models/order.dart` | `CropOrder`, `OrderState`, `stateAt`, `orderTotal` | Order steps and expiry from the dates, unit-tested |
| Async / API | `lib/services/order_service.dart` | `OrderService` (`requestToBuy`, `accept`, `markSold`, `sendOffer`, `_transaction`) | Firestore transactions that refuse when not enough stock is left |
| Navigation | `lib/screens/orders_screen.dart` | `OrdersScreen`, `tabOf` | Orders / My orders tab with status tabs, search, sort, pages, live list |
| Interaction | `lib/widgets/order_card.dart` | `OrderCard`, `OrderStateBadge` | Role-based buttons with confirm sheets; used in Orders and in the chat |
| Forms / validation | `lib/widgets/request_to_buy_sheet.dart`, `lib/widgets/offer_sheet.dart` | `showRequestToBuySheet`, `showOfferSheet` | Quantity checked against what is available, live total |
| Navigation | `lib/screens/home_screen.dart` | `_tabsForRole` (`onPhoneBar`) | Prices for farmers and buyers; on phones it opens from Home so the bottom bar keeps 5 tabs |
| Value widgets | `lib/widgets/stock_summary.dart` | `StockSummary`, `StockChip` | "15 kg available · 5 reserved · 0 sold" with a bar; "Only 3 kg left" |
| Persistence | `lib/services/listing_photo_service.dart`, `lib/utils/photo_compress.dart` | `ListingPhotoService`, `compressPhoto` | Farmer's photo shrunk on the device and saved in Firestore, loaded lazily |
| Interaction | `lib/widgets/photo_picker_field.dart` | `PhotoPickerField` | Add, change or remove a photo with a preview; sample photo as fallback |
| AI | `lib/services/buyer_assistant_service.dart` | `BuyerAssistantService`, `GeminiAssistantAi`, `FakeAssistantAi`, `buildAnswerPrompt` | Buyer assistant: facts first, Gemini words them, fallback without AI |
| Async / API | `lib/utils/assistant_facts.dart` | `comparePrice`, `offerFacts`, `searchListings`, `parseSearchQuery`, `AssistantLimits` | Numbers and search in plain Dart, unit-tested |
| Navigation | `lib/services/assistant_controller.dart` | `AssistantController`, `AssistantScope`, `AssistantRouteObserver` | Pages report their context; button hides on forms and sheets |
| Layout | `lib/widgets/assistant_layer.dart`, `lib/widgets/assistant_messages.dart` | `AssistantLayer`, `AssistantPanel`, `AssistantMessageView` | Floating button and panel (half screen on phones, corner panel on laptops) |
| Privacy | `lib/utils/privacy_filter.dart` | `removeContactDetails` | Removes phone numbers and emails before calling the AI |
