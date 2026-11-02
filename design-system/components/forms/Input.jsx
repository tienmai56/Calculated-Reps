import React from 'react';
import { Icon } from '../core/Icon.jsx';

export function Input({ label, hint, error, iconLeft, value, defaultValue, placeholder, onChange, multiline = false, rows = 3, disabled, type = 'text', style, inputStyle, ...rest }) {
  const [focus, setFocus] = React.useState(false);
  const Tag = multiline ? 'textarea' : 'input';
  const border = error ? 'var(--danger-500)' : focus ? 'var(--border-focus)' : 'var(--border-default)';
  return (
    <label style={{ display: 'flex', flexDirection: 'column', gap: 8, ...style }}>
      {label && <span style={{ font: '700 14px/1.2 var(--font-display)', color: 'var(--text-primary)' }}>{label}</span>}
      <span style={{ display: 'flex', alignItems: multiline ? 'flex-start' : 'center', gap: 10, minHeight: 50, padding: multiline ? '14px 16px' : '0 16px', boxSizing: 'border-box',
        background: 'var(--surface-input)', borderRadius: 'var(--radius-md)', boxShadow: `inset 0 0 0 1.5px ${border}${focus && !error ? ', 0 0 0 4px var(--accent-tint)' : ''}`,
        opacity: disabled ? .5 : 1, transition: 'box-shadow var(--dur-fast) var(--ease-out)' }}>
        {iconLeft && <Icon name={iconLeft} size={18} color="var(--text-tertiary)" style={{ marginTop: multiline ? 2 : 0 }} />}
        <Tag type={multiline ? undefined : type} rows={multiline ? rows : undefined} value={value} defaultValue={defaultValue} placeholder={placeholder} onChange={onChange} disabled={disabled}
          onFocus={() => setFocus(true)} onBlur={() => setFocus(false)}
          style={{ flex: 1, minWidth: 0, border: 0, outline: 'none', background: 'transparent', color: 'var(--text-primary)', resize: 'none', font: '400 16px/1.45 var(--font-body)', padding: 0, ...inputStyle }} {...rest} />
      </span>
      {(error || hint) && <span style={{ font: '500 13px/1.3 var(--font-body)', color: error ? 'var(--danger-500)' : 'var(--text-tertiary)' }}>{error || hint}</span>}
    </label>
  );
}
