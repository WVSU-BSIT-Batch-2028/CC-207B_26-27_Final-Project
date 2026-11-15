// Types for the Deno npm: import. The editor's checker cannot load that
// specifier; the Edge runtime still resolves the real package.
declare module "npm:@supabase/supabase-js@2" {
  export interface SupabaseClient {
    rpc(
      fn: string,
      args?: Record<string, unknown>,
    ): Promise<{
      data: Record<string, unknown>[] | null;
      error: { message: string } | null;
    }>;
    auth: {
      verifyOtp(credentials: {
        email: string;
        token: string;
        type: "recovery";
      }): Promise<{ error: { message: string } | null }>;
      updateUser(attributes: {
        password: string;
      }): Promise<{ error: { message: string } | null }>;
      signOut(): Promise<{ error: { message: string } | null }>;
    };
  }

  export function createClient(
    url: string,
    key: string,
    options?: { auth?: { persistSession?: boolean } },
  ): SupabaseClient;
}
