import { useSearchParams } from "react-router-dom";
import SearchBar from "../../components/SearchBar";
import PlaceCard from "../../components/PlaceCard";
import LoadError from "../../components/LoadError";
import Notice from "../../components/Notice";
import { searchPlaces } from "../../lib/data";
import { useAsync } from "../../lib/usePlaces";

export default function SearchPage() {
  const [params] = useSearchParams();
  const q = params.get("q") ?? "";
  const res = useAsync(q, () => searchPlaces(q));

  return (
    <section>
      <h1 className="page-title">Search</h1>
      {/* key remounts the bar so it always shows exactly what the student typed */}
      <SearchBar key={q} initial={q} autoFocus={!q} />

      {!q.trim() && <p className="muted">Type a room code like CB 203, or an office or building name.</p>}
      {q.trim() && res.state === "loading" && <p className="muted" role="status">Searching…</p>}

      {q.trim() && res.state === "error" && <LoadError what="search results" onRetry={res.reload} />}

      {res.state === "done" && (
        <>
          {res.result.notice && <Notice>{res.result.notice}</Notice>}
          {q.trim() && res.result.data.length === 0 && (
            <div className="card empty" role="status">
              <h2>No match for “{q}”</h2>
              <p className="muted">
                We don’t have {res.result.mode === "live" ? "a verified place" : "a demo record"} with that code or name.
                Check the spelling, or try another search above.
              </p>
            </div>
          )}
          {res.result.data.map((v) => <PlaceCard key={v.place.id} view={v} />)}
        </>
      )}
    </section>
  );
}
