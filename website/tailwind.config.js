/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{js,ts,jsx,tsx}"],
  theme: {
    extend: {
      fontFamily: {
        sans: ["Inter", "SF Pro Display", "SF Pro Text", "-apple-system", "BlinkMacSystemFont", "Segoe UI", "sans-serif"],
        display: ["SF Pro Display", "Inter", "-apple-system", "sans-serif"],
        mono: ["SF Mono", "JetBrains Mono", "Menlo", "monospace"],
      },
      colors: {
        ink: {
          50: "#f6f7f9",
          100: "#e9ecf1",
          200: "#d4d9e3",
          300: "#b3bccf",
          400: "#8a96b3",
          500: "#6b7a9b",
          600: "#556180",
          700: "#444e68",
          800: "#3a4156",
          900: "#1a1e2a",
          950: "#0f111a",
        },
        violet: {
          500: "#7c5cfc",
          600: "#6d4df0",
        },
        aqua: {
          400: "#3dd6d0",
          500: "#1ecab8",
        },
      },
      boxShadow: {
        glass: "0 8px 32px rgba(0,0,0,0.12), 0 1px 1px rgba(255,255,255,0.6) inset, 0 -1px 1px rgba(0,0,0,0.05) inset",
        pill: "0 8px 40px rgba(30,20,80,0.18), 0 1px 0 rgba(255,255,255,0.9) inset",
        card: "0 1px 3px rgba(15,17,26,0.06), 0 12px 32px rgba(15,17,26,0.08)",
        cardHover: "0 4px 16px rgba(15,17,26,0.08), 0 24px 48px rgba(15,17,26,0.12)",
      },
      backdropBlur: {
        glass: "20px",
      },
      keyframes: {
        float: {
          "0%,100%": { transform: "translateY(0px)" },
          "50%": { transform: "translateY(-6px)" },
        },
        pulseDot: {
          "0%,100%": { opacity: "1", transform: "scale(1)" },
          "50%": { opacity: "0.6", transform: "scale(0.85)" },
        },
        shimmer: {
          "0%": { transform: "translateX(-100%)" },
          "100%": { transform: "translateX(200%)" },
        },
        waveform: {
          "0%,100%": { height: "8px" },
          "50%": { height: "28px" },
        },
      },
      animation: {
        float: "float 5s ease-in-out infinite",
        pulseDot: "pulseDot 1.5s ease-in-out infinite",
        shimmer: "shimmer 2s ease-in-out infinite",
      },
    },
  },
  plugins: [],
};
