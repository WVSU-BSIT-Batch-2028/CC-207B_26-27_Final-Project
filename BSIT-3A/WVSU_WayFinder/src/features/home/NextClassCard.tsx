import { Link } from "react-router-dom";
import { CalendarIcon, ClockIcon, PinIcon, UserIcon } from "../../components/Icons";
import { nextClass } from "../../lib/schedule/next";
import { useClasses } from "../../lib/schedule/store";
import { formatClock, relativeStart, WEEKDAYS } from "../../lib/time";
import { useNow } from "../../lib/useNow";

/** The first thing a student sees: when, what, who, which room, and where to tap. */
export default function NextClassCard() {
  const classes = useClasses();
  const now = useNow(30_000);
  const next = nextClass(classes, now);

  if (!next) {
    return (
      <article className="card next-class empty-schedule" aria-label="My Schedule">
        <div className="card-head"><span className="kind"><CalendarIcon /> My Schedule</span></div>
        <h2 className="next-title">See your next class here</h2>
        <p className="muted">Add your weekly classes once. WayFinder shows the next one, its room, and directions.</p>
        <Link className="btn primary wide" to="/schedule/new">Add my schedule</Link>
      </article>
    );
  }

  const { session: s, start, end } = next;
  const findRoom = s.roomPlaceId ? `/map?to=${encodeURIComponent(s.roomPlaceId)}` : `/search?q=${encodeURIComponent(s.roomCodeRaw)}`;
  return (
    <article className="card next-class" aria-label="Next class">
      <div className="card-head">
        <span className="kind"><CalendarIcon /> Next class · {WEEKDAYS[s.weekday - 1]}</span>
        <Link className="inline-link small" to="/schedule">My Schedule</Link>
      </div>
      <h2 className="next-title">{s.subject}</h2>
      <p className="next-when"><ClockIcon /> <strong>{formatClock(s.start)}–{formatClock(s.end)}</strong> <span className="pill">{relativeStart(start, end, now)}</span></p>
      <div className="room-code-row">
        <span className="room-label">Room</span>
        <span className="room-code">{s.roomCodeRaw}</span>
      </div>
      {!s.roomPlaceId && <p className="tbc">Room location unconfirmed</p>}
      {s.professor && <p className="next-prof"><UserIcon /> {s.professor}</p>}
      <Link className="btn primary wide" to={findRoom}><PinIcon /> Find room</Link>
    </article>
  );
}
