import React from 'react';
import { Icon } from '../core/Icon.jsx';

export function TabBar({ items = [], value, onChange, centerAction, style }) {
  const half = Math.ceil(items.length / 2);
  const render = it => {
    const on = it.id === value;
    return (
      <button key={it.id} onClick={() => onChange && onChange(it.id)} aria-label={it.label}
        style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4, padding: '10px 0 0', border: 0, background: 'transparent', cursor: 'pointer',
          color: on ? 'var(--text-primary)' : 'var(--ink-400)' }}>
        <span style={{ position: 'relative', transform: on ? 'translateY(-1px)' : 'none', transition: 'transform var(--dur-base) var(--ease-bounce)' }}>
          <Icon name={it.icon} size={24} strokeWidth={on ? 2.5 : 2} />
          {it.badge && <span style={{ position: 'absolute', top: -2, right: -4, width: 9, height: 9, borderRadius: 999, background: 'var(--accent)', boxShadow: '0 0 0 2px var(--white)' }}></span>}
        </span>
        <span style={{ font: `${on ? 800 : 600} 11px/1 var(--font-display)` }}>{it.label}</span>
      </button>
    );
  };
  return (
    <nav style={{ display: 'flex', alignItems: 'flex-start', height: 86, padding: '0 6px 26px', boxSizing: 'border-box',
      background: 'rgba(255,255,255,.9)', backdropFilter: 'blur(20px)', WebkitBackdropFilter: 'blur(20px)', boxShadow: '0 -1px 0 var(--border-subtle)', ...style }}>
      {items.slice(0, centerAction ? half : items.length).map(render)}
      {centerAction && (
        <span style={{ flex: 1, display: 'flex', justifyContent: 'center', paddingTop: 2 }}>
          <button onClick={centerAction.onClick} aria-label={centerAction.label || 'Create'}
            style={{ width: 56, height: 46, borderRadius: 999, border: 0, background: 'var(--accent)', color: '#fff', boxShadow: '0 3px 0 var(--accent-shade)', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer' }}>
            <Icon name={centerAction.icon || 'plus'} size={26} strokeWidth={2.75} />
          </button>
        </span>
      )}
      {centerAction && items.slice(half).map(render)}
    </nav>
  );
}
