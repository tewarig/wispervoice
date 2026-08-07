import { tailwindTokens } from "./src/designTokens.js";

/** @type {import('tailwindcss').Config} */
export default {
  darkMode: "class",
  content: ["./index.html", "./src/**/*.{js,ts,jsx,tsx}"],
  theme: {
    extend: {
      fontFamily: tailwindTokens.fontFamily,
      colors: tailwindTokens.colors,
      boxShadow: tailwindTokens.boxShadow,
      maxWidth: tailwindTokens.maxWidth,
      keyframes: tailwindTokens.keyframes,
      animation: tailwindTokens.animation,
    },
  },
  plugins: [],
};
