// Reminders for weekly classes. One pending timer per class; every save/delete re-syncs, so a
// rescheduled class drops its old timer and a deleted class loses its timer entirely.
// Web limitation: timers only fire while WayFinder is open. Background push needs a service worker,
// VAPID keys and a Supabase scheduler (see the plan), which are not configured.
import { nextOccurrence } from "../time";
import type { ClassSession } from "./types";

export interface Clock {
  now(): Date;
  setTimeout(fn: () => void, ms: number): unknown;
  clearTimeout(handle: unknown): void;
}

export const systemClock: Clock = {
  now: () => new Date(),
  setTimeout: (fn, ms) => setTimeout(fn, ms),
  clearTimeout: (h) => clearTimeout(h as ReturnType<typeof setTimeout>),
};

export interface Pending { classId: string; fireAt: Date; signature: string; handle: unknown }

const signature = (c: ClassSession) => `${c.weekday}|${c.start}|${c.end}|${c.remindMinutes}|${c.subject}|${c.roomCodeRaw}`;

/** Reminder instant for the next occurrence that is still in the future (or null). */
export function nextReminderAt(c: ClassSession, now: Date): Date | null {
  if (c.remindMinutes === undefined) return null;
  let occ = nextOccurrence(c.weekday, c.start, c.end, now);
  let at = new Date(occ.start.getTime() - c.remindMinutes * 60000);
  if (at <= now) {
    occ = nextOccurrence(c.weekday, c.start, c.end, new Date(occ.end.getTime() + 60000));
    at = new Date(occ.start.getTime() - c.remindMinutes * 60000);
  }
  return at;
}

export class ReminderScheduler {
  private pending = new Map<string, Pending>();
  constructor(private clock: Clock, private notify: (c: ClassSession) => void) {}

  /** Make the pending timers match `classes` exactly. */
  sync(classes: ClassSession[]) {
    const wanted = new Map(classes.map((c) => [c.id, c]));
    for (const [id, p] of this.pending) {
      const c = wanted.get(id);
      if (!c || signature(c) !== p.signature) this.cancel(id); // deleted or changed -> old reminder cancelled
    }
    for (const c of classes) if (!this.pending.has(c.id)) this.schedule(c);
  }

  private schedule(c: ClassSession) {
    const now = this.clock.now();
    const at = nextReminderAt(c, now);
    if (!at) return;
    const handle = this.clock.setTimeout(() => {
      this.pending.delete(c.id);
      this.notify(c);
      this.schedule(c); // next week
    }, at.getTime() - now.getTime());
    this.pending.set(c.id, { classId: c.id, fireAt: at, signature: signature(c), handle });
  }

  cancel(id: string) {
    const p = this.pending.get(id);
    if (p) this.clock.clearTimeout(p.handle);
    this.pending.delete(id);
  }

  cancelAll() {
    for (const id of [...this.pending.keys()]) this.cancel(id);
  }

  list(): Pending[] {
    return [...this.pending.values()];
  }
}
