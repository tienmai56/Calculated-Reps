const { Avatar: CAv, IconButton: CIB, Icon: CIcon, Button: CBtn, Tag: CTag, Input: CIn, Tabs: CTabs, Switch: CSw, Dialog: CDlg, Badge: CBadge, Belt: CBelt } = window.MatMonkeysDesignSystem_8b0f80;
const FUT = [['Today', 'Mon', 2, 'Nov'], ['Tue', 'Tue', 3, 'Nov'], ['Wed', 'Wed', 4, 'Nov'], ['Thu', 'Thu', 5, 'Nov'], ['Fri', 'Fri', 6, 'Nov'], ['Sat', 'Sat', 7, 'Nov'], ['Sun', 'Sun', 8, 'Nov']];
const PAST = [['Yesterday', 'Sun', 1, 'Nov'], ['Sat', 'Sat', 31, 'Oct'], ['Fri', 'Fri', 30, 'Oct'], ['Thu', 'Thu', 29, 'Oct'], ['Wed', 'Wed', 28, 'Oct']];
const TIMES = ['6:30 AM', '12:15 PM', '6:00 PM', '7:30 PM'];

function Field({ label, children, hint }) {
  return <div style={{ padding: '0 16px', marginTop: 22 }}><Row style={{ justifyContent: 'space-between', marginBottom: 10 }}><span style={{ font: '800 16px var(--font-display)', letterSpacing: '-.02em' }}>{label}</span>{hint}</Row>{children}</div>;
}

function CreateScreen({ past: pastInit, friend }) {
  const mm = useMM();
  const [past, setPast] = React.useState(!!pastInit);
  const days = past ? PAST : FUT;
  const [name, setName] = React.useState('');
  const [day, setDay] = React.useState(past ? 0 : 5);
  const [time, setTime] = React.useState(past ? '6:00 PM' : '10:00 AM');
  const [gym, setGym] = React.useState(mm.s.me.gym);
  const [note, setNote] = React.useState(''); const [showNote, setShowNote] = React.useState(false);
  const [inv, setInv] = React.useState(friend ? [friend] : []);
  const [privacy, setPrivacy] = React.useState('friends');
  const [link, setLink] = React.useState(null);
  const d = days[Math.min(day, days.length - 1)];
  const autoName = d[1] === 'Sat' || d[1] === 'Sun' ? (d[1] === 'Sat' ? 'Saturday' : 'Sunday') + ' open mat' : time.includes('AM') ? 'Morning rolls' : time.startsWith('12') ? 'Lunch rolls' : 'Evening rolls';
  const toggle = id => setInv(inv.includes(id) ? inv.filter(x => x !== id) : [...inv, id]);
  const submit = () => mm.createSession({ title: name.trim() || autoName, day: d[1], date: d[2], month: d[3], time, gym, note, invited: inv, privacy, past });
  return <Screen push header={<Header left={<CIB icon="x" label="Close" onClick={mm.back} />} title={past ? 'Log a past session' : 'Plan a session'} />}
    footer={<CBtn size="lg" fullWidth iconLeft={past ? 'camera' : 'send'} onClick={submit}>{past ? 'Next: add a photo' : inv.length ? `Send invites to ${inv.length}` : 'Create session'}</CBtn>}>
    <div style={{ padding: '0 16px' }}><CTabs items={[{ id: 'plan', label: 'Upcoming' }, { id: 'past', label: 'Already happened' }]} value={past ? 'past' : 'plan'} onChange={v => { setPast(v === 'past'); setDay(v === 'past' ? 0 : 5); }} /></div>
    <div style={{ padding: '18px 16px 0' }}>
      <input value={name} onChange={e => setName(e.target.value)} placeholder={autoName} style={{ width: '100%', border: 0, outline: 'none', background: 'transparent', font: '800 30px/1.1 var(--font-display)', letterSpacing: '-.035em', color: 'var(--ink-900)', padding: 0 }} />
      <Txt s={13} c="var(--text-tertiary)">Name it, or keep our suggestion.</Txt>
    </div>
    <Field label="When">
      <div style={{ display: 'flex', gap: 8, overflowX: 'auto', margin: '0 -16px', padding: '0 16px 2px', ...hideScroll }}>
        {days.map((x, i) => { const on = i === day; return <button key={i} onClick={() => setDay(i)} style={{ flexShrink: 0, width: 62, height: 74, border: 0, borderRadius: 18, cursor: 'pointer', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 3,
          background: on ? 'var(--ink-900)' : 'var(--white)', color: on ? 'var(--paper)' : 'var(--ink-900)', boxShadow: on ? 'none' : 'inset 0 0 0 1.5px var(--border-default)', transition: 'all var(--dur-fast) var(--ease-out)' }}>
          <span style={{ font: '700 12px var(--font-body)', opacity: .75 }}>{x[0]}</span><span style={{ font: '800 24px/1 var(--font-display)', letterSpacing: '-.03em' }}>{x[2]}</span></button>; })}
      </div>
      <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', marginTop: 10 }}>{[...new Set([time, ...TIMES])].map(t => <CTag key={t} size="sm" selected={time === t} onClick={() => setTime(t)}>{t}</CTag>)}<CTag size="sm" icon="clock">Other</CTag></div>
    </Field>
    <Field label="Where">
      <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>{mm.s.gyms.map(g => <CTag key={g} size="sm" icon={g === mm.s.me.gym ? 'house' : 'map-pin'} selected={gym === g} onClick={() => setGym(g)}>{g}</CTag>)}</div>
      {!showNote ? <CBtn variant="ghost" size="sm" iconLeft="plus" style={{ marginTop: 8, marginLeft: -8 }} onClick={() => setShowNote(true)}>Add a note (optional)</CBtn>
        : <CIn multiline rows={2} placeholder="Gi or no-gi? Bring anything?" value={note} onChange={e => setNote(e.target.value)} style={{ marginTop: 12 }} />}
    </Field>
    <Field label={past ? 'Who was there' : 'Invite friends'} hint={<Txt s={13} w={600} c="var(--text-tertiary)">{inv.length} picked</Txt>}>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12 }}>
        {mm.s.friends.map(f => { const p = mm.person(f.id); const on = inv.includes(f.id); const n = mm.streakOf(f);
          return <button key={f.id} onClick={() => toggle(f.id)} style={{ border: 0, background: 'transparent', padding: 0, cursor: 'pointer', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6 }}>
            <span style={{ position: 'relative', display: 'inline-flex', transform: on ? 'scale(1.04)' : 'scale(1)', transition: 'transform var(--dur-base) var(--ease-bounce)' }}>
              <span style={{ borderRadius: 999, boxShadow: on ? '0 0 0 3px var(--bg-app), 0 0 0 5.5px var(--accent)' : 'none', display: 'inline-flex', transition: 'box-shadow var(--dur-fast)' }}><CAv name={p.name} size={60} /></span>
              {on && <span style={{ position: 'absolute', right: -3, bottom: -3, width: 24, height: 24, borderRadius: 99, background: 'var(--accent)', display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: '0 0 0 3px var(--bg-app)', animation: 'mmPop .3s var(--ease-bounce)' }}><CIcon name="check" size={14} strokeWidth={3.5} color="#fff" /></span>}
              {!on && n > 0 && <span style={{ position: 'absolute', right: -6, top: -4, height: 22, padding: '0 6px', borderRadius: 99, background: 'var(--flame-100)', display: 'flex', alignItems: 'center', gap: 2, font: '800 11px var(--font-body)', color: '#B5520A', boxShadow: '0 0 0 2px var(--bg-app)' }}><CIcon name="flame" size={11} filled color="var(--flame-500)" />{n}</span>}
            </span>
            <Txt s={13} w={on ? 700 : 500}>{p.name.split(' ')[0]}</Txt>
          </button>; })}
      </div>
    </Field>
    {!past && <Field label="Who can join">
      <CTabs items={[{ id: 'friends', label: 'Friends only' }, { id: 'link', label: 'Anyone with link' }]} value={privacy} onChange={setPrivacy} />
      <div style={{ marginTop: 12, padding: 14, borderRadius: 18, background: 'var(--white)', boxShadow: 'inset 0 0 0 1.5px var(--border-default)' }}>
        {link ? <Row><CIcon name="link" size={18} color="var(--accent)" /><span style={{ flex: 1, font: '600 14px var(--font-mono)', color: 'var(--ink-900)' }}>matmonkeys.app/s/{link}</span><CBtn size="sm" variant="soft" iconLeft="copy" onClick={() => mm.toast('Invite link copied', 'success')}>Copy</CBtn></Row>
          : <Row><span style={{ flex: 1 }}><Txt s={14} c="var(--text-secondary)">{privacy === 'link' ? 'Anyone with a Mat Monkeys account can join from the link.' : 'Only your friends can join from the link.'}</Txt></span><CBtn size="sm" variant="secondary" iconLeft="link" onClick={() => setLink('k3x9q')}>Get link</CBtn></Row>}
      </div>
    </Field>}
    <div style={{ height: 24 }}></div>
  </Screen>;
}
Object.assign(window, { CreateScreen });
