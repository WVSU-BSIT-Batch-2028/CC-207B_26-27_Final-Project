// The editor's TypeScript checker does not know the Supabase Edge runtime.
// Deno still loads the real packages when these functions run.

declare namespace Deno {
  export const env: {
    get(key: string): string | undefined;
  };
  export function serve(
    handler: (req: Request) => Response | Promise<Response>,
  ): void;
  export function test(name: string, fn: () => void | Promise<void>): void;
}

type EdgeRow = Record<string, any> & {
  id: any;
  brand_name: any;
  generic_name: any;
  strength: any;
};

interface EdgeResult<T> {
  data: T;
  error: { message: string; code?: string } | null;
}

interface EdgeQuery extends PromiseLike<EdgeResult<EdgeRow[] | null>> {
  select(columns: string): EdgeQuery;
  eq(column: string, value: unknown): EdgeQuery;
  or(filters: string): EdgeQuery;
  in(column: string, values: readonly unknown[]): EdgeQuery;
  order(column: string, options?: { ascending?: boolean }): EdgeQuery;
  limit(count: number): EdgeQuery;
  maybeSingle(): Promise<EdgeResult<EdgeRow | null>>;
}

declare module "npm:@supabase/supabase-js@2" {
  export interface SupabaseClient {
    from(table: string): EdgeQuery;
    rpc(fn: string, args?: Record<string, unknown>): Promise<EdgeResult<any>>;
    auth: any;
    storage: any;
  }

  export function createClient(
    url: string,
    key: string,
    options?: {
      auth?: { persistSession?: boolean };
      global?: { headers?: Record<string, string> };
    },
  ): SupabaseClient;
}

declare module "jsr:@std/assert@1" {
  export function assertEquals<T>(actual: T, expected: T, msg?: string): void;
}
