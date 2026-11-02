import React from 'react';
import { Icon } from './Icon.jsx';

const V = {
  ghost:   { bg: 'transparent', bgH: 'var(--surface-hover)', fg: 'var(--text-primary)' },
  filled:  { bg: 'var(--paper-2)', bgH: 'var(--paper-3)', fg: 'var(--text-primary)' },
  accent:  { bg: 'var(--accent)', bgH: 'var(--accent-hover)', fg: 'var(--text-on-accent)' },
  overlay: { bg: 'rgba(255,255,255,.88)', bgH: '#fff', fg: 'var(--ink-900)' },
  inverse: { bg: 'var(--ink-900)', bgH: 'var(--ink-800)', fg: 'var(--paper)' },
};

export function IconButton({ icon, variant = 'ghost', size = 44, iconSize, active = false, filledWhenActive = false, activeColor = 'var(--accent)', badge, label, onClick, disabled, style, ...rest }) {
  const [hover, setHover] = React.useState(false);
  const [press, setPress] = React.useState(false);
  const v = V[variant] || V.ghost;
  const color = active && variant !== 'accent' ? activeColor : v.fg;
  return (
    <button type="button" aria-label={label} title={label} onClick={onClick} disabled={disabled}
      onMouseEnter={() => setHover(true)} onMouseLeave={() => { setHover(false); setPress(false); }}
      onMouseDown={() => setPress(true)} onMouseUp={() => setPress(false)}
      style={{ position: 'relative', width: size, height: size, borderRadius: 'var(--radius-pill)', border: 0, padding: 0, flexShrink: 0,
        display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
        background: hover ? v.bgH : v.bg, color, cursor: disabled ? 'not-allowed' : 'pointer', opacity: disabled ? .4 : 1,
        transform: press ? 'scale(.86)' : 'none', transition: 'transform var(--dur-fast) var(--ease-bounce), background var(--dur-fast) var(--ease-out)', ...style }} {...rest}>
      <Icon name={icon} size={iconSize || Math.round(size * 0.5)} strokeWidth={2.25} filled={active && filledWhenActive} color={color} />
      {badge != null && badge !== false && (
        <span style={{ position: 'absolute', top: size * 0.12, right: size * 0.12, minWidth: badge === true ? 9 : 18, height: badge === true ? 9 : 18,
          padding: badge === true ? 0 : '0 5px', borderRadius: 999, background: 'var(--accent)', color: '#fff', boxSizing: 'border-box',
          font: '800 11px/18px var(--font-body)', boxShadow: '0 0 0 2px var(--bg-app)' }}>{badge === true ? '' : badge}</span>
      )}
    </button>
  );
}
