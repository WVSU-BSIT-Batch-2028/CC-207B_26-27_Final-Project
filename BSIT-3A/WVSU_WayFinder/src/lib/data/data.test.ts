import { afterEach, vi } from "vitest";

afterEach(() => {
  vi.unstubAllEnvs();
  vi.unstubAllGlobals();
  vi.resetModules();
});

async function load() {
  vi.resetModules();
  return import("./index");
}

describe("demo mode (no Supabase env)", () => {
  it("finds a known room with its building and floor, labeled demo", async () => {
    vi.stubEnv("VITE_SUPABASE_URL", "");
    vi.stubEnv("VITE_SUPABASE_ANON_KEY", "");
    const { searchPlaces } = await load();
    const r = await searchPlaces("cb 203");
    expect(r.mode).toBe("demo");
    expect(r.notice).toMatch(/DEMO/);
    expect(r.data).toHaveLength(1);
    expect(r.data[0].place.id).toBe("room-demo-cb-203");
    expect(r.data[0].place.floor).toBe(2);
    expect(r.data[0].parent?.name).toBe("Demo College Building");
  });

  it("returns no results for an unknown room", async () => {
    vi.stubEnv("VITE_SUPABASE_URL", "");
    const { searchPlaces } = await load();
    expect((await searchPlaces("zz 999")).data).toEqual([]);
  });

  it("uses the same place ID for search and detail lookups", async () => {
    vi.stubEnv("VITE_SUPABASE_URL", "");
    const { searchPlaces, getPlace } = await load();
    const id = (await searchPlaces("CB203")).data[0].place.id;
    expect((await getPlace(id)).data?.place.roomCode).toBe("CB203");
  });
});

describe("live mode (Supabase env set, fetch mocked)", () => {
  const env = () => {
    vi.stubEnv("VITE_SUPABASE_URL", "https://example.supabase.co");
    vi.stubEnv("VITE_SUPABASE_ANON_KEY", "anon-key");
  };

  it("queries PostgREST for verified rows by normalized room code", async () => {
    env();
    const fetchMock = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => [
        { id: "room-cb-203", kind: "room", name: "CB 203", short_name: null, room_code: "CB203", floor: 2, parent_id: "bldg-cb",
          lng: null, lat: null, status: "verified", source: "x", parent: { id: "bldg-cb", kind: "building", name: "CB", short_name: null, room_code: null, floor: null, parent_id: null, lng: 1, lat: 2, status: "verified", source: null } },
      ],
    });
    vi.stubGlobal("fetch", fetchMock);
    const { searchPlaces } = await load();
    const r = await searchPlaces("cb 203");
    const calledUrl = fetchMock.mock.calls[0][0] as string;
    expect(calledUrl).toContain("/rest/v1/places?");
    expect(calledUrl).toContain("status=eq.verified");
    expect(calledUrl).toContain("room_code=eq.CB203");
    expect(fetchMock.mock.calls[0][1].headers.apikey).toBe("anon-key");
    expect(r.mode).toBe("live");
    expect(r.notice).toBeUndefined();
    expect(r.data[0].parent?.lat).toBe(2);
  });

  it("an empty live result stays empty (never padded with demo data)", async () => {
    env();
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue({ ok: true, json: async () => [] }));
    const { searchPlaces } = await load();
    const r = await searchPlaces("cb 203");
    expect(r.mode).toBe("live");
    expect(r.data).toEqual([]);
  });

  it("a failed request (HTTP 500) rejects: live mode never substitutes demo records", async () => {
    env();
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue({ ok: false, status: 500 }));
    const { searchPlaces } = await load();
    await expect(searchPlaces("cb 203")).rejects.toThrow(/500/);
  });

  it("a network error rejects the same way", async () => {
    env();
    vi.stubGlobal("fetch", vi.fn().mockRejectedValue(new TypeError("Failed to fetch")));
    const { searchPlaces } = await load();
    await expect(searchPlaces("cb 203")).rejects.toThrow();
  });
});

describe("faculty live query (public.faculty_directory)", () => {
  const env = () => {
    vi.stubEnv("VITE_SUPABASE_URL", "https://example.supabase.co");
    vi.stubEnv("VITE_SUPABASE_ANON_KEY", "anon-key");
  };

  it("reads faculty_directory with named columns, published rows only", async () => {
    env();
    const fetchMock = vi.fn().mockResolvedValue({ ok: true, json: async () => [{ record_id: "rec-42", full_name: "Prof. Real Name", college_unit: "College of ICT", college_code: "CICT", department: "Computing", position_title: "Instructor I" }] });
    vi.stubGlobal("fetch", fetchMock);
    const { searchFaculty } = await load();
    const r = await searchFaculty("real");
    const url = decodeURIComponent(fetchMock.mock.calls[0][0] as string);
    expect(url).toContain("/rest/v1/faculty_directory?select=record_id,full_name,college_unit,college_code,department,position_title&is_published=eq.true&review_status=eq.verified");
    expect(url).toContain("full_name=ilike.*real*");
    expect(url).not.toMatch(/select=\*/);
    expect(url).not.toMatch(/\/rest\/v1\/faculty\?/);
    expect(r.mode).toBe("live");
    expect(r.data[0]).toMatchObject({ id: "rec-42", fullName: "Prof. Real Name", collegeUnit: "College of ICT", collegeCode: "CICT", department: "Computing", positionTitle: "Instructor I", isDemo: false });
    expect(r.data[0].office).toBeUndefined(); // no office column known: card says "Office location unconfirmed"
  });

  it("a failed request rejects: no demo faculty in live mode", async () => {
    env();
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue({ ok: false, status: 404 }));
    const { searchFaculty } = await load();
    await expect(searchFaculty("")).rejects.toThrow(/404/);
  });
});

describe("processes and campus paths live queries", () => {
  const env = () => {
    vi.stubEnv("VITE_SUPABASE_URL", "https://example.supabase.co");
    vi.stubEnv("VITE_SUPABASE_ANON_KEY", "anon-key");
  };

  it("processes: published + verified only, steps and requirements ordered by position", async () => {
    env();
    const fetchMock = vi.fn().mockResolvedValue({ ok: true, json: async () => [{
      id: "proc-x", name: "Enrollment", summary: null, before_you_start: null,
      process_requirements: [{ position: 2, kind: "document", text: "B" }, { position: 1, kind: "document", text: "A" }],
      process_steps: [{ position: 2, office_place_id: null, title: "Cashier", action: "Pay" }, { position: 1, office_place_id: "office-reg", title: "Registrar", action: "Submit" }],
    }] });
    vi.stubGlobal("fetch", fetchMock);
    const { listProcesses } = await load();
    const r = await listProcesses("");
    const url = decodeURIComponent(fetchMock.mock.calls[0][0] as string);
    expect(url).toContain("/rest/v1/processes?select=id,name,summary,before_you_start,process_requirements(");
    expect(url).toContain("is_published=eq.true&status=eq.verified");
    expect(r.data[0].requirements.map((x) => x.text)).toEqual(["A", "B"]);
    expect(r.data[0].steps.map((x) => x.title)).toEqual(["Registrar", "Cashier"]);
    expect(r.data[0].steps[1].officePlaceId).toBeUndefined();
  });

  it("campus paths: every table filtered to verified rows", async () => {
    env();
    const fetchMock = vi.fn().mockResolvedValue({ ok: true, json: async () => [] });
    vi.stubGlobal("fetch", fetchMock);
    const { getCampusPaths } = await load();
    await getCampusPaths();
    const urls = fetchMock.mock.calls.map((c) => decodeURIComponent(c[0] as string));
    for (const t of ["entrances", "walk_nodes", "walk_edges", "floor_plans"]) {
      expect(urls.find((u) => u.includes(`/rest/v1/${t}?`))).toContain("status=eq.verified");
    }
  });

  it("a missing table (404) rejects so the UI can show Retry", async () => {
    env();
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue({ ok: false, status: 404 }));
    const { listProcesses } = await load();
    await expect(listProcesses("")).rejects.toThrow(/404/);
  });
});
