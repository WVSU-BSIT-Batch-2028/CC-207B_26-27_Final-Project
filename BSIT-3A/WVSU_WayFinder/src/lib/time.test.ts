import { formatClock, manilaParts, nextOccurrence, relativeStart } from "./time";

// The test runner's TZ is irrelevant: everything is computed against Asia/Manila (UTC+8).
const at = (iso: string) => new Date(iso);

describe("Asia/Manila class times", () => {
  it("reads Manila wall-clock time regardless of device time zone", () => {
    // 2026-11-23T00:30Z = Monday 08:30 in Manila
    expect(manilaParts(at("2026-11-23T00:30:00Z"))).toMatchObject({ weekday: 1, minutes: 8 * 60 + 30 });
  });

  it("next Monday 13:30 class, asked on Monday morning", () => {
    const { start } = nextOccurrence(1, "13:30", "15:00", at("2026-11-23T00:30:00Z"));
    expect(start.toISOString()).toBe("2026-11-23T05:30:00.000Z");
  });

  it("a class in progress is still 'next' until it ends; afterwards it rolls to next week", () => {
    const during = nextOccurrence(1, "08:00", "09:30", at("2026-11-23T00:45:00Z")); // 08:45 Manila
    expect(during.start.toISOString()).toBe("2026-11-23T00:00:00.000Z");
    expect(relativeStart(during.start, during.end, at("2026-11-23T00:45:00Z"))).toBe("In progress");
    const after = nextOccurrence(1, "08:00", "09:30", at("2026-11-23T01:31:00Z")); // 09:31 Manila
    expect(after.start.toISOString()).toBe("2026-11-30T00:00:00.000Z");
  });

  it("Sunday night → Monday class is 'Tomorrow'", () => {
    const now = at("2026-11-22T14:00:00Z"); // Sunday 22:00 Manila
    const { start, end } = nextOccurrence(1, "07:30", "09:00", now);
    expect(relativeStart(start, end, now)).toBe("Tomorrow");
  });

  it("formats 12-hour clock", () => {
    expect(formatClock("13:30")).toBe("1:30 PM");
    expect(formatClock("00:05")).toBe("12:05 AM");
  });
});
