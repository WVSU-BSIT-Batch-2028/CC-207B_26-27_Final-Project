import { nextOccurrence } from "../time";
import type { ClassSession } from "./types";

export interface UpcomingClass { session: ClassSession; start: Date; end: Date }

/** The class in progress, or the soonest upcoming one (Asia/Manila). */
export function nextClass(classes: ClassSession[], now: Date): UpcomingClass | null {
  let best: UpcomingClass | null = null;
  for (const s of classes) {
    const occ = nextOccurrence(s.weekday, s.start, s.end, now);
    if (!best || occ.start < best.start) best = { session: s, ...occ };
  }
  return best;
}
