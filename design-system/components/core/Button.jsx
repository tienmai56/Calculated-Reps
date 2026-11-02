import React from 'react';
import { Icon } from './Icon.jsx';

const SIZES = { sm: { h: 36, px: 14, fs: 14, icon: 16 }, md: { h: 48, px: 20, fs: 16, icon: 18 }, lg: { h: 56, px: 24, fs: 17, icon: 20 } };
const VARIANTS = {
  primary:   { bg: 'var(--accent)', bgH: 'var(--accent-hover)', fg: 'var(--text-on-accent)', edge: 'var(--accent-shade)' },
  secondary: { bg: 'var(--white)', bgH: 'var(--paper-2)', fg: 'var(--text-primary)', bd: 'var(--border-default)', edge: 'var(--ink-200)' },
  soft:      { bg: 'var(--accent-tint)', bgH: '#FFD6C9', fg: 'var(--coral-700)' },
  ghost:     { bg: 'transparent', bgH: 'var(--surface-hover)', fg: 'var(--text-primary)' },
  inverse:   { bg: 'var(--ink-900)', bgH: 'var(--ink-800)', fg: 'var(--paper)', edge: '#000' },
  danger:    { bg: 'var(--danger-tint)', bgH: '#FBD0D0', fg: 'var(--danger-500)' },
};

export function Button({ variant = 'primary', size = 'md', iconLeft, iconRight, fullWidth = false, disabled = false, children, style, onClick, type = 'button', ...rest }) {
  const [hover, setHover] = React.useState(false);
  const [press, setPress] = React.useState(false);
  const s = SIZES[size] || SIZES.md;
  const v = VARIANTS[variant] || VARIANTS.primary;
  const edge = v.edge && !disabled ? (press ? 1 : 3) : 0;
  const shadows = [v.bd ? `inset 0 0 0 1.5px ${v.bd}` : null, edge ? `0 ${edge}px 0 ${v.edge}` : null].filter(Boolean).join(', ') || 'none';
  return (
    <button type={type} disabled={disabled} onClick={onClick}
      onMouseEnter={() => setHover(true)} onMouseLeave={() => { setHover(false); setPress(false); }}
      onMouseDown={() => setPress(true)} onMouseUp={() => setPress(false)}
      style={{
        display: 'inline-flex', alignItems: 'center', justifyContent: 'center', gap: 8,
        height: s.h, padding: `0 ${s.px}px`, width: fullWidth ? '100%' : undefined, boxSizing: 'border-box',
        borderRadius: 'var(--radius-pill)', border: 0,
        background: disabled ? 'var(--ink-100)' : hover ? v.bgH : v.bg,
        color: disabled ? 'var(--text-disabled)' : v.fg, boxShadow: shadows,
        fontFamily: 'var(--font-display)', fontSize: s.fs, fontWeight: 700, letterSpacing: '-0.01em',
        cursor: disabled ? 'not-allowed' : 'pointer', whiteSpace: 'nowrap',
        transform: press && !disabled ? (edge ? 'translateY(2px)' : 'scale(.97)') : 'none',
        transition: 'background var(--dur-fast) var(--ease-out), transform var(--dur-fast) var(--ease-out), box-shadow var(--dur-fast) var(--ease-out)',
        ...style,
      }} {...rest}>
      {iconLeft && <Icon name={iconLeft} size={s.icon} strokeWidth={2.25} />}
      {children}
      {iconRight && <Icon name={iconRight} size={s.icon} strokeWidth={2.25} />}
    </button>
  );
}
