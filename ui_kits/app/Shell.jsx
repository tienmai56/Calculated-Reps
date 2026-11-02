const DS = window.MatMonkeysDesignSystem_8b0f80;
const { Avatar: SAv, Icon: SIcon } = DS;
const HUEV = { coral: ['var(--coral-500)', 'var(--coral-100)', 'var(--coral-700)'], sun: ['var(--sun-400)', 'var(--sun-100)', '#8A6200'], mint: ['var(--mint-500)', 'var(--mint-100)', 'var(--mint-700)'], sky: ['var(--sky-500)', 'var(--sky-100)', 'var(--sky-700)'], plum: ['var(--plum-500)', 'var(--plum-100)', 'var(--plum-700)'] };
const hideScroll = { scrollbarWidth: 'none' };

function StatusBar() {
  return <div style={{ height: 50, display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '6px 30px 0 38px', font: '700 16px var(--font-body)', color: 'var(--ink-900)', flexShrink: 0 }}>
    <span>9:41</span>
    <span style={{ display: 'flex', gap: 6, alignItems: 'center' }}>
      <span style={{ display: 'flex', gap: 2, alignItems: 'flex-end' }}>{[5, 8, 11, 14].map(h => <span key={h} style={{ width: 3, height: h, borderRadius: 1, background: 'currentColor' }}></span>)}</span>
      <span style={{ width: 25, height: 12, borderRadius: 4, boxShadow: 'inset 0 0 0 1.5px var(--ink-400)', padding: 2, boxSizing: 'border-box' }}><span style={{ display: 'block', width: '80%', height: '100%', background: 'currentColor', borderRadius: 1.5 }}></span></span>
    </span>
  </div>;
}
function Phone({ children }) {
  return <div style={{ width: 390, height: 844, borderRadius: 54, background: 'var(--bg-app)', position: 'relative', overflow: 'hidden', display: 'flex', flexDirection: 'column', flexShrink: 0,
    boxShadow: '0 0 0 10px #1D1B18, 0 0 0 11px #3a3631, 0 40px 80px rgba(29,27,24,.35)' }}>
    <div style={{ position: 'absolute', top: 11, left: '50%', transform: 'translateX(-50%)', width: 122, height: 34, borderRadius: 20, background: '#000', zIndex: 90 }}></div>
    <StatusBar />
    <div style={{ flex: 1, position: 'relative', minHeight: 0 }}>{children}</div>
    <div style={{ position: 'absolute', bottom: 8, left: '50%', transform: 'translateX(-50%)', width: 134, height: 5, borderRadius: 3, background: 'var(--ink-900)', zIndex: 90 }}></div>
  </div>;
}
// A screen = fixed header + scroll body + optional footer. push = slides in over tabs.
function Screen({ header, children, footer, push, tabPad, bg, scrollRef }) {
  return <div style={{ position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column', background: bg || 'var(--bg-app)', zIndex: push ? 30 : 1, animation: push ? 'mmPush var(--dur-slow) var(--ease-out)' : 'none' }}>
    {header}
    <div ref={scrollRef} style={{ flex: 1, overflowY: 'auto', ...hideScroll, paddingBottom: tabPad ? 104 : 0 }}>{children}</div>
    {footer && <div style={{ padding: '12px 16px 34px', background: 'linear-gradient(to bottom, rgba(250,246,239,0), var(--bg-app) 30%)', flexShrink: 0 }}>{footer}</div>}
  </div>;
}
function Header({ title, large, left, right, sub }) {
  return <div style={{ display: 'flex', alignItems: 'center', gap: 6, padding: large ? '6px 10px 10px 20px' : '4px 10px 8px 10px', minHeight: 54, flexShrink: 0 }}>
    {left}
    <div style={{ flex: 1, minWidth: 0, textAlign: large || left == null ? 'left' : 'center', paddingRight: !large && left && !right ? 44 : 0 }}>
      <div style={{ font: large ? '800 32px/1 var(--font-display)' : '800 18px/1.2 var(--font-display)', letterSpacing: large ? '-.035em' : '-.015em', color: 'var(--ink-900)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{title}</div>
      {sub && <div style={{ font: '500 13px var(--font-body)', color: 'var(--text-tertiary)', marginTop: 3 }}>{sub}</div>}
    </div>
    <div style={{ display: 'flex', gap: 4 }}>{right}</div>
  </div>;
}
function Eyebrow({ children, right, style }) {
  return <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', padding: '0 20px', margin: '22px 0 10px', ...style }}>
    <span style={{ font: '800 18px/1.2 var(--font-display)', letterSpacing: '-.02em', color: 'var(--ink-900)' }}>{children}</span>{right}
  </div>;
}
function TapeLabel({ children, rotate = -3, style }) {
  return <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6, padding: '6px 12px 6px 11px', background: '#FFFDF8', color: 'var(--ink-900)', font: '800 13px/1 var(--font-display)', letterSpacing: '-.01em',
    transform: `rotate(${rotate}deg)`, boxShadow: '0 2px 6px rgba(29,27,24,.2)', clipPath: 'polygon(2% 0, 98% 4%, 100% 50%, 97% 100%, 3% 96%, 0 50%)', ...style }}>{children}</span>;
}
// Two avatars tied together — the friendship mark
function PairAvatars({ a, b, size = 44, hue = 'coral', knot = true, style }) {
  const [c, tint] = HUEV[hue] || HUEV.coral;
  return <span style={{ position: 'relative', display: 'inline-flex', alignItems: 'center', flexShrink: 0, ...style }}>
    <span style={{ borderRadius: 999, boxShadow: '0 0 0 3px var(--surface-card)', display: 'inline-flex' }}><SAv name={a.name} src={a.src} size={size} /></span>
    <span style={{ marginLeft: -size * 0.3, borderRadius: 999, boxShadow: '0 0 0 3px var(--surface-card)', display: 'inline-flex' }}><SAv name={b.name} src={b.src} size={size} /></span>
    {knot && <span style={{ position: 'absolute', left: '50%', bottom: -4, transform: 'translateX(-50%)', width: size * 0.5, height: size * 0.22, borderRadius: 4, background: c, boxShadow: '0 0 0 2px var(--surface-card)' }}></span>}
  </span>;
}
function PhotoTile({ src, h = 280, radius = 22, children, style, onClick }) {
  return <div onClick={onClick} style={{ position: 'relative', height: h, borderRadius: radius, overflow: 'hidden', background: 'var(--paper-3)', cursor: onClick ? 'pointer' : undefined, ...style }}>
    {src && <img src={src} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }} />}
    {children}
  </div>;
}
function Row({ children, style, onClick }) { return <div onClick={onClick} style={{ display: 'flex', alignItems: 'center', gap: 12, cursor: onClick ? 'pointer' : undefined, ...style }}>{children}</div>; }
function Txt({ s = 15, w = 400, c = 'var(--text-primary)', f = 'body', lh = 1.4, children, style }) { return <span style={{ font: `${w} ${s}px/${lh} var(--font-${f})`, color: c, letterSpacing: f === 'display' ? '-.02em' : 0, ...style }}>{children}</span>; }
function names(list, max = 2) { const n = list.map(x => x.split(' ')[0]); return n.length <= max ? n.join(' & ') : n.slice(0, max).join(', ') + ' +' + (n.length - max); }

Object.assign(window, { Phone, Screen, Header, Eyebrow, TapeLabel, PairAvatars, PhotoTile, Row, Txt, names, HUEV, hideScroll });
