import { useEffect, useRef, useState, type FormEvent } from "react";
import { Link } from "react-router-dom";
import { SparkIcon } from "../../components/Icons";
import { askGuide, fallbackSearch, GuideUnavailable, linkFor, type FallbackHit } from "./guideClient";
import { LANGS, S, type Lang } from "./strings";
import type { Citation } from "../../../supabase/functions/ai-guide/logic";

type Msg =
  | { role: "user"; text: string }
  | { role: "ai"; text: string; citations: Citation[] }
  | { role: "fallback"; hits: FallbackHit[] };

export default function GuidePage() {
  const [lang, setLang] = useState<Lang>("en");
  const [msgs, setMsgs] = useState<Msg[]>([]);
  const [value, setValue] = useState("");
  const [busy, setBusy] = useState(false);
  const [aiDown, setAiDown] = useState(false);
  const endRef = useRef<HTMLDivElement>(null);
  const t = S[lang];

  useEffect(() => {
    // Braces matter: newer browsers return a Promise from scrollIntoView, which React must not get back.
    endRef.current?.scrollIntoView?.({ block: "end" });
  }, [msgs, busy]);

  async function ask(q: string) {
    const text = q.trim();
    if (!text || busy) return;
    setValue("");
    setMsgs((m) => [...m, { role: "user", text }]);
    setBusy(true);
    try {
      const a = await askGuide(text, lang);
      setAiDown(false);
      setMsgs((m) => [...m, { role: "ai", text: a.grounded && a.answer ? a.answer : t.noInfo, citations: a.grounded ? a.citations : [] }]);
    } catch (e) {
      if (!(e instanceof GuideUnavailable)) throw e;
      setAiDown(true);
      setMsgs((m) => [...m, { role: "fallback", hits: [] }]);
      const hits = await fallbackSearch(text);
      setMsgs((m) => [...m.slice(0, -1), { role: "fallback", hits }]);
    } finally {
      setBusy(false);
    }
  }

  const submit = (e: FormEvent) => { e.preventDefault(); ask(value); };

  return (
    <section className="guide">
      <div className="guide-head">
        <span className="guide-avatar"><SparkIcon /></span>
        <div>
          <h1 className="page-title">WayFinder AI</h1>
          <p className="muted small">{aiDown ? "AI unavailable · showing directory and process search" : "Answers from published campus records"}</p>
        </div>
      </div>
      <div className="lang-chips" role="radiogroup" aria-label="Language">
        {LANGS.map((l) => (
          <button key={l.id} role="radio" aria-checked={lang === l.id} className={`chip${lang === l.id ? " on" : ""}`} onClick={() => setLang(l.id)}>{l.label}</button>
        ))}
      </div>

      <div className="chat" aria-live="polite">
        <div className="bubble ai">{t.greeting}</div>
        {msgs.map((m, i) =>
          m.role === "user" ? <div key={i} className="bubble user">{m.text}</div>
          : m.role === "ai" ? (
            <div key={i} className="bubble ai">
              <p>{m.text}</p>
              {m.citations.length > 0 && (
                <div className="cites">{m.citations.map((c) => <Link key={c.type + c.id} className="cite" to={c.type === "place" ? `/map?to=${encodeURIComponent(c.id)}` : linkFor(c.type, c.id)}>{c.label} ›</Link>)}</div>
              )}
            </div>
          ) : (
            <div key={i} className="bubble ai fallback">
              <span className="badge unverified">Search results · not an AI answer</span>
              <p>{t.fallbackTitle}</p>
              {m.hits.length === 0 && !busy && <p className="muted">{t.fallbackNone}</p>}
              <div className="cites">
                {m.hits.map((h) => (
                  <Link key={h.type + h.id} className="cite" to={linkFor(h.type, h.id)}>
                    {h.label}{h.detail ? <span className="muted"> · {h.detail}</span> : null}{h.demo ? <span className="badge demo">Demo</span> : null}
                  </Link>
                ))}
              </div>
            </div>
          ),
        )}
        {busy && <div className="bubble ai muted" role="status">{t.thinking}</div>}
        <div ref={endRef} />
      </div>

      {msgs.length === 0 && (
        <div className="suggested">
          <h2 className="section-label">{t.suggested}</h2>
          {t.suggestions.map((s) => <button key={s} className="chip" onClick={() => ask(s)}>{s}</button>)}
        </div>
      )}

      <form className="chat-input" onSubmit={submit}>
        <input value={value} onChange={(e) => setValue(e.target.value)} placeholder={t.placeholder} aria-label={t.placeholder} />
        <button className="btn primary" type="submit" disabled={busy || !value.trim()}>{t.send}</button>
      </form>
    </section>
  );
}
