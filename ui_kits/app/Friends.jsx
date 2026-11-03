const { Avatar: FAv, IconButton: FIB, Icon: FIcon, Button: FBtn, Tabs: FTabs, StreakBelt: FBelt, Belt: FRank, Badge: FBadge } = window.MatMonkeysDesignSystem_8b0f80;

function streakCopy(mm, f) {
  const n = mm.streakOf(f); const first = mm.person(f.id).name.split(' ')[0];
  if (n === 0 && !f.best) return { line: 'New friend. Train together to start a streak', cta: 'Invite', state: 'broken' };
  if (n === 0) return { line: `Ended ${f.brokeAgo || 'recently'} · best ${f.best} weeks`, cta: 'Start again', state: 'broken' };
  if (f.thisWeek === 'done') return { line: n === 1 ? `New streak with ${first}. Same time next week?` : `This week's locked in. Longest: ${Math.max(f.best, n)} weeks`, state: 'done' };
  return { line: `Roll together by Sunday to make it ${n + 1}`, cta: 'Invite', state: 'pending' };
}

function FriendStreakCard({ f }) {
  const mm = useMM(); const p = mm.person(f.id); const n = mm.streakOf(f); const c = streakCopy(mm, f);
  const [, tint, ink] = HUEV[p.hue]; const broken = c.state === 'broken';
  return <div onClick={() => mm.go('friend', { id: f.id })} style={{ background: 'var(--white)', borderRadius: 24, padding: 16, boxShadow: 'var(--shadow-card)', cursor: 'pointer' }}>
    <Row>
      <PairAvatars a={mm.s.me} b={p} size={40} hue={broken ? 'coral' : p.hue} knot={!broken} />
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ font: '800 17px/1.15 var(--font-display)', letterSpacing: '-.02em' }}>You + {p.name.split(' ')[0]}</div>
        <Txt s={13} c="var(--text-tertiary)">{c.line}</Txt>
      </div>
      {broken ? <FBtn size="sm" variant="secondary" onClick={e => { e.stopPropagation(); mm.go('create', { friend: f.id }); }}>{c.cta}</FBtn>
        : <div style={{ textAlign: 'right', lineHeight: 1 }}><div style={{ font: '800 30px/1 var(--font-display)', letterSpacing: '-.04em', color: ink }}>{n}</div><Txt s={11} w={700} c="var(--text-tertiary)">{n === 1 ? 'WEEK' : 'WEEKS'}</Txt></div>}
    </Row>
    <div style={{ marginTop: 14, opacity: broken ? .55 : 1 }}><FBelt weeks={f.weeks} thisWeek={f.thisWeek} hue={p.hue} showFlame={!broken} /></div>
    {c.state === 'pending' && <Row style={{ marginTop: 12, padding: '10px 12px', borderRadius: 16, background: tint, justifyContent: 'space-between' }}>
      <Txt s={13} w={600} c={ink}>{p.name.split(' ')[0]} is free most Thursdays</Txt>
      <FBtn size="sm" iconLeft="calendar-plus" onClick={e => { e.stopPropagation(); mm.go('create', { friend: f.id }); }}>Invite</FBtn>
    </Row>}
  </div>;
}

function FriendsScreen() {
  const mm = useMM(); const fr = mm.s.friends;
  const pending = fr.filter(f => mm.streakOf(f) > 0 && f.thisWeek === 'pending');
  const done = fr.filter(f => f.thisWeek === 'done');
  const fresh = fr.filter(f => mm.streakOf(f) === 0 && !f.best);
  const broken = fr.filter(f => mm.streakOf(f) === 0 && f.best);
  const Sec = ({ t, sub, list }) => list.length ? <><Eyebrow right={sub && <Txt s={13} w={600} c="var(--text-tertiary)">{sub}</Txt>}>{t}</Eyebrow><div style={{ padding: '0 16px', display: 'flex', flexDirection: 'column', gap: 12 }}>{list.map(f => <FriendStreakCard key={f.id} f={f} />)}</div></> : null;
  return <Screen tabPad header={<Header large title="Friends" right={<FIB icon="qr-code" variant="filled" label="My QR code" onClick={() => mm.go('qr')} />} />}>
    <div onClick={() => mm.go('qr', { tab: 'scan' })} style={{ margin: '4px 16px 0', padding: '16px 16px 16px 18px', borderRadius: 24, background: 'var(--sun-100)', display: 'flex', alignItems: 'center', gap: 14, cursor: 'pointer' }}>
      <div style={{ flex: 1 }}><div style={{ font: '800 18px/1.15 var(--font-display)', letterSpacing: '-.02em' }}>At the gym with someone new?</div><Txt s={13} c="var(--ink-700)">Scan their code. You're friends instantly.</Txt></div>
      <span style={{ width: 52, height: 52, borderRadius: 16, background: 'var(--ink-900)', display: 'flex', alignItems: 'center', justifyContent: 'center', transform: 'rotate(6deg)' }}><FIcon name="scan-line" size={26} color="var(--sun-400)" strokeWidth={2.25} /></span>
    </div>
    <Sec t="New friends" list={fresh} />
    <Sec t="Keep it going" sub="Weeks run Mon–Sun" list={pending} />
    <Sec t="Trained together this week" list={done} />
    <Sec t="Pick it back up" list={broken} />
    <div style={{ textAlign: 'center', padding: '24px 40px 8px' }}><Txt s={13} c="var(--text-tertiary)">A streak grows each week you and a friend finish at least one session together.</Txt></div>
  </Screen>;
}

function FriendProfile({ id }) {
  const mm = useMM(); const p = mm.person(id); const f = mm.s.friends.find(x => x.id === id);
  const n = f ? mm.streakOf(f) : 0; const [, tint, ink] = HUEV[p.hue || 'coral'];
  const shared = mm.s.posts.filter(x => x.participants.includes('me') && x.participants.includes(id));
  const first = p.name.split(' ')[0];
  return <Screen push header={<Header left={<FIB icon="chevron-left" label="Back" onClick={mm.back} />} title="" />} footer={<FBtn size="lg" fullWidth iconLeft="calendar-plus" onClick={() => mm.go('create', { friend: id })}>Invite {first} to train</FBtn>}>
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', textAlign: 'center', padding: '0 24px' }}>
      <FAv name={p.name} src={p.src} size={104} belt={p.belt} />
      <div style={{ font: '800 30px/1.05 var(--font-display)', letterSpacing: '-.035em', marginTop: 14 }}>{p.name}</div>
      <Txt s={14} c="var(--text-tertiary)" style={{ marginTop: 4 }}>{p.gym}</Txt>
      <div style={{ width: 180, marginTop: 14 }}><FRank rank={p.belt} stripes={p.stripes} size="sm" label /></div>
    </div>
    {f && <div style={{ margin: '22px 16px 0', padding: 18, borderRadius: 26, background: tint }}>
      <Row><PairAvatars a={mm.s.me} b={p} size={36} hue={p.hue} /><div style={{ flex: 1 }}><div style={{ font: '800 20px/1.1 var(--font-display)', letterSpacing: '-.03em', color: ink }}>{n ? `${n}-week streak` : 'Streak on pause'}</div><Txt s={13} c="var(--ink-700)">{n ? (f.thisWeek === 'done' ? 'This week is covered.' : 'Train together by Sunday to keep it.') : `Your best was ${f.best} weeks. Start a new one?`}</Txt></div></Row>
      <div style={{ marginTop: 14 }}><FBelt weeks={f.weeks} thisWeek={f.thisWeek} hue={p.hue} /></div>
      <Row style={{ marginTop: 14, gap: 0 }}>{[['Longest streak', Math.max(f.best, n) + ' wks'], ['Sessions together', f.together]].map(([l, v], i) => <div key={l} style={{ flex: 1, paddingLeft: i ? 14 : 0, boxShadow: i ? 'inset 1.5px 0 0 rgba(29,27,24,.1)' : 'none' }}><div style={{ font: '800 22px var(--font-display)', letterSpacing: '-.03em' }}>{v}</div><Txt s={12} w={600} c="var(--ink-700)">{l}</Txt></div>)}</Row>
    </div>}
    <Eyebrow>Memories together</Eyebrow>
    <div style={{ padding: '0 16px 20px', display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
      {shared.length ? shared.map(x => <PhotoTile key={x.id} src={x.photo} h={150} radius={18} onClick={() => mm.go('post', { id: x.id })}><span style={{ position: 'absolute', left: 8, right: 8, bottom: 8, font: '800 13px/1.1 var(--font-display)', color: '#fff', textShadow: '0 1px 6px rgba(0,0,0,.6)' }}>{x.title}</span></PhotoTile>)
        : <Txt s={14} c="var(--text-tertiary)">No shared posts yet. Fix that this week.</Txt>}
    </div>
  </Screen>;
}

function QRGrid({ seed = 7, size = 200 }) {
  const N = 25; let x = seed;
  const rnd = () => (x = (x * 9301 + 49297) % 233280) / 233280;
  const finder = (r, c) => { for (const [R, C] of [[0, 0], [0, N - 7], [N - 7, 0]]) { if (r >= R && r < R + 7 && c >= C && c < C + 7) { const rr = r - R, cc = c - C; return rr === 0 || rr === 6 || cc === 0 || cc === 6 || (rr >= 2 && rr <= 4 && cc >= 2 && cc <= 4) ? 1 : 0; } if (r >= R - 1 && r <= R + 7 && c >= C - 1 && c <= C + 7) return 0; } return null; };
  const cells = []; for (let r = 0; r < N; r++) for (let c = 0; c < N; c++) { const f = finder(r, c); const mid = r > 9 && r < 15 && c > 9 && c < 15; cells.push(mid ? 0 : f !== null ? f : rnd() > .52 ? 1 : 0); }
  return <div style={{ position: 'relative', width: size, height: size, display: 'grid', gridTemplateColumns: `repeat(${N}, 1fr)` }}>
    {cells.map((v, i) => <span key={i} style={{ background: v ? 'var(--ink-900)' : 'transparent', borderRadius: 1.5 }}></span>)}
    <span style={{ position: 'absolute', left: '50%', top: '50%', transform: 'translate(-50%,-50%)', width: size * .18, height: size * .18, borderRadius: 10, background: 'var(--accent)', display: 'flex', alignItems: 'center', justifyContent: 'center', font: `800 ${size * .07}px var(--font-display)`, color: '#fff' }}>mm.</span>
  </div>;
}

function QRScreen({ tab: t0 }) {
  const mm = useMM(); const [tab, setTab] = React.useState(t0 || 'code'); const [found, setFound] = React.useState(null);
  React.useEffect(() => { if (tab !== 'scan' || found) return; const t = setTimeout(() => { setFound('lena'); mm.addFriend('lena'); }, 2200); return () => clearTimeout(t); }, [tab, found]);
  const me = mm.s.me;
  return <Screen push bg={tab === 'scan' ? '#141210' : 'var(--bg-app)'} header={<div style={{ color: tab === 'scan' ? '#fff' : undefined }}><Header left={<FIB icon="x" label="Close" variant={tab === 'scan' ? 'overlay' : 'ghost'} onClick={mm.back} />} title={<span style={{ color: tab === 'scan' ? '#fff' : 'var(--ink-900)' }}>Add friends</span>} />
    <div style={{ padding: '0 16px 4px' }}><FTabs items={[{ id: 'code', label: 'My code' }, { id: 'scan', label: 'Scan' }]} value={tab} onChange={v => { setTab(v); setFound(null); }} /></div></div>}>
    {tab === 'code' ? <div style={{ padding: '28px 24px 0', display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
      <div style={{ position: 'relative', width: '100%', padding: '54px 24px 26px', borderRadius: 32, background: 'var(--coral-500)', display: 'flex', flexDirection: 'column', alignItems: 'center', boxSizing: 'border-box' }}>
        <span style={{ position: 'absolute', top: -40, borderRadius: 999, boxShadow: '0 0 0 5px var(--bg-app)', display: 'inline-flex' }}><FAv name={me.name} src={me.src} size={80} belt={me.belt} ring="var(--coral-500)" /></span>
        <div style={{ font: '800 24px/1 var(--font-display)', letterSpacing: '-.03em', color: '#fff' }}>{me.name}</div>
        <div style={{ width: 120, margin: '10px 0 18px' }}><FRank rank={me.belt} stripes={me.stripes} size="xs" /></div>
        <div style={{ padding: 18, background: '#fff', borderRadius: 24, transform: 'rotate(-2deg)', boxShadow: '0 10px 30px rgba(120,30,0,.3)' }}><QRGrid size={196} /></div>
      </div>
      <div style={{ font: '800 20px/1.2 var(--font-display)', letterSpacing: '-.02em', marginTop: 26, textAlign: 'center' }}>Hold this up after class</div>
      <Txt s={15} c="var(--text-secondary)" style={{ textAlign: 'center', marginTop: 6 }}>When a training partner scans it, you're friends. No requests, no waiting.</Txt>
      <FBtn variant="secondary" iconLeft="scan-line" style={{ marginTop: 18 }} onClick={() => setTab('scan')}>Scan someone instead</FBtn>
    </div>
    : <div style={{ position: 'relative', margin: '14px 16px 0', height: 560, borderRadius: 32, overflow: 'hidden' }}>
      <img src={MM_PH('team-lineup')} style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', objectFit: 'cover', filter: 'brightness(.55) saturate(.8)' }} />
      <div style={{ position: 'absolute', left: '50%', top: '44%', width: 220, height: 220, transform: 'translate(-50%,-50%)' }}>
        {[[0, 0, '0 0'], [1, 0, '0 0'], [0, 1, '0 0'], [1, 1, '0 0']].map(([r, b], i) => <span key={i} style={{ position: 'absolute', width: 44, height: 44, [r ? 'right' : 'left']: 0, [b ? 'bottom' : 'top']: 0, borderStyle: 'solid', borderColor: found ? 'var(--mint-500)' : '#fff', borderWidth: `${b ? 0 : 5}px ${r ? 5 : 0}px ${b ? 5 : 0}px ${r ? 0 : 5}px`, borderRadius: `${!r && !b ? 18 : 0}px ${r && !b ? 18 : 0}px ${r && b ? 18 : 0}px ${!r && b ? 18 : 0}px`, transition: 'border-color .2s' }}></span>)}
        {!found && <span style={{ position: 'absolute', left: 14, right: 14, height: 3, borderRadius: 3, background: 'var(--sun-400)', boxShadow: '0 0 16px var(--sun-400)', animation: 'mmScan 1.6s ease-in-out infinite alternate' }}></span>}
      </div>
      <div style={{ position: 'absolute', left: 0, right: 0, bottom: 28, textAlign: 'center', color: '#fff', font: '700 15px var(--font-body)' }}>{found ? 'Got it!' : 'Point at a friend\'s Mat Monkeys code'}</div>
      {found && <Connected id={found} onDone={() => { setFound(null); mm.back(); }} />}
    </div>}
  </Screen>;
}

function Connected({ id, onDone }) {
  const mm = useMM(); const p = mm.person(id); const me = mm.s.me;
  return <div style={{ position: 'absolute', inset: 0, background: 'var(--sun-400)', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', padding: 24, textAlign: 'center', animation: 'mmFade .25s var(--ease-out)' }}>
    <div style={{ position: 'relative', display: 'flex', alignItems: 'center', height: 120 }}>
      <span style={{ animation: 'mmSlideL .7s var(--ease-bounce) both', borderRadius: 999, boxShadow: '0 0 0 5px var(--sun-400)', display: 'inline-flex' }}><FAv name={me.name} src={me.src} size={104} /></span>
      <span style={{ marginLeft: -26, animation: 'mmSlideR .7s var(--ease-bounce) both', borderRadius: 999, boxShadow: '0 0 0 5px var(--sun-400)', display: 'inline-flex' }}><FAv name={p.name} size={104} /></span>
      <span style={{ position: 'absolute', left: '50%', bottom: -6, width: 56, height: 56, marginLeft: -28, borderRadius: 999, background: 'var(--ink-900)', display: 'flex', alignItems: 'center', justifyContent: 'center', animation: 'mmPop .5s .55s var(--ease-bounce) both', boxShadow: '0 0 0 5px var(--sun-400)' }}><FIcon name="handshake" size={28} color="var(--sun-400)" /></span>
    </div>
    <div style={{ font: '800 30px/1.05 var(--font-display)', letterSpacing: '-.04em', marginTop: 28, color: 'var(--ink-900)', animation: 'mmFadeUp .4s .6s var(--ease-out) both' }}>You & {p.name.split(' ')[0]} are friends</div>
    <Txt s={15} c="var(--ink-800)" style={{ marginTop: 8, animation: 'mmFadeUp .4s .7s var(--ease-out) both' }}>Train together this week to start your first streak.</Txt>
    <div style={{ display: 'flex', flexDirection: 'column', gap: 8, width: '100%', marginTop: 26, animation: 'mmFadeUp .4s .8s var(--ease-out) both' }}>
      <FBtn size="lg" variant="inverse" fullWidth iconLeft="calendar-plus" onClick={() => { mm.back(); mm.go('create', { friend: id }); }}>Plan a session with {p.name.split(' ')[0]}</FBtn>
      <FBtn variant="ghost" fullWidth onClick={onDone}>Done</FBtn>
    </div>
  </div>;
}
Object.assign(window, { FriendsScreen, FriendProfile, QRScreen });
