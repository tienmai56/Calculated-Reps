const { Avatar: MAv, IconButton: MIB, Icon: MIcon, Button: MBtn, Belt: MBelt, Dialog: MDlg, Input: MIn, Select: MSel, Badge: MBadge, StreakBelt: MStreak } = window.GripGorillasDesignSystem_8b0f80;

function ProfileScreen() {
  const mm = useMM(); const me = mm.s.me; const [settings, setSettings] = React.useState(false);
  const mine = mm.s.posts.filter(p => p.participants.includes('me'));
  const active = mm.s.friends.filter(f => mm.streakOf(f) > 0).sort((a, b) => mm.streakOf(b) - mm.streakOf(a));
  return <Screen tabPad header={<div style={{ display: 'flex', justifyContent: 'flex-end', padding: '2px 10px 0', flexShrink: 0 }}><MIB icon="settings" variant="filled" label="Settings" onClick={() => setSettings(true)} /></div>}>
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', textAlign: 'center', paddingTop: 4 }}>
      <MAv name={me.name} src={me.src} size={108} belt={me.belt} />
      <div style={{ font: '800 30px/1.05 var(--font-display)', letterSpacing: '-.035em', marginTop: 14 }}>{me.name}</div>
      <Txt s={14} c="var(--text-tertiary)" style={{ marginTop: 4 }}>{me.gym}</Txt>
      <div style={{ width: 190, marginTop: 14 }}><MBelt rank={me.belt} stripes={me.stripes} size="sm" label /></div>
      <Row style={{ gap: 10, marginTop: 18 }}>
        <MBtn size="sm" variant="secondary" iconLeft="users" onClick={() => mm.setTab('friends')}>{mm.s.friends.length} friends</MBtn>
        <MBtn size="sm" variant="secondary" iconLeft="qr-code" onClick={() => mm.go('qr')}>My code</MBtn>
      </Row>
    </div>
    <Eyebrow>Weekly streaks</Eyebrow>
    <div style={{ display: 'flex', gap: 10, overflowX: 'auto', padding: '0 16px 4px', ...hideScroll }}>
      {active.map(f => { const p = mm.person(f.id); const [, tint, ink] = HUEV[p.hue];
        return <div key={f.id} onClick={() => mm.go('friend', { id: f.id })} style={{ flexShrink: 0, width: 150, padding: 14, borderRadius: 22, background: tint, cursor: 'pointer' }}>
          <PairAvatars a={me} b={p} size={30} hue={p.hue} />
          <div style={{ font: '800 22px/1 var(--font-display)', letterSpacing: '-.03em', color: ink, marginTop: 12 }}>{mm.streakOf(f)} wk{mm.streakOf(f) > 1 ? 's' : ''}</div>
          <Txt s={13} w={600} c="var(--ink-700)">with {p.name.split(' ')[0]}</Txt>
          <div style={{ marginTop: 10 }}><MStreak weeks={f.weeks.slice(-5)} thisWeek={f.thisWeek} hue={p.hue} size="sm" showFlame={false} /></div>
        </div>; })}
    </div>
    <Eyebrow right={<Txt s={13} w={600} c="var(--text-tertiary)">{mine.length} sessions</Txt>}>Activity</Eyebrow>
    <div style={{ padding: '0 16px', display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 4 }}>
      {mine.map((p, i) => <PhotoTile key={p.id} src={p.photo} h={118} radius={i === 0 ? '18px 4px 4px 4px' : i === 2 ? '4px 18px 4px 4px' : 4} onClick={() => mm.go('post', { id: p.id })} />)}
    </div>
    {settings && <MDlg contained variant="sheet" title="Account" onClose={() => setSettings(false)}>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
        <MIn label="Name" defaultValue={me.name} />
        <div><MIn label="Email" defaultValue={me.email} iconLeft="mail" /><Row style={{ gap: 6, marginTop: 8 }}><MIcon name="lock" size={14} color="var(--text-tertiary)" /><Txt s={13} c="var(--text-tertiary)">Private. Only you can see this.</Txt></Row></div>
        <Row style={{ gap: 10 }}><MSel label="Belt" defaultValue={me.belt} options={['white', 'blue', 'purple', 'brown', 'black']} style={{ flex: 1 }} /><MSel label="Stripes" defaultValue={String(me.stripes)} options={['0', '1', '2', '3', '4']} style={{ width: 110 }} /></Row>
        <MBtn variant="ghost" iconLeft="log-out" style={{ alignSelf: 'flex-start', marginLeft: -10 }}>Sign out</MBtn>
      </div>
    </MDlg>}
  </Screen>;
}

const NICON = { invite: ['calendar', 'var(--accent)'], joined: ['user-check', 'var(--mint-500)'], comment: ['message-circle', 'var(--sky-500)'], published: ['images', 'var(--plum-500)'] };
function NotificationsScreen() {
  const mm = useMM(); const P = mm.person;
  React.useEffect(() => () => mm.readAll(), []);
  const item = n => { const p = P(n.who); const [ic, col] = NICON[n.kind]; const s = n.session && mm.s.upcoming.find(x => x.id === n.session);
    return <div key={n.id} style={{ display: 'flex', gap: 12, padding: '14px 16px', background: n.unread ? 'rgba(255,92,57,.06)' : 'transparent' }}>
      <span style={{ position: 'relative', display: 'inline-flex', alignSelf: 'flex-start' }}><MAv name={p.name} src={p.src} size={46} /><span style={{ position: 'absolute', right: -3, bottom: -3, width: 22, height: 22, borderRadius: 99, background: col, display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: '0 0 0 2.5px var(--bg-app)' }}><MIcon name={ic} size={12} strokeWidth={2.5} color="#fff" /></span></span>
      <div style={{ flex: 1, minWidth: 0 }}>
        {n.kind === 'invite' && s ? <>
          <Txt s={15}><b>{p.name.split(' ')[0]}</b> invited you to <b>{s.title}</b></Txt>
          <div><Txt s={13} c="var(--text-tertiary)">{s.day}, {s.month} {s.date} · {s.time} · {s.gym}</Txt></div>
          {s.people.me === 'invited' ? <Row style={{ gap: 8, marginTop: 10 }}><MBtn size="sm" variant="secondary" onClick={() => mm.rsvp(s.id, 'declined')}>Decline</MBtn><MBtn size="sm" iconLeft="check" onClick={() => mm.rsvp(s.id, 'going')}>Join</MBtn></Row>
            : <MBadge variant={s.people.me === 'going' ? 'success' : 'neutral'} dot style={{ marginTop: 8 }}>{s.people.me === 'going' ? "You're going" : 'Declined'}</MBadge>}
        </> : <>
          <Txt s={15}><b>{p.name.split(' ')[0]}</b> {n.text}</Txt>
          {n.quote && <div style={{ marginTop: 4 }}><Txt s={14} c="var(--text-secondary)">“{n.quote}”</Txt></div>}
        </>}
        <div><Txt s={12} w={600} c="var(--text-tertiary)">{n.time}</Txt></div>
      </div>
      {n.photo && <PhotoTile src={n.photo} h={48} radius={10} style={{ width: 48, flexShrink: 0 }} onClick={() => mm.go('post', { id: 'p1' })} />}
    </div>; };
  const fresh = mm.s.notifications.filter(n => n.unread); const old = mm.s.notifications.filter(n => !n.unread);
  return <Screen push header={<Header left={<MIB icon="chevron-left" label="Back" onClick={mm.back} />} title="Notifications" />}>
    {fresh.length > 0 && <><Eyebrow style={{ marginTop: 6 }}>New</Eyebrow>{fresh.map(item)}</>}
    <Eyebrow>Earlier</Eyebrow>{old.map(item)}
    <div style={{ height: 30 }}></div>
  </Screen>;
}
Object.assign(window, { ProfileScreen, NotificationsScreen });
