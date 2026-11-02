const { Avatar: AAv, AvatarStack: AStack, IconButton: AIB, Icon: AIcon, Button: ABtn, Dialog: ADlg, Input: AIn, Badge: ABadge } = window.GripGorillasDesignSystem_8b0f80;
const MMCtx = React.createContext(null);
const useMM = () => React.useContext(MMCtx);

function PostCard({ post, highlight }) {
  const mm = useMM(); const P = mm.person;
  const org = P(post.organizer); const liked = post.likes.includes('me');
  const others = post.participants.filter(x => x !== post.organizer).map(x => x === 'me' ? 'You' : P(x).name);
  const [burst, setBurst] = React.useState(0);
  const dbl = () => { if (!liked) mm.like(post.id); setBurst(b => b + 1); };
  return <article style={{ margin: '0 12px 14px', padding: 12, background: 'var(--white)', borderRadius: 28, boxShadow: highlight ? '0 0 0 3px var(--coral-300), var(--shadow-card)' : 'var(--shadow-card)', animation: highlight ? 'mmPop .5s var(--ease-bounce)' : 'none' }}>
    <Row style={{ padding: '2px 2px 12px' }}>
      <span onClick={() => post.organizer !== 'me' && mm.go('friend', { id: post.organizer })} style={{ cursor: 'pointer', display: 'flex' }}><AAv name={org.name} src={org.src} size={42} belt={org.belt} ring="var(--white)" /></span>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ font: '400 14px/1.3 var(--font-body)', color: 'var(--text-secondary)' }}><b style={{ font: '700 15px var(--font-body)', color: 'var(--ink-900)' }}>{post.organizer === 'me' ? 'You' : org.name}</b> trained with {names(others, 2)}</div>
        <div style={{ font: '500 13px var(--font-body)', color: 'var(--text-tertiary)', marginTop: 2 }}>{post.date} · {post.ago}</div>
      </div>
      <AIB icon="ellipsis" size={36} label="Post options" onClick={() => mm.go('post', { id: post.id, menu: true })} />
    </Row>
    <PhotoTile src={post.photo} h={300} radius={20} onClick={null} style={{ cursor: 'pointer' }}>
      <div onDoubleClick={dbl} onClick={() => mm.go('post', { id: post.id })} style={{ position: 'absolute', inset: 0 }}></div>
      <TapeLabel style={{ position: 'absolute', left: 12, bottom: 14 }}><AIcon name="map-pin" size={13} strokeWidth={2.5} />{post.gym}</TapeLabel>
      <span style={{ position: 'absolute', right: 12, bottom: 12 }}><AStack people={post.participants.map(P)} size={30} ring="#fff" max={4} /></span>
      {burst > 0 && <span key={burst} style={{ position: 'absolute', left: '50%', top: '50%', marginLeft: -44, marginTop: -44, animation: 'mmHeartBurst .8s var(--ease-out) forwards', pointerEvents: 'none' }}><AIcon name="heart" size={88} filled color="#fff" strokeWidth={1.5} /></span>}
    </PhotoTile>
    <div style={{ padding: '14px 4px 0' }}>
      <div style={{ font: '800 21px/1.15 var(--font-display)', letterSpacing: '-.025em', color: 'var(--ink-900)' }}>{post.title}</div>
      {post.caption && <p style={{ margin: '6px 0 0', font: '400 15px/1.45 var(--font-body)', color: 'var(--ink-800)', textWrap: 'pretty' }}>{post.caption}</p>}
    </div>
    <Row style={{ gap: 2, marginTop: 8, marginLeft: -4 }}>
      <AIB icon="heart" label="Like" size={40} active={liked} filledWhenActive onClick={() => mm.like(post.id)} style={{ animation: liked ? 'mmLike .4s var(--ease-bounce)' : 'none' }} />
      <Txt s={14} w={700} style={{ marginRight: 10 }}>{post.likes.length + post.extraLikes}</Txt>
      <AIB icon="message-circle" label="Comment" size={40} onClick={() => mm.go('post', { id: post.id, focus: true })} />
      <Txt s={14} w={700}>{post.comments.length}</Txt>
      <span style={{ flex: 1 }}></span>
      <Row style={{ gap: 5, paddingRight: 6 }}><AIcon name="users" size={15} color="var(--text-tertiary)" /><Txt s={12} w={600} c="var(--text-tertiary)">On {post.participants.length} profiles</Txt></Row>
    </Row>
    {post.comments[0] && <div onClick={() => mm.go('post', { id: post.id })} style={{ padding: '2px 4px 4px', cursor: 'pointer' }}>
      <Txt s={14}><b>{P(post.comments[0].who).name.split(' ')[0]}</b> {post.comments[0].text}</Txt>
      {post.comments.length > 1 && <div style={{ font: '500 13px var(--font-body)', color: 'var(--text-tertiary)', marginTop: 4 }}>View all {post.comments.length} comments</div>}
    </div>}
  </article>;
}

function StreakNudges() {
  const mm = useMM();
  const list = mm.s.friends.filter(f => f.thisWeek === 'pending' && mm.streakOf(f) > 0);
  if (!list.length) return null;
  return <div style={{ display: 'flex', gap: 10, overflowX: 'auto', padding: '2px 12px 16px', ...hideScroll }}>
    {list.map(f => { const p = mm.person(f.id); const n = mm.streakOf(f); const [c, tint, ink] = HUEV[p.hue];
      return <div key={f.id} onClick={() => mm.go('friend', { id: f.id })} style={{ flexShrink: 0, width: 262, padding: 14, borderRadius: 24, background: tint, display: 'flex', gap: 12, alignItems: 'center', cursor: 'pointer' }}>
        <PairAvatars a={mm.s.me} b={p} size={38} hue={p.hue} />
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ font: '800 16px/1.15 var(--font-display)', letterSpacing: '-.02em', color: ink }}>{n} weeks with {p.name.split(' ')[0]}</div>
          <div style={{ font: '500 13px/1.3 var(--font-body)', color: 'var(--ink-700)', marginTop: 3 }}>Roll together by Sunday to make it {n + 1}</div>
        </div>
        <AIcon name="flame" size={22} filled color="var(--flame-500)" />
      </div>; })}
  </div>;
}

function ActivityScreen({ highlight }) {
  const mm = useMM();
  const unread = mm.s.notifications.filter(n => n.unread).length;
  return <Screen tabPad header={<Header large title={<span>grip gorillas<span style={{ color: 'var(--accent)' }}>.</span></span>} right={<AIB icon="bell" label="Notifications" badge={unread || false} onClick={() => mm.go('notifications')} />} />}>
    <StreakNudges />
    {mm.s.posts.map(p => <PostCard key={p.id} post={p} highlight={p.id === highlight} />)}
    <div style={{ textAlign: 'center', padding: '10px 40px 20px', font: '500 13px/1.45 var(--font-body)', color: 'var(--text-tertiary)' }}>That's everything from your crew this week.<br />Go make a new memory.</div>
  </Screen>;
}

function PostDetail({ id, menu, focus }) {
  const mm = useMM(); const P = mm.person;
  const post = mm.s.posts.find(p => p.id === id);
  const [text, setText] = React.useState('');
  const [sheet, setSheet] = React.useState(menu ? 'menu' : null);
  const [editing, setEditing] = React.useState(false);
  const [cap, setCap] = React.useState(post ? post.caption : '');
  if (!post) return null;
  const isOrg = post.organizer === 'me'; const isIn = post.participants.includes('me');
  const send = () => { if (!text.trim()) return; mm.comment(post.id, text.trim()); setText(''); };
  return <Screen push header={<Header left={<AIB icon="chevron-left" label="Back" onClick={mm.back} />} title={post.title} right={(isOrg || isIn) ? <AIB icon="ellipsis" label="Options" onClick={() => setSheet('menu')} /> : null} />}
    footer={<Row style={{ gap: 8 }}><AAv name={mm.s.me.name} src={mm.s.me.src} size={36} /><AIn placeholder="Say something nice…" value={text} onChange={e => setText(e.target.value)} onKeyDown={e => e.key === 'Enter' && send()} autoFocus={!!focus} style={{ flex: 1 }} /><AIB icon="send" variant="accent" label="Send" onClick={send} /></Row>}>
    <div style={{ padding: '0 12px' }}>
      <PhotoTile src={post.photo} h={340} radius={24}><TapeLabel style={{ position: 'absolute', left: 12, bottom: 14 }}><AIcon name="map-pin" size={13} strokeWidth={2.5} />{post.gym}</TapeLabel></PhotoTile>
      <div style={{ padding: '16px 6px 0' }}>
        <Txt s={13} w={600} c="var(--text-tertiary)">{post.date} · organized by {isOrg ? 'you' : P(post.organizer).name}</Txt>
        {editing ? <div style={{ marginTop: 10 }}><AIn multiline rows={3} value={cap} onChange={e => setCap(e.target.value)} /><Row style={{ gap: 8, marginTop: 10 }}><ABtn size="sm" onClick={() => { mm.editCaption(post.id, cap); setEditing(false); }}>Save</ABtn><ABtn size="sm" variant="ghost" onClick={() => setEditing(false)}>Cancel</ABtn></Row></div>
          : <p style={{ margin: '8px 0 0', font: '400 16px/1.5 var(--font-body)', color: 'var(--ink-800)' }}>{post.caption}</p>}
        <div style={{ marginTop: 18, font: '800 16px var(--font-display)', letterSpacing: '-.02em' }}>On the mat</div>
        <div style={{ display: 'flex', gap: 14, overflowX: 'auto', padding: '12px 0 4px', ...hideScroll }}>
          {post.participants.map(x => { const p = P(x); return <div key={x} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6, width: 60, flexShrink: 0 }}>
            <AAv name={p.name} src={p.src} size={52} belt={p.belt} /><Txt s={12} w={600} style={{ textAlign: 'center' }}>{x === 'me' ? 'You' : p.name.split(' ')[0]}</Txt>{x === post.organizer && <ABadge variant="soft" style={{ height: 18, padding: '0 6px', fontSize: 10 }}>Host</ABadge>}</div>; })}
        </div>
        <Row style={{ marginTop: 14, gap: 4, marginLeft: -6 }}>
          <AIB icon="heart" label="Like" active={post.likes.includes('me')} filledWhenActive onClick={() => mm.like(post.id)} />
          <Txt s={14} w={600} c="var(--text-secondary)">Liked by <b style={{ color: 'var(--ink-900)' }}>{names(post.likes.map(l => l === 'me' ? 'You' : P(l).name), 2)}</b> and {post.extraLikes} others</Txt>
        </Row>
        <div style={{ marginTop: 8, display: 'flex', flexDirection: 'column', gap: 14, paddingBottom: 16 }}>
          {post.comments.map((c, i) => { const p = P(c.who); return <Row key={i} style={{ alignItems: 'flex-start', animation: c.fresh ? 'mmFadeUp .35s var(--ease-out)' : 'none' }}><AAv name={p.name} src={p.src} size={34} />
            <div style={{ background: 'var(--white)', borderRadius: '6px 18px 18px 18px', padding: '9px 13px', boxShadow: 'var(--shadow-hairline)' }}><Txt s={13} w={700}>{c.who === 'me' ? 'You' : p.name}</Txt><div><Txt s={15}>{c.text}</Txt></div></div></Row>; })}
          {!post.comments.length && <Txt s={14} c="var(--text-tertiary)">No comments yet. Be the first.</Txt>}
        </div>
      </div>
    </div>
    {sheet === 'menu' && <ADlg contained variant="sheet" onClose={() => setSheet(null)} title={isOrg ? 'Your post' : 'Post options'} description={isOrg ? 'Only you, the organizer, can edit or delete this post.' : `${P(post.organizer).name} organized this session.`}>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
        {isOrg && <ABtn variant="secondary" iconLeft="pencil" fullWidth onClick={() => { setSheet(null); setEditing(true); }}>Edit caption</ABtn>}
        {isOrg && <ABtn variant="danger" iconLeft="trash-2" fullWidth onClick={() => setSheet('delete')}>Delete post</ABtn>}
        {!isOrg && isIn && <ABtn variant="danger" iconLeft="user-minus" fullWidth onClick={() => { mm.removeMe(post.id); }}>Remove me from this post</ABtn>}
        {!isOrg && !isIn && <Txt s={14} c="var(--text-tertiary)">You weren't in this session.</Txt>}
      </div>
    </ADlg>}
    {sheet === 'delete' && <ADlg contained variant="modal" title="Delete this post?" description={`It disappears from all ${post.participants.length} profiles and your friends' feeds.`} onClose={() => setSheet(null)}
      actions={<><ABtn variant="secondary" fullWidth onClick={() => setSheet(null)}>Keep it</ABtn><ABtn variant="danger" fullWidth onClick={() => mm.deletePost(post.id)}>Delete</ABtn></>} />}
  </Screen>;
}
Object.assign(window, { MMCtx, useMM, PostCard, ActivityScreen, PostDetail });
