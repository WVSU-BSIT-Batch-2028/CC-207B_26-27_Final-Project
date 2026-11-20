import { Link, useParams } from "react-router-dom";
import { CheckIcon, DocIcon, PinIcon } from "../../components/Icons";
import LoadError from "../../components/LoadError";
import Notice from "../../components/Notice";
import { DataBadge } from "../../components/PlaceCard";
import { getProcess } from "../../lib/data";
import { progressStore, useProgress } from "../../lib/progress";
import { useAsync } from "../../lib/usePlaces";

export default function ProcessDetailPage() {
  const { processId = "" } = useParams();
  const res = useAsync(processId, () => getProcess(processId));
  const done = useProgress(processId);

  if (res.state === "loading") return <p className="muted" role="status">Loading…</p>;
  if (res.state === "error") return <section><Link to="/processes" className="back">← Processes</Link><LoadError what="this guide" onRetry={res.reload} /></section>;
  const p = res.result.data;
  if (!p) return <section><Link to="/processes" className="back">← Processes</Link><div className="card empty"><h2>Guide not available</h2><p className="muted">It may not be published yet.</p></div></section>;

  const docs = p.requirements.filter((r) => r.kind === "document");
  const notes = p.requirements.filter((r) => r.kind === "note");
  const current = p.steps.find((s) => !done.includes(s.position));
  const pct = p.steps.length ? Math.round((done.length / p.steps.length) * 100) : 0;

  return (
    <section className="process-detail">
      <Link to="/processes" className="back">← Processes</Link>
      <p className="eyebrow">STUDENT PROCESS</p>
      <div className="title-row"><h1 className="page-title">{p.name}</h1><DataBadge status={p.isDemo ? "demo" : "verified"} /></div>
      {p.summary && <p className="muted">{p.summary}</p>}
      {res.result.notice && <Notice>{res.result.notice}</Notice>}

      <div className="process-grid">
        <div>
          <article className="card before">
            <div className="card-head"><span className="kind"><DocIcon /> Before you start</span></div>
            {p.beforeYouStart && <p>{p.beforeYouStart}</p>}
            {notes.map((n) => <p key={n.position}>{n.text}</p>)}
            <h3 className="sub-label">Required documents</h3>
            {docs.length ? <ul className="dots">{docs.map((d) => <li key={d.position}>{d.text}</li>)}</ul> : <p className="muted small">No documents listed.</p>}
          </article>
        </div>
        <div>
          <div className="card progress-card" aria-label="Progress">
            <span><strong>{done.length} of {p.steps.length}</strong> steps completed</span>
            <span className="bar"><span style={{ width: `${pct}%` }} /></span>
          </div>
          <ol className="steps">
            {p.steps.map((s) => {
              const isDone = done.includes(s.position);
              const isCurrent = current?.position === s.position;
              return (
                <li key={s.position} className={`step${isDone ? " done" : ""}${isCurrent ? " current" : ""}`}>
                  <span className="step-dot">{isDone ? <CheckIcon /> : s.position}</span>
                  <div className={isCurrent ? "card step-card" : "step-card plain"}>
                    <div className="card-head">
                      <span className="step-no">STEP {s.position}</span>
                      {isCurrent && <span className="badge current-badge">Current</span>}
                      {isDone && <span className="badge verified">Done</span>}
                    </div>
                    <strong className="place-name">{s.title}</strong>
                    <p className="muted">{s.action}</p>
                    <div className="actions">
                      {s.officePlaceId ? (
                        <Link className={isCurrent ? "btn primary" : "btn ghost"} to={`/map?to=${encodeURIComponent(s.officePlaceId)}`}><PinIcon /> Show office on map</Link>
                      ) : (
                        <span className="tbc small-tbc">Office location unconfirmed</span>
                      )}
                      <button className="btn ghost" onClick={() => progressStore.toggle(p.id, s.position)} aria-pressed={isDone}>
                        {isDone ? "Mark not done" : "Mark step complete"}
                      </button>
                    </div>
                  </div>
                </li>
              );
            })}
          </ol>
          {done.length > 0 && <button className="link-btn" onClick={() => progressStore.reset(p.id)}>Reset progress</button>}
        </div>
      </div>

      {current ? (
        <div className="next-step-bar" role="region" aria-label="Next step">
          <div>
            <span className="eyebrow">NEXT STEP</span>
            <strong className="place-name">{current.title}</strong>
            <span className="muted small">{current.action}</span>
          </div>
          <div className="next-step-actions">
            {current.officePlaceId && <Link className="btn gold" to={`/map?to=${encodeURIComponent(current.officePlaceId)}`}>Take me there</Link>}
            <button className="btn ghost" onClick={() => progressStore.toggle(p.id, current.position)}><CheckIcon /> Mark step complete</button>
          </div>
        </div>
      ) : (
        <Notice tone="info">All steps completed. 🎉</Notice>
      )}
    </section>
  );
}
