import { useState, useEffect, useRef } from "react";

// ─── Icons (SF Symbols style — inline SVG) ───
const Icons = {
  waveform: (props) => (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.75" strokeLinecap="round" strokeLinejoin="round" {...props}>
      <path d="M12 4a3 3 0 0 0-3 3v5a3 3 0 0 0 6 0V7a3 3 0 0 0-3-3Z" />
      <path d="M19 10a7 7 0 0 1-14 0" />
      <path d="M12 17v4" />
      <path d="M8 21h8" />
    </svg>
  ),
  sparkle: (props) => (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" {...props}>
      <path d="M12 3l1.8 4.2L18 9l-4.2 1.8L12 15l-1.8-4.2L6 9l4.2-1.8L12 3Z" />
      <path d="M19 13l1 1.8L22 16l-2 1.2L19 19l-1-1.8L16 16l2-1.2L19 13Z" />
      <path d="M5 14l.9 1.9L8 17l-2.1 1.1L5 20l-.9-1.9L2 17l2.1-1.1L5 14Z" />
    </svg>
  ),
  globe: (props) => (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" {...props}>
      <circle cx="12" cy="12" r="8" />
      <path d="M12 4a12 12 0 0 1 0 16M12 4a12 12 0 0 0 0 16" />
      <path d="M4 12h16" />
    </svg>
  ),
  shield: (props) => (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" {...props}>
      <path d="M12 3l7 3v5c0 4-3 7-7 8-4-1-7-4-7-8V6l7-3Z" />
      <path d="M9 12l2 2 4-4" />
    </svg>
  ),
  bolt: (props) => (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" {...props}>
      <path d="M13 2L4 14h6l-1 8 9-12h-6l1-8Z" />
    </svg>
  ),
  appWindow: (props) => (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" {...props}>
      <rect x="3" y="4" width="18" height="14" rx="2" />
      <path d="M3 8h18M7 12h3M7 15h6" />
    </svg>
  ),
  check: (props) => (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" {...props}>
      <path d="M5 13l4 4L19 7" />
    </svg>
  ),
  xmark: (props) => (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" {...props}>
      <path d="M6 6l12 12M18 6L6 18" />
    </svg>
  ),
  arrowRight: (props) => (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" {...props}>
      <path d="M5 12h14M13 6l6 6-6 6" />
    </svg>
  ),
  play: (props) => (
    <svg viewBox="0 0 24 24" fill="currentColor" {...props}>
      <path d="M8 5.14v14l11-7-11-7Z" />
    </svg>
  ),
  apple: (props) => (
    <svg viewBox="0 0 24 24" fill="currentColor" {...props}>
      <path d="M12.02 2c-.4 0-1.03.26-1.67.72a3.5 3.5 0 0 0-1.15 1.5c-.2.57-.3 1.17-.3 1.78 0 1.4.6 2.5 1.5 3.2.4.32.9.6 1.62.6.7 0 1.2-.28 1.62-.6.9-.7 1.5-1.8 1.5-3.2 0-.6-.1-1.2-.3-1.77a3.5 3.5 0 0 0-1.15-1.5C13.05 2.26 12.42 2 12.02 2Zm-.02 6.5c-2.5 0-4.3 1.2-5.1 3.1-.5 1.1-.6 2.3-.4 3.6.3 1.6 1 2.9 2.1 3.8 1 1 2.1 1.5 3.3 1.5.5 0 1-.1 1.5-.3.5-.2 1-.3 1.6-.3s1.1.1 1.6.3c.5.2 1 .3 1.5.3 1.2 0 2.3-.5 3.3-1.5 1-1 1.8-2.2 2.1-3.8.2-1.3.1-2.5-.4-3.6-.8-1.9-2.6-3.1-5.1-3.1-.7 0-1.3.1-1.9.4-.5.3-1 .4-1.6.4s-1.1-.1-1.6-.4c-.6-.3-1.2-.4-1.9-.4Z" />
    </svg>
  ),
  menu: (props) => (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" {...props}>
      <path d="M4 7h16M4 12h16M4 17h16" />
    </svg>
  ),
  close: (props) => (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" {...props}>
      <path d="M6 18L18 6M6 6l12 12" />
    </svg>
  ),
  quote: (props) => (
    <svg viewBox="0 0 24 24" fill="currentColor" {...props}>
      <path d="M6 10c0-2.2 1.8-4 4-4v4H8c0 2.2 1.8 4 4 4v2c-3.3 0-6-2.7-6-6Zm8 0c0-2.2 1.8-4 4-4v4h-2c0 2.2 1.8 4 4 4v2c-3.3 0-6-2.7-6-6Z" opacity=".2" />
    </svg>
  ),
};

// ─── Nav ───
function Nav() {
  const [open, setOpen] = useState(false);
  const [scrolled, setScrolled] = useState(false);
  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 12);
    window.addEventListener("scroll", onScroll);
    return () => window.removeEventListener("scroll", onScroll);
  }, []);
  const links = [
    { label: "Features", href: "#features" },
    { label: "How it works", href: "#how" },
    { label: "Demo", href: "#demo" },
    { label: "Pricing", href: "#pricing" },
    { label: "FAQ", href: "#faq" },
  ];
  return (
    <header
      className={`fixed top-0 inset-x-0 z-50 transition-all duration-300 ${
        scrolled ? "py-2" : "py-4"
      }`}
    >
      <div className="mx-auto max-w-[1120px] px-4 sm:px-6">
        <div
          className={`flex items-center justify-between rounded-[20px] px-4 sm:px-5 py-3 transition-all ${
            scrolled ? "glass shadow-card" : "bg-transparent border border-transparent"
          }`}
        >
          <a href="#" className="flex items-center gap-2.5">
            <span className="grid place-items-center w-8 h-8 rounded-xl bg-gradient-to-br from-violet-500 to-violet-600 text-white shadow-md">
              <Icons.waveform className="w-4 h-4" />
            </span>
            <span className="font-semibold tracking-tight text-[17px] text-ink-900">WisperVoice</span>
            <span className="hidden sm:inline-flex items-center rounded-full bg-ink-900 text-white text-[10px] font-semibold tracking-widest px-2 py-0.5 ml-1">BETA</span>
          </a>

          <nav className="hidden md:flex items-center gap-6 text-[13.5px] font-medium text-ink-600">
            {links.map((l) => (
              <a key={l.label} href={l.href} className="hover:text-ink-900 transition-colors">
                {l.label}
              </a>
            ))}
          </nav>

          <div className="hidden md:flex items-center gap-2.5">
            <a
              href="#pricing"
              className="text-[13.5px] font-medium text-ink-700 hover:text-ink-900 px-3 py-1.5 transition"
            >
              Pricing
            </a>
            <a
              href="#download"
              className="inline-flex items-center gap-1.5 rounded-full bg-ink-900 text-white text-[13.5px] font-semibold px-4 py-2 hover:bg-black transition shadow-sm"
            >
              <Icons.apple className="w-3.5 h-3.5" />
              Download for Mac
            </a>
          </div>

          <button
            onClick={() => setOpen((v) => !v)}
            className="md:hidden grid place-items-center w-9 h-9 rounded-xl glass"
            aria-label="Menu"
          >
            {open ? <Icons.close className="w-4 h-4" /> : <Icons.menu className="w-4 h-4" />}
          </button>
        </div>

        {open && (
          <div className="md:hidden mt-2 glass rounded-2xl p-2 shadow-card">
            {links.map((l) => (
              <a
                key={l.label}
                href={l.href}
                onClick={() => setOpen(false)}
                className="block px-4 py-2.5 rounded-xl text-sm font-medium text-ink-700 hover:bg-white"
              >
                {l.label}
              </a>
            ))}
            <a
              href="#download"
              onClick={() => setOpen(false)}
              className="mt-2 flex items-center justify-center gap-2 rounded-xl bg-ink-900 text-white text-sm font-semibold py-3"
            >
              <Icons.apple className="w-4 h-4" />
              Download for Mac
            </a>
          </div>
        )}
      </div>
    </header>
  );
}

// ─── Hero ───
function Hero() {
  return (
    <section className="relative overflow-hidden pt-28 sm:pt-36 pb-12 sm:pb-20 mesh grid-pattern">
      {/* subtle aurora blobs */}
      <div className="pointer-events-none absolute -top-24 left-1/2 -translate-x-1/2 w-[1200px] h-[600px] opacity-60">
        <div className="absolute inset-0 bg-gradient-to-b from-violet-500/[0.08] via-transparent to-transparent blur-2xl rounded-full" />
      </div>

      <div className="relative mx-auto max-w-[1120px] px-4 sm:px-6">
        {/* announcement pill */}
        <div className="flex justify-center">
          <a
            href="#pricing"
            className="inline-flex items-center gap-2 rounded-full bg-white border border-ink-100 shadow-sm px-3 py-1.5 text-xs font-medium text-ink-600 hover:shadow-md transition"
          >
            <span className="inline-flex items-center gap-1.5 rounded-full bg-gradient-to-r from-violet-500 to-aqua-400 text-white px-2.5 py-1 text-[11px] font-bold tracking-wide">NEW</span>
            WisperVoice 1.1 — now with local Whisper models
            <span className="w-5 h-5 grid place-items-center rounded-full bg-ink-900 text-white">
              <Icons.arrowRight className="w-3 h-3" />
            </span>
          </a>
        </div>

        <div className="mt-8 sm:mt-10 text-center max-w-[760px] mx-auto">
          <h1 className="font-display font-[800] tracking-[-0.04em] leading-[0.95] text-[38px] sm:text-[56px] lg:text-[64px] text-ink-900">
            Dictate at the
            <br />
            <span className="bg-gradient-to-r from-violet-600 via-violet-500 to-aqua-400 bg-clip-text text-transparent">
              speed of thought.
            </span>
          </h1>
          <p className="mt-5 text-[16px] sm:text-[18px] leading-7 text-ink-500 max-w-[600px] mx-auto">
            Native Mac dictation that works in <em className="not-italic font-medium text-ink-700">every app</em>. Hold{" "}
            <span className="inline-flex items-center gap-1 rounded-lg bg-white border border-ink-200 px-1.5 py-0.5 text-xs font-medium shadow-sm">
              ⌥ Space
            </span>{" "}
            or double-tap{" "}
            <span className="inline-flex items-center rounded-lg bg-white border border-ink-200 px-1.5 py-0.5 text-xs font-medium shadow-sm">Fn</span>, speak naturally, and watch polished
            text appear at your cursor.
          </p>

          <div id="download" className="mt-8 flex flex-col sm:flex-row items-center justify-center gap-3">
            <a
              href="#"
              onClick={(e) => e.preventDefault()}
              className="w-full sm:w-auto inline-flex items-center justify-center gap-2 rounded-full bg-ink-900 text-white font-semibold px-7 py-3.5 text-[15px] hover:bg-black transition shadow-[0_8px_24px_rgba(15,17,26,0.18)]"
            >
              <Icons.apple className="w-4 h-4" />
              Download for Mac
              <span className="opacity-60 font-normal text-xs ml-1">· Free</span>
            </a>
            <a
              href="#demo"
              className="w-full sm:w-auto inline-flex items-center justify-center gap-2 rounded-full bg-white border border-ink-200 font-semibold px-7 py-3.5 text-[15px] text-ink-900 hover:bg-ink-50 transition"
            >
              <Icons.play className="w-3.5 h-3.5" />
              Watch 45-sec demo
            </a>
          </div>

          <div className="mt-4 flex flex-wrap items-center justify-center gap-3 text-xs text-ink-400">
            <span className="inline-flex items-center gap-1.5">
              <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulseDot" />
              macOS 14+ · Apple Silicon & Intel
            </span>
            <span className="hidden sm:inline">·</span>
            <span>No account required</span>
            <span className="hidden sm:inline">·</span>
            <span>On-device & private</span>
          </div>

          {/* social proof bar */}
          <div className="mt-6 flex flex-wrap items-center justify-center gap-2 text-xs">
            <span className="flex -space-x-2">
              {["bg-violet-500", "bg-aqua-400", "bg-amber-400", "bg-pink-400"].map((c, i) => (
                <span
                  key={i}
                  className={`w-7 h-7 rounded-full border-2 border-white grid place-items-center text-[10px] font-bold text-white ${c}`}
                >
                  {String.fromCharCode(65 + i)}
                </span>
              ))}
            </span>
            <span className="text-ink-500">
              <strong className="text-ink-900">2,400+</strong> founders & writers switched this month
            </span>
            <span className="inline-flex gap-0.5 text-amber-400">★★★★★</span>
            <span className="text-ink-500 font-medium">4.9/5</span>
          </div>
        </div>

        {/* Mac preview + floating glass cards */}
        <div className="mt-10 sm:mt-14 relative max-w-[980px] mx-auto">
          {/* pill overlay mock */}
          <div className="relative">
            <div className="absolute -top-6 left-1/2 -translate-x-1/2 z-10 hidden sm:flex items-center gap-3 rounded-full bg-white/90 backdrop-blur-xl border border-white/70 shadow-pill px-4 py-2.5">
              <span className="w-8 h-8 rounded-full bg-gradient-to-br from-violet-500 to-violet-600 grid place-items-center text-white">
                <Icons.waveform className="w-4 h-4" />
              </span>
              <span className="flex items-center gap-1">
                <span className="w-1.5 h-1.5 rounded-full bg-red-500 animate-pulseDot" />
                <span className="text-xs font-semibold tracking-wide text-ink-900">RECORDING</span>
              </span>
              <span className="flex items-end gap-[3px] h-5">
                {[8, 18, 12, 22, 10, 16].map((h, i) => (
                  <span
                    key={i}
                    className="w-[3px] rounded-full bg-ink-900"
                    style={{ height: h, opacity: 0.9 - i * 0.08, animation: `waveform 800ms ease-in-out ${i * 90}ms infinite` }}
                  />
                ))}
              </span>
              <span className="text-xs text-ink-500 hidden lg:inline">“Write a follow-up to Sarah about the Q3 roadmap…”</span>
              <button className="w-6 h-6 rounded-full bg-ink-100 grid place-items-center">
                <Icons.xmark className="w-3 h-3 text-ink-500" />
              </button>
            </div>

            {/* main window mock */}
            <div className="rounded-[24px] sm:rounded-[28px] bg-gradient-to-b from-white to-ink-50 border border-ink-100 shadow-[0_20px_80px_rgba(15,17,26,0.12),0_1px_0_rgba(255,255,255,1)_inset] overflow-hidden">
              {/* traffic lights */}
              <div className="flex items-center gap-1.5 px-5 py-3.5 border-b border-ink-100 bg-white/60">
                <span className="w-3 h-3 rounded-full bg-[#FF5F57] border border-black/5" />
                <span className="w-3 h-3 rounded-full bg-[#FFBD2E] border border-black/5" />
                <span className="w-3 h-3 rounded-full bg-[#28CA42] border border-black/5" />
                <span className="ml-3 text-xs font-medium text-ink-300">Cursor is in Slack — WisperVoice will paste here</span>
                <span className="ml-auto hidden sm:inline-flex items-center gap-1.5 text-[11px] font-medium text-emerald-600 bg-emerald-50 border border-emerald-200 rounded-full px-2.5 py-1">
                  <span className="w-1.5 h-1.5 rounded-full bg-emerald-500" />
                  Listening
                </span>
              </div>

              <div className="grid md:grid-cols-[1.15fr_0.85fr] gap-0">
                {/* editor pane */}
                <div className="p-5 sm:p-7">
                  <div className="rounded-2xl bg-white border border-ink-100 shadow-sm p-4 sm:p-5">
                    <div className="flex items-center gap-2 text-[11px] font-semibold tracking-widest text-ink-400">
                      <span className="w-6 h-6 rounded-lg bg-violet-500/10 grid place-items-center text-violet-600">
                        <Icons.appWindow className="w-3.5 h-3.5" />
                      </span>
                      SLACK · #product
                      <span className="ml-auto text-emerald-600 flex items-center gap-1">
                        <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulseDot" />
                        Inserted ✓
                      </span>
                    </div>
                    <div className="mt-4 text-[14.5px] leading-6 text-ink-900">
                      Hey Sarah — quick follow-up on the Q3 roadmap. We&apos;ve aligned on the new onboarding flow and
                      <span className="bg-violet-500/10 rounded px-1"> decided to ship the AI polish feature first</span>. Let me know if
                      you want to sync tomorrow around 10am.
                    </div>
                    <div className="mt-3 flex items-center gap-2 text-xs text-ink-400">
                      <span>Pasted in 0.4s</span>
                      <span>·</span>
                      <span>Auto-edited • filler words removed • Hinglish preserved</span>
                    </div>
                  </div>

                  <div className="mt-3 grid grid-cols-3 gap-2.5">
                    {[
                      { k: "⌥ Space", v: "Hold to talk" },
                      { k: "Fn ×2", v: "Double-tap" },
                      { k: "Auto", v: "Paste at cursor" },
                    ].map((x) => (
                      <div key={x.k} className="rounded-xl bg-white border border-ink-100 px-3 py-2.5 text-center">
                        <div className="text-xs font-semibold text-ink-900">{x.k}</div>
                        <div className="text-[11px] text-ink-400">{x.v}</div>
                      </div>
                    ))}
                  </div>
                </div>

                {/* menu bar tray mock */}
                <div className="bg-ink-900 text-white p-5 sm:p-6 flex flex-col">
                  <div className="flex items-center justify-between">
                    <span className="text-xs font-semibold tracking-widest text-white/60">MENU BAR</span>
                    <span className="w-7 h-7 rounded-full bg-white/10 grid place-items-center">◐</span>
                  </div>
                  <div className="mt-4 rounded-2xl bg-white/[0.06] border border-white/10 p-4 backdrop-blur">
                    <div className="flex items-center gap-2">
                      <span className="w-8 h-8 rounded-xl bg-gradient-to-br from-violet-500 to-aqua-400 grid place-items-center">
                        <Icons.waveform className="w-4 h-4 text-white" />
                      </span>
                      <div>
                        <div className="text-sm font-semibold">WisperVoice</div>
                        <div className="text-xs text-white/60">Ready — press ⌥ Space</div>
                      </div>
                      <span className="ml-auto w-2 h-2 rounded-full bg-emerald-400 shadow-[0_0_10px_rgba(52,211,153,0.8)]" />
                    </div>
                    <div className="mt-4 space-y-2 text-xs">
                      <div className="flex items-center justify-between rounded-xl bg-white text-ink-900 px-3 py-2.5 font-medium">
                        <span>● Start Dictation</span>
                        <span className="text-ink-400">⌥ Space</span>
                      </div>
                      <div className="rounded-xl bg-white/5 border border-white/10 px-3 py-2.5">
                        <div className="text-white/60 text-[11px]">Last transcript</div>
                        <div className="text-white/90 leading-5 mt-1 line-clamp-2">
                          “We&apos;ve aligned on the new onboarding flow and decided to ship the AI polish…”
                        </div>
                        <div className="mt-2 flex gap-1.5">
                          <button className="rounded-full bg-white text-ink-900 text-[11px] font-semibold px-3 py-1">Copy</button>
                          <button className="rounded-full bg-white/10 text-white text-[11px] font-medium px-3 py-1 border border-white/10">
                            Paste again
                          </button>
                        </div>
                      </div>
                    </div>
                  </div>
                  <div className="mt-4 flex items-center gap-2 text-[11px] text-white/50">
                    <Icons.shield className="w-3.5 h-3.5" />
                    Works in every app — Notion, Slack, Xcode, Gmail
                  </div>
                </div>
              </div>
            </div>
          </div>

          {/* floating feature chips */}
          <div className="hidden lg:flex absolute -left-6 top-24 glass rounded-2xl px-3 py-2.5 shadow-card items-center gap-2.5 rotate-[-1deg]">
            <span className="w-8 h-8 rounded-xl bg-emerald-500 grid place-items-center text-white">
              <Icons.check className="w-4 h-4" />
            </span>
            <div className="text-xs leading-tight">
              <div className="font-semibold text-ink-900">Filler words removed</div>
              <div className="text-ink-500">um, uh, like — gone</div>
            </div>
          </div>
          <div className="hidden lg:flex absolute -right-6 bottom-16 glass rounded-2xl px-3 py-2.5 shadow-card items-center gap-2.5 rotate-[1deg]">
            <span className="w-8 h-8 rounded-xl bg-gradient-to-br from-violet-500 to-violet-600 grid place-items-center text-white text-xs font-bold">
              हि
            </span>
            <div className="text-xs leading-tight">
              <div className="font-semibold text-ink-900">Hinglish — preserved</div>
              <div className="text-ink-500">100+ languages</div>
            </div>
          </div>
        </div>

        {/* logos */}
        <div className="mt-10 flex flex-wrap items-center justify-center gap-6 sm:gap-10 opacity-60">
          <span className="text-xs font-semibold tracking-[0.14em] text-ink-400">AS SEEN IN</span>
          {["Product Hunt #1", "Hacker News", "r/MacApps", "Superhuman fans"].map((t) => (
            <span key={t} className="text-sm font-semibold tracking-tight text-ink-500">
              {t}
            </span>
          ))}
        </div>
      </div>
    </section>
  );
}

// ─── Features ───
const FEATURES = [
  {
    icon: Icons.bolt,
    title: "System-wide hotkey",
    desc: "Hold ⌥ Space or double-tap Fn from anywhere. A floating glass pill appears — speak, release, done.",
    accent: "from-violet-500 to-violet-600",
    badge: "0.2s to appear",
  },
  {
    icon: Icons.sparkle,
    title: "AI polish, on by default",
    desc: "Removes filler words, fixes punctuation, and optionally polishes with gpt-4o-mini — Hinglish intact.",
    accent: "from-amber-400 to-orange-500",
    badge: "Auto-edits",
  },
  {
    icon: Icons.globe,
    title: "100+ languages & Hinglish",
    desc: "Apple Speech for free on-device dictation plus OpenAI Whisper with language passthrough.",
    accent: "from-aqua-400 to-teal-500",
    badge: "hi-IN → en-IN",
  },
  {
    icon: Icons.appWindow,
    title: "Works in every app",
    desc: "Paste at cursor via Accessibility API with clipboard + ⌘V fallback. Slack, Notion, Xcode, Gmail — all of them.",
    accent: "from-pink-500 to-rose-500",
    badge: "Any text field",
  },
  {
    icon: Icons.shield,
    title: "Private by design",
    desc: "Apple Speech runs on-device. Whisper via your own API key. No account, no cloud copy, no training on your voice.",
    accent: "from-emerald-500 to-teal-600",
    badge: "On-device first",
  },
  {
    icon: Icons.waveform,
    title: "Local Whisper models",
    desc: "Download tiny / base / small ggml models to Application Support. Transcribe offline with no API key.",
    accent: "from-ink-700 to-ink-900",
    badge: "Offline",
  },
];

function Features() {
  return (
    <section id="features" className="py-16 sm:py-24 bg-white">
      <div className="mx-auto max-w-[1120px] px-4 sm:px-6">
        <div className="max-w-[640px]">
          <div className="inline-flex items-center gap-2 rounded-full bg-ink-900 text-white text-[11px] font-bold tracking-widest px-3 py-1">
            <span className="w-1.5 h-1.5 rounded-full bg-aqua-400 animate-pulseDot" />
            FEATURES
          </div>
          <h2 className="mt-4 font-display font-bold tracking-[-0.03em] text-[28px] sm:text-[40px] leading-[0.95] text-ink-900">
            Everything Wispr Flow does.
            <br />
            <span className="text-ink-400">Native on Mac. No Electron.</span>
          </h2>
          <p className="mt-3 text-[15px] leading-6 text-ink-500">
            WisperVoice mirrors the Wispr Flow experience — the same magic, built with SwiftUI, AVAudioEngine, and a floating
            NSWindow that feels like part of macOS.
          </p>
        </div>

        <div className="mt-10 grid sm:grid-cols-2 lg:grid-cols-3 gap-4 sm:gap-5">
          {FEATURES.map((f) => (
            <div
              key={f.title}
              className="group relative rounded-[20px] bg-ink-50/60 border border-ink-100 p-5 sm:p-6 hover:bg-white hover:shadow-cardHover hover:-translate-y-0.5 transition-all duration-300"
            >
              <div className={`w-10 h-10 rounded-xl bg-gradient-to-br ${f.accent} grid place-items-center text-white shadow-sm`}>
                <f.icon className="w-5 h-5" />
              </div>
              <div className="absolute top-5 right-5 hidden sm:inline-flex rounded-full bg-white border border-ink-100 text-[11px] font-semibold tracking-wide text-ink-500 px-2.5 py-1">
                {f.badge}
              </div>
              <h3 className="mt-4 font-semibold text-[15px] text-ink-900">{f.title}</h3>
              <p className="mt-1.5 text-[13.5px] leading-6 text-ink-500">{f.desc}</p>
              <div className="mt-4 flex items-center gap-1 text-xs font-semibold text-ink-900 opacity-0 group-hover:opacity-100 transition">
                Learn more <Icons.arrowRight className="w-3 h-3" />
              </div>
            </div>
          ))}
        </div>

        {/* parity strip */}
        <div className="mt-6 rounded-2xl bg-ink-900 text-white p-4 sm:p-5 flex flex-col sm:flex-row items-start sm:items-center gap-4">
          <div className="flex items-center gap-3">
            <span className="w-9 h-9 rounded-xl bg-white/10 grid place-items-center">⌘</span>
            <div>
              <div className="text-sm font-semibold">Wispr Flow parity — open source</div>
              <div className="text-xs text-white/60">OverlayWindow · AX paste · History · Launch at Login · Live transcript</div>
            </div>
          </div>
          <a
            href="https://github.com"
            target="_blank"
            rel="noreferrer"
            className="sm:ml-auto inline-flex items-center gap-2 rounded-full bg-white text-ink-900 text-xs font-semibold px-4 py-2 hover:bg-ink-50 transition"
          >
            View on GitHub <Icons.arrowRight className="w-3 h-3" />
          </a>
        </div>
      </div>
    </section>
  );
}

// ─── Demo ───
function Demo() {
  const [playing, setPlaying] = useState(false);
  const videoRef = useRef(null);
  return (
    <section id="demo" className="py-16 sm:py-24 bg-ink-50/70 border-y border-ink-100">
      <div className="mx-auto max-w-[1120px] px-4 sm:px-6">
        <div className="grid lg:grid-cols-[0.95fr_1.05fr] gap-8 lg:gap-10 items-center">
          <div>
            <div className="inline-flex items-center gap-2 rounded-full bg-white border border-ink-200 text-[11px] font-bold tracking-widest text-ink-600 px-3 py-1">
              <span className="w-2 h-2 rounded-full bg-red-500 animate-pulseDot" />
              LIVE DEMO
            </div>
            <h2 className="mt-4 font-display font-bold tracking-[-0.03em] text-[28px] sm:text-[36px] leading-[0.95] text-ink-900">
              See the pill.
              <br />
              <span className="text-ink-400">Hear the speed.</span>
            </h2>
            <p className="mt-3 text-[15px] leading-6 text-ink-500">
              From hotkey to pasted text in under a second. The pill floats above all spaces, shows live transcript, and pastes at
              your cursor — no window switching.
            </p>
            <ul className="mt-6 space-y-3">
              {[
                "Press ⌥ Space → pill appears instantly (NSWindow .floating)",
                "Live transcript via SFSpeechAudioBufferRecognitionRequest",
                "Release → polish → AX paste. Works in Figma, too.",
              ].map((t) => (
                <li key={t} className="flex gap-2.5 text-sm leading-5 text-ink-700">
                  <span className="mt-0.5 w-5 h-5 rounded-full bg-emerald-500 grid place-items-center text-white shrink-0">
                    <Icons.check className="w-3 h-3" />
                  </span>
                  {t}
                </li>
              ))}
            </ul>
            <div className="mt-6 flex gap-2.5">
              <a href="#download" className="inline-flex items-center gap-2 rounded-full bg-ink-900 text-white text-sm font-semibold px-5 py-2.5">
                Try it now <Icons.arrowRight className="w-3.5 h-3.5" />
              </a>
              <span className="inline-flex items-center rounded-full bg-white border border-ink-200 text-xs font-medium text-ink-600 px-3 py-2">
                45 sec · no signup
              </span>
            </div>
          </div>

          {/* video placeholder */}
          <div className="relative">
            <div className="rounded-[24px] bg-ink-900 p-2 sm:p-3 shadow-[0_24px_64px_rgba(15,17,26,0.24)]">
              <div className="rounded-[18px] overflow-hidden bg-gradient-to-br from-ink-800 to-ink-900 border border-white/10 relative aspect-[16/10] grid place-items-center">
                {/* fake waveform bg */}
                <div className="absolute inset-0 opacity-30">
                  <div className="absolute inset-0" style={{ background: "radial-gradient(600px 300px at 50% 0%, rgba(124,92,252,0.35), transparent 70%)" }} />
                </div>

                {!playing ? (
                  <button
                    onClick={() => setPlaying(true)}
                    className="relative z-10 group flex flex-col items-center gap-3"
                    aria-label="Play demo"
                  >
                    <span className="w-16 h-16 rounded-full bg-white grid place-items-center shadow-xl group-hover:scale-105 transition">
                      <Icons.play className="w-6 h-6 text-ink-900 ml-0.5" />
                    </span>
                    <span className="text-white/80 text-xs font-medium tracking-wide">Click to play — real WisperVoice capture</span>
                    <span className="flex items-end gap-1 h-8">
                      {[10, 22, 14, 28, 12, 20, 9, 18].map((h, i) => (
                        <span key={i} className="w-1.5 rounded-full bg-white/60" style={{ height: h }} />
                      ))}
                    </span>
                  </button>
                ) : (
                  <div ref={videoRef} className="relative z-10 w-full h-full grid place-items-center p-6">
                    <div className="w-full max-w-[520px] rounded-2xl bg-white p-4 shadow-xl">
                      <div className="flex items-center gap-2 text-xs font-semibold text-ink-500">
                        <span className="w-2 h-2 rounded-full bg-red-500 animate-pulseDot" />
                        Demo playing — press ⌥ Space in any app to try for real
                      </div>
                      <div className="mt-3 h-2 rounded-full bg-ink-100 overflow-hidden">
                        <div className="h-full w-[62%] bg-gradient-to-r from-violet-500 to-aqua-400 rounded-full animate-[shimmer_1.2s_ease-in-out_infinite]" />
                      </div>
                      <div className="mt-3 text-sm leading-6 text-ink-900">
                        “Hey team, let&apos;s move the design review to Thursday — I&apos;ll share the updated specs in Notion right after
                        this.”
                      </div>
                      <button onClick={() => setPlaying(false)} className="mt-3 text-xs font-medium text-ink-500 hover:text-ink-900">
                        ↺ Replay placeholder
                      </button>
                    </div>
                  </div>
                )}

                {/* bottom pill replay */}
                <div className="absolute bottom-3 left-1/2 -translate-x-1/2 flex items-center gap-2 rounded-full bg-white/95 backdrop-blur border border-white/60 shadow-pill px-3 py-1.5">
                  <span className="w-1.5 h-1.5 rounded-full bg-emerald-500" />
                  <span className="text-[11px] font-semibold text-ink-900">Transcribed in 0.6s</span>
                  <span className="text-[11px] text-ink-500">· Pasted at cursor ✓</span>
                </div>
              </div>
              <div className="flex items-center justify-between px-2 pt-2.5 text-[11px] text-white/50">
                <span>wispervoice.ai/demo.mp4 — 45s · 1080p</span>
                <span className="hidden sm:inline">No audio capture stored</span>
              </div>
            </div>

            {/* caption card */}
            <div className="mt-3 rounded-2xl bg-white border border-ink-100 p-3 flex items-center gap-3 shadow-sm">
              <span className="w-8 h-8 rounded-xl bg-ink-900 text-white grid place-items-center text-xs font-bold">A</span>
              <div className="text-xs">
                <div className="font-semibold text-ink-900">Replace with your screen recording</div>
                <div className="text-ink-500">Drop a .mp4 at <code className="bg-ink-50 border border-ink-100 rounded px-1 py-0.5">/public/demo.mp4</code> and swap this div for a &lt;video&gt;.</div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}

// ─── How it works ───
function HowItWorks() {
  const steps = [
    {
      n: "01",
      title: "Hold. Speak. Release.",
      desc: "Press ⌥ Space (or double-tap Fn) anywhere. The glass pill appears at the bottom-center, above all spaces.",
      detail: "NSWindow .floating · canJoinAllSpaces · ultraThinMaterial",
    },
    {
      n: "02",
      title: "We clean & polish",
      desc: "Filler words removed, punctuation fixed, Hinglish preserved. Optional gpt-4o-mini polish in ~300ms.",
      detail: "polish() + gpt-4o-mini · language passthrough",
    },
    {
      n: "03",
      title: "Pasted where you type",
      desc: "Text lands at your cursor via AX. If an app blocks AX, we fall back to clipboard + synthetic ⌘V.",
      detail: "AXSelectedText → pasteboard + CGEvent",
    },
  ];
  return (
    <section id="how" className="py-16 sm:py-24 bg-white">
      <div className="mx-auto max-w-[1120px] px-4 sm:px-6">
        <div className="flex flex-col lg:flex-row lg:items-end justify-between gap-4">
          <div>
            <div className="inline-flex rounded-full bg-violet-500/10 text-violet-700 text-[11px] font-bold tracking-widest px-3 py-1">HOW IT WORKS</div>
            <h2 className="mt-3 font-display font-bold tracking-[-0.03em] text-[28px] sm:text-[36px] leading-none text-ink-900">Three steps. Zero friction.</h2>
          </div>
          <p className="text-sm leading-6 text-ink-500 max-w-[420px]">
            Inspired by exploreswiftui.com — precise, glassy, and fast. Every detail mirrors a native Mac interaction.
          </p>
        </div>

        <div className="mt-10 grid md:grid-cols-3 gap-4 sm:gap-5">
          {steps.map((s) => (
            <div key={s.n} className="relative rounded-[20px] bg-ink-900 text-white p-6 overflow-hidden">
              <div className="absolute -top-10 -right-10 w-40 h-40 rounded-full bg-gradient-to-br from-violet-500/30 to-aqua-400/20 blur-2xl" />
              <div className="text-[11px] font-bold tracking-[0.18em] text-white/40">{s.n}</div>
              <h3 className="mt-2 font-semibold text-[17px] leading-tight">{s.title}</h3>
              <p className="mt-2 text-sm leading-6 text-white/70">{s.desc}</p>
              <div className="mt-4 inline-flex rounded-full bg-white/10 border border-white/10 text-[11px] font-mono text-white/70 px-2.5 py-1">
                {s.detail}
              </div>
            </div>
          ))}
        </div>

        <div className="mt-6 grid sm:grid-cols-3 gap-3 text-xs">
          {[
            { k: "Audio", v: "AVAudioEngine → 16kHz mono WAV in tmp/" },
            { k: "Providers", v: "Apple Speech (free) · Whisper API · local ggml" },
            { k: "History", v: "Last transcript + 8-item tray · 100 stored" },
          ].map((x) => (
            <div key={x.k} className="rounded-2xl bg-ink-50 border border-ink-100 px-4 py-3 flex gap-3">
              <span className="font-semibold text-ink-900">{x.k}</span>
              <span className="text-ink-500">{x.v}</span>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

// ─── Pricing ───
function Pricing() {
  const [annual, setAnnual] = useState(true);
  return (
    <section id="pricing" className="py-16 sm:py-24 bg-ink-50/60 border-y border-ink-100">
      <div className="mx-auto max-w-[1120px] px-4 sm:px-6">
        <div className="text-center max-w-[640px] mx-auto">
          <div className="inline-flex rounded-full bg-ink-900 text-white text-[11px] font-bold tracking-widest px-3 py-1">PRICING</div>
          <h2 className="mt-3 font-display font-bold tracking-[-0.03em] text-[28px] sm:text-[40px] leading-none text-ink-900">
            Free to start.
            <br />
            <span className="text-ink-400">Pro when you need more.</span>
          </h2>
          <p className="mt-3 text-sm leading-6 text-ink-500">One-time download. No subscription required for core dictation. Bring your own OpenAI key for Whisper & polish.</p>

          <div className="mt-6 inline-flex items-center rounded-full bg-ink-900 p-1 text-xs font-medium">
            <button
              onClick={() => setAnnual(false)}
              className={`rounded-full px-4 py-1.5 transition ${!annual ? "bg-white text-ink-900 shadow" : "text-white/70"}`}
            >
              Monthly
            </button>
            <button
              onClick={() => setAnnual(true)}
              className={`rounded-full px-4 py-1.5 transition ${annual ? "bg-white text-ink-900 shadow" : "text-white/70"}`}
            >
              Annual <span className="ml-1 rounded-full bg-emerald-500 text-white text-[10px] font-bold px-1.5 py-0.5">−20%</span>
            </button>
          </div>
        </div>

        <div className="mt-10 grid lg:grid-cols-3 gap-4 sm:gap-5 max-w-[1020px] mx-auto">
          {/* Free */}
          <div className="rounded-[24px] bg-white border border-ink-100 p-6 sm:p-7 shadow-card">
            <div className="text-xs font-bold tracking-widest text-ink-400">FREE</div>
            <div className="mt-2 flex items-baseline gap-1">
              <span className="text-[36px] font-extrabold tracking-tight text-ink-900">$0</span>
              <span className="text-sm text-ink-400">forever</span>
            </div>
            <p className="mt-2 text-sm leading-5 text-ink-500">Perfect for trying WisperVoice in your daily workflow.</p>
            <a href="#download" className="mt-5 flex items-center justify-center rounded-full bg-ink-900 text-white text-sm font-semibold py-3 hover:bg-black transition">
              Download free
            </a>
            <ul className="mt-6 space-y-2.5 text-sm text-ink-700">
              {[
                "Apple Speech (on-device, 100+ languages)",
                "System hotkey ⌥ Space + Fn×2",
                "Floating pill + live transcript",
                "Filler-word cleanup + history (100)",
                "Works in every Mac app",
              ].map((t) => (
                <li key={t} className="flex gap-2">
                  <span className="mt-0.5 w-5 h-5 rounded-full bg-ink-900 text-white grid place-items-center shrink-0">
                    <Icons.check className="w-3 h-3" />
                  </span>
                  {t}
                </li>
              ))}
            </ul>
          </div>

          {/* Pro — featured */}
          <div className="rounded-[24px] bg-ink-900 text-white p-6 sm:p-7 shadow-[0_24px_64px_rgba(15,17,26,0.28)] relative overflow-hidden lg:scale-[1.02] lg:-mt-2">
            <div className="absolute inset-0 bg-gradient-to-br from-violet-600/20 via-transparent to-aqua-400/10 pointer-events-none" />
            <div className="relative">
              <div className="inline-flex items-center gap-1.5 rounded-full bg-white text-ink-900 text-[11px] font-bold tracking-wide px-2.5 py-1">
                <Icons.sparkle className="w-3 h-3" />
                PRO · MOST POPULAR
              </div>
              <div className="mt-3 flex items-baseline gap-1.5">
                <span className="text-[36px] font-extrabold tracking-tight">${annual ? "8" : "10"}</span>
                <span className="text-sm text-white/60">/ month</span>
                {annual && <span className="ml-2 text-xs text-white/50 line-through">$10</span>}
              </div>
              <p className="mt-1 text-sm leading-5 text-white/60">For power users who dictate all day.</p>
              <a href="#download" className="mt-5 flex items-center justify-center rounded-full bg-white text-ink-900 text-sm font-semibold py-3 hover:bg-ink-50 transition">
                Get Pro — 14-day trial
              </a>
              <ul className="mt-6 space-y-2.5 text-sm text-white/90">
                {[
                  "Everything in Free, plus:",
                  "OpenAI Whisper + gpt-4o-mini polish",
                  "Local Whisper models (offline)",
                  "Custom vocabulary & per-app formatting",
                  "Priority support + early features",
                ].map((t, i) => (
                  <li key={t} className="flex gap-2">
                    <span className={`mt-0.5 w-5 h-5 rounded-full grid place-items-center shrink-0 ${i === 0 ? "bg-white/15 text-white" : "bg-white text-ink-900"}`}>
                      <Icons.check className="w-3 h-3" />
                    </span>
                    <span className={i === 0 ? "font-semibold text-white" : ""}>{t}</span>
                  </li>
                ))}
              </ul>
              <div className="mt-5 rounded-xl bg-white/10 border border-white/10 px-3 py-2.5 text-xs text-white/70">
                Bring your own OpenAI key — you pay OpenAI directly, we add no markup.
              </div>
            </div>
          </div>

          {/* Comparison */}
          <div className="rounded-[24px] bg-white border border-ink-100 p-6 sm:p-7">
            <div className="text-xs font-bold tracking-widest text-ink-400">VS WISPR FLOW</div>
            <h3 className="mt-2 font-semibold text-ink-900">How we compare</h3>
            <p className="mt-1 text-xs leading-5 text-ink-500">Wispr Flow is $12/mo. WisperVoice is free & open-source.</p>
            <div className="mt-5 space-y-2.5 text-sm">
              {[
                { label: "Works in every app", us: true, them: true },
                { label: "Floating pill overlay", us: true, them: true },
                { label: "100+ languages", us: true, them: true },
                { label: "On-device (no cloud)", us: true, them: false },
                { label: "Open source", us: true, them: false },
                { label: "One-time / free tier", us: true, them: false },
              ].map((r) => (
                <div key={r.label} className="flex items-center justify-between rounded-xl bg-ink-50 px-3 py-2">
                  <span className="text-ink-700 text-[13px]">{r.label}</span>
                  <span className="flex items-center gap-3 text-xs">
                    <span className={`w-6 h-6 rounded-full grid place-items-center ${r.us ? "bg-emerald-500 text-white" : "bg-ink-200 text-ink-400"}`}>
                      {r.us ? <Icons.check className="w-3.5 h-3.5" /> : <Icons.xmark className="w-3 h-3" />}
                    </span>
                    <span className={`w-6 h-6 rounded-full grid place-items-center ${r.them ? "bg-ink-900 text-white" : "bg-ink-200 text-ink-400"}`}>
                      {r.them ? <Icons.check className="w-3.5 h-3.5" /> : <Icons.xmark className="w-3 h-3" />}
                    </span>
                  </span>
                </div>
              ))}
              <div className="flex justify-between text-[11px] font-semibold tracking-wide text-ink-400 px-3">
                <span>WisperVoice</span>
                <span>Wispr Flow</span>
              </div>
            </div>
          </div>
        </div>

        <p className="mt-6 text-center text-xs text-ink-400">Prices in USD. Pro is optional — core dictation is free forever. Not affiliated with Wispr AI.</p>
      </div>
    </section>
  );
}

// ─── Testimonials ───
const TESTIMONIALS = [
  { name: "Aarav Mehta", role: "Founder, BuildShip", text: "WisperVoice replaced my typing for Slack, Notion, and email. The Hinglish handling is unreal — it keeps my mix intact.", avatar: "A" },
  { name: "Sofia Chen", role: "Product Designer", text: "The pill is so fast I forget it's an app. Double-tap Fn and just talk. My Figma comments are now voice-first.", avatar: "S" },
  { name: "Rahul Verma", role: "Staff Engineer", text: "On-device Apple Speech means I can dictate code comments on a plane. Offline Whisper models are clutch.", avatar: "R" },
  { name: "Maya Patel", role: "Writer", text: "Filler words gone, punctuation perfect. I dictated a 2,000-word draft in 20 minutes. Feels like Superhuman for voice.", avatar: "M" },
  { name: "Daniel Kim", role: "PM, Linear", text: "Finally a Mac dictation app that pastes where my cursor is — not in some separate window. Every app just works.", avatar: "D" },
  { name: "Priya Nair", role: "Researcher", text: "100+ languages and it actually understands my accent. Switched from Wispr Flow and never looked back — it's free.", avatar: "P" },
];

function Testimonials() {
  return (
    <section className="py-16 sm:py-24 bg-white">
      <div className="mx-auto max-w-[1120px] px-4 sm:px-6">
        <div className="flex flex-col sm:flex-row sm:items-end justify-between gap-4">
          <div>
            <div className="inline-flex rounded-full bg-amber-400 text-ink-900 text-[11px] font-bold tracking-widest px-3 py-1">LOVED BY TEAMS</div>
            <h2 className="mt-3 font-display font-bold tracking-[-0.03em] text-[28px] sm:text-[36px] leading-none text-ink-900">Dictation you&apos;ll actually use.</h2>
          </div>
          <div className="flex items-center gap-2 text-sm">
            <span className="text-amber-400">★★★★★</span>
            <span className="font-semibold text-ink-900">4.9/5</span>
            <span className="text-ink-400">· 400+ reviews</span>
          </div>
        </div>

        <div className="mt-8 grid sm:grid-cols-2 lg:grid-cols-3 gap-4 sm:gap-5">
          {TESTIMONIALS.map((t) => (
            <div key={t.name} className="rounded-[20px] bg-ink-50/60 border border-ink-100 p-5 hover:bg-white hover:shadow-card transition">
              <div className="flex gap-0.5 text-amber-400 text-xs">★★★★★</div>
              <p className="mt-3 text-[14px] leading-6 text-ink-700">“{t.text}”</p>
              <div className="mt-4 flex items-center gap-3">
                <span className="w-9 h-9 rounded-full bg-gradient-to-br from-violet-500 to-aqua-400 grid place-items-center text-white text-xs font-bold">
                  {t.avatar}
                </span>
                <div>
                  <div className="text-sm font-semibold text-ink-900">{t.name}</div>
                  <div className="text-xs text-ink-500">{t.role}</div>
                </div>
                <Icons.quote className="ml-auto w-6 h-6 text-ink-200" />
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

// ─── FAQ ───
const FAQS = [
  { q: "Does it work in every app?", a: "Yes. WisperVoice uses the Accessibility API to insert at your cursor. In apps that block AX (some Electron apps), it falls back to clipboard + synthetic ⌘V. Slack, Notion, Xcode, Gmail, Figma — all supported." },
  { q: "Do I need an OpenAI API key?", a: "No. Apple Speech is free and on-device for 100+ languages. Add an OpenAI key in Settings → General to enable Whisper transcription and gpt-4o-mini polish. Local ggml models also work offline with no key." },
  { q: "Is my voice sent to the cloud?", a: "Apple Speech can run on-device (offline). Whisper calls go to OpenAI only if you enable that provider and supply a key — your audio is sent directly to OpenAI, not through our servers. We store no audio." },
  { q: "How is this different from Wispr Flow?", a: "WisperVoice is an open-source Mac-native clone inspired by Wispr Flow. Same hotkey + pill + paste flow, but free for core use, open-source, and with local offline models. Not affiliated with Wispr AI." },
  { q: "What are the system requirements?", a: "macOS 14 Sonoma or later, Apple Silicon or Intel. Microphone + Accessibility permissions required (System Settings → Privacy & Security). No Dock icon — it lives in the menu bar." },
  { q: "Can I customize the hotkey?", a: "Yes — edit Managers/HotkeyManager.swift (keyCode/modifiers). Default is ⌥ Space plus Fn double-tap. The overlay position and filler-word list are also configurable in code." },
];

function FAQ() {
  const [open, setOpen] = useState(0);
  return (
    <section id="faq" className="py-16 sm:py-24 bg-ink-50/60 border-y border-ink-100">
      <div className="mx-auto max-w-[780px] px-4 sm:px-6">
        <div className="text-center">
          <div className="inline-flex rounded-full bg-white border border-ink-200 text-[11px] font-bold tracking-widest text-ink-600 px-3 py-1">FAQ</div>
          <h2 className="mt-3 font-display font-bold tracking-[-0.03em] text-[28px] sm:text-[36px] text-ink-900">Questions, answered.</h2>
          <p className="mt-2 text-sm text-ink-500">Can&apos;t find what you need? <a href="mailto:hello@wispervoice.ai" className="font-medium text-ink-900 underline underline-offset-4">hello@wispervoice.ai</a></p>
        </div>

        <div className="mt-8 rounded-[20px] bg-white border border-ink-100 shadow-card overflow-hidden divide-y divide-ink-100">
          {FAQS.map((f, i) => (
            <div key={f.q}>
              <button
                onClick={() => setOpen(open === i ? -1 : i)}
                className="w-full flex items-center justify-between gap-4 px-5 sm:px-6 py-4 text-left hover:bg-ink-50/60 transition"
              >
                <span className="font-medium text-[14.5px] text-ink-900">{f.q}</span>
                <span className={`w-7 h-7 rounded-full border grid place-items-center shrink-0 transition ${open === i ? "bg-ink-900 text-white border-ink-900" : "bg-white text-ink-500 border-ink-200"}`}>
                  <span className={`transition-transform ${open === i ? "rotate-45" : ""}`}>
                    <Icons.xmark className="w-3.5 h-3.5 rotate-45" />
                  </span>
                </span>
              </button>
              {open === i && <div className="px-5 sm:px-6 pb-4 text-sm leading-6 text-ink-500">{f.a}</div>}
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

// ─── Footer ───
function Footer() {
  return (
    <footer className="bg-ink-900 text-white">
      <div className="mx-auto max-w-[1120px] px-4 sm:px-6 py-12 sm:py-14">
        <div className="flex flex-col lg:flex-row gap-10">
          <div className="lg:w-[360px]">
            <a href="#" className="flex items-center gap-2.5">
              <span className="w-8 h-8 rounded-xl bg-white text-ink-900 grid place-items-center">
                <Icons.waveform className="w-4 h-4" />
              </span>
              <span className="font-semibold tracking-tight">WisperVoice</span>
              <span className="rounded-full bg-white/10 text-white/70 text-[10px] font-semibold tracking-widest px-2 py-0.5">BETA</span>
            </a>
            <p className="mt-3 text-sm leading-6 text-white/60">
              Native Mac dictation — hold hotkey, speak, paste. Open-source Wispr Flow for macOS. Built with SwiftUI.
            </p>
            <div className="mt-5 flex gap-2">
              <a href="#" onClick={(e) => e.preventDefault()} className="inline-flex items-center gap-2 rounded-full bg-white text-ink-900 text-xs font-semibold px-4 py-2">
                <Icons.apple className="w-3.5 h-3.5" />
                Download for Mac
              </a>
              <a href="https://github.com" target="_blank" rel="noreferrer" className="inline-flex items-center gap-2 rounded-full bg-white/10 border border-white/10 text-xs font-medium px-4 py-2">
                GitHub
              </a>
            </div>
            <p className="mt-4 text-xs text-white/40">© {new Date().getFullYear()} WisperVoice. Not affiliated with Wispr AI. MIT licensed.</p>
          </div>

          <div className="flex-1 grid grid-cols-2 sm:grid-cols-4 gap-8 text-sm">
            <div>
              <div className="font-semibold text-white">Product</div>
              <ul className="mt-3 space-y-2 text-white/60">
                <li><a href="#features" className="hover:text-white">Features</a></li>
                <li><a href="#demo" className="hover:text-white">Demo</a></li>
                <li><a href="#pricing" className="hover:text-white">Pricing</a></li>
                <li><a href="#faq" className="hover:text-white">FAQ</a></li>
              </ul>
            </div>
            <div>
              <div className="font-semibold text-white">Resources</div>
              <ul className="mt-3 space-y-2 text-white/60">
                <li><a href="#" className="hover:text-white">Docs</a></li>
                <li><a href="#" className="hover:text-white">Changelog</a></li>
                <li><a href="#" className="hover:text-white">Roadmap</a></li>
                <li><a href="#" className="hover:text-white">Support</a></li>
              </ul>
            </div>
            <div>
              <div className="font-semibold text-white">Developers</div>
              <ul className="mt-3 space-y-2 text-white/60">
                <li><a href="https://github.com" target="_blank" rel="noreferrer" className="hover:text-white">GitHub</a></li>
                <li><a href="#" className="hover:text-white">Contributing</a></li>
                <li><a href="#" className="hover:text-white">Architecture</a></li>
                <li><a href="#" className="hover:text-white">Releases</a></li>
              </ul>
            </div>
            <div>
              <div className="font-semibold text-white">Legal</div>
              <ul className="mt-3 space-y-2 text-white/60">
                <li><a href="#" className="hover:text-white">Privacy</a></li>
                <li><a href="#" className="hover:text-white">Terms</a></li>
                <li><a href="#" className="hover:text-white">Contact</a></li>
              </ul>
            </div>
          </div>
        </div>

        <div className="mt-10 pt-6 border-t border-white/10 flex flex-col sm:flex-row items-center justify-between gap-3 text-xs text-white/40">
          <span>Crafted with SwiftUI · AVAudioEngine · SFSpeech · Whisper · CGEvent</span>
          <span className="inline-flex items-center gap-2">
            <span className="w-2 h-2 rounded-full bg-emerald-400" />
            All systems operational
          </span>
        </div>
      </div>
    </footer>
  );
}

// ─── App ───
export default function App() {
  return (
    <div className="min-h-screen bg-[#fcfcfe]">
      <Nav />
      <Hero />
      <Features />
      <Demo />
      <HowItWorks />
      <Pricing />
      <Testimonials />
      <FAQ />
      <Footer />
    </div>
  );
}
