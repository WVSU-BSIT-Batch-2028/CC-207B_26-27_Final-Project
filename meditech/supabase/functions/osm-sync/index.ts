import { createClient } from "npm:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface OverpassElement {
  type: "node" | "way" | "relation";
  id: number;
  lat?: number;
  lon?: number;
  center?: { lat: number; lon: number };
  timestamp?: string;
  tags?: Record<string, string>;
}

const BBOX = "10.67,122.48,10.78,122.62";

const OVERPASS_MIRRORS = [
  "https://overpass-api.de/api/interpreter",
  "https://overpass.kumi.systems/api/interpreter",
  "https://overpass.private.coffee/api/interpreter",
];

const QUERY_PHARMACIES = `
[out:json][timeout:15];
(
  node["amenity"="pharmacy"](${BBOX});
  way["amenity"="pharmacy"](${BBOX});
);
out center tags;
`;

const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
const MIRROR_ATTEMPTS = 2;
const MIRROR_RETRY_DELAY_MS = 2_000;

function reply(status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

function formatAddress(tags: Record<string, string>): string {
  const parts = [
    tags["addr:housenumber"] && tags["addr:street"]
      ? `${tags["addr:housenumber"]} ${tags["addr:street"]}`
      : tags["addr:street"],
    tags["addr:suburb"] || tags["addr:barangay"] || tags["addr:quarter"],
    tags["addr:city"] || "Iloilo City",
  ].filter(Boolean);

  return parts.length > 0 ? parts.join(", ") : "Iloilo City";
}

function formatLastEdited(iso?: string): string | null {
  if (!iso || iso.length < 7) return null;
  const year = iso.slice(0, 4);
  const monthIdx = Number(iso.slice(5, 7)) - 1;
  if (monthIdx < 0 || monthIdx > 11 || Number.isNaN(Number(year))) return null;
  return `${MONTHS[monthIdx]} ${year}`;
}

async function fetchFromMirror(
  mirror: string,
  query: string,
): Promise<OverpassElement[]> {
  const res = await fetch(mirror, {
    method: "POST",
    headers: {
      "Accept": "*/*",
      "Content-Type": "application/x-www-form-urlencoded",
      "User-Agent": "MediTechPharmacySync/1.0 (contact: admin@meditech.app)",
    },
    body: `data=${encodeURIComponent(query)}`,
    signal: AbortSignal.timeout(18_000),
  });

  if (!res.ok) {
    throw new Error(`${new URL(mirror).hostname}:HTTP_${res.status}`);
  }

  const payload = await res.json();
  if (!Array.isArray(payload?.elements)) {
    throw new Error(`${new URL(mirror).hostname}:INVALID_PAYLOAD`);
  }
  return payload.elements;
}

async function loadPharmacyElements(): Promise<OverpassElement[]> {
  const errors: string[] = [];

  for (let attempt = 0; attempt < MIRROR_ATTEMPTS; attempt++) {
    for (const mirror of OVERPASS_MIRRORS) {
      try {
        return await fetchFromMirror(mirror, QUERY_PHARMACIES);
      } catch (err) {
        const msg = err instanceof Error ? err.message : String(err);
        errors.push(msg);
      }
    }

    if (attempt + 1 < MIRROR_ATTEMPTS) {
      await new Promise((resolve) => setTimeout(resolve, MIRROR_RETRY_DELAY_MS));
    }
  }

  throw new Error(`All Overpass mirrors failed (${errors.join(" | ")})`);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: cors });
  }
  if (req.method !== "POST") {
    return reply(405, { error: "Use POST." });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !serviceKey) {
      return reply(500, { error: "Supabase sync configuration is missing." });
    }

    const authorization = req.headers.get("Authorization");
    if (!authorization?.startsWith("Bearer ")) {
      return reply(401, { error: "Sign in before syncing OpenStreetMap listings." });
    }
    const jwt = authorization.slice(7);

    const supabase = createClient(supabaseUrl, serviceKey, {
      auth: { persistSession: false },
    });

    const { data: userData, error: userError } = await supabase.auth.getUser(jwt);
    if (userError || !userData.user) {
      return reply(401, { error: "Sign in before syncing OpenStreetMap listings." });
    }

    const { data: account, error: accountError } = await supabase
      .from("accounts")
      .select("account_type, state")
      .eq("id", userData.user.id)
      .maybeSingle();

    if (
      accountError ||
      account?.account_type !== "admin" ||
      account?.state !== "active"
    ) {
      return reply(403, { error: "Only active administrators can sync listings." });
    }

    let elements: OverpassElement[] = [];
    try {
      const body = await req.json();
      if (Array.isArray(body?.elements)) {
        elements = body.elements;
      }
    } catch {
      // Ignore empty or non-JSON body
    }

    if (elements.length === 0) {
      try {
        elements = await loadPharmacyElements();
      } catch (e) {
        const msg = e instanceof Error ? e.message : "Overpass request failed.";
        return reply(502, {
          error: `Could not download pharmacy data from OpenStreetMap. ${msg}`,
        });
      }
    }

    const { data: existingRows, error: fetchError } = await supabase
      .from("osm_listings")
      .select("osm_id, status");

    if (fetchError) {
      return reply(500, { error: fetchError.message });
    }

    const existingStatus = new Map<string, string>(
      (existingRows ?? []).map((row) => [row.osm_id, row.status]),
    );

    const now = new Date().toISOString();
    const rowsToUpsert = [];

    for (const el of elements) {
      const lat = el.lat ?? el.center?.lat;
      const lon = el.lon ?? el.center?.lon;
      const name = el.tags?.name?.trim();
      if (lat == null || lon == null || !name) continue;

      const osmId = `${el.type}/${el.id}`;
      rowsToUpsert.push({
        osm_id: osmId,
        name,
        address: formatAddress(el.tags ?? {}),
        latitude: Number(lat.toFixed(6)),
        longitude: Number(lon.toFixed(6)),
        last_edited_there: formatLastEdited(el.timestamp),
        status: existingStatus.get(osmId) ?? "shown",
        synced_at: now,
      });
    }

    if (rowsToUpsert.length > 0) {
      const { error: upsertError } = await supabase
        .from("osm_listings")
        .upsert(rowsToUpsert, { onConflict: "osm_id" });

      if (upsertError) {
        return reply(500, { error: upsertError.message });
      }
    }

    return reply(200, {
      synced: rowsToUpsert.length,
      synced_at: now,
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : "Unexpected sync error.";
    return reply(500, { error: message });
  }
});