import { useState, type FormEvent } from "react";
import { Link, useNavigate, useSearchParams } from "react-router-dom";
import { DocIcon, SearchIcon } from "../../components/Icons";
import LoadError from "../../components/LoadError";
import Notice from "../../components/Notice";
import { listProcesses } from "../../lib/data";
import { useAsync } from "../../lib/usePlaces";

export default function ProcessListPage() {
  const [params] = useSearchParams();
  const q = params.get("q") ?? "";
  const [value, setValue] = useState(q);
  const navigate = useNavigate();
  const res = useAsync(`proc:${q}`, () => listProcesses(q));

  function submit(e: FormEvent) {
    e.preventDefault();
    navigate(value.trim() ? `/processes?q=${encodeURIComponent(value.trim())}` : "/processes");
  }

  return (
    <section>
      <h1 className="page-title">What do you need to process?</h1>
      <p className="muted">Clear steps for common student transactions.</p>
      <form className="searchbar" role="search" onSubmit={submit}>
        <SearchIcon />
        <input type="search" value={value} onChange={(e) => setValue(e.target.value)} placeholder="Search student processes" aria-label="Search student processes" />
      </form>
      {res.state === "loading" && <p className="muted" role="status">Loading…</p>}
      {res.state === "error" && <LoadError what="process guides" onRetry={res.reload} />}
      {res.state === "done" && (
        <>
          {res.result.notice && <Notice>{res.result.notice}</Notice>}
          {res.result.data.length === 0 && (
            <div className="card empty" role="status">
              <h2>{q ? `No guide matches “${q}”` : "No process guides published yet"}</h2>
              <p className="muted">Only guides verified by the university are shown. Ask the office directly, or try <Link className="inline-link" to="/directory">the Directory</Link>.</p>
            </div>
          )}
          <div className="list-grid">
            {res.result.data.map((p) => (
              <Link key={p.id} to={`/processes/${p.id}`} className="card proc-row">
                <span className="proc-icon"><DocIcon /></span>
                <span className="proc-text">
                  <strong className="place-name">{p.name}</strong>
                  <span className="muted small">{p.steps.length} steps{p.isDemo ? " · Demo" : ""}</span>
                </span>
                <span aria-hidden>›</span>
              </Link>
            ))}
          </div>
        </>
      )}
    </section>
  );
}
