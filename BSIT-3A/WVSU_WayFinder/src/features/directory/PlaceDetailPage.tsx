import { Link, useParams } from "react-router-dom";
import LoadError from "../../components/LoadError";
import Notice from "../../components/Notice";
import { DataBadge, PlaceFacts } from "../../components/PlaceCard";
import { PinIcon } from "../../components/Icons";
import { getPlace } from "../../lib/data";
import { useAsync } from "../../lib/usePlaces";

export default function PlaceDetailPage() {
  const { placeId = "" } = useParams();
  const res = useAsync(placeId, () => getPlace(placeId));
  return (
    <div>
      <Link to="/directory" className="back mobile-only">← Directory</Link>
      {res.state === "loading" && <p className="muted" role="status">Loading…</p>}
      {res.state === "error" && <LoadError what="this place" onRetry={res.reload} />}
      {res.state === "done" && (
        <>
          {res.result.notice && <Notice>{res.result.notice}</Notice>}
          {!res.result.data ? (
            <div className="card empty"><h2>Place not found</h2><p className="muted">No place has the ID “{placeId}”.</p></div>
          ) : (
            <article className="card place-card">
              <div className="card-head"><span className="kind">{res.result.data.place.kind}</span><DataBadge status={res.result.data.place.status} /></div>
              <h1 className="place-name detail-name">{res.result.data.place.name}</h1>
              <PlaceFacts view={res.result.data} />
              <div className="actions"><Link className="btn primary" to={`/map?to=${res.result.data.place.id}`}><PinIcon /> Show on map</Link></div>
              <p className="muted small">Place ID: {res.result.data.place.id}</p>
            </article>
          )}
        </>
      )}
    </div>
  );
}
