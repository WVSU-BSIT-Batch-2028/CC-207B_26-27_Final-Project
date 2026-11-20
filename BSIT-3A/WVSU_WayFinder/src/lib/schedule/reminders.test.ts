import { ReminderScheduler, nextReminderAt, type Clock } from "./reminders";
import type { ClassSession } from "./types";

function fakeClock(startIso: string) {
  let now = new Date(startIso).getTime();
  const timers = new Map<number, { at: number; fn: () => void }>();
  let seq = 0;
  const clock: Clock = {
    now: () => new Date(now),
    setTimeout: (fn, ms) => { const id = ++seq; timers.set(id, { at: now + ms, fn }); return id; },
    clearTimeout: (h) => { timers.delete(h as number); },
  };
  const advanceTo = (iso: string) => {
    const target = new Date(iso).getTime();
    for (;;) {
      const due = [...timers.entries()].filter(([, t]) => t.at <= target).sort((a, b) => a[1].at - b[1].at)[0];
      if (!due) break;
      timers.delete(due[0]);
      now = due[1].at;
      due[1].fn();
    }
    now = target;
  };
  return { clock, timers, advanceTo };
}

const cls = (over: Partial<ClassSession> = {}): ClassSession => ({
  id: "c1", subject: "CIT 210", weekday: 1, start: "13:30", end: "15:00", roomCodeRaw: "CB 203", remindMinutes: 15, ...over,
});

describe("class reminders (Asia/Manila)", () => {
  it("fires 15 minutes before a Monday 1:30 PM class (05:15Z)", () => {
    expect(nextReminderAt(cls(), new Date("2026-11-23T00:00:00Z"))!.toISOString()).toBe("2026-11-23T05:15:00.000Z");
  });

  it("rescheduling cancels the old reminder and schedules the new time", () => {
    const { clock, timers, advanceTo } = fakeClock("2026-11-23T00:00:00Z"); // Mon 08:00 Manila
    const fired: string[] = [];
    const s = new ReminderScheduler(clock, (c) => fired.push(`${c.id}@${clock.now().toISOString()}`));
    s.sync([cls()]);
    expect(s.list()[0].fireAt.toISOString()).toBe("2026-11-23T05:15:00.000Z");
    s.sync([cls({ start: "16:00", end: "17:00" })]); // moved to 4 PM
    expect(timers.size).toBe(1);
    expect(s.list()[0].fireAt.toISOString()).toBe("2026-11-23T07:45:00.000Z");
    advanceTo("2026-11-23T06:00:00Z"); // past the OLD reminder time
    expect(fired).toEqual([]); // old reminder did not fire
    advanceTo("2026-11-23T07:46:00Z");
    expect(fired).toEqual(["c1@2026-11-23T07:45:00.000Z"]);
  });

  it("deleting a class cancels its reminder", () => {
    const { clock, timers, advanceTo } = fakeClock("2026-11-23T00:00:00Z");
    const fired: string[] = [];
    const s = new ReminderScheduler(clock, (c) => fired.push(c.id));
    s.sync([cls(), cls({ id: "c2", start: "10:00", end: "11:00" })]);
    expect(timers.size).toBe(2);
    s.sync([cls({ id: "c2", start: "10:00", end: "11:00" })]); // c1 deleted
    expect(timers.size).toBe(1);
    expect(s.list().map((p) => p.classId)).toEqual(["c2"]);
    advanceTo("2026-11-23T08:00:00Z");
    expect(fired).toEqual(["c2"]);
  });

  it("turning the reminder off cancels it; after firing it re-arms for next week", () => {
    const { clock, timers, advanceTo } = fakeClock("2026-11-23T00:00:00Z");
    const s = new ReminderScheduler(clock, () => {});
    s.sync([cls()]);
    s.sync([cls({ remindMinutes: undefined })]);
    expect(timers.size).toBe(0);
    s.sync([cls()]);
    advanceTo("2026-11-23T05:16:00Z");
    expect(s.list()[0].fireAt.toISOString()).toBe("2026-11-30T05:15:00.000Z");
  });
});
