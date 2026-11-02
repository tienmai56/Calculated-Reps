/**
 * Grip Gorillas — Tailwind preset. Every value points at a CSS custom property, so
 * load styles.css (or design-system/tokens/*.css) before Tailwind's output.
 * Usage: module.exports = { presets: [require('./design-system/tailwind.config.js')], content: [...] }
 * Generated from design-system/tokens — edit the tokens, not this file.
 */
module.exports = {
  theme: {
    colors: {
      transparent: "transparent",
      current: "currentColor",
      white: "var(--white)",
      paper: {
        "2": "var(--paper-2)",
        "3": "var(--paper-3)",
        DEFAULT: "var(--paper)"
      },
      ink: {
        "100": "var(--ink-100)",
        "200": "var(--ink-200)",
        "300": "var(--ink-300)",
        "400": "var(--ink-400)",
        "500": "var(--ink-500)",
        "700": "var(--ink-700)",
        "800": "var(--ink-800)",
        "900": "var(--ink-900)"
      },
      coral: {
        "100": "var(--coral-100)",
        "300": "var(--coral-300)",
        "500": "var(--coral-500)",
        "600": "var(--coral-600)",
        "700": "var(--coral-700)"
      },
      sun: {
        "100": "var(--sun-100)",
        "400": "var(--sun-400)",
        "600": "var(--sun-600)"
      },
      mint: {
        "100": "var(--mint-100)",
        "500": "var(--mint-500)",
        "700": "var(--mint-700)"
      },
      sky: {
        "100": "var(--sky-100)",
        "500": "var(--sky-500)",
        "700": "var(--sky-700)"
      },
      plum: {
        "100": "var(--plum-100)",
        "500": "var(--plum-500)",
        "700": "var(--plum-700)"
      },
      flame: {
        "100": "var(--flame-100)",
        "500": "var(--flame-500)"
      },
      belt: {
        white: "var(--belt-white)",
        blue: "var(--belt-blue)",
        purple: "var(--belt-purple)",
        brown: "var(--belt-brown)",
        black: "var(--belt-black)",
        coral: "var(--belt-coral)",
        red: "var(--belt-red)",
        grey: "var(--belt-grey)",
        yellow: "var(--belt-yellow)",
        orange: "var(--belt-orange)",
        green: "var(--belt-green)",
        "bar-black": "var(--belt-bar-black)",
        "bar-red": "var(--belt-bar-red)",
        stripe: "var(--belt-stripe)"
      },
      success: {
        DEFAULT: "var(--success-500)",
        tint: "var(--success-tint)"
      },
      warning: {
        DEFAULT: "var(--warning-500)",
        tint: "var(--warning-tint)"
      },
      danger: {
        DEFAULT: "var(--danger-500)",
        tint: "var(--danger-tint)"
      },
      info: {
        DEFAULT: "var(--info-500)",
        tint: "var(--info-tint)"
      },
      accent: {
        DEFAULT: "var(--accent)",
        hover: "var(--accent-hover)",
        press: "var(--accent-press)",
        shade: "var(--accent-shade)",
        tint: "var(--accent-tint)"
      }
    },
    backgroundColor: {
      app: "var(--bg-app)",
      card: "var(--surface-card)",
      sunken: "var(--surface-sunken)",
      input: "var(--surface-input)",
      overlay: "var(--surface-overlay)",
      inverse: "var(--surface-inverse)"
    },
    textColor: {
      primary: "var(--text-primary)",
      secondary: "var(--text-secondary)",
      tertiary: "var(--text-tertiary)",
      disabled: "var(--text-disabled)",
      inverse: "var(--text-inverse)",
      "on-accent": "var(--text-on-accent)",
      accent: "var(--text-accent)",
      link: "var(--text-link)"
    },
    borderColor: {
      subtle: "var(--border-subtle)",
      DEFAULT: "var(--border-default)",
      strong: "var(--border-strong)",
      focus: "var(--border-focus)"
    },
    fontFamily: {
      display: [
        "var(--font-display)"
      ],
      body: [
        "var(--font-body)"
      ],
      mono: [
        "var(--font-mono)"
      ]
    },
    fontSize: {
      "display-xl": [
        "var(--text-display-xl)",
        {
          lineHeight: "var(--lh-display-xl)"
        }
      ],
      "display-l": [
        "var(--text-display-l)",
        {
          lineHeight: "var(--lh-display-l)"
        }
      ],
      "display-m": [
        "var(--text-display-m)",
        {
          lineHeight: "var(--lh-display-m)"
        }
      ],
      "title-l": [
        "var(--text-title-l)",
        {
          lineHeight: "var(--lh-title-l)"
        }
      ],
      "title-m": [
        "var(--text-title-m)",
        {
          lineHeight: "var(--lh-title-m)"
        }
      ],
      "title-s": [
        "var(--text-title-s)",
        {
          lineHeight: "var(--lh-title-s)"
        }
      ],
      "body-l": [
        "var(--text-body-l)",
        {
          lineHeight: "var(--lh-body-l)"
        }
      ],
      body: [
        "var(--text-body)",
        {
          lineHeight: "var(--lh-body)"
        }
      ],
      "body-s": [
        "var(--text-body-s)",
        {
          lineHeight: "var(--lh-body-s)"
        }
      ],
      caption: [
        "var(--text-caption)",
        {
          lineHeight: "var(--lh-caption)"
        }
      ],
      overline: [
        "var(--text-overline)",
        {
          lineHeight: "var(--lh-overline)"
        }
      ]
    },
    letterSpacing: {
      display: "var(--tracking-display)",
      title: "var(--tracking-title)",
      overline: "var(--tracking-overline)"
    },
    spacing: {
      "0": "var(--space-0)",
      "1": "var(--space-1)",
      "2": "var(--space-2)",
      "3": "var(--space-3)",
      "4": "var(--space-4)",
      "5": "var(--space-5)",
      "6": "var(--space-6)",
      "7": "var(--space-7)",
      "8": "var(--space-8)",
      "9": "var(--space-9)",
      "10": "var(--space-10)",
      "11": "var(--space-11)"
    },
    borderRadius: {
      none: "0",
      xs: "var(--radius-xs)",
      sm: "var(--radius-sm)",
      md: "var(--radius-md)",
      lg: "var(--radius-lg)",
      xl: "var(--radius-xl)",
      full: "var(--radius-pill)"
    },
    boxShadow: {
      none: "none",
      hairline: "var(--shadow-hairline)",
      card: "var(--shadow-card)",
      float: "var(--shadow-float)",
      sheet: "var(--shadow-sheet)",
      press: "var(--shadow-press)",
      focus: "var(--ring-focus)"
    },
    transitionTimingFunction: {
      out: "var(--ease-out)",
      "in-out": "var(--ease-in-out)",
      bounce: "var(--ease-bounce)"
    },
    transitionDuration: {
      fast: "var(--dur-fast)",
      base: "var(--dur-base)",
      slow: "var(--dur-slow)"
    }
  },
  plugins: [],
};
