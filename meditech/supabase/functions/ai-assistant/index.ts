// Answer from MediTech facts only, using the free Gemini API
import { createClient } from "npm:@supabase/supabase-js@2";
import { hasInventedFact, refuseReason, type AiFacts } from "./guard.ts";

const url = Deno.env.get("SUPABASE_URL")!;
const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const geminiKey = Deno.env.get("GEMINI_API_KEY");

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function reply(status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

function money(value: unknown) {
  return Number(value).toFixed(2);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return reply(405, { error: "Use POST." });

  const header = req.headers.get("Authorization");
  if (!header) return reply(401, { error: "Sign in before using the assistant." });

  const body = await req.json().catch(() => ({}));
  const message = String(body.message ?? "").trim();
  if (!message) return reply(400, { error: "Enter a question." });
  if (message.length > 500) return reply(400, { error: "Ask a shorter question." });

  const refusal = refuseReason(message);
  if (refusal) return reply(200, { answer: refusal });

  if (!geminiKey) return reply(503, { error: "The assistant is unavailable." });

  const userClient = createClient(url, anonKey, {
    global: { headers: { Authorization: header } },
    auth: { persistSession: false },
  });
  const { data: userData, error: userError } = await userClient.auth.getUser();
  if (userError || !userData.user) return reply(401, { error: "Sign in before using the assistant." });

  const server = createClient(url, serviceKey, { auth: { persistSession: false } });
  const userId = userData.user.id;
  const { data: account } = await server.from("accounts").select("account_type").eq("id", userId).maybeSingle();
  if (account?.account_type !== "customer") {
    return reply(403, { error: "This assistant is for customers." });
  }

  const { data: allowed, error: limitError } = await server.rpc("consume_ai_message", {
    p_account_id: userId,
  });
  if (limitError) return reply(503, { error: "The assistant is unavailable." });
  if (allowed !== true) return reply(429, { error: "You have reached today's limit of 20 questions." });

  const facts = await loadFacts(server, userId, message);
  const gemini = await fetch(
    "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent",
    {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-goog-api-key": geminiKey },
      body: JSON.stringify({
        systemInstruction: {
          parts: [{
            text: "You are the MediTech assistant. Use only the facts below. If a fact is missing, say you do not have it in MediTech. Do not answer questions outside medicines, pharmacies, offers, and this customer's reservations. Do not give diagnosis or dosing advice. Do not invent a price, availability, reservation status, reference number, or pickup code.\n\nFacts:\n" +
              JSON.stringify(facts.forModel),
          }],
        },
        contents: [{ role: "user", parts: [{ text: message }] }],
        generationConfig: { temperature: 0.2, maxOutputTokens: 400 },
      }),
    },
  );

  if (!gemini.ok) return reply(503, { error: "The assistant is unavailable." });
  const payload = await gemini.json();
  const parts = payload?.candidates?.[0]?.content?.parts ?? [];
  const answer = parts.map((part: { text?: string }) => part.text ?? "").join("").trim();
  if (!answer || hasInventedFact(answer, facts.check)) {
    return reply(200, {
      answer: "I can only tell you what is saved in MediTech. Please ask again with a medicine or reservation.",
    });
  }
  return reply(200, { answer });
});

// Read medicines, offers, and this customer's reservations. Nothing is written.
async function loadFacts(server: ReturnType<typeof createClient>, userId: string, message: string) {
  const words = message
    .toLowerCase()
    .split(/[^a-z0-9]+/)
    .filter((word) => word.length > 3 && !["where", "find", "medicine", "pharmacy", "price", "with", "your", "have", "does"].includes(word))
    .slice(0, 3);

  let medicines: { id: string; brand_name: string; generic_name: string; strength: string }[] = [];
  if (words.length > 0) {
    const filter = words
      .map((word) => `brand_name.ilike.%${word}%,generic_name.ilike.%${word}%`)
      .join(",");
    const { data } = await server
      .from("medicines")
      .select("id, brand_name, generic_name, strength")
      .eq("status", "active")
      .or(filter)
      .limit(5);
    medicines = data ?? [];
  }

  const medicineIds = medicines.map((medicine) => medicine.id);
  const { data: offers } = medicineIds.length === 0
    ? { data: [] }
    : await server
      .from("public_availability")
      .select("medicine_id, branch_id, price_per_unit, availability")
      .in("medicine_id", medicineIds)
      .limit(10);

  const branchIds = [...new Set((offers ?? []).map((offer) => offer.branch_id))];
  const { data: branches } = branchIds.length === 0
    ? { data: [] }
    : await server.from("branches").select("id, pharmacy_name, branch_name").in("id", branchIds);

  const branchName = new Map((branches ?? []).map((branch) => [branch.id, `${branch.pharmacy_name} ${branch.branch_name}`]));
  const offerFacts = (offers ?? []).map((offer) => ({
    pharmacy: branchName.get(offer.branch_id) ?? "Pharmacy",
    price: money(offer.price_per_unit),
    availability: offer.availability,
  }));

  let reservations: { reference_no: string; status: string; total: string; pickup_code: string | null }[] = [];
  if (/reserv|pickup|reference/i.test(message)) {
    const { data: rows } = await server
      .from("reservations")
      .select("id, reference_no, status, total_amount")
      .eq("customer_id", userId)
      .order("submitted_at", { ascending: false })
      .limit(5);
    const ids = (rows ?? []).map((row) => row.id);
    const { data: codes } = ids.length === 0
      ? { data: [] }
      : await server.from("pickup_codes").select("reservation_id, code_suffix").in("reservation_id", ids);
    const codeByReservation = new Map((codes ?? []).map((code) => [code.reservation_id, code.code_suffix]));
    reservations = (rows ?? []).map((row) => ({
      reference_no: row.reference_no,
      status: row.status,
      total: money(row.total_amount),
      pickup_code: codeByReservation.get(row.id) ?? null,
    }));
  }

  const check: AiFacts = {
    prices: [...offerFacts.map((offer) => offer.price), ...reservations.map((row) => row.total)],
    referenceNumbers: reservations.map((row) => row.reference_no),
    pickupCodes: reservations.map((row) => row.pickup_code).filter((code): code is string => code != null),
  };

  return {
    check,
    forModel: {
      medicines: medicines.map((medicine) => ({
        brand_name: medicine.brand_name,
        generic_name: medicine.generic_name,
        strength: medicine.strength,
      })),
      offers: offerFacts,
      reservations,
    },
  };
}