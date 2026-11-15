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
    /medicine|pharmacy|pharmacies|reserve|reservation|pickup|price|stock|available|brand|generic|paracetamol|biogesic|offer/i;
  
  // A refusal, or null when the question may be answered from MediTech data
  export function refuseReason(message: string): string | null {
    if (dosingOrDiagnosis.test(message)) {
      return "I can't help with diagnosis or how much medicine to take. Ask a pharmacist or a doctor.";
    }
    if (outsideMeditech.test(message) || !aboutMeditech.test(message)) {
      return "I can only help with MediTech medicines, pharmacies, and your own reservations.";
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