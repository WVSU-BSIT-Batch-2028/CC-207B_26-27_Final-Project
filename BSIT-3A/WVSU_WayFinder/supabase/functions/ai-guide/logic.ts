// Pure helpers for the ai-guide function (no Deno/npm imports, so they are unit-tested with Vitest).

export type Lang = "en" | "tl" | "hil";
export type SourceType = "place" | "process" | "faculty";

export interface SourceRecord {
  type: SourceType;
  id: string;     // shared place ID, process ID, or faculty record_id
  label: string;  // display name
  text: string;   // the verified facts the model may use
}

export interface Citation { type: SourceType; id: string; label: string }
export interface GuideAnswer { answer: string; lang: Lang; citations: Citation[]; grounded: boolean }

const STOP = new Set(
  ("the a an is are where what how do does i my to of in on for and or can find get go saan ang ng sa mga ko ako paano " +
   "asa diin ano ang sang sa mga ko ako paano paagi ka kag please po")
    .split(" "),
);

/** Lower-case keywords worth matching (drops common EN/TL/HIL question words). */
export function keywords(q: string): string[] {
  return q.toLowerCase().normalize("NFKD").replace(/[^a-z0-9\s]/g, " ").split(/\s+/)
    .filter((w) => w.length >= 2 && !STOP.has(w));
}

/** Picks the records that best match the question (simple keyword overlap; small campus dataset). */
export function pickContext(records: SourceRecord[], q: string, limit = 8): SourceRecord[] {
  const kws = keywords(q);
  const code = q.toUpperCase().replace(/[^A-Z0-9]/g, "");
  return records
    .map((r) => {
      const hay = `${r.label} ${r.text}`.toLowerCase();
      let score = kws.reduce((s, k) => s + (hay.includes(k) ? 1 : 0), 0);
      if (code.length >= 3 && hay.toUpperCase().replace(/[^A-Z0-9]/g, "").includes(code)) score += 3;
      return { r, score };
    })
    .filter((x) => x.score > 0)
    .sort((a, b) => b.score - a.score)
    .slice(0, limit)
    .map((x) => x.r);
}

const LANG_NAME: Record<Lang, string> = { en: "English", tl: "Tagalog (Filipino)", hil: "Hiligaynon" };

export function buildSystemPrompt(lang: Lang): string {
  return [
    "You are WayFinder, a campus guide for students of West Visayas State University (WVSU) Main Campus.",
    "Answer ONLY from the SOURCES provided in the user message. They are the university's published, verified records.",
    "If the sources do not contain the answer, say you do not have verified information on that yet, set grounded to false, and return no citations. Never guess office locations, requirements, people or schedules.",
    `Write the answer in ${LANG_NAME[lang]}, in 1-4 short sentences a student can read while walking.`,
    "Cite every source you used by its exact type and id from the SOURCES list. Do not invent ids.",
  ].join("\n");
}

export function buildUserMessage(q: string, context: SourceRecord[]): string {
  const sources = context.length
    ? context.map((c) => `- [${c.type}:${c.id}] ${c.label}: ${c.text}`).join("\n")
    : "(no matching verified records)";
  return `SOURCES:\n${sources}\n\nSTUDENT QUESTION:\n${q}`;
}

/** Keeps only citations that point at records we actually sent; ungrounded if none remain. */
export function sanitize(raw: GuideAnswer, context: SourceRecord[], lang: Lang): GuideAnswer {
  const allowed = new Map(context.map((c) => [`${c.type}:${c.id}`, c]));
  const citations = (raw.citations ?? [])
    .filter((c) => allowed.has(`${c.type}:${c.id}`))
    .map((c) => ({ type: c.type, id: c.id, label: allowed.get(`${c.type}:${c.id}`)!.label }));
  const grounded = Boolean(raw.grounded) && citations.length > 0;
  return { answer: String(raw.answer ?? ""), lang, citations: grounded ? citations : [], grounded };
}

export const isLang = (x: unknown): x is Lang => x === "en" || x === "tl" || x === "hil";
