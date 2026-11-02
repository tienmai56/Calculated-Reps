import React from 'react';

export function Switch({ checked, defaultChecked = false, onChange, label, description, disabled, style }) {
  const [inner, setInner] = React.useState(defaultChecked);
  const on = checked ?? inner;
  const toggle = () => { if (disabled) return; setInner(!on); onChange && onChange(!on); };
  const track = (
    <span role="switch" aria-checked={on} onClick={label ? undefined : toggle} style={{ width: 52, height: 32, flexShrink: 0, borderRadius: 999, position: 'relative', cursor: disabled ? 'not-allowed' : 'pointer',
      background: on ? 'var(--accent)' : 'var(--control-off)', opacity: disabled ? .45 : 1, transition: 'background var(--dur-base) var(--ease-out)' }}>
      <span style={{ position: 'absolute', top: 3, left: 3, width: 26, height: 26, borderRadius: 999, background: '#fff', boxShadow: '0 2px 4px rgba(29,27,24,.18)',
        transform: on ? 'translateX(20px)' : 'none', transition: 'transform var(--dur-base) var(--ease-bounce)' }}></span>
    </span>
  );
  if (!label) return track;
  return (
    <label onClick={toggle} style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 16, cursor: 'pointer', ...style }}>
      <span style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
        <span style={{ font: '500 16px/1.3 var(--font-body)', color: 'var(--text-primary)' }}>{label}</span>
        {description && <span style={{ font: '400 13px/1.4 var(--font-body)', color: 'var(--text-tertiary)' }}>{description}</span>}
      </span>
      {track}
    </label>
  );
}
