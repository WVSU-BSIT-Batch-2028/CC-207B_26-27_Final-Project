import { useState, type FormEvent } from "react";
import { Link, Outlet, useLocation, useNavigate, useSearchParams } from "react-router-dom";
import { FacultyRow } from "../../components/FacultyCard";
import { SearchIcon } from "../../components/Icons";
import LoadError from "../../components/LoadError";
import Notice from "../../components/Notice";
import { listPlaces, searchFaculty } from "../../lib/data";
import { useAsync } from "../../lib/usePlaces";

const CATEGORIES = [
  { id: "all", label: "All" },
  { id: "faculty", label: "Faculty" },
  { id: "building", label: "Buildings" },
  { id: "room", label: "Rooms" },
  { id: "office", label: "Offices" },
  { id: "college", label: "Colleges" },
] as const;
type Cat = (typeof CATEGORIES)[number]["id"];

/** Directory list + (on desktop) the selected item's details beside it. */
export default function DirectoryPage() {
  const [params] = useSearchParams();
  const { pathname } = useLocation();
  const q = params.get("q") ?? "";
  const cat = (params.get("cat") as Cat) ?? "all";
  const [value, setValue] = useState(q);
  const navigate = useNavigate();
  const faculty = useAsync(`fac:${q}`, () => searchFaculty(q));
  const places = useAsync("list", listPlaces);
  const detailOpen = pathname !== "/directory" && pathname !== "/directory/";

  const go = (next: { q?: string; cat?: Cat }) => {
    const p = new URLSearchParams();
    const nq = next.q ?? q;
    const nc = next.cat ?? cat;
    if (nq) p.set("q", nq);
    if (nc !== "all") p.set("cat", nc);
    navigate(`/directory${p.size ? `?${p}` : ""}`);
  };

  const submit = (e: FormEvent) => { e.preventDefault(); go({ q: value.trim() }); };
  const needle = q.trim().toLowerCase();
  const placeRows = places.state === "done"
    ? places.result.data.filter(({ place }) => (cat === "all" || place.kind === cat) &&
        (!needle || `${place.name} ${place.roomCode ?? ""} ${place.shortName ?? ""}`.toLowerCase().includes(needle)))
    : [];
  const showFaculty = cat === "all" || cat === "faculty";
  const showPlaces = cat !== "faculty";
  const qs = params.size ? `?${params}` : "";

  return (
    <section className={`directory${detailOpen ? " detail-open" : ""}`}>
      <div className="dir-list">
        <h1 className="page-title">Directory</h1>
        <p className="muted">Teachers, buildings, rooms and offices.</p>
        <form className="searchbar" role="search" onSubmit={submit}>
          <SearchIcon />
          <input type="search" value={value} onChange={(e) => setValue(e.target.value)} placeholder="Search teachers, rooms, offices" aria-label="Search the directory" enterKeyHint="search" />
        </form>
        <div className="chips" role="tablist" aria-label="Categories">
          {CATEGORIES.map((c) => (
            <button key={c.id} role="tab" aria-selected={cat === c.id} className={`chip${cat === c.id ? " on" : ""}`} onClick={() => go({ cat: c.id })}>{c.label}</button>
          ))}
        </div>

        {showFaculty && (
          <>
            <h2 className="section-label">Faculty</h2>
            {faculty.state === "loading" && <p className="muted" role="status">Loading…</p>}
            {faculty.state === "error" && <LoadError what="faculty profiles" onRetry={faculty.reload} />}
            {faculty.state === "done" && (
              <>
                {faculty.result.notice && <Notice>{faculty.result.notice}</Notice>}
                {faculty.result.data.length === 0 && (
                  <div className="card empty" role="status">
                    {q ? <><h2>No teacher matches “{q}”</h2><p className="muted">Check the spelling or try part of the name. Only verified profiles are shown.</p></>
                      : <h2>No verified faculty profiles yet.</h2>}
                  </div>
                )}
                {faculty.result.data.map((f) => <FacultyRow key={f.id} faculty={f} active={pathname === `/directory/faculty/${f.id}`} />)}
              </>
            )}
          </>
        )}

        {showPlaces && (
          <>
            <h2 className="section-label">{cat === "all" ? "Buildings, rooms and offices" : CATEGORIES.find((c) => c.id === cat)!.label}</h2>
            {places.state === "loading" && <p className="muted" role="status">Loading…</p>}
            {places.state === "error" && <LoadError what="buildings, rooms and offices" onRetry={places.reload} />}
            {places.state === "done" && placeRows.length === 0 && <div className="card empty" role="status"><h2>{q ? `No place matches “${q}”` : "No verified places yet."}</h2></div>}
            {placeRows.map(({ place, parent }) => (
              <Link key={place.id} to={`/directory/${place.id}${qs}`} className={`card dir-row${pathname === `/directory/${place.id}` ? " active" : ""}`}>
                <span className="kind">{place.kind}{place.roomCode ? ` · ${place.roomCode}` : ""}</span>
                <span className="place-name">{place.name}</span>
                {parent && <span className="muted small">{parent.name}</span>}
              </Link>
            ))}
          </>
        )}
      </div>
      <div className="dir-detail">
        {detailOpen ? <Outlet /> : <div className="card empty desktop-only"><h2>Select a teacher or place</h2><p className="muted">Details appear here.</p></div>}
      </div>
    </section>
  );
}
