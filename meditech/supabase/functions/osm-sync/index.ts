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

function reply(status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

// Build a clean street/barangay address from OpenStreetMap tags
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

// Format ISO timestamp into "Mon YYYY" (e.g. "Mar 2025")
function formatLastEdited(iso?: string): string | null {
  if (!iso) return null;
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return null;
  return date.toLocaleDateString("en-US", { month: "short", year: "numeric", timeZone: "UTC" });
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

    // Query pharmacies in the Iloilo City bounding box from Overpass API
    const overpassQuery = `
      [out:json][timeout:25];
      (
        node["amenity"="pharmacy"](10.67,122.48,10.78,122.62);
        way["amenity"="pharmacy"](10.67,122.48,10.78,122.62);
      );
      out center meta;
    `;

    const response = await fetch("https://overpass-api.de/api/interpreter", {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
        "User-Agent": "MediTech-OSM-Sync/1.0",
      },
      body: `data=${encodeURIComponent(overpassQuery)}`,
      signal: AbortSignal.timeout(30_000),
    });

    if (!response.ok) {
      return reply(502, { error: "Could not reach OpenStreetMap Overpass API." });
    }

    const payload = await response.json();
    const elements: OverpassElement[] = Array.isArray(payload?.elements) ? payload.elements : [];

    // Fetch existing osm_ids so we keep admin hidden/replaced states intact
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