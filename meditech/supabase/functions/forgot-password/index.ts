// Send a reset code, then save a new password after the code is checked
/// <reference path="./supabase-js.d.ts" />
import { createClient } from "npm:@supabase/supabase-js@2";

// This file runs on the Supabase Edge runtime. Declare the globals it uses so
// the editor's TypeScript checker recognizes them.
declare namespace Deno {
  export const env: {
    get(key: string): string | undefined;
  };
  export function serve(
    handler: (req: Request) => Response | Promise<Response>,
  ): void;
}

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

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return reply(405, { error: "Use POST." });

  const body = await req.json().catch(() => ({}));
  const action = String(body.action ?? "");
  const identifier = String(body.identifier ?? "").trim();
  if (!identifier) return reply(400, { error: "Enter your email or mobile number." });

  const server = createClient(url, serviceKey, { auth: { persistSession: false } });
  const { data: found } = await server.rpc("find_account_for_sign_in", { p_identifier: identifier });
  const account = found?.[0];
  const email = account?.account_type === "customer" ? account.email as string : null;

  // Always say a code was sent, so nobody can search for accounts
  if (action === "send") {
    if (email) {
      const sent = await fetch(`${url}/auth/v1/recover`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          apikey: anonKey,
          Authorization: `Bearer ${anonKey}`,
        },
        body: JSON.stringify({ email }),
      });
      if (!sent.ok) return reply(500, { error: "Could not send the code. Try again." });
    }
    return reply(200, { sent: true });
  }

  if (action !== "reset") return reply(400, { error: "Use send or reset." });

  const code = String(body.code ?? "").trim();
  const password = String(body.password ?? "");
  if (!email || !/^\d{6}$/.test(code) || password.length === 0) {
    return reply(400, { error: "That code is wrong or expired." });
  }

  const auth = createClient(url, anonKey, { auth: { persistSession: false } });
  const { error: codeError } = await auth.auth.verifyOtp({
    email,
    token: code,
    type: "recovery",
  });
  if (codeError) return reply(400, { error: "That code is wrong or expired." });

  const { error: saveError } = await auth.auth.updateUser({ password });
  if (saveError) return reply(400, { error: saveError.message });
  await auth.auth.signOut();
  return reply(200, { reset: true });
});