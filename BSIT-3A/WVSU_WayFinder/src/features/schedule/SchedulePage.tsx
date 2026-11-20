import { useRef, useState } from "react";
import { Link } from "react-router-dom";
import { BellIcon, ClockIcon, UploadIcon, UserIcon } from "../../components/Icons";
import Notice from "../../components/Notice";
import { downscaleImage, scheduleStore, useClasses } from "../../lib/schedule/store";
import { formatClock, WEEKDAYS } from "../../lib/time";
import { useSyncExternalStore } from "react";
import { notificationStatus, requestNotifications } from "./ReminderHost";

export default function SchedulePage() {
  const classes = useClasses();
  const image = useSyncExternalStore(scheduleStore.subscribe, scheduleStore.getImage, scheduleStore.getImage);
  const fileRef = useRef<HTMLInputElement>(null);
  const [error, setError] = useState<string | null>(null);
  const [notif, setNotif] = useState(notificationStatus());

  async function onPick(e: React.ChangeEvent<HTMLInputElement>) {
    const f = e.target.files?.[0];
    e.target.value = "";
    if (!f) return;
    if (!/^image\/(jpeg|png|webp)$/.test(f.type)) return setError("Choose a JPG, PNG or WebP image.");
    try {
      setError(null);
      scheduleStore.setImage(await downscaleImage(f));
    } catch (err) {
      setError((err as Error).message || "The image couldn't be saved.");
    }
  }

  const byDay = WEEKDAYS.map((name, i) => ({ name, items: classes.filter((c) => c.weekday === i + 1).sort((a, b) => a.start.localeCompare(b.start)) }))
    .filter((d) => d.items.length);

  return (
    <section className="schedule">
      <Link to="/" className="back">← Home</Link>
      <h1 className="page-title">My Schedule</h1>
      <Notice tone="info">Private: your timetable and classes are saved on this device only. Times use Asia/Manila.</Notice>

      <div className="schedule-grid">
        <article className="card">
          <div className="card-head"><span className="kind"><UploadIcon /> Timetable image</span></div>
          {image ? (
            <>
              <img className="timetable" src={image} alt="Your uploaded timetable" />
              <p className="muted small">Use it as a reference while you enter or confirm each class below. WayFinder doesn’t read the image automatically.</p>
              <div className="actions">
                <button className="btn ghost" onClick={() => fileRef.current?.click()}>Replace image</button>
                <button className="btn ghost" onClick={() => scheduleStore.setImage(null)}>Remove image</button>
              </div>
            </>
          ) : (
            <>
              <p className="muted">Upload a photo or screenshot of your class schedule, then confirm each class.</p>
              <button className="btn primary" onClick={() => fileRef.current?.click()}><UploadIcon /> Upload timetable</button>
            </>
          )}
          <input ref={fileRef} type="file" accept="image/jpeg,image/png,image/webp" hidden onChange={onPick} data-testid="timetable-input" />
          {error && <Notice>{error}</Notice>}
        </article>

        <article className="card">
          <div className="card-head"><span className="kind"><BellIcon /> Reminders</span></div>
          {notif === "granted" && <p className="muted small">Notifications are on. Reminders appear while WayFinder is open in this browser.</p>}
          {notif === "default" && (
            <>
              <p className="muted small">Get a notification before each class (while WayFinder is open).</p>
              <button className="btn ghost" onClick={async () => setNotif(await requestNotifications())}>Turn on notifications</button>
            </>
          )}
          {notif === "denied" && <p className="muted small">Notifications are blocked in this browser. Reminders show inside WayFinder instead.</p>}
          {notif === "unsupported" && <p className="muted small">This browser has no notifications. Reminders show inside WayFinder instead.</p>}
          <p className="muted small">Background reminders when the app is closed aren’t available yet.</p>
        </article>
      </div>

      <div className="section-row">
        <h2 className="section-label">Weekly classes</h2>
        <Link className="btn primary" to="/schedule/new">Add class</Link>
      </div>
      {classes.length === 0 && <div className="card empty"><h2>No classes yet</h2><p className="muted">Add each class from your timetable.</p></div>}
      {byDay.map((d) => (
        <div key={d.name}>
          <h3 className="day-label">{d.name}</h3>
          {d.items.map((c) => (
            <Link key={c.id} to={`/schedule/${c.id}`} className="card class-row" aria-label={`${c.subject}, ${d.name}`}>
              <div className="class-main">
                <strong className="place-name">{c.subject}</strong>
                <span className="muted small"><ClockIcon /> {formatClock(c.start)}–{formatClock(c.end)}{c.professor && <> · <UserIcon /> {c.professor}</>}</span>
                {!c.roomPlaceId && <span className="tbc small-tbc">Room location unconfirmed</span>}
              </div>
              <span className="room-code small-code">{c.roomCodeRaw}</span>
            </Link>
          ))}
        </div>
      ))}
    </section>
  );
}
