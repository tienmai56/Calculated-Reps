import React from 'react';

export function Card({ children, padding = 16, variant = 'default', interactive = false, onClick, style }) {
  const [hover, setHover] = React.useState(false);
  const [press, setPress] = React.useState(false);
  const bg = variant === 'sunken' ? 'var(--paper-2)' : variant === 'outline' ? 'transparent' : 'var(--surface-card)';
  const sh = variant === 'default' ? 'var(--shadow-card)' : variant === 'outline' ? 'inset 0 0 0 1.5px var(--border-default)' : 'none';
  return (
    <div onClick={onClick} onMouseEnter={() => setHover(true)} onMouseLeave={() => { setHover(false); setPress(false); }} onMouseDown={() => setPress(true)} onMouseUp={() => setPress(false)}
      style={{ background: bg, borderRadius: 'var(--radius-lg)', padding, boxShadow: sh, boxSizing: 'border-box',
        cursor: interactive ? 'pointer' : undefined, transform: interactive && press ? 'scale(.985)' : interactive && hover ? 'translateY(-1px)' : 'none',
        transition: 'transform var(--dur-fast) var(--ease-out)', ...style }}>
      {children}
    </div>
  );
}
