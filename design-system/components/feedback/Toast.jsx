import React from 'react';
import { Icon } from '../core/Icon.jsx';

const ICON = { default: null, success: 'circle-check', danger: 'triangle-alert', streak: 'flame', friend: 'handshake' };
const COLOR = { default: 'var(--paper)', success: 'var(--mint-500)', danger: '#FF7B7D', streak: 'var(--flame-500)', friend: 'var(--sun-400)' };

export function Toast({ message, variant = 'default', icon, action, style }) {
  const ic = icon || ICON[variant];
  return (
    <div role="status" style={{ display: 'flex', alignItems: 'center', gap: 10, minHeight: 52, padding: '10px 10px 10px 16px', borderRadius: 999,
      background: 'var(--ink-900)', boxShadow: 'var(--shadow-float)', color: 'var(--paper)', font: '600 15px/1.3 var(--font-body)', boxSizing: 'border-box', ...style }}>
      {ic && <Icon name={ic} size={20} color={COLOR[variant]} filled={variant === 'streak'} />}
      <span style={{ flex: 1 }}>{message}</span>
      {action && <button onClick={action.onClick} style={{ border: 0, background: 'rgba(255,255,255,.12)', color: '#fff', font: '700 14px var(--font-display)', cursor: 'pointer', height: 34, padding: '0 14px', borderRadius: 999 }}>{action.label}</button>}
    </div>
  );
}
