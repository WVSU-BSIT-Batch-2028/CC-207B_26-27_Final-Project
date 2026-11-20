import { useMemo, useState } from "react";
import type { PlaceView } from "../../lib/types";

/** Choose a starting building or room (indoors, poor GPS, or no permission). */
export default function StartPicker({ places, onPick, onClose }: { places: PlaceView[]; onPick: (id: string) => void; onClose: () => void }) {
  const [q, setQ] = useState("");
  const usable = useMemo(
    () => places.filter((v) => v.place.kind === "building" || v.place.kind === "room" || v.place.kind === "office")
      .filter((v) => (v.place.lng !== undefined || v.parent?.lng !== undefined) || v.place.kind === "building")
      .filter((v) => `${v.place.name} ${v.place.roomCode ?? ""} ${v.parent?.name ?? ""}`.toLowerCase().includes(q.trim().toLowerCase())),
    [places, q],
  );
  return (
    <div className="sheet-backdrop" onClick={onClose}>
      <div className="sheet" role="dialog" aria-modal="true" aria-label="Choose starting point" onClick={(e) => e.stopPropagation()}>
        <div className="sheet-head">
          <h2>Choose starting point</h2>
          <button className="link-btn" onClick={onClose}>Close</button>
        </div>
        <input className="sheet-search" value={q} onChange={(e) => setQ(e.target.value)} placeholder="Building, room code or office" aria-label="Filter starting points" autoFocus />
        {usable.length === 0 && <p className="muted">No building or room with a recorded location is available yet.</p>}
        <ul className="pick-list">
          {usable.map((v) => (
            <li key={v.place.id}>
              <button onClick={() => onPick(v.place.id)}>
                <strong>{v.place.roomCode ?? v.place.name}</strong>
                <span className="muted small">{v.place.roomCode ? v.place.name : v.place.kind}{v.parent ? ` · ${v.parent.name}` : ""}</span>
              </button>
            </li>
          ))}
        </ul>
      </div>
    </div>
  );
}
