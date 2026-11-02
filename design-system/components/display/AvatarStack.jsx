import React from 'react';
import { Avatar } from './Avatar.jsx';

export function AvatarStack({ people = [], size = 32, max = 4, ring = 'var(--surface-card)', label, style }) {
  const shown = people.slice(0, max); const extra = people.length - shown.length;
  return (
    <span style={{ display: 'inline-flex', alignItems: 'center', gap: 8, ...style }}>
      <span style={{ display: 'inline-flex' }}>
        {shown.map((p, i) => <span key={p.name + i} style={{ marginLeft: i ? -size * 0.32 : 0, borderRadius: 999, boxShadow: `0 0 0 2.5px ${ring}`, display: 'inline-flex', zIndex: shown.length - i }}><Avatar name={p.name} src={p.src} size={size} /></span>)}
        {extra > 0 && <span style={{ marginLeft: -size * 0.32, width: size, height: size, borderRadius: 999, background: 'var(--paper-2)', boxShadow: `0 0 0 2.5px ${ring}`, display: 'inline-flex', alignItems: 'center', justifyContent: 'center', font: `700 ${Math.round(size * 0.34)}px var(--font-body)`, color: 'var(--text-secondary)' }}>+{extra}</span>}
      </span>
      {label && <span style={{ font: '500 13px/1.3 var(--font-body)', color: 'var(--text-secondary)' }}>{label}</span>}
    </span>
  );
}
