import { Link } from "react-router-dom";

export default function NotFound() {
  return (
    <section>
      <h1 className="page-title">Page not found</h1>
      <div className="card"><p className="muted">That page doesn’t exist. <Link className="inline-link" to="/">Go to Home</Link></p></div>
    </section>
  );
}
