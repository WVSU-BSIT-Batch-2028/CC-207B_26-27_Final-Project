/** Shown when a live request fails. Never substitutes demo data. */
export default function LoadError({ what, onRetry }: { what: string; onRetry: () => void }) {
  return (
    <div className="notice warn" role="alert">
      <p style={{ margin: "0 0 8px" }}>Couldn’t load {what}. Check your connection and try again.</p>
      <button className="btn ghost" onClick={onRetry}>Retry</button>
    </div>
  );
}
