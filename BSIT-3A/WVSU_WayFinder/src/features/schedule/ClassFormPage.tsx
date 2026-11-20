import { useState, type FormEvent } from "react";
import { Link, useNavigate, useParams } from "react-router-dom";
import Notice from "../../components/Notice";
import { resolveRoom } from "../../lib/schedule/resolveRoom";
import { newId, scheduleStore } from "../../lib/schedule/store";
import type { ClassSession } from "../../lib/schedule/types";
import { toMinutes, WEEKDAYS } from "../../lib/time";

export default function ClassFormPage() {
  const { classId } = useParams();
  const existing = classId ? scheduleStore.get(classId) : undefined;
  const navigate = useNavigate();
  const [form, setForm] = useState({
    subject: existing?.subject ?? "",
    weekday: existing?.weekday ?? 1,
    start: existing?.start ?? "08:00",
    end: existing?.end ?? "09:30",
    room: existing?.roomCodeRaw ?? "",
    professor: existing?.professor ?? "",
    remind: existing?.remindMinutes === undefined ? (existing ? "off" : "15") : String(existing.remindMinutes),
  });
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  if (classId && !existing) {
    return <section><Link to="/schedule" className="back">← My Schedule</Link><div className="card empty"><h2>Class not found</h2></div></section>;
  }

  const set = (k: keyof typeof form) => (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) =>
    setForm((f) => ({ ...f, [k]: k === "weekday" ? Number(e.target.value) : e.target.value }));

  async function submit(e: FormEvent) {
    e.preventDefault();
    if (!form.subject.trim()) return setError("Enter the subject.");
    if (!form.room.trim()) return setError("Enter the room code from your timetable.");
    if (toMinutes(form.end) <= toMinutes(form.start)) return setError("End time must be after the start time.");
    setSaving(true);
    const roomCodeRaw = form.room.trim();
    const session: ClassSession = {
      id: existing?.id ?? newId(),
      subject: form.subject.trim(),
      weekday: form.weekday,
      start: form.start,
      end: form.end,
      roomCodeRaw,
      roomPlaceId: await resolveRoom(roomCodeRaw),
      professor: form.professor.trim() || undefined,
      remindMinutes: form.remind === "off" ? undefined : Number(form.remind),
    };
    scheduleStore.save(session);
    navigate("/schedule");
  }

  return (
    <section>
      <Link to="/schedule" className="back">← My Schedule</Link>
      <h1 className="page-title">{existing ? "Edit class" : "Add class"}</h1>
      <form className="card form" onSubmit={submit} noValidate>
        <label>Subject<input value={form.subject} onChange={set("subject")} placeholder="e.g. CIT 210 Web Systems" required /></label>
        <label>Day
          <select value={form.weekday} onChange={set("weekday")}>
            {WEEKDAYS.map((d, i) => <option key={d} value={i + 1}>{d}</option>)}
          </select>
        </label>
        <div className="form-row">
          <label>Starts<input type="time" value={form.start} onChange={set("start")} required /></label>
          <label>Ends<input type="time" value={form.end} onChange={set("end")} required /></label>
        </div>
        <label>Room code<input value={form.room} onChange={set("room")} placeholder="As written on your timetable, e.g. CB 203" required /></label>
        <label>Professor<input value={form.professor} onChange={set("professor")} placeholder="Optional" /></label>
        <label>Reminder
          <select value={form.remind} onChange={set("remind")}>
            <option value="off">No reminder</option>
            <option value="5">5 minutes before</option>
            <option value="10">10 minutes before</option>
            <option value="15">15 minutes before</option>
            <option value="30">30 minutes before</option>
          </select>
        </label>
        <p className="muted small">Times are Asia/Manila. If the room code isn’t in the campus records, it’s kept exactly as typed and marked “Room location unconfirmed”.</p>
        {error && <Notice>{error}</Notice>}
        <div className="actions sticky-actions">
          <button className="btn primary" type="submit" disabled={saving}>{saving ? "Saving…" : "Save class"}</button>
          {existing && (
            <button className="btn danger" type="button" onClick={() => { scheduleStore.remove(existing.id); navigate("/schedule"); }}>
              Delete class
            </button>
          )}
        </div>
      </form>
    </section>
  );
}
