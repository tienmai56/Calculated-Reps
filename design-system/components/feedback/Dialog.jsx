import React from 'react';
import { IconButton } from '../core/IconButton.jsx';

export function Dialog({ open = true, onClose, title, description, children, actions, variant = 'sheet', contained = false, style }) {
  if (!open) return null;
  const sheet = variant === 'sheet';
  return (
    <div onClick={onClose} style={{ position: contained ? 'absolute' : 'fixed', inset: 0, zIndex: 50, background: 'var(--surface-overlay)',
      display: 'flex', alignItems: sheet ? 'flex-end' : 'center', justifyContent: 'center', padding: sheet ? 0 : 24, animation: 'mmFade var(--dur-base) var(--ease-out)' }}>
      <div role="dialog" aria-modal="true" onClick={e => e.stopPropagation()}
        style={{ width: '100%', maxWidth: sheet ? undefined : 340, background: 'var(--white)', boxSizing: 'border-box',
          borderRadius: sheet ? 'var(--radius-xl) var(--radius-xl) 0 0' : 'var(--radius-xl)', boxShadow: sheet ? 'var(--shadow-sheet)' : 'var(--shadow-float)',
          padding: sheet ? '10px 20px 34px' : 22, maxHeight: '88%', overflowY: 'auto', animation: sheet ? 'mmSheet var(--dur-slow) var(--ease-out)' : 'mmPop var(--dur-base) var(--ease-bounce)', ...style }}>
        {sheet && <div style={{ width: 40, height: 5, borderRadius: 999, background: 'var(--ink-200)', margin: '0 auto 16px' }}></div>}
        {(title || onClose) && (
          <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', gap: 12 }}>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
              {title && <div style={{ font: '800 22px/1.15 var(--font-display)', letterSpacing: '-.02em', color: 'var(--text-primary)' }}>{title}</div>}
              {description && <div style={{ font: '400 15px/1.45 var(--font-body)', color: 'var(--text-secondary)' }}>{description}</div>}
            </div>
            {onClose && <IconButton icon="x" size={36} variant="filled" label="Close" onClick={onClose} />}
          </div>
        )}
        {children && <div style={{ marginTop: 16 }}>{children}</div>}
        {actions && <div style={{ display: 'flex', gap: 10, marginTop: 20 }}>{actions}</div>}
      </div>
      <style>{'@keyframes mmFade{from{opacity:0}}@keyframes mmSheet{from{transform:translateY(100%)}}@keyframes mmPop{from{transform:scale(.92);opacity:0}}'}</style>
    </div>
  );
}
