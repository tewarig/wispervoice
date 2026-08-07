/**
 * WisperVoice Design System — single source of truth
 * Edit tokens here to change the entire site (light + dark).
 * Used by: tailwind.config.js (via import) and index.css (via CSS variables).
 * For future: change a token here, rebuild — no hunt through components.
 */

export const tokens = {
  // ── Colors ──
  colors: {
    light: {
      // Base
      paper: "#ffffff",
      surface: "#fafafb",
      line: "#e8e8ec",
      // Ink scale — primary neutral (black → white)
      ink: {
        50: "#fafafb",
        100: "#f0f0f3",
        200: "#e8e8ec",
        300: "#d4d4dc",
        400: "#9f9fa9",
        500: "#71717a",
        600: "#52525b",
        700: "#3f3f46",
        800: "#27272a",
        900: "#111113",
        950: "#09090b",
      },
      // Violet kept for legacy / accent if needed (now secondary)
      violet: {
        50: "#f5f3ff",
        100: "#ede9fe",
        500: "#7c5cfc",
        600: "#6d5aff",
        700: "#5b4ad3",
      },
      // Zinc — used for grey cloud / highlight
      zinc: {
        100: "#f4f4f5",
        200: "#e4e4e7",
        300: "#d4d4d8",
        400: "#a1a1aa",
        700: "#3f3f46",
        800: "#27272a",
      },
      // Semantic
      bodyBg: "#ffffff",
      bodyText: "#111113",
      selectionBg: "#111113",
      selectionText: "#ffffff",
      focusRing: "#27272a",
    },
    dark: {
      // Pitch dark — entire page
      bodyBg: "#000000",
      bodyText: "#f1f1f3", // softer white — less harsh than #fafafb
      surface: "#000000", // sections (FAQ, demo) — same as body for pitch
      card: "#18181b", // lighter than body — elevated (no white inset)
      cardHover: "#1e1e22",
      line: "#2e2e32", // better border — visible on #000
      lineHover: "#3f3f46",
      ink: {
        900: "#f1f1f3",
        600: "#a8a8b0",
        400: "#94949e",
      },
      selectionBg: "#f1f1f3",
      selectionText: "#09090b",
      focusRing: "#3f3f46",
      // Hero highlight — inverted
      heroHighlightBg: "#f1f1f3",
      heroHighlightText: "#09090b",
      // Glass / nav
      glassBg: "rgba(24, 24, 27, 0.88)",
      // Button — white pill on dark
      buttonDarkBg: "#f1f1f3",
      buttonDarkHover: "#f8f8f9",
      buttonDarkBorder: "#e4e4e7",
    },
  },

  // ── Typography ──
  font: {
    sans: ["Inter", "SF Pro Display", "-apple-system", "BlinkMacSystemFont", "Segoe UI", "sans-serif"],
    display: ["Inter", "-apple-system", "BlinkMacSystemFont", "sans-serif"],
    mono: ["SF Mono", "JetBrains Mono", "Menlo", "monospace"],
    // Scale
    hero: { size: "40px", weight: 750, tracking: "-0.04em", lineHeight: "0.92" },
    h2: { size: "28px", weight: 700, tracking: "-0.03em" },
    body: { size: "16px", lineHeight: "1.7" },
    small: { size: "12px", tracking: "0.14em" },
  },

  // ── Layout ──
  layout: {
    maxWidth: "1040px",
    navHeight: "64px",
    radius: {
      pill: "9999px",
      card: "24px",
      cardSm: "16px",
      glass: "9999px",
    },
    contentPadding: { base: "20px", sm: "24px" },
  },

  // ── Shadows & Borders — light has depth, dark is flat per your request ──
  shadow: {
    light: {
      nav: "0 1px 2px rgba(0,0,0,0.04), 0 4px 16px rgba(0,0,0,0.04)",
      card: "0 1px 2px rgba(0,0,0,0.04), 0 8px 24px rgba(0,0,0,0.05)",
      pill: "0 8px 32px rgba(0,0,0,0.10), 0 1px 2px rgba(0,0,0,0.06)",
      subtle: "0 1px 3px rgba(0,0,0,0.06)",
      metallicCard: "inset 0 1px 0 rgba(255,255,255,0.98), inset 0 -1px 0 rgba(0,0,0,0.03), 0 8px 24px rgba(17,17,19,0.05), 0 1px 3px rgba(17,17,19,0.04)",
      metallicPill: "inset 0 1px 0 rgba(255,255,255,0.98), inset 0 -1px 0 rgba(0,0,0,0.02), 0 6px 16px rgba(17,17,19,0.05), 0 1px 3px rgba(17,17,19,0.04)",
      glass: "inset 0 1px 0 rgba(255,255,255,0.96), inset 0 -1px 0 rgba(0,0,0,0.04), 0 8px 24px rgba(17,17,19,0.06), 0 1px 3px rgba(17,17,19,0.05)",
    },
    dark: {
      // flat — no inner white, no outer glow per your “remove box shadow for dark”
      card: "none",
      pill: "none",
      glass: "none",
      nav: "none",
      buttonDark: "none",
    },
  },

  border: {
    light: { line: "#e8e8ec", glass: "rgba(232,232,236,0.96)", nav: "rgba(232,232,236,0.65)" },
    dark: { line: "#2e2e32", hover: "#3f3f46", glass: "#2e2e32" },
  },

  // ── Motion ──
  motion: {
    duration: { fast: "180ms", normal: "560ms" },
    ease: { soft: "cubic-bezier(0.16,1,0.3,1)", linear: "linear" },
    keyframes: {
      pulseDot: { "0%,100%": { opacity: "1" }, "50%": { opacity: "0.45" } },
      shimmer: { "0%": { transform: "translateX(-100%)" }, "100%": { transform: "translateX(200%)" } },
      fadeIn: { "0%": { opacity: "0", transform: "translateY(4px)" }, "100%": { opacity: "1", transform: "translateY(0)" } },
      heroHighlightIn: { "0%": { transform: "scaleX(0)" }, "100%": { transform: "scaleX(1)" } },
      heroHighlightText: { to: { opacity: "1" } },
    },
    animation: {
      pulseDot: "pulseDot 2s ease-in-out infinite",
      shimmer: "shimmer 1.8s ease-in-out infinite",
      fadeIn: "fadeIn 0.5s ease-out",
      heroHighlightIn: "hero-highlight-in 0.85s cubic-bezier(0.16,1,0.3,1) 0.35s forwards",
    },
  },

  // ── Components — semantic tokens referencing above ──
  components: {
    nav: { height: "64px", glassBlur: "20px" },
    hero: {
      cloud: {
        // fluffy grey cloud — not a pill
        container: { w: "920px", h: "300px", wSm: "1100px", hSm: "360px" },
        puffs: [
          { w: "680px", h: "180px", bg: "zinc-300/55", blur: "26px" },
          { w: "280px", h: "150px", bg: "zinc-400/40", blur: "20px" },
          { w: "320px", h: "160px", bg: "zinc-300/50", blur: "22px" },
        ],
      },
      highlight: {
        lightBg: "#27272a",
        lightText: "#ffffff",
        darkBg: "#f1f1f3",
        darkText: "#09090b",
      },
    },
    card: { radius: "24px", padding: "24px" },
    pill: { radius: "9999px", padding: "12px" },
  },
};

// Tailwind helper — so tailwind.config.js stays DRY: import { tokens } and spread
export const tailwindTokens = {
  fontFamily: {
    sans: tokens.font.sans,
    display: tokens.font.display,
    mono: tokens.font.mono,
  },
  colors: {
    ink: tokens.colors.light.ink,
    violet: tokens.colors.light.violet,
    paper: tokens.colors.light.paper,
    line: tokens.colors.light.line,
    surface: tokens.colors.light.surface,
    zinc: tokens.colors.light.zinc,
  },
  boxShadow: tokens.shadow.light,
  maxWidth: { site: tokens.layout.maxWidth },
  keyframes: tokens.motion.keyframes,
  animation: tokens.motion.animation,
};

export default tokens;
