// Sync OpenStreetMap pharmacy listings in the Iloilo area into osm_listings
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
  "https://lz4.overpass-api.de/api/interpreter",
  "https://overpass.kumi.systems/api/interpreter",
  "https://overpass.openstreetmap.ru/api/interpreter",
  "https://maps.mail.ru/osm/tools/overpass/api/interpreter",
];

// Full result (nodes + building outlines). Heavier — try after quick node-only pass.
const QUERY_FULL = `
[out:json][timeout:60];
(
  node["amenity"="pharmacy"](${BBOX});
  way["amenity"="pharmacy"](${BBOX});
);
out center meta;
`;

// Fast fallback when mirrors are overloaded (504)
const QUERY_NODES_ONLY = `
[out:json][timeout:30];
node["amenity"="pharmacy"](${BBOX});
out meta;
`;

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
  if (!iso) return null;
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return null;
  return date.toLocaleDateString("en-US", { month: "short", year: "numeric", timeZone: "UTC" });
}

const RETRYABLE_HTTP = new Set([408, 425, 429, 500, 502, 503, 504]);

async function sleep(ms: number) {
  await new Promise((resolve) => setTimeout(resolve, ms));
}

async function fetchOverpassOnce(
  mirror: string,
  query: string,
  timeoutMs: number,
): Promise<{ ok: true; elements: OverpassElement[] } | { ok: false; status: number }> {
  const res = await fetch(mirror, {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
      "User-Agent": "MediTech-OSM-Sync/1.1 (+https://meditech)",
    },
    body: `data=${encodeURIComponent(query)}`,
    signal: AbortSignal.timeout(timeoutMs),
  });

  if (!res.ok) {
    return { ok: false, status: res.status };
  }

  const payload = await res.json();
  const elements: OverpassElement[] = Array.isArray(payload?.elements)
    ? payload.elements
    : [];
  return { ok: true, elements };
}

async function runOverpassQuery(
  query: string,
  timeoutMs: number,
): Promise<OverpassElement[] | null> {
  let lastStatus = 0;

  for (const mirror of OVERPASS_MIRRORS) {
    for (let attempt = 0; attempt < 2; attempt++) {
      try {
        const result = await fetchOverpassOnce(mirror, query, timeoutMs);
        if (result.ok) {
          return result.elements;
        }
        lastStatus = result.status;
        if (!RETRYABLE_HTTP.has(result.status)) break;
        await sleep(1_500 * (attempt + 1));
      } catch {
        lastStatus = 408;
        await sleep(1_000);
      }
    }
  }

  if (lastStatus > 0) {
    throw new Error(`overpass_http_${lastStatus}`);
  }
  throw new Error("overpass_timeout");
}

async function loadPharmacyElements(): Promise<OverpassElement[]> {
  try {
    const full = await runOverpassQuery(QUERY_FULL, 90_000);
    if (full && full.length > 0) return full;
  } catch (e) {
    const msg = e instanceof Error ? e.message : "";
    if (!msg.startsWith("overpass_")) throw e;
  }

  const nodes = await runOverpassQuery(QUERY_NODES_ONLY, 45_000);
  return nodes ?? [];
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
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !anonKey || !serviceKey) {
      return reply(500, { error: "Supabase sync configuration is missing." });
    }

    const authorization = req.headers.get("Authorization");
    if (!authorization) {
      return reply(401, { error: "Sign in before syncing OpenStreetMap listings." });
    }

    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false },
    });
    const { data: userData, error: userError } = await userClient.auth.getUser();
    if (userError || !userData.user) {
      return reply(401, { error: "Sign in before syncing OpenStreetMap listings." });
    }

    const supabase = createClient(supabaseUrl, serviceKey, {
      auth: { persistSession: false },
    });
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

    let elements: OverpassElement[];
    try {
      elements = await loadPharmacyElements();
    } catch (e) {
      const raw = e instanceof Error ? e.message : "overpass_unknown";
      const code = raw.replace("overpass_http_", "").replace("overpass_", "");
      const hint =
        code === "504" || code === "timeout"
          ? "Overpass is busy. Wait a minute and try Sync OSM again."
          : "Could not download pharmacy data from OpenStreetMap.";
      return reply(502, {
        error: `${hint} (last HTTP ${code === "timeout" ? "timeout" : code}).`,
      });
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
    const rowsToUpsert = elements
      .map((el) => {
        const lat = el.lat ?? el.center?.lat;
        const lon = el.lon ?? el.center?.lon;
        const name = el.tags?.name?.trim();
        if (lat == null || lon == null || !name) return null;

        const osmId = `${el.type}/${el.id}`;
        return {
          osm_id: osmId,
          name,
          address: formatAddress(el.tags ?? {}),
          latitude: Number(lat.toFixed(6)),
          longitude: Number(lon.toFixed(6)),
          last_edited_there: formatLastEdited(el.timestamp),
          status: existingStatus.get(osmId) ?? "shown",
          synced_at: now,
        };
      })
      .filter((row): row is NonNullable<typeof row> => row !== null);

    if (rowsToUpsert.length > 0) {
      const { error: upsertError } = await (supabase.from("osm_listings") as any)
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