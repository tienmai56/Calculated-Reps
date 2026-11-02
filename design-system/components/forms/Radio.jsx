import React from 'react';

export function Radio({ checked = false, onChange, label, description, disabled, name, value, style }) {
  return (
    <label onClick={() => !disabled && onChange && onChange(value)} style={{ display: 'flex', alignItems: 'flex-start', gap: 12, cursor: disabled ? 'not-allowed' : 'pointer', opacity: disabled ? .45 : 1, ...style }}>
      <span role="radio" aria-checked={checked} data-name={name} style={{ width: 24, height: 24, flexShrink: 0, borderRadius: 999, display: 'flex', alignItems: 'center', justifyContent: 'center', background: 'var(--white)',
        boxShadow: checked ? 'inset 0 0 0 2px var(--accent)' : 'inset 0 0 0 2px var(--control-border)', transition: 'box-shadow var(--dur-fast) var(--ease-out)' }}>
        <span style={{ width: 12, height: 12, borderRadius: 999, background: 'var(--accent)', transform: checked ? 'scale(1)' : 'scale(0)', transition: 'transform var(--dur-base) var(--ease-bounce)' }}></span>
      </span>
      {(label || description) && <span style={{ display: 'flex', flexDirection: 'column', gap: 2, paddingTop: 2 }}>
        {label && <span style={{ font: '500 16px/1.3 var(--font-body)', color: 'var(--text-primary)' }}>{label}</span>}
        {description && <span style={{ font: '400 13px/1.4 var(--font-body)', color: 'var(--text-tertiary)' }}>{description}</span>}
      </span>}
    </label>
  );
}
