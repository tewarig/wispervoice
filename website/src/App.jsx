import { useState, useEffect, useRef } from "react";
import {
  Mic,
  Check,
  ArrowRight,
  Menu,
  X,
  Play,
  Sparkles,
  ShieldCheck,
  Globe,
  Zap,
  AudioLines,
  Command,
  Star,
  Sun,
  Moon,
  Monitor,
} from "lucide-react";

function GithubIcon({ className = "", ...props }) {
  return (
    <svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true" className={className} {...props}>
      <path d="M12 .297c-6.63 0-12 5.373-12 12 0 5.303 3.438 9.8 8.205 11.385.6.113.82-.258.82-.577 0-.285-.01-1.04-.015-2.04-3.338.724-4.042-1.61-4.042-1.61C4.422 18.07 3.633 17.7 3.633 17.7c-1.087-.744.084-.729.084-.729 1.205.084 1.838 1.236 1.838 1.236 1.07 1.835 2.809 1.305 3.495.998.108-.776.417-1.305.76-1.605-2.665-.3-5.466-1.332-5.466-5.93 0-1.31.465-2.38 1.235-3.22-.135-.303-.54-1.523.105-3.176 0 0 1.005-.322 3.3 1.23.96-.267 1.98-.399 3-.405 1.02.006 2.04.138 3 .405 2.28-1.552 3.285-1.23 3.285-1.23.645 1.653.24 2.873.12 3.176.765.84 1.23 1.91 1.23 3.22 0 4.61-2.805 5.625-5.475 5.92.42.36.81 1.096.81 2.22 0 1.606-.015 2.896-.015 3.286 0 .315.21.69.825.57C20.565 22.092 24 17.592 24 12.297c0-6.627-5.373-12-12-12" />
    </svg>
  );
}

// Precise half-eaten Apple — filled silhouette (Font Awesome Apple, 384×512) — scaled to currentColor
function AppleIcon({ className = "", ...props }) {
  return (
    <svg viewBox="0 0 384 512" fill="currentColor" aria-hidden="true" className={className} {...props}>
      <path d="M318.7 268.7c-.2-36.7 16.4-64.4 50-84.8-18.8-26.9-47.2-41.7-84.7-44.6-35.5-2.8-74.3 20.7-88.5 20.7-15 0-49.4-19.7-76.4-19.7C63.3 141.2 4 184.8 4 273.5q0 39.3 14.4 81.2c12.8 36.7 59 126.7 107.2 125.2 25.2-.6 43-17.9 75.8-17.9 31.8 0 48.3 17.9 76.4 17.9 48.6-.6 90.4-82.5 102.6-119.3-65.2-30.7-61.7-90-61.7-91.9zm-56.6-164.2c27.3-32.4 24.8-61.9 24-72.5-24.1 1.4-52 16.4-67.9 34.9-17.5 19.8-27.8 44.3-25.6 71.9 26.1 2 49.9-11.4 69.5-34.3z" />
    </svg>
  );
}

// ─── Subtle reveal on scroll — IntersectionObserver, once ───
function Reveal({ children, delay = 0, className = "" }) {
  const ref = useRef(null);
  const [visible, setVisible] = useState(false);
  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      setVisible(true);
      return;
    }
    const obs = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          setVisible(true);
          obs.disconnect();
        }
      },
      { threshold: 0.12, rootMargin: "0px 0px -40px 0px" }
    );
    obs.observe(el);
    return () => obs.disconnect();
  }, []);
  return (
    <div
      ref={ref}
      className={className}
      style={{
        opacity: visible ? 1 : 0,
        transform: visible ? "translateY(0)" : "translateY(8px)",
        transition: `opacity 560ms cubic-bezier(0.16,1,0.3,1) ${delay}ms, transform 560ms cubic-bezier(0.16,1,0.3,1) ${delay}ms`,
      }}
    >
      {children}
    </div>
  );
}

// ─── Shared primitives — DRY + More-is-Less ───
const NAV_LINKS = [
  { label: "Features", href: "#features" },
  { label: "How it works", href: "#how" },
  { label: "Demo", href: "#demo" },
  { label: "FAQ", href: "#faq" },
];
const APPS = ["Notion", "Slack", "Xcode", "Gmail", "Figma"];
const LANGS = ["EN", "HI", "ES", "JA", "FR", "DE"];

function Kicker({ children }) {
  return <div className="metallic-pill inline-flex rounded-full px-3 py-1 text-[11px] font-semibold tracking-widest text-ink-600">{children}</div>;
}
function Pill({ children, className = "" }) {
  return <span className={`metallic-pill rounded-full px-3 py-1 text-xs font-medium text-ink-600 ${className}`}>{children}</span>;
}
function Card({ children, className = "", hover = true }) {
  return <div className={`metallic-card rounded-[24px] ${hover ? "hover:shadow-pill" : ""} ${className}`}>{children}</div>;
}
function IconBadge({ children }) {
  return <span className="grid h-9 w-9 shrink-0 place-items-center rounded-xl bg-ink-900 text-white">{children}</span>;
}
function GitHubStars({ stars, status }) {
  return (
    <span className={`inline-flex items-center gap-1 ${status === "loading" ? "opacity-60" : "opacity-100"} transition-opacity duration-200`} aria-live="polite" aria-busy={status === "loading"}>
      <Star className="h-3.5 w-3.5 shrink-0 text-ink-400" strokeWidth={1.7} aria-hidden="true" />
      <span className="min-w-[2ch] text-center font-mono text-xs font-semibold tracking-tight text-ink-900 tabular-nums">{formatStars(stars)}</span>
    </span>
  );
}

// ─── Nav ───
const GITHUB_REPO = "tewarig/wispervoice";
const GITHUB_API = `https://api.github.com/repos/${GITHUB_REPO}`;
const GH_CACHE_KEY = "wv_gh_stars";
const GH_CACHE_TS_KEY = "wv_gh_stars_ts";
const GH_CACHE_TTL = 1000 * 60 * 60 * 6; // 6 hours
const GH_FALLBACK_STARS = 87; // graceful static fallback when API unavailable and no cache

function formatStars(n) {
  if (typeof n !== "number" || Number.isNaN(n)) return String(GH_FALLBACK_STARS);
  if (n >= 1000) return `${(n / 1000).toFixed(1).replace(/\.0$/, "")}k`;
  return String(n);
}

function Nav() {
  const [open, setOpen] = useState(false);
  const [scrolled, setScrolled] = useState(false);
  const [stars, setStars] = useState(() => {
    try {
      const c = localStorage.getItem(GH_CACHE_KEY);
      const ts = localStorage.getItem(GH_CACHE_TS_KEY);
      if (c !== null) {
        const v = parseInt(c, 10);
        if (!Number.isNaN(v)) {
          // use cached value immediately (fresh or stale) for instant paint
          return v;
        }
      }
      // no cached value yet — show static fallback until fetch resolves
      void ts;
    } catch {}
    return GH_FALLBACK_STARS;
  });
  const [starsStatus, setStarsStatus] = useState("loading"); // loading | ready | error

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 8);
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  useEffect(() => {
    let cancelled = false;
    const controller = new AbortController();

    // if we have a fresh cache, skip network entirely
    try {
      const c = localStorage.getItem(GH_CACHE_KEY);
      const ts = localStorage.getItem(GH_CACHE_TS_KEY);
      if (c !== null && ts !== null) {
        const age = Date.now() - parseInt(ts, 10);
        if (!Number.isNaN(age) && age < GH_CACHE_TTL) {
          const v = parseInt(c, 10);
          if (!Number.isNaN(v)) {
            setStars(v);
            setStarsStatus("ready");
            return;
          }
        }
      }
    } catch {}

    setStarsStatus("loading");
    fetch(GITHUB_API, {
      headers: { Accept: "application/vnd.github+json" },
      signal: controller.signal,
    })
      .then((r) => {
        if (!r.ok) throw new Error(`GitHub API ${r.status}`);
        return r.json();
      })
      .then((d) => {
        if (cancelled) return;
        if (d && typeof d.stargazers_count === "number") {
          setStars(d.stargazers_count);
          setStarsStatus("ready");
          try {
            localStorage.setItem(GH_CACHE_KEY, String(d.stargazers_count));
            localStorage.setItem(GH_CACHE_TS_KEY, String(Date.now()));
          } catch {}
        } else {
          throw new Error("invalid payload");
        }
      })
      .catch((err) => {
        if (cancelled || err?.name === "AbortError") return;
        setStarsStatus("error");
        // graceful fallback: keep cached value if any, otherwise static count
        try {
          const c = localStorage.getItem(GH_CACHE_KEY);
          if (c !== null) {
            const v = parseInt(c, 10);
            if (!Number.isNaN(v)) {
              setStars(v);
              return;
            }
          }
        } catch {}
        setStars(GH_FALLBACK_STARS);
      });

    return () => {
      cancelled = true;
      controller.abort();
    };
  }, []);
  return (
    <header
      className={`fixed inset-x-0 top-0 z-50 border-b transition-all duration-200 ease-out ${
        scrolled ? "glass-nav glass-nav--scrolled" : "border-transparent bg-white/0"
      }`}
    >
      <div className="mx-auto max-w-[1040px] px-5 sm:px-6">
        <div className="flex h-[64px] items-center justify-between">
          <a href="#" className="group flex items-center gap-2.5">
            <span className="grid h-8 w-8 place-items-center rounded-lg bg-ink-900 text-white transition-colors duration-200 group-hover:bg-ink-800">
              <Mic className="h-4 w-4" strokeWidth={1.9} />
            </span>
            <span className="text-[15px] font-semibold tracking-tight text-ink-900">WisperVoice</span>
            <span className="metallic-pill hidden sm:inline-flex rounded-full px-2 py-0.5 text-[10px] font-semibold tracking-widest text-ink-600">
              BETA
            </span>
          </a>

          <nav className="hidden items-center gap-7 md:flex">
            {NAV_LINKS.map((l) => (
              <a key={l.label} href={l.href} className="text-[13.5px] font-medium text-ink-600 transition-colors duration-200 hover:text-ink-900">
                {l.label}
              </a>
            ))}
          </nav>

          <div className="hidden items-center gap-3 md:flex">
            <a
              href="https://github.com/tewarig/wispervoice"
              target="_blank"
              rel="noreferrer"
              aria-label={`GitHub — ${formatStars(stars)} stars`}
              title={`GitHub — ${formatStars(stars)} stars`}
              className="metallic-pill inline-flex items-center gap-2 rounded-full px-3.5 py-[7px] text-[13px] font-medium text-ink-600 transition-all duration-200 hover:border-ink-300 hover:text-ink-900"
            >
              <GithubIcon className="h-4 w-4 shrink-0 text-ink-900" />
              <span className="hidden sm:inline tracking-tight">GitHub</span>
              <span className="h-3 w-px shrink-0 bg-line" aria-hidden="true" />
              <GitHubStars stars={stars} status={starsStatus} />
            </a>
          </div>

          <button
            onClick={() => setOpen((v) => !v)}
            aria-label="Menu"
            className="metallic-pill grid h-9 w-9 place-items-center rounded-full md:hidden"
          >
            {open ? <X className="h-4 w-4 text-ink-600" strokeWidth={1.8} /> : <Menu className="h-4 w-4 text-ink-600" strokeWidth={1.8} />}
          </button>
        </div>

        {open && (
          <div className="animate-fadeIn border-t border-line py-3 md:hidden">
            <div className="flex flex-col gap-2">
              {NAV_LINKS.map((l) => (
                <a
                  key={l.label}
                  href={l.href}
                  onClick={() => setOpen(false)}
                  className="rounded-xl px-3 py-2.5 text-[14px] font-medium text-ink-600 transition-colors duration-200 hover:bg-surface hover:text-ink-900"
                >
                  {l.label}
                </a>
              ))}
              <a
                href="https://github.com/tewarig/wispervoice"
                target="_blank"
                rel="noreferrer"
                onClick={() => setOpen(false)}
                aria-label={`GitHub — ${formatStars(stars)} stars`}
                className="metallic-pill inline-flex items-center justify-center gap-2 rounded-full px-3.5 py-2.5 text-[13px] font-medium text-ink-600"
              >
                <GithubIcon className="h-4 w-4 shrink-0 text-ink-900" />
                GitHub
                <span className="h-3 w-px shrink-0 bg-line" aria-hidden="true" />
                <GitHubStars stars={stars} status={starsStatus} />
              </a>
              <a
                href="#download"
                onClick={() => setOpen(false)}
                className="metallic-dark inline-flex items-center justify-center gap-2 rounded-full px-4 py-3 text-sm font-semibold text-white"
              >
                <AppleIcon className="h-4 w-4" /> Download for Mac
              </a>
            </div>
          </div>
        )}
      </div>
    </header>
  );
}

// ─── Hero — center blob only, fully static, fixed to viewport center — side blobs removed 2026-08-07 ───
function Hero() {
  return (
    <section className="relative overflow-hidden">
      <div className="relative mx-auto max-w-[1040px] px-5 pb-10 pt-28 sm:px-6 sm:pb-14 sm:pt-36">
        <Reveal className="flex justify-center">
          <a
            href="#features"
            className="metallic-pill group inline-flex items-center gap-2 rounded-full px-3.5 py-1.5 text-[12px] font-medium text-ink-600 transition-all duration-200 hover:border-ink-200"
          >
            <span className="h-1.5 w-1.5 rounded-full bg-violet-600" />
            Free & open source — local Whisper, offline
            <ArrowRight className="h-3 w-3 text-ink-400 transition-transform duration-200 group-hover:translate-x-0.5" strokeWidth={1.8} />
          </a>
        </Reveal>

        <div className="mx-auto mt-8 max-w-[720px] text-center">
          <Reveal delay={60}>
            <h1 className="relative text-[40px] font-[750] leading-[0.92] tracking-[-0.04em] text-ink-900 sm:text-[58px] lg:text-[64px]">
              <span className="hero-glow pointer-events-none absolute left-1/2 top-1/2 -z-10 h-[150%] w-[132%] -translate-x-1/2 -translate-y-1/2 rounded-full bg-gradient-to-r from-violet-200/70 via-violet-100/50 to-violet-200/70 blur-[36px]" />
              Dictate at the
              <br />
              <span className="bg-gradient-to-r from-violet-600 via-violet-500 to-violet-600 bg-clip-text text-transparent">speed of thought.</span>
            </h1>
          </Reveal>
          <Reveal delay={120}>
            <p className="mx-auto mt-5 max-w-[560px] text-[16px] leading-7 text-ink-600 sm:text-[17px]">
              Native Mac dictation that works in <span className="font-medium text-ink-900">every app</span>. Hold{" "}
              <span className="metallic-pill rounded-md px-1.5 py-0.5 font-mono text-xs font-medium text-ink-600">⌥ Space</span> or double-tap{" "}
              <span className="metallic-pill rounded-md px-1.5 py-0.5 font-mono text-xs font-medium text-ink-600">Fn</span>, speak naturally, and watch
              polished text appear at your cursor.
            </p>
          </Reveal>

          <Reveal delay={180}>
            <div id="download" className="mt-8 flex flex-col items-center justify-center gap-3 sm:flex-row">
              <a
                href="#"
                onClick={(e) => e.preventDefault()}
                className="metallic-dark group inline-flex w-full items-center justify-center gap-2.5 rounded-full px-8 py-[14px] text-[15px] font-semibold text-white sm:w-auto"
              >
                <AppleIcon className="h-[15px] w-[13px] transition-transform duration-200 group-hover:scale-105" />
                Download for Mac
                <span className="ml-0.5 text-xs font-normal text-white/60">· Free</span>
              </a>
              <a
                href="https://github.com/tewarig/wispervoice"
                target="_blank"
                rel="noreferrer"
                className="metallic-secondary group inline-flex w-full items-center justify-center gap-2 rounded-full px-7 py-3.5 text-[14.5px] font-semibold text-ink-900 sm:w-auto"
              >
                <GithubIcon className="h-4 w-4" />
                View on GitHub
              </a>
            </div>
          </Reveal>

          <Reveal delay={220}>
            <div className="mt-4 flex flex-wrap items-center justify-center gap-2 text-xs text-ink-400 sm:gap-3">
              <span className="inline-flex items-center gap-1.5">
                <span className="h-1.5 w-1.5 animate-pulseDot rounded-full bg-violet-600" />
                macOS 14+ · Apple Silicon & Intel
              </span>
              <span className="hidden h-3 w-px bg-line sm:block" />
              <span>No account required</span>
              <span className="hidden h-3 w-px bg-line sm:block" />
              <span>On-device & private</span>
            </div>
          </Reveal>
        </div>

        <Reveal delay={260} className="mx-auto mt-10 max-w-[860px] sm:mt-14">
          <div className="relative">
            <div className="metallic-glass absolute left-1/2 top-0 z-10 hidden -translate-x-1/2 -translate-y-1/2 items-center gap-3 rounded-full px-4 py-2.5 sm:flex">
              <span className="grid h-7 w-7 place-items-center rounded-full bg-violet-600 text-white">
                <AudioLines className="h-3.5 w-3.5" strokeWidth={1.9} />
              </span>
              <span className="flex items-center gap-1.5 text-[11px] font-semibold tracking-wide text-ink-900">
                <span className="h-1.5 w-1.5 animate-pulseDot rounded-full bg-violet-600" /> RECORDING
              </span>
              <span className="flex items-end gap-[2px]">
                {[7, 14, 10, 18, 9, 13].map((h, i) => (
                  <span key={i} className="w-[3px] rounded-full bg-ink-900" style={{ height: h, opacity: 0.9 - i * 0.07 }} />
                ))}
              </span>
              <span className="max-w-[260px] truncate text-xs text-ink-600">“Write a follow-up to Sarah about the Q3 roadmap…”</span>
            </div>

            <div className="metallic-card overflow-hidden rounded-[20px] transition-shadow duration-300 hover:shadow-pill sm:rounded-[24px]">
              <div className="flex items-center gap-1.5 border-b border-line bg-surface px-4 py-3">
                <span className="h-3 w-3 rounded-full border border-line bg-white" />
                <span className="h-3 w-3 rounded-full border border-line bg-white" />
                <span className="h-3 w-3 rounded-full border border-line bg-white" />
                <span className="ml-3 hidden text-xs font-medium text-ink-400 sm:inline">Slack · #product — WisperVoice will paste here</span>
                <span className="metallic-pill ml-auto inline-flex items-center gap-1.5 rounded-full px-2.5 py-1 text-[11px] font-medium text-ink-600">
                  <span className="h-1.5 w-1.5 rounded-full bg-violet-600" /> Listening
                </span>
              </div>

              <div className="p-4 sm:p-6">
                <div className="metallic-card rounded-2xl p-4 sm:p-5">
                  <div className="flex items-center gap-2 text-[11px] font-semibold tracking-wide text-ink-600">
                    <span className="grid h-6 w-6 place-items-center rounded-md bg-ink-900 text-white">
                      <Command className="h-3 w-3" strokeWidth={1.8} />
                    </span>
                    SLACK · #product
                    <span className="metallic-pill ml-auto inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-xs font-medium text-violet-600">
                      <span className="h-1.5 w-1.5 rounded-full bg-violet-600" /> Inserted ✓
                    </span>
                  </div>
                  <p className="mt-3 text-[14.5px] leading-6 text-ink-900">
                    Hey Sarah — quick follow-up on the Q3 roadmap. We&apos;ve aligned on the new onboarding flow and{" "}
                    <span className="rounded bg-violet-50 px-1 py-0.5 transition-colors duration-200">decided to ship the AI polish feature first</span>. Let me know if you
                    want to sync tomorrow around 10am.
                  </p>
                  <div className="mt-3 flex flex-wrap items-center gap-2 text-xs text-ink-400">
                    <span>Pasted in 0.4s</span>
                    <span className="h-3 w-px bg-line" />
                    <span>Auto-edited · filler words removed</span>
                  </div>
                </div>

                <div className="mt-4 grid grid-cols-3 gap-2.5">
                  {[
                    { k: "⌥ Space", v: "Hold to talk" },
                    { k: "Fn ×2", v: "Double-tap" },
                    { k: "Auto", v: "Paste at cursor" },
                  ].map((x) => (
                    <div key={x.k} className="metallic-card rounded-xl px-3 py-3 text-center">
                      <div className="text-xs font-semibold text-ink-900">{x.k}</div>
                      <div className="text-[11px] text-ink-600">{x.v}</div>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </div>
        </Reveal>
      </div>
    </section>
  );
}

// ─── Features — editorial bento (4 cards, 6 concepts merged) — DRY via APPS/LANGS + Card ───
function Features() {
  return (
    <section id="features" className="border-y border-line bg-surface">
      <div className="mx-auto max-w-[1040px] px-5 py-16 sm:px-6 sm:py-24">
        <Reveal className="mx-auto max-w-[640px] text-center">
          <Kicker>FEATURES</Kicker>
          <h2 className="mt-4 text-[28px] font-bold leading-[0.95] tracking-[-0.03em] text-ink-900 sm:text-[36px]">
            Everything you need. Nothing you don&apos;t.
          </h2>
          <p className="mt-3 text-[15px] leading-6 text-ink-600">
            Six essentials, four cards. Native feel, on-device privacy, and polish — no extra chrome.
          </p>
        </Reveal>

        {/* Bento — 12-col desktop: [large 8 | tall 4] / [small 4 | small 4 | tall↓] */}
        <div className="mt-12 grid gap-4 sm:gap-5 lg:grid-cols-12 lg:auto-rows-fr">
          {/* Large — Works in every app + 0.2s to appear — uses Card (DRY) */}
          <Reveal delay={0} className="lg:col-span-8">
            <Card className="flex h-full flex-col p-6 sm:p-7 lg:p-8">
              <div className="flex items-start justify-between gap-4">
                <IconBadge>
                  <Zap className="h-5 w-5" strokeWidth={1.7} />
                </IconBadge>
                <span className="metallic-pill hidden items-center gap-1.5 rounded-full px-3 py-1 text-[11px] font-medium text-ink-600 sm:inline-flex">
                  <span className="h-1.5 w-1.5 rounded-full bg-violet-600" />
                  Paste at cursor
                </span>
              </div>

              <h3 className="mt-5 text-[17px] font-semibold tracking-[-0.015em] text-ink-900 sm:text-[18px]">Works in every app</h3>
              <p className="mt-2 max-w-[520px] text-[13.5px] leading-6 text-ink-600">
                Pastes at your cursor via Accessibility API with clipboard + <span className="font-medium text-ink-900">⌘V</span> fallback. Notion,
                Slack, Xcode, Gmail — if it takes text, it works.
              </p>

              <div className="mt-5 flex flex-wrap gap-2">
                {APPS.map((app) => (
                  <Pill key={app}>{app}</Pill>
                ))}
                <span className="px-2 py-1 text-xs text-ink-400">+ any app</span>
              </div>

              <div className="mt-auto border-t border-line pt-5">
                <div className="flex flex-wrap items-center gap-x-3 gap-y-2">
                  <span className="inline-flex items-center gap-2 text-xs font-semibold text-ink-900">
                    <span className="grid h-6 w-6 place-items-center rounded-md bg-ink-900 text-white">
                      <Zap className="h-3.5 w-3.5" strokeWidth={1.8} />
                    </span>
                    0.2s to appear
                  </span>
                  <span className="hidden h-3 w-px bg-line sm:block" />
                  <span className="text-xs leading-5 text-ink-600">
                    NSWindow <span className="font-mono text-[11px] text-ink-500">.floating</span> · canJoinAllSpaces · ultraThinMaterial
                  </span>
                </div>
                <p className="mt-2 text-xs leading-5 text-ink-400">AXSelectedText → clipboard + synthetic ⌘V when AX is blocked.</p>
              </div>
            </Card>
          </Reveal>

          {/* Tall — Private by design + Local Whisper */}
          <Reveal delay={80} className="lg:col-span-4 lg:row-span-2">
            <div className="metallic-card flex h-full flex-col rounded-[24px] p-6 sm:p-7">
              <IconBadge>
                <ShieldCheck className="h-5 w-5" strokeWidth={1.7} />
              </IconBadge>
              <h3 className="mt-4 text-[16px] font-semibold tracking-[-0.015em] text-ink-900">Private by design</h3>
              <p className="mt-2 text-[13.5px] leading-6 text-ink-600">
                Apple Speech runs on-device. Whisper via your own key. No account, no cloud copy, no training on your voice.
              </p>

              <div className="my-5 flex items-center gap-3">
                <span className="h-px flex-1 bg-line" />
                <span className="text-[10px] font-semibold tracking-widest text-ink-400">ON-DEVICE</span>
                <span className="h-px flex-1 bg-line" />
              </div>

              <div className="metallic-pill rounded-2xl p-4">
                <div className="flex items-center gap-2.5">
                  <span className="grid h-7 w-7 place-items-center rounded-lg bg-ink-900 text-white">
                    <Mic className="h-3.5 w-3.5" strokeWidth={1.8} />
                  </span>
                  <span className="text-[13px] font-semibold text-ink-900">Local Whisper</span>
                  <span className="metallic-pill ml-auto rounded-full px-2 py-0.5 text-[10px] font-semibold tracking-widest text-ink-600">
                    OFFLINE
                  </span>
                </div>
                <p className="mt-2.5 text-xs leading-5 text-ink-600">
                  tiny / base / small <span className="font-mono text-[11px] text-ink-500">ggml</span> — no key, no network.
                </p>
                <div className="mt-3 flex flex-wrap gap-1.5">
                  <span className="metallic-pill rounded-full px-2.5 py-1 font-mono text-[11px] font-medium text-ink-600">tiny</span>
                  <span className="metallic-pill rounded-full px-2.5 py-1 font-mono text-[11px] font-medium text-ink-600">base</span>
                  <span className="metallic-pill rounded-full px-2.5 py-1 font-mono text-[11px] font-medium text-ink-600">small</span>
                </div>
              </div>

              <p className="mt-auto pt-5 text-xs leading-5 text-ink-400">Audio never leaves your Mac unless you choose a cloud provider.</p>
            </div>
          </Reveal>

          {/* Small — Polished by AI */}
          <Reveal delay={120} className="lg:col-span-4">
            <div className="metallic-card flex h-full flex-col rounded-[24px] p-6 sm:p-6">
              <IconBadge>
                <Sparkles className="h-5 w-5" strokeWidth={1.7} />
              </IconBadge>
              <h3 className="mt-4 text-[15px] font-semibold tracking-[-0.015em] text-ink-900">Polished by AI</h3>
              <p className="mt-2 text-[13.5px] leading-6 text-ink-600">
                Filler words removed, punctuation fixed, Hinglish preserved. Optional{" "}
                <span className="font-mono text-xs font-medium text-ink-900">gpt-4o-mini</span> in ~300ms.
              </p>
              <div className="metallic-pill mt-5 rounded-xl p-3.5">
                <div className="text-[10px] font-semibold tracking-widest text-ink-400">BEFORE → AFTER</div>
                <p className="mt-2 text-xs leading-5 text-ink-400 line-through decoration-ink-300">“uh so basically like…”</p>
                <p className="text-xs leading-5 text-ink-900">“So basically…” — filler cut, caps fixed.</p>
              </div>
            </div>
          </Reveal>

          {/* Small — 100+ languages */}
          <Reveal delay={180} className="lg:col-span-4">
            <div className="metallic-card flex h-full flex-col rounded-[24px] p-6 sm:p-6">
              <IconBadge>
                <Globe className="h-5 w-5" strokeWidth={1.7} />
              </IconBadge>
              <h3 className="mt-4 text-[15px] font-semibold tracking-[-0.015em] text-ink-900">100+ languages</h3>
              <p className="mt-2 text-[13.5px] leading-6 text-ink-600">Apple Speech + Whisper passthrough. Hinglish intact — switch mid-sentence.</p>
              <div className="mt-5 flex flex-wrap gap-1.5">
                {LANGS.map((code) => (
                  <Pill key={code} className="px-2.5 py-1 text-[11px]">{code}</Pill>
                ))}
                <span className="px-1 py-1 text-[11px] text-ink-400">+96</span>
              </div>
              <div className="mt-4 inline-flex items-center gap-1.5 text-xs text-ink-400">
                <span className="h-1.5 w-1.5 rounded-full bg-violet-600" />
                Apple + Whisper — same transcript
              </div>
            </div>
          </Reveal>
        </div>
      </div>
    </section>
  );
}

// ─── How it works ───
function HowItWorks() {
  const steps = [
    { n: "01", title: "Hold. Speak.", desc: "Press ⌥ Space or double-tap Fn anywhere. The pill appears above all spaces — bottom-center, glass, instant.", mono: "NSWindow .floating" },
    { n: "02", title: "We clean it.", desc: "Filler words cut, punctuation fixed, Hinglish kept. Optional gpt-4o-mini polish in a blink.", mono: "polish() · 300ms" },
    { n: "03", title: "Pasted.", desc: "Text lands at your cursor via AX. If blocked, we fall back to clipboard + synthetic ⌘V.", mono: "AXSelectedText → ⌘V" },
  ];
  return (
    <section id="how" className="bg-white">
      <div className="mx-auto max-w-[1040px] px-5 py-16 sm:px-6 sm:py-24">
        <Reveal className="flex flex-col gap-5 sm:flex-row sm:items-end sm:justify-between">
          <div>
            <Kicker>HOW IT WORKS</Kicker>
            <h2 className="mt-4 text-[28px] font-bold leading-[0.96] tracking-[-0.03em] text-ink-900 sm:text-[34px]">
              Three steps. <span className="font-[300] tracking-[-0.03em] text-ink-400">Zero friction.</span>
            </h2>
          </div>
          <p className="max-w-[340px] text-[14px] leading-6 text-ink-600">
            Built the Mac way — <span className="font-medium text-ink-900">MenuBarExtra</span>, NSStatusItem, and a glass pill that feels native.
          </p>
        </Reveal>

        {/* refined 3-col — white metallic-card + hairline connector */}
        <div className="relative mt-10 sm:mt-12">
          {/* subtle connecting hairline — desktop only, behind cards (visible only in gutters) */}
          <div
            aria-hidden="true"
            className="pointer-events-none absolute left-[calc(16.66%+28px)] right-[calc(16.66%+28px)] top-[39px] hidden h-px bg-line sm:block"
          />

          <div className="grid gap-4 sm:grid-cols-3 sm:gap-5">
            {steps.map((s, i) => (
              <Reveal key={s.n} delay={i * 90}>
                <div className="metallic-card group relative flex min-h-[188px] flex-col overflow-hidden rounded-[20px] p-6 transition-all duration-200 hover:-translate-y-0.5 sm:min-h-[212px] sm:p-7">
                  {/* top row: numbered dot on hairline + metallic mono tag */}
                  <div className="flex items-center justify-between gap-3">
                    <span className="inline-flex items-center gap-2.5">
                      <span
                        aria-hidden="true"
                        className="grid h-[22px] w-[22px] place-items-center rounded-full border border-line bg-white text-[10px] font-medium tracking-wide text-ink-400 shadow-subtle"
                      >
                        <span className="font-mono text-[10px] font-semibold leading-none text-ink-400">{s.n.slice(1)}</span>
                      </span>
                      <span className="hidden h-px w-6 bg-line sm:block" />
                      <span className="font-mono text-[11px] font-medium tracking-[0.14em] text-ink-400">{s.n}</span>
                    </span>
                    <span className="metallic-pill inline-flex shrink-0 rounded-full px-2.5 py-1 font-mono text-[10.5px] font-medium tracking-wide text-ink-600">
                      {s.mono}
                    </span>
                  </div>

                  <h3 className="mt-6 text-[17px] font-semibold tracking-[-0.02em] text-ink-900 sm:text-[18px]">{s.title}</h3>
                  <p className="mt-2 text-[13.5px] leading-6 text-ink-600">{s.desc}</p>

                  {/* ghost number — editorial, ultra-light */}
                  <span
                    aria-hidden="true"
                    className="pointer-events-none absolute bottom-4 right-5 select-none font-mono text-[44px] font-[200] leading-none tracking-[-0.06em] text-ink-900/[0.035] sm:bottom-5 sm:right-6 sm:text-[52px]"
                  >
                    {s.n}
                  </span>
                </div>
              </Reveal>
            ))}
          </div>

          {/* closing hairline + micro-caption — editorial marginalia */}
          <div className="mt-6 flex items-center gap-3 sm:mt-7">
            <div className="h-px flex-1 bg-line" />
            <span className="font-mono text-[10.5px] tracking-[0.12em] text-ink-400">
              HOLD &nbsp;·&nbsp; POLISH &nbsp;·&nbsp; PASTE
            </span>
            <div className="h-px flex-1 bg-line" />
          </div>
        </div>
      </div>
    </section>
  );
}

// ─── Demo ───
function Demo() {
  const [playing, setPlaying] = useState(false);
  return (
    <section id="demo" className="border-y border-line bg-surface">
      <div className="mx-auto max-w-[1040px] px-5 py-16 sm:px-6 sm:py-20">
        <Reveal className="mx-auto max-w-[640px] text-center">
          <Kicker>
            <span className="flex items-center gap-2">
              <span className="h-1.5 w-1.5 animate-pulseDot rounded-full bg-violet-600" /> LIVE DEMO
            </span>
          </Kicker>
          <h2 className="mt-3 text-[28px] font-bold tracking-[-0.03em] text-ink-900 sm:text-[34px]">See the pill. Hear the speed.</h2>
          <p className="mt-2 text-sm leading-6 text-ink-600">From hotkey to pasted text in under a second. No window switching.</p>
        </Reveal>

        <Reveal delay={120} className="mx-auto mt-8 max-w-[760px]">
          <div className="metallic-card overflow-hidden rounded-[20px] p-2 transition-shadow duration-300 hover:shadow-pill">
            <div className="relative aspect-[16/10] overflow-hidden rounded-[14px] bg-ink-900">
              {!playing ? (
                <button onClick={() => setPlaying(true)} className="group absolute inset-0 grid place-items-center" aria-label="Play demo">
                  <div className="absolute inset-0 opacity-40" style={{ background: "radial-gradient(500px 280px at 50% 0%, #7c5cfc 0%, transparent 70%)" }} />
                  <div className="relative flex flex-col items-center gap-3">
                    <span className="metallic-pill grid h-14 w-14 place-items-center rounded-full transition-all duration-200 ease-out group-hover:scale-105">
                      <Play className="ml-0.5 h-5 w-5 text-ink-900" strokeWidth={1.7} fill="none" />
                    </span>
                    <span className="text-xs font-medium tracking-wide text-white/70">45 sec · real capture</span>
                    <span className="flex items-end gap-1">
                      {[9, 18, 12, 24, 10, 16, 8, 14].map((h, i) => (
                        <span key={i} className="w-1 rounded-full bg-white/50" style={{ height: h }} />
                      ))}
                    </span>
                  </div>
                  <span className="metallic-pill absolute bottom-3 left-1/2 flex -translate-x-1/2 items-center gap-2 rounded-full px-3 py-1.5 text-[11px] font-medium text-ink-600">
                    <span className="h-1.5 w-1.5 rounded-full bg-violet-600" /> Transcribed in 0.6s · Pasted ✓
                  </span>
                </button>
              ) : (
                <div className="absolute inset-0 grid place-items-center p-6">
                  <div className="metallic-card w-full max-w-[460px] rounded-2xl p-5">
                    <div className="flex items-center gap-2 text-xs font-medium text-ink-600">
                      <span className="h-1.5 w-1.5 animate-pulseDot rounded-full bg-violet-600" /> Now playing — press ⌥ Space to try for real
                    </div>
                    <div className="mt-3 h-1.5 overflow-hidden rounded-full bg-ink-100">
                      <div className="h-full w-[62%] rounded-full bg-ink-900" />
                    </div>
                    <p className="mt-3 text-sm leading-6 text-ink-900">“Hey team — let’s move the design review to Thursday. I’ll share the updated specs in Notion right after this.”</p>
                    <button onClick={() => setPlaying(false)} className="mt-3 text-xs font-medium text-ink-400 transition-colors duration-200 hover:text-ink-600">
                      ↺ Replay
                    </button>
                  </div>
                </div>
              )}
            </div>
            <div className="flex items-center justify-between px-2 pb-1 pt-2 text-[11px] text-ink-400">
              <span>wispervoice.ai/demo.mp4</span>
              <span className="hidden sm:inline">No audio stored</span>
            </div>
          </div>
          <p className="mt-3 text-center text-xs text-ink-400">
            Replace with your recording at <code className="metallic-pill rounded px-1 py-0.5 font-mono text-ink-600">/public/demo.mp4</code>
          </p>
        </Reveal>
      </div>
    </section>
  );
}

// ─── FAQ ───
const FAQS = [
  { q: "Does it work in every app?", a: "Yes. WisperVoice uses the Accessibility API to insert at your cursor. In apps that block AX (some Electron apps), it falls back to clipboard + synthetic ⌘V. Slack, Notion, Xcode, Gmail, Figma — all supported." },
  { q: "Do I need an OpenAI API key?", a: "No. Apple Speech is free and on-device for 100+ languages. Add an OpenAI key in Settings → General to enable Whisper and gpt-4o-mini polish. Local ggml models also work offline with no key." },
  { q: "Is my voice sent to the cloud?", a: "Apple Speech can run on-device. Whisper calls go to OpenAI only if you enable that provider and supply a key — audio is sent directly to OpenAI, not through our servers. We store no audio." },
  { q: "How is this different from Wispr Flow?", a: "WisperVoice is an open-source Mac-native clone inspired by Wispr Flow. Same hotkey + pill + paste flow, but free, open-source, and with local offline models. Not affiliated with Wispr AI." },
  { q: "What are the requirements?", a: "macOS 14 Sonoma or later, Apple Silicon or Intel. Microphone + Accessibility permissions required. No Dock icon — it lives in the menu bar." },
];

function FAQ() {
  const [open, setOpen] = useState(0);
  return (
    <section id="faq" className="border-y border-line bg-surface">
      <div className="mx-auto max-w-[720px] px-5 py-16 sm:px-6 sm:py-24">
        <Reveal className="text-center">
          <Kicker>FAQ</Kicker>
          <h2 className="mt-3 text-[26px] font-bold tracking-[-0.03em] text-ink-900 sm:text-[30px]">Questions, answered.</h2>
          <p className="mt-2 text-sm text-ink-600">
            Can&apos;t find what you need?{" "}
            <a href="mailto:hello@wispervoice.ai" className="font-medium text-ink-900 underline decoration-line underline-offset-4 transition-colors duration-200 hover:decoration-ink-300">
              hello@wispervoice.ai
            </a>
          </p>
        </Reveal>

        <Reveal delay={100} className="metallic-card mt-8 divide-y divide-line overflow-hidden rounded-[16px]">
          {FAQS.map((f, i) => (
            <div key={f.q} className={open === i ? "bg-white" : ""}>
              <button
                onClick={() => setOpen(open === i ? -1 : i)}
                className="flex w-full items-center justify-between gap-4 px-5 py-4 text-left transition-colors duration-200 hover:bg-surface/60"
              >
                <span className="text-[14px] font-medium text-ink-900">{f.q}</span>
                <span
                  className={`grid h-7 w-7 shrink-0 place-items-center rounded-full border transition-all duration-200 ease-out ${
                    open === i ? "metallic-dark rotate-45 border-ink-900 text-white" : "metallic-pill border-line text-ink-600"
                  }`}
                >
                  <X className="h-3.5 w-3.5 rotate-45" strokeWidth={1.8} />
                </span>
              </button>
              <div
                className={`grid transition-all duration-200 ease-out ${open === i ? "grid-rows-[1fr] opacity-100" : "grid-rows-[0fr] opacity-0"}`}
              >
                <div className="overflow-hidden">
                  <div className="px-5 pb-4 text-sm leading-6 text-ink-600">{f.a}</div>
                </div>
              </div>
            </div>
          ))}
        </Reveal>
      </div>
    </section>
  );
}

// ─── Footer ───
function Footer() {
  return (
    <footer className="bg-white">
      <div className="mx-auto max-w-[1040px] px-5 py-10 sm:px-6 sm:py-12">
        <div className="flex flex-col gap-8 sm:flex-row sm:justify-between">
          <div className="max-w-[320px]">
            <a href="#" className="group flex items-center gap-2">
              <span className="grid h-7 w-7 place-items-center rounded-lg bg-ink-900 text-white transition-colors duration-200 group-hover:bg-ink-800">
                <Mic className="h-3.5 w-3.5" strokeWidth={1.8} />
              </span>
              <span className="text-sm font-semibold tracking-tight text-ink-900">WisperVoice</span>
              <span className="metallic-pill rounded-full px-2 py-0.5 text-[10px] font-semibold tracking-widest text-ink-400">BETA</span>
            </a>
            <p className="mt-3 text-sm leading-6 text-ink-600">Native Mac dictation — hold hotkey, speak, paste. Open-source Wispr Flow for macOS.</p>
            <div className="mt-4 flex gap-2">
              <a
                href="#"
                onClick={(e) => e.preventDefault()}
                className="metallic-dark inline-flex items-center gap-1.5 rounded-full px-4 py-2 text-xs font-semibold text-white"
              >
                <AppleIcon className="h-3 w-[10px]" /> Download
              </a>
              <a
                href="https://github.com/tewarig/wispervoice"
                target="_blank"
                rel="noreferrer"
                className="metallic-secondary inline-flex items-center gap-1.5 rounded-full px-4 py-2 text-xs font-medium text-ink-600"
              >
                <GithubIcon className="h-3.5 w-3.5" /> GitHub
              </a>
            </div>
          </div>

          <div className="grid grid-cols-2 gap-8 text-sm sm:grid-cols-3 sm:gap-12">
            <div>
              <div className="text-xs font-semibold tracking-wide text-ink-900">Product</div>
              <ul className="mt-3 space-y-2 text-ink-600">
                <li>
                  <a href="#features" className="transition-colors duration-200 hover:text-ink-900">
                    Features
                  </a>
                </li>
                <li>
                  <a href="#how" className="transition-colors duration-200 hover:text-ink-900">
                    How it works
                  </a>
                </li>
                <li>
                  <a href="#demo" className="transition-colors duration-200 hover:text-ink-900">
                    Demo
                  </a>
                </li>
              </ul>
            </div>
            <div>
              <div className="text-xs font-semibold tracking-wide text-ink-900">Developers</div>
              <ul className="mt-3 space-y-2 text-ink-600">
                <li>
                  <a href="https://github.com/tewarig/wispervoice" target="_blank" rel="noreferrer" className="transition-colors duration-200 hover:text-ink-900">
                    GitHub
                  </a>
                </li>
                <li>
                  <a href="#" className="transition-colors duration-200 hover:text-ink-900">
                    Contributing
                  </a>
                </li>
                <li>
                  <a href="#" className="transition-colors duration-200 hover:text-ink-900">
                    Releases
                  </a>
                </li>
              </ul>
            </div>
            <div>
              <div className="text-xs font-semibold tracking-wide text-ink-900">Legal</div>
              <ul className="mt-3 space-y-2 text-ink-600">
                <li>
                  <a href="#" className="transition-colors duration-200 hover:text-ink-900">
                    Privacy
                  </a>
                </li>
                <li>
                  <a href="#" className="transition-colors duration-200 hover:text-ink-900">
                    Terms
                  </a>
                </li>
                <li>
                  <a href="mailto:hello@wispervoice.ai" className="transition-colors duration-200 hover:text-ink-900">
                    Contact
                  </a>
                </li>
              </ul>
            </div>
          </div>
        </div>

        <div className="mt-10 flex flex-col items-center justify-between gap-3 border-t border-line pt-6 text-xs text-ink-400 sm:flex-row">
          <span>© {new Date().getFullYear()} WisperVoice · MIT · Not affiliated with Wispr AI</span>
          <span className="inline-flex items-center gap-2">
            <span className="h-1.5 w-1.5 rounded-full bg-violet-600" /> All systems operational
          </span>
        </div>
      </div>
    </footer>
  );
}

function ThemeSwitcher() {
  const [theme, setTheme] = useState("system");
  useEffect(() => {
    const saved = localStorage.getItem("theme");
    if (saved === "light" || saved === "dark" || saved === "system") setTheme(saved);
  }, []);
  useEffect(() => {
    const root = document.documentElement;
    const media = window.matchMedia("(prefers-color-scheme: dark)");
    const apply = (t) => {
      const isDark = t === "dark" || (t === "system" && media.matches);
      root.classList.toggle("dark", isDark);
    };
    apply(theme);
    localStorage.setItem("theme", theme);
    if (theme === "system") {
      const handler = () => apply("system");
      media.addEventListener("change", handler);
      return () => media.removeEventListener("change", handler);
    }
  }, [theme]);

  const opts = [
    { id: "light", label: "Light", icon: Sun },
    { id: "dark", label: "Dark", icon: Moon },
    { id: "system", label: "System", icon: Monitor },
  ];

  return (
    <div className="fixed bottom-5 left-1/2 z-50 flex -translate-x-1/2 items-center gap-1 rounded-full border border-line bg-white/90 p-1 shadow-[0_8px_32px_rgba(0,0,0,0.12)] backdrop-blur-xl dark:border-white/10 dark:bg-ink-900/80">
      {opts.map((o) => {
        const Icon = o.icon;
        const active = theme === o.id;
        return (
          <button
            key={o.id}
            onClick={() => setTheme(o.id)}
            aria-label={`Switch to ${o.label} mode`}
            aria-pressed={active}
            className={`inline-flex items-center gap-1.5 rounded-full px-3.5 py-1.5 text-xs font-medium transition-all duration-200 ${
              active
                ? "bg-ink-900 text-white shadow-sm dark:bg-white dark:text-ink-900"
                : "text-ink-600 hover:text-ink-900 dark:text-white/60 dark:hover:text-white"
            }`}
          >
            <Icon className="h-3.5 w-3.5" strokeWidth={1.8} />
            {o.label}
          </button>
        );
      })}
    </div>
  );
}

export default function App() {
  return (
    <div className="min-h-screen bg-white antialiased">
      {/* Center blob — fixed to viewport center, stays in place while scrolling */}
      <div
        className="pointer-events-none fixed left-1/2 top-1/2 -z-10 h-[90vh] w-[90vw] -translate-x-1/2 -translate-y-1/2 rounded-full blur-[32px]"
        style={{ background: "radial-gradient(50% 50% at 50% 50%, rgba(91,74,211,0.09) 0%, rgba(124,92,252,0.05) 42%, transparent 70%)", opacity: 0.87 }}
      />
      <Nav />
      <Hero />
      <Features />
      <HowItWorks />
      <Demo />
      <FAQ />
      <Footer />
      <ThemeSwitcher />
    </div>
  );
}
