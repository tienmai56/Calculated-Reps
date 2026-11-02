import React from 'react';
import { BELT_COLORS } from './Belt.jsx';

const HUES = ['var(--sun-100)', 'var(--mint-100)', 'var(--sky-100)', 'var(--plum-100)', 'var(--coral-100)'];
const INK = ['var(--sun-600)', 'var(--mint-700)', 'var(--sky-700)', 'var(--plum-700)', 'var(--coral-700)'];

export function Avatar({ src, name = '', size = 40, belt, ring = 'var(--bg-app)', online = false, style }) {
  const initials = name.split(' ').filter(Boolean).slice(0, size < 30 ? 1 : 2).map(w => w[0]).join('').toUpperCase();
  const h = [...name].reduce((a, c) => a + c.charCodeAt(0), 0) % HUES.length;
  const beltW = belt ? Math.max(2, Math.round(size / 18)) : 0;
  return (
    <span style={{ position: 'relative', display: 'inline-flex', width: size, height: size, flexShrink: 0, borderRadius: 999, boxSizing: 'border-box',
      padding: beltW ? beltW + 2 : 0, background: ring, boxShadow: beltW ? `inset 0 0 0 ${beltW}px ${BELT_COLORS[belt] || belt}${belt === 'white' ? ', inset 0 0 0 ' + (beltW + 1) + 'px rgba(29,27,24,.2)' : ''}` : 'none', ...style }}>
      <span style={{ width: '100%', height: '100%', borderRadius: 999, overflow: 'hidden', background: HUES[h], color: INK[h], display: 'flex', alignItems: 'center', justifyContent: 'center',
        font: `800 ${Math.round(size * 0.38)}px/1 var(--font-display)` }}>
        {src ? <img src={src} alt={name} style={{ width: '100%', height: '100%', objectFit: 'cover' }} /> : initials}
      </span>
      {online && <span style={{ position: 'absolute', right: 0, bottom: 0, width: Math.max(9, size * 0.26), height: Math.max(9, size * 0.26), borderRadius: 999, background: 'var(--mint-500)', boxShadow: '0 0 0 2px var(--bg-app)' }}></span>}
    </span>
  );
}
