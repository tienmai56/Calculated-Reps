import React from 'react';
import { Icon } from '../core/Icon.jsx';

export function Tag({ children, icon, selected = false, onClick, onRemove, size = 'md', style }) {
  const [hover, setHover] = React.useState(false);
  const h = size === 'sm' ? 32 : 40;
  return (
    <span onClick={onClick} onMouseEnter={() => setHover(true)} onMouseLeave={() => setHover(false)}
      style={{ display: 'inline-flex', alignItems: 'center', gap: 6, height: h, padding: `0 ${size === 'sm' ? 12 : 16}px`, borderRadius: 999, boxSizing: 'border-box', flexShrink: 0,
        background: selected ? 'var(--ink-900)' : hover && onClick ? 'var(--paper-2)' : 'var(--white)', color: selected ? 'var(--paper)' : 'var(--text-primary)',
        boxShadow: selected ? 'none' : 'inset 0 0 0 1.5px var(--border-default)', font: `600 ${size === 'sm' ? 13 : 15}px/1 var(--font-body)`,
        cursor: onClick ? 'pointer' : 'default', whiteSpace: 'nowrap', userSelect: 'none', transition: 'background var(--dur-fast) var(--ease-out)', ...style }}>
      {icon && <Icon name={icon} size={size === 'sm' ? 14 : 16} strokeWidth={2.25} />}
      {children}
      {onRemove && <span onClick={e => { e.stopPropagation(); onRemove(); }} style={{ display: 'flex', marginRight: -4, opacity: .6, cursor: 'pointer' }}><Icon name="x" size={14} strokeWidth={2.5} /></span>}
    </span>
  );
}
