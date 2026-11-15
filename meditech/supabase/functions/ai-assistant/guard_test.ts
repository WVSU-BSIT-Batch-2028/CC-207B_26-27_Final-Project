import { assertEquals } from "jsr:@std/assert@1";
import { hasInventedFact, refuseReason } from "./guard.ts";

Deno.test("refuses dosing", () => {
  assertEquals(
    refuseReason("how many tablets should I take"),
    "I can't help with diagnosis or how much medicine to take. Ask a pharmacist or a doctor.",
  );
});

Deno.test("refuses an outside question", () => {
  assertEquals(
    refuseReason("what is the weather today"),
    "I can only help with MediTech medicines, pharmacies, and your own reservations.",
  );
});

Deno.test("allows a medicine question", () => {
  assertEquals(refuseReason("where can I find paracetamol"), null);
});

Deno.test("blocks a made-up price", () => {
  const invented = hasInventedFact("It costs 99.50.", {
    prices: ["12.00"],
    referenceNumbers: [],
    pickupCodes: [],
  });
  assertEquals(invented, true);
});

Deno.test("allows a real price", () => {
  const invented = hasInventedFact("It costs 12.00.", {
    prices: ["12.00"],
    referenceNumbers: [],
    pickupCodes: [],
  });
  assertEquals(invented, false);
});