import React from 'react';
import { Icon } from '../core/Icon.jsx';

const HUE = {
  coral: ['var(--coral-500)', 'var(--coral-100)'], sun: ['var(--sun-400)', 'var(--sun-100)'], mint: ['var(--mint-500)', 'var(--mint-100)'],
  sky: ['var(--sky-500)', 'var(--sky-100)'], plum: ['var(--plum-500)', 'var(--plum-100)'],
};

export function StreakBelt({ weeks = [], thisWeek = 'pending', hue = 'coral', size = 'md', showFlame = true, style }) {
  const [c, tint] = HUE[hue] || HUE.coral;
  const h = size === 'sm' ? 14 : 22;
  const cells = [...weeks, thisWeek];
  const lastIdx = cells.length - 1;
  const alive = thisWeek === 'done' || (thisWeek === 'pending' && weeks[weeks.length - 1]);
  return (
    <span style={{ display: 'flex', alignItems: 'center', gap: 6, ...style }}>
      <span style={{ flex: 1, display: 'flex', gap: 3, height: h }}>
        {cells.map((w, i) => {
          const isNow = i === lastIdx;
          const done = isNow ? thisWeek === 'done' : !!w;
          const first = i === 0 || !(isNow ? weeks[i - 1] : cells[i - 1]);
          const last = isNow || !cells[i + 1] || (i + 1 === lastIdx && thisWeek !== 'done');
          return <span key={i} title={isNow ? 'This week' : ''} style={{ flex: 1, position: 'relative', borderRadius: `${first ? 6 : 2}px ${last ? 6 : 2}px ${last ? 6 : 2}px ${first ? 6 : 2}px`,
            background: done ? c : isNow ? 'transparent' : 'var(--paper-3)', boxShadow: isNow && !done ? `inset 0 0 0 2px ${c}` : 'none', opacity: isNow && !done ? .7 : 1,
            backgroundImage: isNow && !done ? `repeating-linear-gradient(135deg, ${tint} 0 4px, transparent 4px 8px)` : 'none' }}>
            {done && size !== 'sm' && <span style={{ position: 'absolute', right: 4, top: 4, bottom: 4, width: 3, borderRadius: 1, background: 'rgba(255,255,255,.85)' }}></span>}
          </span>;
        })}
      </span>
      {showFlame && <span style={{ width: h + 6, height: h + 6, borderRadius: 999, flexShrink: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', background: alive ? 'var(--flame-100)' : 'var(--paper-2)' }}>
        <Icon name="flame" size={Math.round(h * 0.72)} filled={alive} color={alive ? 'var(--flame-500)' : 'var(--ink-300)'} />
      </span>}
    </span>
  );
}
