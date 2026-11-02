import React from 'react';
import { Icon } from '../core/Icon.jsx';

export function Checkbox({ checked, defaultChecked = false, onChange, label, description, disabled, style }) {
  const [inner, setInner] = React.useState(defaultChecked);
  const on = checked ?? inner;
  const toggle = () => { if (disabled) return; setInner(!on); onChange && onChange(!on); };
  return (
    <label onClick={toggle} style={{ display: 'flex', alignItems: 'flex-start', gap: 12, cursor: disabled ? 'not-allowed' : 'pointer', opacity: disabled ? .45 : 1, ...style }}>
      <span role="checkbox" aria-checked={on} style={{ width: 24, height: 24, flexShrink: 0, borderRadius: 8, display: 'flex', alignItems: 'center', justifyContent: 'center',
        background: on ? 'var(--accent)' : 'var(--white)', boxShadow: on ? '0 2px 0 var(--accent-shade)' : 'inset 0 0 0 2px var(--control-border)',
        transform: on ? 'scale(1)' : 'scale(.96)', transition: 'all var(--dur-fast) var(--ease-bounce)' }}>
        {on && <Icon name="check" size={16} strokeWidth={3.25} color="#fff" />}
      </span>
      {(label || description) && <span style={{ display: 'flex', flexDirection: 'column', gap: 2, paddingTop: 2 }}>
        {label && <span style={{ font: '500 16px/1.3 var(--font-body)', color: 'var(--text-primary)' }}>{label}</span>}
        {description && <span style={{ font: '400 13px/1.4 var(--font-body)', color: 'var(--text-tertiary)' }}>{description}</span>}
      </span>}
    </label>
  );
}
