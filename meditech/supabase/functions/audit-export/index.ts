// Build a CSV of audit records for a signed-in administrator
import { createClient } from "npm:@supabase/supabase-js@2";

const url = Deno.env.get("SUPABASE_URL")!;
const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

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

function csvCell(value: unknown) {
  const text = value == null ? "" : String(value);
  return `"${text.replaceAll('"', '""')}"`;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST" && req.method !== "GET") {
    return reply(405, { error: "Use GET or POST." });
  }

  const header = req.headers.get("Authorization");
  if (!header) return reply(401, { error: "Sign in before exporting." });

  const userClient = createClient(url, anonKey, {
    global: { headers: { Authorization: header } },
    auth: { persistSession: false },
  });
  const { data: userData, error: userError } = await userClient.auth.getUser();
  if (userError || !userData.user) return reply(401, { error: "Sign in before exporting." });

  const server = createClient(url, serviceKey, { auth: { persistSession: false } });
  const { data: account } = await server
    .from("accounts")
    .select("account_type")
    .eq("id", userData.user.id)
    .maybeSingle();
  if (account?.account_type !== "admin") {
    return reply(403, { error: "Only an administrator can export audit records." });
  }

  const { data: rows, error } = await server
    .from("audit_records")
    .select(
      "display_id, created_at, actor_label, actor_role, event_type, action, record_ref, details",
    )
    .order("created_at", { ascending: false })
    .limit(1000);
  if (error) return reply(500, { error: "Could not export the audit records." });

  const lines = [
    "display_id,created_at,actor_label,actor_role,event_type,action,record_ref,details",
    ...(rows ?? []).map((row) =>
      [
        csvCell(row.display_id),
        csvCell(row.created_at),
        csvCell(row.actor_label),
        csvCell(row.actor_role),
        csvCell(row.event_type),
        csvCell(row.action),
        csvCell(row.record_ref),
        csvCell(JSON.stringify(row.details ?? {})),
      ].join(",")
    ),
  ];

  await server.rpc("log_audit", {
    p_actor_id: userData.user.id,
    p_actor_label: "Demo Admin",
    p_actor_role: "admin",
    p_event: "data_export",
    p_action: "Exported audit records as CSV",
    p_record_ref: "audit_records",
    p_details: { row_count: rows?.length ?? 0 },
  });

  return reply(200, { csv: lines.join("\n") });
});