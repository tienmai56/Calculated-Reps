import React from 'react';

const COLORS = {
  white: 'var(--belt-white)', blue: 'var(--belt-blue)', purple: 'var(--belt-purple)', brown: 'var(--belt-brown)', black: 'var(--belt-black)',
  coral: 'var(--belt-coral)', red: 'var(--belt-red)', grey: 'var(--belt-grey)', yellow: 'var(--belt-yellow)', orange: 'var(--belt-orange)', green: 'var(--belt-green)',
};
const H = { xs: 8, sm: 12, md: 16, lg: 24 };
export const BELT_COLORS = COLORS;

export function Belt({ rank = 'white', stripes = 0, size = 'md', width, label = false, style }) {
  const h = H[size] || H.md;
  const bar = rank === 'black' || rank === 'coral' || rank === 'red' ? 'var(--belt-bar-red)' : 'var(--belt-bar-black)';
  const barW = size === 'xs' ? 14 : Math.max(h * 3.2, 26);
  const stripeW = Math.max(2, Math.round(h * 0.24));
  const n = Math.max(0, Math.min(4, stripes));
  const name = rank.charAt(0).toUpperCase() + rank.slice(1) + ' belt' + (n ? ` · ${n} stripe${n > 1 ? 's' : ''}` : '');
  const strip = (
    <span role="img" aria-label={name} style={{ display: 'flex', height: h, width: width ?? '100%', minWidth: barW * 2.5, borderRadius: Math.max(3, h * 0.25), overflow: 'hidden',
      background: COLORS[rank] || COLORS.white, boxShadow: 'inset 0 0 0 1.5px rgba(29,27,24,.16)', flexShrink: 0, ...(label ? {} : style) }}>
      <span style={{ flex: 1 }}></span>
      <span style={{ width: barW, background: bar, display: 'flex', justifyContent: 'flex-end', gap: Math.max(2, stripeW * 0.8), padding: size === 'xs' ? '0 2px' : `0 ${Math.round(h * 0.35)}px` }}>
        {Array.from({ length: n }).map((_, i) => <span key={i} style={{ width: stripeW, background: 'var(--belt-stripe)' }}></span>)}
      </span>
      <span style={{ width: Math.round(h * 0.8) }}></span>
    </span>
  );
  if (!label) return strip;
  return (
    <span style={{ display: 'flex', flexDirection: 'column', gap: 6, ...style }}>
      {strip}
      <span style={{ font: '600 13px/1.2 var(--font-body)', color: 'var(--text-secondary)' }}>{name}</span>
    </span>
  );
}
