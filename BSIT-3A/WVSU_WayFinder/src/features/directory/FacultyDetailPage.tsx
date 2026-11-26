import { Link, useParams } from "react-router-dom";
import FacultyCard from "../../components/FacultyCard";
import LoadError from "../../components/LoadError";
import Notice from "../../components/Notice";
import { getFaculty } from "../../lib/data";
import { useAsync } from "../../lib/usePlaces";

export default function FacultyDetailPage() {
  const { recordId = "" } = useParams();
  const res = useAsync(`facd:${recordId}`, () => getFaculty(recordId));
  return (
    <div>
      <Link to="/directory" className="back mobile-only">← Directory</Link>
      {res.state === "loading" && <p className="muted" role="status">Loading…</p>}
      {res.state === "error" && <LoadError what="this profile" onRetry={res.reload} />}
      {res.state === "done" && (
        <>
          {res.result.notice && <Notice>{res.result.notice}</Notice>}
          {res.result.data ? <FacultyCard faculty={res.result.data} /> : <div className="card empty"><h2>Profile not available</h2><p className="muted">It may not be published or verified.</p></div>}
        </>
      )}
    </div>
  );
}
