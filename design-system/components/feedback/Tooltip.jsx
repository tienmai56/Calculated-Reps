import React from 'react';

export function Tooltip({ content, children, placement = 'top', open, style }) {
  const [hover, setHover] = React.useState(false);
  const show = open ?? hover;
  const top = placement === 'top';
  return (
    <span onMouseEnter={() => setHover(true)} onMouseLeave={() => setHover(false)} style={{ position: 'relative', display: 'inline-flex', ...style }}>
      {children}
      <span role="tooltip" style={{ position: 'absolute', left: '50%', [top ? 'bottom' : 'top']: 'calc(100% + 8px)', transform: `translateX(-50%) translateY(${show ? 0 : top ? 4 : -4}px)`,
        opacity: show ? 1 : 0, pointerEvents: 'none', whiteSpace: 'nowrap', padding: '7px 11px', borderRadius: 10, background: 'var(--ink-900)', color: 'var(--paper)',
        font: '600 13px/1.2 var(--font-body)', transition: 'opacity var(--dur-fast) var(--ease-out), transform var(--dur-fast) var(--ease-out)', zIndex: 20 }}>
        {content}
      </span>
    </span>
  );
}
