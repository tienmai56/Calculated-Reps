import React from 'react';
import { Icon } from '../core/Icon.jsx';

export function Select({ label, options = [], value, defaultValue, onChange, placeholder, disabled, style }) {
  const [focus, setFocus] = React.useState(false);
  return (
    <label style={{ display: 'flex', flexDirection: 'column', gap: 8, ...style }}>
      {label && <span style={{ font: '700 14px/1.2 var(--font-display)', color: 'var(--text-primary)' }}>{label}</span>}
      <span style={{ position: 'relative', display: 'flex', alignItems: 'center' }}>
        <select value={value} defaultValue={defaultValue} onChange={onChange} disabled={disabled} onFocus={() => setFocus(true)} onBlur={() => setFocus(false)}
          style={{ appearance: 'none', WebkitAppearance: 'none', width: '100%', height: 50, padding: '0 44px 0 16px', border: 0, outline: 'none',
            background: 'var(--surface-input)', color: 'var(--text-primary)', font: '500 16px var(--font-body)', borderRadius: 'var(--radius-md)',
            boxShadow: `inset 0 0 0 1.5px ${focus ? 'var(--border-focus)' : 'var(--border-default)'}`, cursor: 'pointer', opacity: disabled ? .5 : 1 }}>
          {placeholder && <option value="" disabled>{placeholder}</option>}
          {options.map(o => typeof o === 'string' ? <option key={o} value={o}>{o}</option> : <option key={o.value} value={o.value}>{o.label}</option>)}
        </select>
        <Icon name="chevron-down" size={18} color="var(--text-tertiary)" style={{ position: 'absolute', right: 16, pointerEvents: 'none' }} />
      </span>
    </label>
  );
}
