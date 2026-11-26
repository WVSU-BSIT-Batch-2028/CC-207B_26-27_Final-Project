import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter } from "react-router-dom";
import { afterEach, vi } from "vitest";

afterEach(() => {
  vi.unstubAllEnvs();
  vi.unstubAllGlobals();
  vi.resetModules();
});

const placeRow = { id: "bldg-v", kind: "building", name: "Verified Building", short_name: null, room_code: null, floor: null,
  parent_id: null, lng: 122.5, lat: 10.7, status: "verified", source: "s", parent: null };

async function renderLive(fetchImpl: (url: string) => unknown) {
  vi.stubEnv("VITE_SUPABASE_URL", "https://example.supabase.co");
  vi.stubEnv("VITE_SUPABASE_ANON_KEY", "anon-key");
  const fetchMock = vi.fn(async (url: string) => fetchImpl(url));
  vi.stubGlobal("fetch", fetchMock);
  vi.resetModules();
  const { default: DirectoryPage } = await import("./DirectoryPage");
  render(<MemoryRouter><DirectoryPage /></MemoryRouter>);
  return fetchMock;
}

const ok = (body: unknown) => ({ ok: true, status: 200, json: async () => body });

describe("Directory in live mode", () => {
  it("200 with [] shows 'No verified faculty profiles yet.' and no demo records", async () => {
    await renderLive((url) => ok(url.includes("/faculty") ? [] : [placeRow]));
    expect(await screen.findByText("No verified faculty profiles yet.")).toBeInTheDocument();
    expect(await screen.findByText("Verified Building")).toBeInTheDocument();
    expect(screen.queryByText(/Demo/)).not.toBeInTheDocument();
  });

  it("faculty request fails: shows Retry, keeps the places directory, no demo records", async () => {
    let facultyUp = false;
    await renderLive((url) =>
      url.includes("/faculty") ? (facultyUp ? ok([]) : { ok: false, status: 404 }) : ok([placeRow]),
    );
    expect(await screen.findByRole("alert")).toHaveTextContent(/Couldn’t load faculty profiles/);
    expect(await screen.findByText("Verified Building")).toBeInTheDocument();
    expect(screen.queryByText(/Demo/)).not.toBeInTheDocument();

    facultyUp = true;
    await userEvent.click(screen.getByRole("button", { name: "Retry" }));
    expect(await screen.findByText("No verified faculty profiles yet.")).toBeInTheDocument();
    expect(screen.queryByRole("alert")).not.toBeInTheDocument();
  });

  it("places request fails but faculty works: faculty stays visible with its own Retry for places", async () => {
    await renderLive((url) => (url.includes("/faculty") ? ok([]) : { ok: false, status: 500 }));
    expect(await screen.findByText("No verified faculty profiles yet.")).toBeInTheDocument();
    expect(await screen.findByRole("alert")).toHaveTextContent(/buildings, rooms and offices/);
  });
});
