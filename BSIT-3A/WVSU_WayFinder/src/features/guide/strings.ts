// UI strings. Tagalog and Hiligaynon drafts need review by a native-speaker teammate before release.
export type Lang = "en" | "tl" | "hil";
export const LANGS: { id: Lang; label: string }[] = [
  { id: "en", label: "English" },
  { id: "tl", label: "Tagalog" },
  { id: "hil", label: "Hiligaynon" },
];

export const S: Record<Lang, {
  greeting: string; placeholder: string; send: string; suggested: string; suggestions: string[];
  noInfo: string; fallbackTitle: string; fallbackNone: string; thinking: string;
}> = {
  en: {
    greeting: "Hi! Where do you need to go or what do you need to process?",
    placeholder: "Ask about a place, room or process",
    send: "Send",
    suggested: "Suggested questions",
    suggestions: ["Where is the Registrar?", "How do I process my clearance?", "Where can I request my transcript?", "Where is CB 203?"],
    noInfo: "I don’t have verified information on that yet. Try the Directory or Processes.",
    fallbackTitle: "AI answers are unavailable. Here are matching directory and process results:",
    fallbackNone: "No matching place, teacher or process was found.",
    thinking: "Checking campus records…",
  },
  tl: {
    greeting: "Kumusta! Saan ka pupunta o ano ang kailangan mong asikasuhin?",
    placeholder: "Magtanong tungkol sa lugar, silid o proseso",
    send: "Ipadala",
    suggested: "Mga mungkahing tanong",
    suggestions: ["Saan ang Registrar?", "Paano mag-process ng clearance?", "Saan puwedeng humingi ng transcript?", "Saan ang CB 203?"],
    noInfo: "Wala pa akong beripikadong impormasyon tungkol diyan. Subukan ang Directory o Processes.",
    fallbackTitle: "Hindi available ang AI. Narito ang mga tugmang resulta sa directory at proseso:",
    fallbackNone: "Walang nakitang tugmang lugar, guro o proseso.",
    thinking: "Sinusuri ang mga tala ng kampus…",
  },
  hil: {
    greeting: "Maayong adlaw! Diin ka makadto ukon ano ang kinahanglan mo i-proseso?",
    placeholder: "Pamangkot parte sa lugar, kwarto ukon proseso",
    send: "Ipadala",
    suggested: "Mga ginapanugyan nga pamangkot",
    suggestions: ["Diin ang Registrar?", "Paano ko ma-proseso ang clearance?", "Diin ako makapangayo sang transcript?", "Diin ang CB 203?"],
    noInfo: "Wala pa ako sang beripikado nga impormasyon parte sina. Tilawi ang Directory ukon Processes.",
    fallbackTitle: "Indi available ang AI. Ari ang nagakaangay nga resulta sa directory kag proseso:",
    fallbackNone: "Wala sang nakita nga nagakaangay nga lugar, maestro ukon proseso.",
    thinking: "Ginatan-aw ang mga rekord sang kampus…",
  },
};
