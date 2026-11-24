// Decide which questions to refuse, and which replies invented a fact

export type AiFacts = {
  prices: string[];
  referenceNumbers: string[];
  pickupCodes: string[];
};

const dosingOrDiagnosis =
  /diagnos|dosage|\bdose\b|how many (tablet|tablets|capsule|capsules|ml|mg)|how much should i take|side effect|symptom|pregnant|what (medicine|drug) should i|treatment|\bcure\b|prescri/i;

const outsideMeditech =
  /weather|joke|homework|write (me )?code|politic|president|movie|song lyric|recipe|stock market|bitcoin|another (customer|person)|someone else/i;

const aboutMeditech =
  /meditech|medicine|pharmacy|pharmacies|reserve|reservation|pickup|price|stock|available|brand|generic|find|where|offer|\bmg\b|tablet|capsule|syrup|biogesic|paracetamol|cart|search|sign ?in|sign ?up|profile|notification|assistant|account|how (do|to|can)|help|recommend|steps?|app/i;

const appHelp =
  /how (do|to|can)|steps?|help|recommend|what is meditech|about (the )?app|sign ?in|sign ?up|cart|profile|notification|forgot password|guest|pickup code|my reservation|use (the )?app|walk me through/i;

// Fixed guide about the customer app only. No medical advice.
export const appGuide = {
  what_meditech_is:
    "MediTech helps customers find medicines at partner pharmacies in the app, compare offers, and reserve for pickup. It does not give medical advice.",
  main_steps: [
    "1. Sign in with your email or mobile number (or continue as guest to browse).",
    "2. Use Search or Home to look up a medicine by brand or generic name.",
    "3. Open a medicine, compare pharmacy offers, and add Available or Low Stock items to your cart.",
    "4. Keep one pharmacy per cart. Guests must sign in before using a cart.",
    "5. Upload a prescription in the cart when an item needs one.",
    "6. Place the reservation, then track it under My Reservations.",
    "7. After the pharmacy confirms, your pickup code appears on the reservation details.",
    "8. Bring the pickup code to the pharmacy to collect your order.",
  ],
  recommendations: [
    "Prefer pharmacies marked Available. Low Stock can still be reserved, but may run out.",
    "If several pharmacies list the same medicine, compare price and availability in the offers list.",
    "If a medicine is not listed, it is not on MediTech yet. Try another brand or generic name in Search.",
    "Use this Assistant for listings, offers, your own reservations, and how to use the app. Ask a pharmacist or doctor for dosing or diagnosis.",
  ],
  limits: [
    "Customers can cancel a pending reservation before the pharmacy confirms it.",
    "Only medicines shown in MediTech can be recommended.",
    "Never invent a price, availability, reservation status, reference number, or pickup code.",
  ],
};

// True when the customer is asking about a medicine listing, not app help or reservations
export function isMedicineLookup(message: string): boolean {
  if (appHelp.test(message)) return false;
  if (/reserv|pickup|reference/i.test(message)) return false;
  if (/nearby pharmac|pharmacies (near|around)|open now/i.test(message)) return false;
  return /find|where|available|stock|price|offer|listed|listing|brand|generic|\bmg\b|tablet|capsule|syrup|medicine/i
    .test(message);
}

// What to say when MediTech has no matching medicine
export function medicineNotListedAnswer(): string {
  return "That medicine is not available on MediTech yet. Try another brand or generic name from Search, or ask about a medicine listed in the app. I can also walk you through Search → medicine details → cart → reservation if you want the steps.";
}

// True when the customer wants app how-to help
export function isAppHelp(message: string): boolean {
  // "Recommend a pharmacy for Biogesic" should use live offers, not only tips
  if (
    /recommend/i.test(message) &&
    /biogesic|paracetamol|\bmg\b|tablet|capsule|syrup|for [a-z]/i.test(message) &&
    !/how (do|to|can)|steps|what is meditech|sign ?in|cart|profile/i.test(message)
  ) {
    return false;
  }
  return appHelp.test(message);
}

// Fixed MediTech-only steps and tips, without calling the model
export function appHelpAnswer(message: string): string {
  const lower = message.toLowerCase();
  if (/reserv|pickup|cart|prescription/.test(lower)) {
    return [
      "Here’s how reservations work in MediTech:",
      "1. Search for a medicine and open one listed in the app.",
      "2. Choose a pharmacy offer marked Available or Low Stock and add it to your cart.",
      "3. One pharmacy per cart. Sign in if you are still a guest.",
      "4. Upload a prescription in the cart when an item needs one.",
      "5. Place the reservation, then open My Reservations to track it.",
      "6. After the pharmacy confirms, your pickup code shows on the reservation details. Bring that code to the pharmacy.",
      "Customers can cancel a pending reservation before confirmation. Ask a pharmacist or doctor for medical advice.",
    ].join("\n");
  }
  if (/recommend/.test(lower)) {
    return [
      "In MediTech I only recommend from medicines and offers listed in the app:",
      "- Prefer pharmacies marked Available. Low Stock can still be reserved, but may run out.",
      "- Compare price and availability on the medicine’s offer list.",
      "- Ask me about a specific listed medicine (for example Biogesic or paracetamol) for pharmacy options.",
      "- If it isn’t in Search, it isn’t on MediTech yet.",
      appGuide.what_meditech_is,
    ].join("\n");
  }
  if (/sign ?in|sign ?up|account|guest|forgot password|profile/.test(lower)) {
    return [
      "Account help in the MediTech customer app:",
      "- Sign in with your email or mobile number and password.",
      "- New here? Use Sign up, then confirm your details.",
      "- Guests can browse Search, but need to sign in for cart, reservations, and this Assistant’s personal reservation answers.",
      "- Forgot password? Use Forgot password on the sign-in screen for an emailed code.",
      "- Profile and the privacy notice are under Profile.",
    ].join("\n");
  }
  return [
    appGuide.what_meditech_is,
    "",
    "Basic steps:",
    ...appGuide.main_steps,
    "",
    "Tips:",
    ...appGuide.recommendations.map((tip) => `- ${tip}`),
  ].join("\n");
}

// A refusal, or null when the question may be answered from MediTech data
export function refuseReason(message: string): string | null {
  if (dosingOrDiagnosis.test(message)) {
    return "I can't help with diagnosis or how much medicine to take. Ask a pharmacist or a doctor. I can still help you search medicines in MediTech or explain how reservations work.";
  }
  if (outsideMeditech.test(message) || !aboutMeditech.test(message)) {
    return "I can only help with the MediTech app: medicines, pharmacies, your reservations, and how to use the customer app.";
  }
  return null;
}

// True when the reply names a price, reference number, or pickup code that was not in the facts
export function hasInventedFact(reply: string, facts: AiFacts): boolean {
  const prices = reply.match(/\d+\.\d{2}/g) ?? [];
  if (prices.some((price) => !facts.prices.includes(price))) return true;

  const references = reply.match(/RM-\d{6}-\d{4,5}/g) ?? [];
  if (references.some((reference) => !facts.referenceNumbers.includes(reference))) return true;

  const pickup = reply.match(/pickup code[^A-Za-z0-9]*([A-Za-z0-9]{4})/i);
  if (pickup && !facts.pickupCodes.includes(pickup[1].toUpperCase())) return true;

  return false;
}
