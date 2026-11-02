The Silverback logo, drawn inline from tokens (no asset paths needed). Rules: `DESIGN.md` §5.1.

```jsx
<Logo />                                   {/* mark, coral brow, 40px */}
<Logo variant="lockup" size={48} />        {/* splash / onboarding header */}
<Logo variant="appIcon" size={64} />       {/* on ink or photos */}
<Logo variant="mono" size={32} />          {/* on a coral surface */}
<Logo variant="lockupInverse" size={40} /> {/* on an ink card */}
```

- One logo per screen at most; tab headers keep the plain Bricolage title.
- Mark minimum 24px; lockup at least 120px wide (size ≥ 28).
- Never recolor, outline or redraw it. For native or print, use the files in `assets/brand/`.
