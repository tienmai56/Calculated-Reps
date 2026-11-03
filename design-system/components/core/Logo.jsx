import React from 'react';

// The Silverback mark. Geometry matches assets/brand/logo-mark.svg (viewBox 36 22 228 256).
const VIEWBOX = '36 22 228 256';
const RATIO = 228 / 256;

function Mark({ height, brow }) {
  return (
    <svg viewBox={VIEWBOX} width={Math.round(height * RATIO)} height={height} aria-hidden="true" style={{ display: 'block', flexShrink: 0 }}>
      <path d="M150 28C222 28 258 72 258 132C258 204 226 266 150 272C74 266 42 204 42 132C42 72 78 28 150 28Z" style={{ fill: 'var(--ink-900)' }} />
      <path d="M150 112C202 108 226 132 222 168C218 222 188 252 150 254C112 252 82 222 78 168C74 132 98 108 150 112Z" style={{ fill: 'var(--paper-3)' }} />
      <rect x="68" y="98" width="164" height="38" rx="19" style={{ fill: brow }} />
      <rect x="100" y="148" width="30" height="11" rx="5.5" style={{ fill: 'var(--ink-900)' }} />
      <rect x="170" y="148" width="30" height="11" rx="5.5" style={{ fill: 'var(--ink-900)' }} />
      <ellipse cx="136" cy="200" rx="10" ry="7" style={{ fill: 'var(--ink-900)' }} />
      <ellipse cx="164" cy="200" rx="10" ry="7" style={{ fill: 'var(--ink-900)' }} />
      <path d="M124 230H176" strokeWidth="9" strokeLinecap="round" style={{ stroke: 'var(--ink-900)' }} />
    </svg>
  );
}

function Tile({ size }) {
  return (
    <span style={{ width: size, height: size, borderRadius: size * 0.225, background: 'var(--sun-400)', flexShrink: 0,
      display: 'inline-flex', alignItems: 'center', justifyContent: 'center', paddingTop: size * 0.03, boxSizing: 'border-box' }}>
      <Mark height={Math.round(size * 0.69)} brow="var(--accent)" />
    </span>
  );
}

function Wordmark({ size, color }) {
  return (
    <span style={{ font: `800 ${Math.round(size * 0.6)}px/1 var(--font-display)`, letterSpacing: '-0.045em', color, whiteSpace: 'nowrap' }}>
      mat monkey<span style={{ color: 'var(--accent)' }}>.</span>
    </span>
  );
}

export function Logo({ variant = 'mark', size = 40, label = 'Mat Monkey', style, ...rest }) {
  let content;
  if (variant === 'mono') content = <Mark height={size} brow="var(--ink-900)" />;
  else if (variant === 'appIcon') content = <Tile size={size} />;
  else if (variant === 'lockup') content = <><Mark height={size} brow="var(--accent)" /><Wordmark size={size} color="var(--text-primary)" /></>;
  else if (variant === 'lockupInverse') content = <><Tile size={size} /><Wordmark size={size} color="var(--text-inverse)" /></>;
  else content = <Mark height={size} brow="var(--accent)" />;
  return (
    <span role="img" aria-label={label} {...rest}
      style={{ display: 'inline-flex', alignItems: 'center', gap: Math.round(size * 0.3), lineHeight: 0, ...style }}>
      {content}
    </span>
  );
}
