/** @type {import('tailwindcss').Config} */
export default {
  darkMode: "class",
  content: ["./index.html", "./src/**/*.{js,ts,jsx,tsx}"],
  theme: {
    extend: {
      fontFamily: {
        sans: ["Inter", "SF Pro Display", "-apple-system", "BlinkMacSystemFont", "Segoe UI", "sans-serif"],
        display: ["Inter", "-apple-system", "BlinkMacSystemFont", "sans-serif"],
        mono: ["SF Mono", "JetBrains Mono", "Menlo", "monospace"],
      },
      colors: {
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
        violet: {
          50: "#f5f3ff",
          100: "#ede9fe",
          500: "#7c5cfc",
          600: "#6d5aff",
          700: "#5b4ad3",
        },
        paper: "#ffffff",
        line: "#e8e8ec",
        surface: "#fafafb",
      },
      boxShadow: {
        nav: "0 1px 2px rgba(0,0,0,0.04), 0 4px 16px rgba(0,0,0,0.04)",
        card: "0 1px 2px rgba(0,0,0,0.04), 0 8px 24px rgba(0,0,0,0.05)",
        pill: "0 8px 32px rgba(0,0,0,0.10), 0 1px 2px rgba(0,0,0,0.06)",
        subtle: "0 1px 3px rgba(0,0,0,0.06)",
      },
      maxWidth: {
        site: "1040px",
      },
      keyframes: {
        pulseDot: {
          "0%,100%": { opacity: "1" },
          "50%": { opacity: "0.45" },
        },
        shimmer: {
          "0%": { transform: "translateX(-100%)" },
          "100%": { transform: "translateX(200%)" },
        },
        fadeIn: {
          "0%": { opacity: "0", transform: "translateY(4px)" },
          "100%": { opacity: "1", transform: "translateY(0)" },
        },
      },
      animation: {
        pulseDot: "pulseDot 2s ease-in-out infinite",
        shimmer: "shimmer 1.8s ease-in-out infinite",
        fadeIn: "fadeIn 0.5s ease-out",
      },
    },
  },
  plugins: [],
};
