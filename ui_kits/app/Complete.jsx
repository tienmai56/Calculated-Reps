const { Avatar: KAv, AvatarStack: KStack, IconButton: KIB, Icon: KIcon, Button: KBtn, Input: KIn, Switch: KSw, Dialog: KDlg, StreakBelt: KBelt } = window.GripGorillasDesignSystem_8b0f80;

function CompleteScreen({ id }) {
  const mm = useMM(); const P = mm.person;
  const s = mm.findSession(id);
  const [removed, setRemoved] = React.useState([]);
  const [photo, setPhoto] = React.useState(null);
  const [roll, setRoll] = React.useState(false);
  const [caption, setCaption] = React.useState('');
  const [done, setDone] = React.useState(false);
  const [result, setResult] = React.useState(null);
  if (result) return <Celebrate result={result} />;
  if (!s) return null;
  const people = Object.keys(s.people).filter(k => s.people[k] === 'going' && !removed.includes(k));
  const publish = () => setResult(mm.publish(s.id, { photo, caption, people }));
  return <Screen push header={<Header left={<KIB icon="x" label="Close" onClick={mm.back} />} title="Share the session" sub={`${s.title} · ${s.day} ${s.month} ${s.date}`} />}
    footer={<KBtn size="lg" fullWidth iconLeft="send" disabled={!done} onClick={publish}>{done ? 'Publish to Activity' : 'Mark as completed to publish'}</KBtn>}>
    <div style={{ padding: '4px 16px 0' }}>
      {photo ? <PhotoTile src={photo} h={330} radius={26} style={{ animation: 'mmPop .4s var(--ease-bounce)' }}>
          <TapeLabel style={{ position: 'absolute', left: 12, bottom: 14 }}><KIcon name="map-pin" size={13} strokeWidth={2.5} />{s.gym}</TapeLabel>
          <KIB icon="repeat-2" variant="overlay" label="Change photo" size={40} onClick={() => setRoll(true)} style={{ position: 'absolute', top: 12, right: 12 }} />
        </PhotoTile>
        : <div style={{ height: 300, borderRadius: 26, background: 'var(--paper-2)', boxShadow: 'inset 0 0 0 2px var(--ink-200)', backgroundImage: 'repeating-linear-gradient(135deg, transparent 0 14px, rgba(29,27,24,.025) 14px 28px)', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 14, textAlign: 'center', padding: 24 }}>
          <div style={{ font: '800 22px/1.15 var(--font-display)', letterSpacing: '-.03em' }}>Grab the post-training photo</div>
          <Txt s={14} c="var(--text-secondary)">Sweaty, smiling, slightly crooked. That's the one.</Txt>
          <Row style={{ gap: 8, marginTop: 4 }}><KBtn iconLeft="camera" onClick={() => setRoll(true)}>Take photo</KBtn><KBtn variant="secondary" iconLeft="image-plus" onClick={() => setRoll(true)}>Upload</KBtn></Row>
        </div>}
      <KIn multiline rows={2} placeholder="What happened on the mat?" value={caption} onChange={e => setCaption(e.target.value)} style={{ marginTop: 16 }} />
      <Row style={{ justifyContent: 'space-between', margin: '22px 2px 10px' }}><span style={{ font: '800 16px var(--font-display)', letterSpacing: '-.02em' }}>Who trained</span><Txt s={13} w={600} c="var(--text-tertiary)">{people.length} people</Txt></Row>
      <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
        {Object.keys(s.people).filter(k => s.people[k] === 'going').map(k => { const p = P(k); const out = removed.includes(k);
          return <span key={k} style={{ display: 'inline-flex', alignItems: 'center', gap: 8, height: 42, padding: '0 6px 0 4px', borderRadius: 99, background: out ? 'transparent' : 'var(--white)', boxShadow: out ? 'inset 0 0 0 1.5px var(--ink-200)' : 'var(--shadow-card)', opacity: out ? .5 : 1, transition: 'all var(--dur-base)' }}>
            <KAv name={p.name} src={p.src} size={34} /><Txt s={14} w={600} style={{ textDecoration: out ? 'line-through' : 'none' }}>{k === 'me' ? 'You' : p.name.split(' ')[0]}</Txt>
            {k !== 'me' ? <KIB icon={out ? 'plus' : 'x'} size={28} label={out ? 'Add back' : 'Remove'} onClick={() => setRemoved(out ? removed.filter(x => x !== k) : [...removed, k])} /> : <span style={{ width: 6 }}></span>}
          </span>; })}
      </div>
      <div style={{ marginTop: 22, padding: 16, borderRadius: 22, background: done ? 'var(--mint-100)' : 'var(--white)', boxShadow: done ? 'none' : 'var(--shadow-card)', transition: 'background var(--dur-base)' }}>
        <KSw label="Training completed" description="Counts toward weekly streaks for everyone here." checked={done} onChange={setDone} />
      </div>
      <div style={{ height: 20 }}></div>
    </div>
    {roll && <KDlg contained variant="sheet" title="Recent photos" onClose={() => setRoll(false)}>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 6 }}>{mm.s.cameraRoll.map(src => <div key={src} onClick={() => { setPhoto(src); setRoll(false); }} style={{ aspectRatio: '1', borderRadius: 12, overflow: 'hidden', cursor: 'pointer', boxShadow: photo === src ? '0 0 0 3px var(--accent)' : 'none' }}><img src={src} style={{ width: '100%', height: '100%', objectFit: 'cover' }} /></div>)}</div>
    </KDlg>}
  </Screen>;
}

function Counter({ from, to, delay = 700 }) {
  const [v, setV] = React.useState(from);
  React.useEffect(() => { const t = setTimeout(() => setV(to), delay); return () => clearTimeout(t); }, []);
  return <span key={v} style={{ display: 'inline-block', animation: v !== from ? 'mmCount .5s var(--ease-bounce)' : 'none' }}>{v}</span>;
}
function LiveBelt({ f, hue, delay }) {
  const [d, setD] = React.useState(false);
  React.useEffect(() => { const t = setTimeout(() => setD(true), delay); return () => clearTimeout(t); }, []);
  return <KBelt weeks={f.weeks} thisWeek={d ? 'done' : 'pending'} hue={hue} size="sm" />;
}

function Celebrate({ result }) {
  const mm = useMM(); const { post, streaks } = result;
  return <div style={{ position: 'absolute', inset: 0, zIndex: 40, background: 'var(--coral-500)', color: '#fff', display: 'flex', flexDirection: 'column', animation: 'mmFade .3s var(--ease-out)', overflowY: 'auto', ...hideScroll }}>
    <div style={{ padding: '24px 24px 0', textAlign: 'center' }}>
      <div style={{ font: '800 34px/1 var(--font-display)', letterSpacing: '-.04em' }}>Shared with the crew</div>
      <div style={{ font: '500 15px var(--font-body)', opacity: .9, marginTop: 8 }}>Now on {post.participants.length} profiles and in your friends' feeds.</div>
    </div>
    <div style={{ margin: '22px auto 0', width: 250, padding: '10px 10px 14px', background: '#FFFDF8', borderRadius: 8, boxShadow: '0 18px 40px rgba(90,20,0,.35)', animation: 'mmDrop .8s var(--ease-bounce) both', color: 'var(--ink-900)' }}>
      <div style={{ height: 200, borderRadius: 4, overflow: 'hidden', background: 'var(--paper-3)' }}>{post.photo && <img src={post.photo} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />}</div>
      <Row style={{ justifyContent: 'space-between', padding: '10px 4px 0' }}><span style={{ font: '800 15px/1.1 var(--font-display)', letterSpacing: '-.02em' }}>{post.title}</span><KStack people={post.participants.map(mm.person)} size={22} max={3} ring="#FFFDF8" /></Row>
    </div>
    {streaks.length > 0 && <div style={{ margin: '24px 16px 0', padding: '14px 16px', background: '#fff', borderRadius: 24, color: 'var(--ink-900)', animation: 'mmFadeUp .5s .5s var(--ease-out) both' }}>
      <div style={{ font: '800 16px var(--font-display)', letterSpacing: '-.02em', marginBottom: 6 }}>Streaks this week</div>
      {streaks.map((x, i) => { const p = mm.person(x.id);
        return <div key={x.id} style={{ padding: '10px 0', boxShadow: i < streaks.length - 1 ? 'inset 0 -1px 0 var(--border-subtle)' : 'none' }}>
          <Row><PairAvatars a={mm.s.me} b={p} size={30} hue={p.hue} /><span style={{ flex: 1 }}><Txt s={15} w={700}>{p.name.split(' ')[0]}</Txt></span>
            <span style={{ font: '800 22px var(--font-display)', letterSpacing: '-.03em', color: 'var(--flame-500)' }}><Counter from={x.from} to={x.to} delay={1100 + i * 300} /></span><Txt s={13} w={600} c="var(--text-tertiary)">{x.to === 1 ? 'week' : 'weeks'}</Txt></Row>
          <div style={{ marginTop: 8 }}><LiveBelt f={x.f} hue={p.hue} delay={1100 + i * 300} /></div>
        </div>; })}
    </div>}
    <div style={{ padding: '20px 16px 40px', display: 'flex', flexDirection: 'column', gap: 8, marginTop: 'auto' }}>
      <KBtn size="lg" variant="inverse" fullWidth onClick={() => mm.showPost(post.id)}>See it in Activity</KBtn>
    </div>
  </div>;
}
Object.assign(window, { CompleteScreen });
