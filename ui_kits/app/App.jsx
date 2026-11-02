const { TabBar: XTab, Toast: XToast, Button: XBtn, Icon: XIcon } = window.MatMindDesignSystem_8b0f80;
const clone = o => JSON.parse(JSON.stringify(o));
const TABS = [{ id: 'activity', icon: 'house', label: 'Activity' }, { id: 'training', icon: 'calendar', label: 'Training' }, { id: 'friends', icon: 'users', label: 'Friends' }, { id: 'profile', icon: 'user', label: 'Profile' }];
const SCREENS = { post: PostDetail, session: SessionDetail, create: CreateScreen, complete: CompleteScreen, friend: FriendProfile, qr: QRScreen, notifications: NotificationsScreen };

function useApp() {
  const [s, setS] = React.useState(() => ({ ...clone(window.MM_SEED), drafts: [], emptyTraining: false }));
  const [tab, setTabRaw] = React.useState(() => localStorage.getItem('mm2-tab') || 'activity');
  const [stack, setStack] = React.useState([]);
  const [toastMsg, setToast] = React.useState(null);
  const [highlight, setHighlight] = React.useState(null);
  const [fresh, setFresh] = React.useState(null);
  const timers = React.useRef([]);
  const later = (fn, ms) => timers.current.push(setTimeout(fn, ms));
  React.useEffect(() => { localStorage.setItem('mm2-tab', tab); }, [tab]);
  const up = fn => setS(prev => { const n = clone(prev); fn(n); return n; });
  const person = id => id === 'me' ? s.me : s.people[id];
  const streakOf = f => { let n = 0; for (let i = f.weeks.length - 1; i >= 0 && f.weeks[i]; i--) n++; return n + (f.thisWeek === 'done' ? 1 : 0); };
  const toast = (message, variant = 'default') => { setToast({ message, variant, k: Date.now() }); later(() => setToast(t => t && t.message === message ? null : t), 2600); };
  const go = (name, props = {}) => setStack(st => [...st, { name, props, key: Date.now() + Math.random() }]);
  const back = () => setStack(st => st.slice(0, -1));
  const replace = (name, props = {}) => setStack(st => [...st.slice(0, -1), { name, props, key: Date.now() }]);
  const setTab = t => { setStack([]); setTabRaw(t); };
  const findSession = id => s.upcoming.find(x => x.id === id) || (s.toComplete && s.toComplete.id === id ? s.toComplete : null) || s.drafts.find(x => x.id === id);
  const mm = {
    s, person, streakOf, toast, go, back, setTab, findSession, fresh,
    like: id => up(n => { const p = n.posts.find(x => x.id === id); p.likes = p.likes.includes('me') ? p.likes.filter(x => x !== 'me') : ['me', ...p.likes]; }),
    comment: (id, text) => up(n => { n.posts.find(x => x.id === id).comments.push({ who: 'me', text, fresh: true }); }),
    editCaption: (id, cap) => { up(n => { n.posts.find(x => x.id === id).caption = cap; }); toast('Caption updated', 'success'); },
    deletePost: id => { up(n => { n.posts = n.posts.filter(x => x.id !== id); }); back(); toast('Post deleted from every profile'); },
    removeMe: id => { up(n => { const p = n.posts.find(x => x.id === id); p.participants = p.participants.filter(x => x !== 'me'); }); back(); toast("You're off that post. It's gone from your profile."); },
    rsvp: (sid, st) => { up(n => { n.upcoming.find(x => x.id === sid).people.me = st; n.notifications.forEach(x => { if (x.session === sid) x.unread = false; }); });
      if (st === 'going') { setFresh(sid + 'me'); toast("You're in. See you on the mat.", 'success'); } else toast('Declined. No hard feelings.'); },
    removeParticipant: (sid, pid) => { up(n => { delete n.upcoming.find(x => x.id === sid).people[pid]; }); toast(person(pid).name.split(' ')[0] + ' removed'); },
    addParticipants: (sid, ids) => { up(n => { const x = n.upcoming.find(y => y.id === sid); ids.forEach(i => x.people[i] = 'going'); }); setFresh(sid + ids[0]); toast(`Added ${ids.length} to the session`, 'success'); },
    createSession: d => {
      const id = 'n' + Date.now();
      const people = { me: 'going' }; d.invited.forEach(i => people[i] = d.past ? 'going' : 'invited');
      const sess = { id, title: d.title, day: d.day, date: d.date, month: d.month, time: d.time, gym: d.gym, organizer: 'me', privacy: d.privacy, note: d.note, people };
      if (d.past) { up(n => { n.drafts.push(sess); }); replace('complete', { id }); return; }
      up(n => { n.upcoming.push(sess); n.emptyTraining = false; });
      replace('session', { id });
      toast(d.invited.length ? `Invites sent to ${d.invited.length}` : 'Session created', 'success');
      d.invited.slice(0, 2).forEach((pid, i) => later(() => {
        up(n => { const x = n.upcoming.find(y => y.id === id); if (x) x.people[pid] = 'going'; n.notifications.unshift({ id: 'j' + Date.now(), kind: 'joined', who: pid, text: 'joined ' + d.title, time: 'now', unread: true }); });
        setFresh(id + pid); toast(`${person(pid).name.split(' ')[0]} joined ${d.title}`, 'friend');
      }, 2200 + i * 2000));
    },
    publish: (sid, { photo, caption, people }) => {
      const sess = findSession(sid);
      const post = { id: 'p' + Date.now(), organizer: 'me', title: sess.title, gym: sess.gym, date: `${sess.day}, ${sess.month} ${sess.date}`, ago: 'now', photo, participants: people, caption, likes: [], extraLikes: 0, comments: [] };
      const streaks = [];
      s.friends.forEach(f => { if (people.includes(f.id) && f.thisWeek !== 'done') { const from = streakOf(f); streaks.push({ id: f.id, from, to: from + 1, f: clone(f) }); } });
      up(n => { n.posts.unshift(post); n.upcoming = n.upcoming.filter(x => x.id !== sid); n.drafts = n.drafts.filter(x => x.id !== sid); if (n.toComplete && n.toComplete.id === sid) n.toComplete = null;
        n.friends.forEach(f => { if (people.includes(f.id)) f.thisWeek = 'done'; }); });
      return { post, streaks };
    },
    showPost: id => { setStack([]); setTabRaw('activity'); setHighlight(id); later(() => setHighlight(null), 2500);
      later(() => { up(n => { const p = n.posts.find(x => x.id === id); if (p) { p.likes = ['sarah']; p.extraLikes = 0; } }); toast('Sarah liked your post', 'friend'); }, 1800);
      later(() => { up(n => { const p = n.posts.find(x => x.id === id); if (p) { p.likes.push('alex'); p.comments.push({ who: 'alex', text: 'Great rounds today. Same time next week?', fresh: true }); } }); toast('Alex commented on your post'); }, 3800); },
    addFriend: id => up(n => { if (!n.friends.find(f => f.id === id)) n.friends.unshift({ id, weeks: [false, false, false, false, false, false, false, false, false], thisWeek: 'pending', best: 0, together: 0 }); }),
    readAll: () => up(n => n.notifications.forEach(x => x.unread = false)),
  };
  const reset = () => { timers.current.forEach(clearTimeout); timers.current = []; setS({ ...clone(window.MM_SEED), drafts: [], emptyTraining: false }); setStack([]); setToast(null); setHighlight(null); };
  return { mm, tab, setTabRaw, stack, setStack, toastMsg, highlight, reset, up };
}

function App() {
  const app = useApp(); const { mm, tab, stack, toastMsg, highlight } = app;
  window.__mm = app;
  React.useEffect(() => { const h = location.hash.slice(1); if (h) runPreset(app, h); }, []);
  const TabScreen = { activity: ActivityScreen, training: TrainingScreen, friends: FriendsScreen, profile: ProfileScreen }[tab] || ActivityScreen;
  return <div style={{ display: 'flex', gap: 56, alignItems: 'center', justifyContent: 'center', minHeight: '100vh', padding: '32px 24px', boxSizing: 'border-box' }}>
    <ReviewPanel app={app} />
    <MMCtx.Provider value={mm}>
      <Phone>
        <TabScreen key={tab} highlight={highlight} />
        {stack.map(st => { const C = SCREENS[st.name]; return <C key={st.key} {...st.props} />; })}
        {stack.length === 0 && <XTab style={{ position: 'absolute', left: 0, right: 0, bottom: 0, zIndex: 20 }} value={tab} onChange={mm.setTab} items={TABS.map(t => t.id === 'friends' ? { ...t, badge: mm.s.friends.some(f => mm.streakOf(f) > 0 && f.thisWeek === 'pending') } : t)}
          centerAction={{ icon: 'plus', label: 'Plan a session', onClick: () => mm.go('create') }} />}
        {toastMsg && <div key={toastMsg.k} style={{ position: 'absolute', top: 6, left: 12, right: 12, zIndex: 85, animation: 'mmToast .4s var(--ease-bounce)' }}><XToast variant={toastMsg.variant} message={toastMsg.message} /></div>}
      </Phone>
    </MMCtx.Provider>
  </div>;
}

const PRESETS = {
  activity: a => a.mm.setTab('activity'), training: a => a.mm.setTab('training'), friends: a => a.mm.setTab('friends'), profile: a => a.mm.setTab('profile'),
  create: a => { a.mm.setTab('training'); setTimeout(() => a.mm.go('create'), 30); },
  complete: a => { a.mm.setTab('training'); setTimeout(() => a.mm.go('complete', { id: 'c1' }), 30); },
  qr: a => { a.mm.setTab('friends'); setTimeout(() => a.mm.go('qr'), 30); },
  scan: a => { a.mm.setTab('friends'); setTimeout(() => a.mm.go('qr', { tab: 'scan' }), 30); },
  notifications: a => { a.mm.setTab('activity'); setTimeout(() => a.mm.go('notifications'), 30); },
  post: a => { a.mm.setTab('activity'); setTimeout(() => a.mm.go('post', { id: 'p1' }), 30); },
  empty: a => { a.up(n => { n.emptyTraining = true; }); a.mm.setTab('training'); },
  invite: a => { a.mm.setTab('training'); setTimeout(() => a.mm.go('session', { id: 's2' }), 30); },
  broken: a => { a.mm.setTab('friends'); setTimeout(() => a.mm.go('friend', { id: 'jamie' }), 30); },
  active: a => { a.mm.setTab('friends'); setTimeout(() => a.mm.go('friend', { id: 'sarah' }), 30); },
};
function runPreset(app, key) { app.reset(); setTimeout(() => PRESETS[key] && PRESETS[key](app), 20); }

const JOURNEYS = [
  { k: 'A', title: 'Plan training together', start: 'training', steps: ['Training tab → Plan a training session', 'Pick a day, time and gym', 'Tap friends to invite → Send', 'Watch Sarah & Alex join live'] },
  { k: 'B', title: 'Share a training memory', start: 'training', steps: ['"How was Halloween open mat?" → Complete & share', 'Take photo → pick one', 'Toggle Training completed → Publish', 'See it in Activity; friends like & comment'] },
  { k: 'C', title: 'Keep a friendship streak', start: 'friends', steps: ['Friends → tap You + Sarah', 'Invite Sarah to train → send', 'Training → Complete & share with Sarah in it', 'Streak ticks 8 → 9'] },
];
function ReviewPanel({ app }) {
  const [j, setJ] = React.useState(null);
  const L = ({ k, children }) => <button onClick={() => runPreset(app, k)} style={{ display: 'block', width: '100%', textAlign: 'left', border: 0, background: 'transparent', padding: '6px 10px', borderRadius: 10, cursor: 'pointer', font: '500 14px var(--font-body)', color: 'var(--ink-800)' }} onMouseEnter={e => e.currentTarget.style.background = 'var(--paper-2)'} onMouseLeave={e => e.currentTarget.style.background = 'transparent'}>{children}</button>;
  const H = ({ children }) => <div style={{ font: '800 13px var(--font-display)', color: 'var(--ink-500)', margin: '18px 10px 6px', letterSpacing: '-.01em' }}>{children}</div>;
  return <aside className="mm-panel" style={{ width: 250, flexShrink: 0, alignSelf: 'center' }}>
    <div style={{ font: '800 26px/1 var(--font-display)', letterSpacing: '-.04em', padding: '0 10px' }}>mat mind<span style={{ color: 'var(--accent)' }}>.</span></div>
    <div style={{ font: '500 13px var(--font-body)', color: 'var(--ink-500)', padding: '6px 10px 0' }}>First draft · interactive prototype · <a href="flows.html">IA & flows</a></div>
    <H>Journeys</H>
    {JOURNEYS.map(x => <div key={x.k} style={{ margin: '0 0 6px' }}>
      <button onClick={() => { setJ(j === x.k ? null : x.k); runPreset(app, x.start); }} style={{ display: 'flex', gap: 10, alignItems: 'center', width: '100%', textAlign: 'left', border: 0, cursor: 'pointer', padding: '8px 10px', borderRadius: 14, background: j === x.k ? 'var(--white)' : 'transparent', boxShadow: j === x.k ? 'var(--shadow-card)' : 'none' }}>
        <span style={{ width: 26, height: 26, borderRadius: 99, background: 'var(--accent)', color: '#fff', font: '800 13px/26px var(--font-display)', textAlign: 'center', flexShrink: 0 }}>{x.k}</span><span style={{ font: '700 14px var(--font-body)', color: 'var(--ink-900)' }}>{x.title}</span></button>
      {j === x.k && <ol style={{ margin: '8px 0 6px', paddingLeft: 46, font: '400 13px/1.5 var(--font-body)', color: 'var(--ink-700)' }}>{x.steps.map(s => <li key={s}>{s}</li>)}</ol>}
    </div>)}
    <H>Screens</H>
    {[['activity', 'Activity feed'], ['training', 'Upcoming training'], ['create', 'Create session'], ['complete', 'Complete & share'], ['friends', 'Friends & streaks'], ['qr', 'QR code'], ['profile', 'Profile'], ['notifications', 'Notifications']].map(([k, l], i) => <L key={k} k={k}><span style={{ color: 'var(--ink-400)', font: '600 12px var(--font-mono)', marginRight: 8 }}>{i + 1}</span>{l}</L>)}
    <H>States</H>
    {[['empty', 'Empty training schedule'], ['invite', 'Pending invitation'], ['active', 'Active streak'], ['broken', 'Broken streak'], ['scan', 'Scan → instant friends'], ['post', 'Post detail + comments']].map(([k, l]) => <L key={k} k={k}>{l}</L>)}
    <button onClick={app.reset} style={{ marginTop: 14, marginLeft: 10, border: 0, background: 'transparent', cursor: 'pointer', font: '600 13px var(--font-body)', color: 'var(--coral-600)', padding: 0 }}>Reset demo</button>
  </aside>;
}
ReactDOM.createRoot(document.getElementById('root')).render(<App />);
