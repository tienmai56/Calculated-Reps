const { Avatar: TAv, AvatarStack: TStack, IconButton: TIB, Icon: TIcon, Button: TBtn, Badge: TBadge, Tabs: TTabs, Dialog: TDlg, Checkbox: TCb } = window.MatMindDesignSystem_8b0f80;
const STATUS = { going: ['success', 'Going'], invited: ['warning', 'Invited'], declined: ['neutral', 'Declined'] };

function SessionTicket({ s, onClick, big }) {
  const mm = useMM(); const org = mm.person(s.organizer); const hue = s.organizer === 'me' ? 'coral' : org.hue;
  const [c, tint, ink] = HUEV[hue];
  const going = Object.entries(s.people).filter(([, v]) => v === 'going').map(([k]) => mm.person(k));
  const mine = s.people.me;
  return <div onClick={onClick} style={{ display: 'flex', background: 'var(--white)', borderRadius: 24, boxShadow: 'var(--shadow-card)', cursor: onClick ? 'pointer' : undefined, position: 'relative', overflow: 'hidden' }}>
    <div style={{ width: big ? 96 : 84, flexShrink: 0, background: tint, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', padding: '16px 0', color: ink }}>
      <span style={{ font: '800 13px/1 var(--font-display)', letterSpacing: '.04em', textTransform: 'uppercase' }}>{s.day}</span>
      <span style={{ font: `800 ${big ? 48 : 40}px/1 var(--font-display)`, letterSpacing: '-.04em', margin: '4px 0 2px' }}>{s.date}</span>
      <span style={{ font: '700 12px/1 var(--font-body)' }}>{s.month}</span>
    </div>
    <div style={{ width: 0, borderLeft: '2px dashed var(--ink-200)', margin: '10px 0', position: 'relative' }}></div>
    <span style={{ position: 'absolute', left: (big ? 96 : 84) - 9, top: -9, width: 18, height: 18, borderRadius: 99, background: 'var(--bg-app)' }}></span>
    <span style={{ position: 'absolute', left: (big ? 96 : 84) - 9, bottom: -9, width: 18, height: 18, borderRadius: 99, background: 'var(--bg-app)' }}></span>
    <div style={{ flex: 1, minWidth: 0, padding: '14px 14px 14px 16px', display: 'flex', flexDirection: 'column', gap: 6 }}>
      <Row style={{ gap: 6, justifyContent: 'space-between' }}><span style={{ font: '800 18px/1.15 var(--font-display)', letterSpacing: '-.02em', color: 'var(--ink-900)' }}>{s.title}</span>
        {mine === 'invited' && <TBadge variant="warning" dot>Invite</TBadge>}</Row>
      <Row style={{ gap: 6 }}><TIcon name="clock" size={14} color="var(--text-tertiary)" /><Txt s={13} w={500} c="var(--text-secondary)">{s.time}</Txt><TIcon name="map-pin" size={14} color="var(--text-tertiary)" style={{ marginLeft: 4 }} /><Txt s={13} w={500} c="var(--text-secondary)" style={{ whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{s.gym}</Txt></Row>
      <Row style={{ justifyContent: 'space-between', marginTop: 4 }}>
        <TStack people={going} size={28} max={4} ring="#fff" label={going.length + ' going'} />
        <Txt s={12} w={600} c="var(--text-tertiary)">{s.organizer === 'me' ? 'You host' : 'by ' + org.name.split(' ')[0]}</Txt>
      </Row>
    </div>
  </div>;
}

function ReadyToShare({ s }) {
  const mm = useMM();
  return <div style={{ margin: '4px 16px 0', padding: 16, borderRadius: 24, background: 'var(--ink-900)', color: 'var(--paper)', display: 'flex', gap: 14, alignItems: 'center', position: 'relative', overflow: 'hidden' }}>
    <div style={{ width: 64, height: 64, borderRadius: 18, overflow: 'hidden', flexShrink: 0, transform: 'rotate(-4deg)', boxShadow: '0 0 0 3px #fff' }}><img src={MM_PH('floor-drill')} style={{ width: '100%', height: '100%', objectFit: 'cover' }} /></div>
    <div style={{ flex: 1 }}>
      <div style={{ font: '800 17px/1.2 var(--font-display)', letterSpacing: '-.02em' }}>How was {s.title.toLowerCase().replace('no-gi ', '')}?</div>
      <div style={{ font: '500 13px/1.35 var(--font-body)', color: 'var(--ink-200)', marginTop: 4 }}>Add a photo and share it with the {Object.keys(s.people).length} of you.</div>
      <TBtn size="sm" iconLeft="camera" style={{ marginTop: 10 }} onClick={() => mm.go('complete', { id: s.id })}>Complete & share</TBtn>
    </div>
  </div>;
}

function TrainingScreen() {
  const mm = useMM(); const [tab, setTab] = React.useState('Upcoming');
  const list = mm.s.emptyTraining ? [] : mm.s.upcoming;
  const invites = list.filter(s => s.people.me === 'invited');
  const rest = list.filter(s => s.people.me !== 'invited' && s.people.me !== 'declined');
  return <Screen tabPad header={<><Header large title="Training" right={<TIB icon="calendar-plus" variant="filled" label="Plan a session" onClick={() => mm.go('create')} />} /><div style={{ padding: '0 16px 6px' }}><TTabs items={['Upcoming', 'Past']} value={tab} onChange={setTab} /></div></>}>
    {tab === 'Past' ? <div style={{ padding: '16px 16px 0', display: 'flex', flexDirection: 'column', gap: 12 }}>
        <Txt s={14} c="var(--text-tertiary)" style={{ padding: '0 4px' }}>Missed a session? Log it after the fact and it still counts for your streaks.</Txt>
        <TBtn variant="secondary" iconLeft="history" onClick={() => mm.go('create', { past: true })}>Log a past session</TBtn>
        {mm.s.posts.filter(p => p.participants.includes('me')).map(p => <Row key={p.id} onClick={() => mm.go('post', { id: p.id })} style={{ background: 'var(--white)', borderRadius: 20, padding: 10, boxShadow: 'var(--shadow-card)' }}>
          <PhotoTile src={p.photo} h={56} radius={14} style={{ width: 56, flexShrink: 0 }} /><div style={{ flex: 1 }}><div style={{ font: '800 15px var(--font-display)', letterSpacing: '-.02em' }}>{p.title}</div><Txt s={13} c="var(--text-tertiary)">{p.date} · {p.participants.length} people</Txt></div><TBadge variant="success">Shared</TBadge></Row>)}
      </div>
    : <>
      {mm.s.toComplete && !mm.s.emptyTraining && <div style={{ marginTop: 12 }}><ReadyToShare s={mm.s.toComplete} /></div>}
      {invites.length > 0 && <><Eyebrow>Invites</Eyebrow><div style={{ padding: '0 16px', display: 'flex', flexDirection: 'column', gap: 12 }}>{invites.map(s => <div key={s.id}><SessionTicket s={s} onClick={() => mm.go('session', { id: s.id })} />
        <Row style={{ gap: 8, marginTop: 8 }}><TBtn size="sm" variant="secondary" fullWidth onClick={() => mm.rsvp(s.id, 'declined')}>Decline</TBtn><TBtn size="sm" fullWidth iconLeft="check" onClick={() => mm.rsvp(s.id, 'going')}>Join</TBtn></Row></div>)}</div></>}
      {rest.length > 0 && <><Eyebrow>Coming up</Eyebrow><div style={{ padding: '0 16px', display: 'flex', flexDirection: 'column', gap: 12 }}>{rest.map(s => <SessionTicket key={s.id} s={s} onClick={() => mm.go('session', { id: s.id })} />)}</div></>}
      {list.length === 0 ? <EmptyTraining /> : <div style={{ padding: '20px 16px 0' }}><TBtn size="lg" fullWidth iconLeft="plus" onClick={() => mm.go('create')}>Plan a training session</TBtn></div>}
    </>}
  </Screen>;
}

function EmptyTraining() {
  const mm = useMM(); const crew = mm.s.friends.slice(0, 5).map(f => mm.person(f.id));
  return <div style={{ margin: '24px 16px 0', padding: '32px 24px 26px', borderRadius: 28, background: 'var(--white)', boxShadow: 'var(--shadow-card)', textAlign: 'center', display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
    <div style={{ display: 'flex', marginBottom: 18 }}>{crew.map((p, i) => <span key={i} style={{ marginLeft: i ? -14 : 0, transform: `rotate(${[-8, 4, -3, 6, -5][i]}deg) translateY(${[4, -4, 2, -6, 3][i]}px)`, borderRadius: 999, boxShadow: '0 0 0 3px #fff', display: 'inline-flex', animation: `mmBob 2.4s ${i * .2}s ease-in-out infinite` }}><TAv name={p.name} size={52} /></span>)}</div>
    <div style={{ font: '800 24px/1.1 var(--font-display)', letterSpacing: '-.03em' }}>Nothing on the calendar</div>
    <p style={{ margin: '8px 0 20px', font: '400 15px/1.45 var(--font-body)', color: 'var(--text-secondary)', textWrap: 'pretty' }}>Rolls are better with friends. Pick a day, pick a gym, and bring someone along.</p>
    <TBtn size="lg" fullWidth iconLeft="plus" onClick={() => mm.go('create')}>Plan a training session</TBtn>
    <TBtn variant="ghost" size="sm" style={{ marginTop: 8 }} onClick={() => mm.go('create', { past: true })}>Already trained? Log it</TBtn>
  </div>;
}

function SessionDetail({ id }) {
  const mm = useMM(); const P = mm.person;
  const s = mm.s.upcoming.find(x => x.id === id) || (mm.s.toComplete && mm.s.toComplete.id === id ? mm.s.toComplete : null);
  const [add, setAdd] = React.useState(false); const [pick, setPick] = React.useState([]);
  if (!s) return null;
  const isOrg = s.organizer === 'me'; const mine = s.people.me;
  const rows = Object.entries(s.people).sort((a, b) => (a[0] === s.organizer ? -1 : b[0] === s.organizer ? 1 : 0));
  const addable = mm.s.friends.map(f => f.id).filter(fid => !s.people[fid]);
  const footer = isOrg ? <Row style={{ gap: 8 }}><TBtn variant="secondary" iconLeft="user-plus" fullWidth onClick={() => { setPick([]); setAdd(true); }}>Add people</TBtn><TBtn variant="soft" iconLeft="link" fullWidth onClick={() => mm.toast('Invite link copied', 'success')}>Copy link</TBtn></Row>
    : mine === 'invited' ? <Row style={{ gap: 8 }}><TBtn variant="secondary" fullWidth onClick={() => { mm.rsvp(s.id, 'declined'); mm.back(); }}>Decline</TBtn><TBtn fullWidth iconLeft="check" onClick={() => mm.rsvp(s.id, 'going')}>Join</TBtn></Row>
    : <Row style={{ gap: 8, justifyContent: 'center' }}><TBadge variant="success" dot style={{ height: 34, padding: '0 14px', fontSize: 14 }}>You're going</TBadge><TBtn variant="ghost" size="sm" onClick={() => { mm.rsvp(s.id, 'declined'); mm.back(); }}>Can't make it</TBtn></Row>;
  return <Screen push header={<Header left={<TIB icon="chevron-left" label="Back" onClick={mm.back} />} title="" right={isOrg ? <TIB icon="share-2" label="Share" onClick={() => mm.toast('Invite link copied', 'success')} /> : null} />} footer={footer}>
    <div style={{ padding: '0 16px' }}>
      <SessionTicket s={s} big />
      <div style={{ marginTop: 14, padding: '6px 16px', background: 'var(--white)', borderRadius: 22, boxShadow: 'var(--shadow-card)' }}>
        {[['map-pin', s.gym], ['clock', s.day + ', ' + s.month + ' ' + s.date + ' · ' + s.time], [s.privacy === 'link' ? 'globe' : 'lock', s.privacy === 'link' ? 'Anyone with the link (Mat Mind account required)' : 'Friends only']].map(([ic, t], i) =>
          <Row key={i} style={{ padding: '11px 0', boxShadow: i < 2 ? 'inset 0 -1px 0 var(--border-subtle)' : 'none' }}><TIcon name={ic} size={18} color="var(--text-tertiary)" /><Txt s={15} w={500}>{t}</Txt></Row>)}
      </div>
      {s.note && <p style={{ margin: '14px 4px 0', font: '400 15px/1.45 var(--font-body)', color: 'var(--ink-700)' }}>“{s.note}”</p>}
      <div style={{ font: '800 18px var(--font-display)', letterSpacing: '-.02em', margin: '22px 4px 10px' }}>Who's coming</div>
      <div style={{ background: 'var(--white)', borderRadius: 22, boxShadow: 'var(--shadow-card)', padding: '4px 14px' }}>
        {rows.map(([pid, st], i) => { const p = P(pid); const [v, l] = STATUS[st];
          return <Row key={pid} style={{ padding: '10px 0', boxShadow: i < rows.length - 1 ? 'inset 0 -1px 0 var(--border-subtle)' : 'none', animation: mm.fresh === s.id + pid ? 'mmJoin .6s var(--ease-bounce)' : 'none' }}>
            <TAv name={p.name} src={p.src} size={40} belt={p.belt} ring="#fff" />
            <div style={{ flex: 1 }}><Txt s={15} w={700}>{pid === 'me' ? 'You' : p.name}</Txt><div><Txt s={13} c="var(--text-tertiary)">{pid === s.organizer ? 'Organizer' : p.gym}</Txt></div></div>
            <TBadge variant={v}>{l}</TBadge>
            {isOrg && pid !== 'me' && <TIB icon="x" size={32} label={'Remove ' + p.name} onClick={() => mm.removeParticipant(s.id, pid)} />}
          </Row>; })}
      </div>
      <div style={{ height: 16 }}></div>
    </div>
    {add && <TDlg contained variant="sheet" title="Add people" description="They're added straight to the session." onClose={() => setAdd(false)}
      actions={<TBtn fullWidth disabled={!pick.length} onClick={() => { mm.addParticipants(s.id, pick); setAdd(false); }}>Add {pick.length || ''}</TBtn>}>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>{addable.length ? addable.map(fid => { const p = P(fid); return <Row key={fid}><TAv name={p.name} size={36} /><span style={{ flex: 1 }}><Txt w={600}>{p.name}</Txt></span><TCb checked={pick.includes(fid)} onChange={on => setPick(on ? [...pick, fid] : pick.filter(x => x !== fid))} /></Row>; }) : <Txt c="var(--text-tertiary)">All your friends are already in.</Txt>}</div>
    </TDlg>}
  </Screen>;
}
Object.assign(window, { SessionTicket, TrainingScreen, SessionDetail });
