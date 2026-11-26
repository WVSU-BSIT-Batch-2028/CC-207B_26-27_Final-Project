import { Link } from "react-router-dom";
import { mappableOfficeId } from "../lib/faculty";
import type { Faculty } from "../lib/types";
import { PinIcon } from "./Icons";
import { DataBadge } from "./PlaceCard";

/** Compact teacher row for the directory list. */
export function FacultyRow({ faculty: f, active }: { faculty: Faculty; active?: boolean }) {
  return (
    <Link to={`/directory/faculty/${encodeURIComponent(f.id)}`} className={`card dir-row${active ? " active" : ""}`} aria-label={f.fullName}>
      <span className="kind">Faculty{f.collegeCode ? ` · ${f.collegeCode}` : ""}</span>
      <span className="place-name">{f.fullName}</span>
      {(f.positionTitle || f.department) && <span className="muted small">{[f.positionTitle, f.department].filter(Boolean).join(" · ")}</span>}
    </Link>
  );
}

/** Full teacher details. "Show on map" only when a verified office link exists. */
export default function FacultyCard({ faculty: f }: { faculty: Faculty }) {
  const mapId = mappableOfficeId(f);
  return (
    <article className="card place-card" aria-label={f.fullName}>
      <div className="card-head">
        <span className="kind">Faculty</span>
        <DataBadge status={f.isDemo ? "demo" : "verified"} />
      </div>
      <h1 className="place-name detail-name">{f.fullName}</h1>
      <dl className="facts">
        {f.positionTitle && <div><dt>Position</dt><dd>{f.positionTitle}</dd></div>}
        {f.department && <div><dt>Dept.</dt><dd>{f.department}</dd></div>}
        {f.collegeUnit && <div><dt>College</dt><dd>{f.collegeUnit}{f.collegeCode ? ` (${f.collegeCode})` : ""}</dd></div>}
        {f.office && <div><dt>Office</dt><dd>{[f.office.name, f.office.parent?.name, f.office.floor !== undefined ? `Floor ${f.office.floor}` : null].filter(Boolean).join(" · ")}</dd></div>}
      </dl>
      {mapId ? (
        <div className="actions"><Link className="btn primary" to={`/map?to=${encodeURIComponent(mapId)}`}><PinIcon /> Show on map</Link></div>
      ) : (
        <p className="tbc" role="note">Office location unconfirmed</p>
      )}
    </article>
  );
}
