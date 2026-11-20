// @vitest-environment node
// Applies 0001-0005 in an in-process Postgres (PGlite) with stand-ins for Supabase's auth/storage
// schemas, then checks the access rules. This proves the SQL, not that it is applied to the live project.
import { PGlite } from "@electric-sql/pglite";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { beforeAll, describe, expect, it } from "vitest";

const sql = (f: string) => readFileSync(join(process.cwd(), "supabase/migrations", f), "utf8");
let db: PGlite;
const A = "00000000-0000-0000-0000-00000000000a";
const B = "00000000-0000-0000-0000-00000000000b";

beforeAll(async () => {
  db = new PGlite();
  await db.exec(`
    create role anon nologin; create role authenticated nologin; create role service_role nologin bypassrls;
    grant usage on schema public to anon, authenticated, service_role;
    create schema auth; create table auth.users (id uuid primary key);
    create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('test.uid', true), '')::uuid $$;
    grant usage on schema auth to anon, authenticated; grant execute on function auth.uid() to anon, authenticated;
    create schema storage;
    create table storage.buckets (id text primary key, name text, public boolean, file_size_limit bigint, allowed_mime_types text[]);
    create table storage.objects (id serial primary key, bucket_id text, name text);
    alter table storage.objects enable row level security;
    create function storage.foldername(name text) returns text[] language sql immutable as $$ select string_to_array(name, '/') $$;
    grant usage on schema storage to authenticated; grant all on storage.objects to authenticated; grant usage, select on all sequences in schema storage to authenticated;
    insert into auth.users values ('${A}'), ('${B}');
  `);
  for (const f of ["0001_places.sql", "0002_faculty.sql", "0003_schedule.sql", "0004_processes.sql", "0005_campus_paths.sql"]) await db.exec(sql(f));
  await db.exec(`grant select on public.places to anon, authenticated;`);
  await db.exec(`
    insert into places (id, kind, name, status, source, verified_by, verified_at) values ('office-reg', 'office', 'Registrar', 'verified', 's', 'v', now());
    insert into processes (id, name, is_published, status, source, verified_by, verified_at) values
      ('p-pub', 'Published', true, 'verified', 's', 'v', now()), ('p-draft', 'Draft', false, 'verified', 's', 'v', now());
    insert into processes (id, name, is_published, status) values ('p-unv', 'Unverified', true, 'unverified');
    insert into process_steps values ('p-pub', 1, 'office-reg', 'Registrar', 'Submit'), ('p-draft', 1, 'office-reg', 'Registrar', 'Secret');
    insert into walk_nodes values ('n1', 1, 1, 'verified'), ('n2', 1, 2, 'unverified');
  `);
});

async function as<T>(role: string, uid: string | null, q: string) {
  await db.exec(`set role ${role}; select set_config('test.uid', '${uid ?? ""}', false);`);
  try { return (await db.query<T>(q)).rows; } finally { await db.exec("reset role"); }
}

describe("processes", () => {
  it("students see only published + verified guides and their steps", async () => {
    expect(await as<{ id: string }>("anon", null, "select id from processes order by id")).toEqual([{ id: "p-pub" }]);
    expect(await as<{ action: string }>("anon", null, "select action from process_steps")).toEqual([{ action: "Submit" }]);
  });
  it("a verified guide needs a source", async () => {
    await expect(db.exec("insert into processes (id, name, status) values ('x', 'x', 'verified')")).rejects.toThrow(/processes_verified_requires_source/);
  });
});

describe("walkways", () => {
  it("only verified nodes are readable", async () => {
    expect(await as<{ id: string }>("anon", null, "select id from walk_nodes")).toEqual([{ id: "n1" }]);
  });
});

describe("private schedules", () => {
  it("each student sees only their own classes; anon sees nothing", async () => {
    await as("authenticated", A, "insert into class_sessions (subject, weekday, start_time, end_time, room_code_raw) values ('Mine', 1, '08:00', '09:00', 'CB 203')");
    await as("authenticated", B, "insert into class_sessions (subject, weekday, start_time, end_time, room_code_raw) values ('Theirs', 2, '10:00', '11:00', 'GYM-X')");
    expect(await as<{ subject: string }>("authenticated", A, "select subject from class_sessions")).toEqual([{ subject: "Mine" }]);
    await expect(as("anon", null, "select * from class_sessions")).rejects.toThrow(/permission denied/);
  });
  it("can't write a row for someone else, and times are Asia/Manila only", async () => {
    await expect(as("authenticated", A, `insert into class_sessions (user_id, subject, weekday, start_time, end_time, room_code_raw) values ('${B}', 'x', 1, '08:00', '09:00', 'x')`)).rejects.toThrow(/row-level security/);
    await expect(as("authenticated", A, "insert into class_sessions (subject, weekday, start_time, end_time, room_code_raw, tz) values ('x', 1, '08:00', '09:00', 'x', 'UTC')")).rejects.toThrow(/check/);
  });
  it("schedule images: only inside the owner's folder", async () => {
    await as("authenticated", A, `insert into storage.objects (bucket_id, name) values ('schedule-images', '${A}/t.jpg')`);
    await expect(as("authenticated", A, `insert into storage.objects (bucket_id, name) values ('schedule-images', '${B}/t.jpg')`)).rejects.toThrow(/row-level security/);
    expect(await as("authenticated", B, "select name from storage.objects")).toEqual([]);
  });
});
