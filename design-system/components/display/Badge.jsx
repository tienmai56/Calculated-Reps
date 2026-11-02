import React from 'react';

const V = {
  neutral: { bg: 'var(--paper-2)', fg: 'var(--text-secondary)' },
  accent:  { bg: 'var(--accent)', fg: '#fff' },
  soft:    { bg: 'var(--accent-tint)', fg: 'var(--coral-700)' },
  success: { bg: 'var(--success-tint)', fg: 'var(--mint-700)' },
  warning: { bg: 'var(--warning-tint)', fg: '#8A6200' },
  danger:  { bg: 'var(--danger-tint)', fg: 'var(--danger-500)' },
  info:    { bg: 'var(--info-tint)', fg: 'var(--sky-700)' },
  flame:   { bg: 'var(--flame-100)', fg: '#B5520A' },
};

export function Badge({ variant = 'neutral', children, dot = false, icon, style }) {
  const v = V[variant] || V.neutral;
  return (
    <span style={{ display: 'inline-flex', alignItems: 'center', gap: 5, height: 24, padding: '0 10px', borderRadius: 999, background: v.bg, color: v.fg,
      font: '700 12px/1 var(--font-body)', whiteSpace: 'nowrap', ...style }}>
      {dot && <span style={{ width: 6, height: 6, borderRadius: 999, background: 'currentColor' }}></span>}
      {icon}
      {children}
    </span>
  );
}
