// @vitest-environment node
import { buildSystemPrompt, buildUserMessage, keywords, pickContext, sanitize, type SourceRecord } from "./logic";

const recs: SourceRecord[] = [
  { type: "place", id: "office-registrar", label: "Office of the Registrar", text: "office, in Administration Building, floor 1" },
  { type: "place", id: "room-cb-203", label: "CB 203", text: "room, room code CB203, in College Building, floor 2" },
  { type: "process", id: "proc-enrollment", label: "Enrollment", text: "Steps: 1. Registrar: submit form" },
];

describe("ai-guide logic", () => {
  it("drops question words in English, Tagalog and Hiligaynon", () => {
    expect(keywords("Where is the Registrar?")).toEqual(["registrar"]);
    expect(keywords("Saan ang Registrar?")).toEqual(["registrar"]);
    expect(keywords("Asa ang Registrar?")).toEqual(["registrar"]);
  });

  it("matches room codes written any way", () => {
    expect(pickContext(recs, "where is cb-203")[0].id).toBe("room-cb-203");
  });

  it("returns nothing for unrelated questions (so the model must say it has no verified info)", () => {
    expect(pickContext(recs, "cafeteria menu")).toEqual([]);
    expect(buildUserMessage("cafeteria menu", [])).toContain("(no matching verified records)");
  });

  it("asks for the requested language and forbids guessing", () => {
    expect(buildSystemPrompt("hil")).toContain("Hiligaynon");
    expect(buildSystemPrompt("tl")).toContain("Tagalog");
    expect(buildSystemPrompt("en")).toMatch(/Never guess/);
  });

  it("strips invented citations and marks ungrounded answers", () => {
    const ctx = pickContext(recs, "registrar");
    const out = sanitize(
      { answer: "It is in Admin.", lang: "en", grounded: true,
        citations: [{ type: "place", id: "office-registrar", label: "x" }, { type: "place", id: "made-up", label: "y" }] },
      ctx, "en");
    expect(out.citations).toEqual([{ type: "place", id: "office-registrar", label: "Office of the Registrar" }]);
    expect(out.grounded).toBe(true);
    const none = sanitize({ answer: "?", lang: "en", grounded: true, citations: [{ type: "place", id: "made-up", label: "y" }] }, ctx, "en");
    expect(none.grounded).toBe(false);
    expect(none.citations).toEqual([]);
  });
});
