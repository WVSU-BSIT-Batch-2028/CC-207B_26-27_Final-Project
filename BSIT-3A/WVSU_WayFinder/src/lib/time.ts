// Class times are wall-clock times in Asia/Manila. Manila is UTC+8 all year (no daylight saving),
// so a fixed offset is exact and does not depend on the device's own time zone.
const OFFSET_MS = 8 * 60 * 60 * 1000;
export const TZ = "Asia/Manila";
export const WEEKDAYS = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];

/** Manila wall-clock parts for an instant. weekday: 1 = Monday ... 7 = Sunday. */
export function manilaParts(at: Date) {
  const m = new Date(at.getTime() + OFFSET_MS);
  const dow = m.getUTCDay(); // 0 = Sunday
  return { y: m.getUTCFullYear(), mo: m.getUTCMonth(), d: m.getUTCDate(), weekday: dow === 0 ? 7 : dow, minutes: m.getUTCHours() * 60 + m.getUTCMinutes() };
}

/** "13:30" -> 810 */
export const toMinutes = (hhmm: string) => {
  const [h, m] = hhmm.split(":").map(Number);
  return h * 60 + m;
};

/** The UTC instant of a Manila wall-clock time on a given Manila date. */
function manilaInstant(y: number, mo: number, d: number, minutes: number): Date {
  return new Date(Date.UTC(y, mo, d, 0, minutes) - OFFSET_MS);
}

/**
 * Next start of a weekly class at or after `now` (a class already in progress counts until it ends).
 * Returns the start and end instants.
 */
export function nextOccurrence(weekday: number, start: string, end: string, now: Date): { start: Date; end: Date } {
  const p = manilaParts(now);
  const s = toMinutes(start);
  const e = toMinutes(end);
  let addDays = (weekday - p.weekday + 7) % 7;
  if (addDays === 0 && p.minutes >= e) addDays = 7; // today's class is over
  return { start: manilaInstant(p.y, p.mo, p.d + addDays, s), end: manilaInstant(p.y, p.mo, p.d + addDays, e) };
}

/** "1:30 PM" in Manila time. */
export function formatClock(hhmm: string): string {
  const mins = toMinutes(hhmm);
  const h = Math.floor(mins / 60);
  const m = mins % 60;
  return `${((h + 11) % 12) + 1}:${String(m).padStart(2, "0")} ${h < 12 ? "AM" : "PM"}`;
}

/** "Now", "in 25 min", "in 3 h 5 min", "Tomorrow", "Friday" */
export function relativeStart(start: Date, end: Date, now: Date): string {
  if (now >= start && now < end) return "In progress";
  const diff = Math.round((start.getTime() - now.getTime()) / 60000);
  if (diff < 60) return `in ${diff} min`;
  const a = manilaParts(now);
  const b = manilaParts(start);
  const sameDay = a.y === b.y && a.mo === b.mo && a.d === b.d;
  if (sameDay) return `in ${Math.floor(diff / 60)} h ${diff % 60} min`;
  const tomorrow = manilaParts(new Date(now.getTime() + 86400000));
  if (tomorrow.y === b.y && tomorrow.mo === b.mo && tomorrow.d === b.d) return "Tomorrow";
  return WEEKDAYS[b.weekday - 1];
}
