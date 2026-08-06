# WisperVoice — Marketing Website

Premium marketing site for **WisperVoice**, a native Mac dictation app (Wispr Flow clone). Built with Vite + React + Tailwind — fast, simple, and deploy-ready.

**Stack:** Vite 5 · React 18 · Tailwind 3.4 · Inter font · no extra deps

---

## Quick start

```bash
cd website
pnpm install
pnpm dev            # http://localhost:5173
pnpm build          # production build → dist/
pnpm preview        # preview build → http://localhost:4173
```

> **Node note:** `create-vite@9` needs Node `^20.19`. This project pins Vite 5 so Node 20.0 works.

---

## Pages / sections

Single-page site with anchor navigation:

| Section | ID | Content |
|---|---|---|
| **Nav** | — | Glass pill nav (sticky), beta badge, mobile drawer |
| **Hero** | `#download` | Headline, ⌥Space / Fn hint, Download + Watch demo CTAs, glass pill preview, Mac window mock (Slack + menu bar tray), floating chips |
| **Features** | `#features` | 6-card grid — hotkey, AI polish, 100+ languages, every-app paste, privacy, local models + open-source parity strip |
| **Demo** | `#demo` | Video placeholder (click to play mock + waveform), replace with `<video>` at `/public/demo.mp4` |
| **How it works** | `#how` | 3 steps (Hold → Polish → Paste) + technical detail chips (AVAudioEngine, providers, history) |
| **Pricing** | `#pricing` | Free / Pro (annual toggle, $8 vs $10) / Wispr Flow comparison. Free is primary; Pro = BYO OpenAI key |
| **Testimonials** | — | 6 cards, 4.9/5 |
| **FAQ** | `#faq` | 6-item accordion |
| **Footer** | — | Links, copyright, stack credits |

---

## Design

Inspired by **exploreswiftui.com** and **wisprflow.ai**:

- **Glass** — `backdrop-blur + saturate + border-white/60` on nav, pill, and chips (`glass` utility in `src/index.css`)
- **Gradients** — violet `#7c5cfc` → aqua `#3dd6d0` for headline, orbs, and Pro card; mesh + grid-pattern on hero
- **SF Symbols style** — inline SVG icons with 1.7px stroke, rounded caps (waveform, sparkle, globe, shield, bolt, etc.)
- **Typography** — Inter + SF Pro fallback, tight tracking (`-0.04em` hero), 13–15px body
- **Shadows** — `shadow-glass`, `shadow-pill`, `shadow-card` / `shadow-cardHover` from `tailwind.config.js`
- **Motion** — `float`, `pulseDot`, `waveform` keyframes; hover lift on feature cards

Colors and shadows are centralized in `tailwind.config.js` (`ink`, `violet`, `aqua` + custom `boxShadow`).

---

## Customization

- **Download link:** `Hero` + `Pricing` CTAs currently `href="#"` with `preventDefault` — wire to your DMG/TestFlight URL or GitHub release.
- **Demo video:** Drop a file at `public/demo.mp4` and replace the placeholder div in `src/App.jsx` → `Demo` with:
  ```jsx
  <video src="/demo.mp4" autoPlay muted loop playsInline className="w-full h-full object-cover rounded-[18px]" />
  ```
- **Copy / pricing:** Edit constants at top of `src/App.jsx` (`FEATURES`, `TESTIMONIALS`, `FAQS`, `steps`).
- **Deploy:** `dist/` is static — deploy to Cloudflare Pages, Vercel, or Netlify. For Cloudflare Pages: `Build command: pnpm build`, `Output: dist`.

---

## Project structure

```
website/
  index.html          # entry + Inter font + meta/OG
  vite.config.js      # @vitejs/plugin-react, ports 5173/4173
  tailwind.config.js  # theme (colors, shadows, keyframes) + content globs
  postcss.config.js
  package.json
  src/
    main.jsx          # React root
    index.css         # Tailwind directives + .glass / .mesh / .grid-pattern
    App.jsx           # All sections (Nav, Hero, Features, Demo, HowItWorks, Pricing, Testimonials, FAQ, Footer)
```

No router — single page with `scroll-behavior: smooth` and `scroll-padding-top: 72px` for anchor offsets.

---

## Build

Verified:

```
vite v5.4.21 building for production...
✓ 31 modules transformed.
dist/index.html                 1.54 kB │ gzip: 0.79 kB
dist/assets/index-*.css        31.23 kB │ gzip: 6.03 kB
dist/assets/index-*.js        189.61 kB │ gzip: 57.0 kB
✓ built in ~1s
```

Xcode project is untouched (`../WisperVoice/`).

---

## License

MIT — marketing site for the WisperVoice reference app.
