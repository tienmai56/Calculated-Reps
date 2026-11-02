import React from 'react';

export function Tabs({ items = [], value, onChange, variant = 'segmented', style }) {
  const seg = variant === 'segmented';
  return (
    <div role="tablist" style={{ display: 'flex', gap: seg ? 2 : 22, padding: seg ? 4 : 0, borderRadius: 999, background: seg ? 'var(--paper-2)' : 'transparent', ...style }}>
      {items.map(it => {
        const id = it.id ?? it.label ?? it; const label = it.label ?? it; const on = id === value;
        return (
          <button key={id} role="tab" aria-selected={on} onClick={() => onChange && onChange(id)}
            style={{ flex: seg ? 1 : undefined, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6, border: 0, cursor: 'pointer',
              height: seg ? 38 : 40, padding: seg ? '0 14px' : 0, borderRadius: 999,
              background: seg && on ? 'var(--white)' : 'transparent', boxShadow: seg && on ? '0 1px 3px rgba(29,27,24,.12)' : 'none',
              color: on ? 'var(--text-primary)' : 'var(--text-tertiary)',
              font: `${on ? 800 : 600} 15px/1 var(--font-display)`, position: 'relative', transition: 'all var(--dur-fast) var(--ease-out)' }}>
            {label}
            {it.count != null && <span style={{ minWidth: 20, height: 20, padding: '0 6px', boxSizing: 'border-box', borderRadius: 999, background: 'var(--accent)', color: '#fff', font: '800 11px/20px var(--font-body)' }}>{it.count}</span>}
            {!seg && on && <span style={{ position: 'absolute', left: '20%', right: '20%', bottom: 0, height: 4, borderRadius: 4, background: 'var(--accent)' }}></span>}
          </button>
        );
      })}
    </div>
  );
}
