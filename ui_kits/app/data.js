(() => {
const ph = n => '../../assets/photos/' + n + '.jpg';
const T = true, F = false;
window.MM_PH = ph;
window.MM_SEED = {
  me: { id: 'me', name: 'Dani Alves', belt: 'purple', stripes: 2, gym: 'Tidewater BJJ', email: 'dani.alves@gmail.com', src: ph('portrait-gi') },
  people: {
    sarah: { name: 'Sarah Lee', belt: 'blue', stripes: 3, gym: 'Tidewater BJJ', hue: 'sky' },
    alex:  { name: 'Alex Moreno', belt: 'white', stripes: 3, gym: 'Tidewater BJJ', hue: 'mint' },
    priya: { name: 'Priya Nair', belt: 'blue', stripes: 1, gym: 'Tidewater BJJ', hue: 'sun' },
    kenji: { name: 'Kenji Ito', belt: 'purple', stripes: 0, gym: 'Tidewater BJJ', hue: 'plum' },
    jamie: { name: 'Jamie Cole', belt: 'brown', stripes: 1, gym: 'North Shore Grappling', hue: 'plum' },
    marco: { name: 'Marco Silva', belt: 'black', stripes: 2, gym: 'Harbor Jiu-Jitsu', hue: 'coral' },
    lena:  { name: 'Lena Park', belt: 'white', stripes: 1, gym: 'Tidewater BJJ', hue: 'mint' },
  },
  // weeks: last 9 completed calendar weeks oldest→newest; thisWeek: done | pending
  friends: [
    { id: 'sarah', weeks: [F,T,T,T,T,T,T,T,T], thisWeek: 'pending', best: 8, together: 31 },
    { id: 'kenji', weeks: [F,F,T,F,F,F,F,T,T], thisWeek: 'pending', best: 3, together: 9 },
    { id: 'alex',  weeks: [T,F,F,F,F,F,T,T,T], thisWeek: 'done', best: 5, together: 22 },
    { id: 'priya', weeks: [F,F,F,F,F,F,F,F,F], thisWeek: 'done', best: 1, together: 2 },
    { id: 'jamie', weeks: [T,T,T,T,T,T,F,F,F], thisWeek: 'pending', best: 12, together: 40, brokeAgo: '3 weeks ago' },
    { id: 'marco', weeks: [T,T,T,F,F,F,F,F,F], thisWeek: 'pending', best: 4, together: 7, brokeAgo: '6 weeks ago' },
  ],
  posts: [
    { id: 'p1', organizer: 'sarah', title: 'Sunday No-Gi open mat', gym: 'Tidewater BJJ', date: 'Sun, Nov 1', ago: '18h', photo: ph('roll-gi'), participants: ['sarah', 'me', 'alex', 'kenji'],
      caption: 'Six rounds, zero ego. Alex finally hit that knee cut on me and will not stop talking about it.', likes: ['alex', 'kenji', 'priya', 'jamie', 'lena'], extraLikes: 19,
      comments: [{ who: 'alex', text: 'Took me four months. Worth it.' }, { who: 'kenji', text: 'Rematch Thursday?' }] },
    { id: 'p2', organizer: 'jamie', title: 'Leg drag drilling', gym: 'North Shore Grappling', date: 'Sat, Oct 31', ago: '2d', photo: ph('coach-help'), participants: ['jamie', 'priya', 'marco'],
      caption: 'Slow reps, then positional rounds from the leg drag. Priya was a menace.', likes: ['priya', 'marco'], extraLikes: 11,
      comments: [{ who: 'priya', text: 'Hips sore in the best way' }] },
    { id: 'p3', organizer: 'me', title: 'Friday fundamentals + rolls', gym: 'Tidewater BJJ', date: 'Fri, Oct 30', ago: '3d', photo: ph('group-class'), participants: ['me', 'sarah', 'priya', 'lena'],
      caption: 'Brought Lena to her first open roll. She tapped me with a collar choke. Proud and slightly embarrassed.', likes: ['sarah', 'lena', 'alex'], extraLikes: 27,
      comments: [{ who: 'lena', text: 'I will be telling everyone about this' }] },
    { id: 'p4', organizer: 'alex', title: 'Early bird gi class', gym: 'Tidewater BJJ', date: 'Wed, Oct 28', ago: '5d', photo: ph('gym-throw'), participants: ['alex', 'me', 'sarah'],
      caption: '6am crew. Takedown day.', likes: ['sarah'], extraLikes: 8, comments: [] },
  ],
  upcoming: [
    { id: 's2', title: 'Leg-lock study group', day: 'Tue', date: 3, month: 'Nov', time: '7:30 PM', gym: 'North Shore Grappling', organizer: 'jamie', privacy: 'friends',
      people: { jamie: 'going', marco: 'going', priya: 'going', me: 'invited' }, note: 'Heel hook entries from SLX. Bring a rash guard.' },
    { id: 's3', title: 'Lunch rolls', day: 'Thu', date: 5, month: 'Nov', time: '12:15 PM', gym: 'Tidewater BJJ', organizer: 'sarah', privacy: 'friends',
      people: { sarah: 'going', me: 'going', priya: 'going', kenji: 'invited' }, note: '45 min, rounds only.' },
    { id: 's1', title: 'Saturday open mat', day: 'Sat', date: 7, month: 'Nov', time: '10:00 AM', gym: 'Tidewater BJJ', organizer: 'me', privacy: 'link',
      people: { me: 'going', sarah: 'going', alex: 'going', kenji: 'invited', lena: 'declined' }, note: 'All levels. Bring water, the mats get warm.' },
  ],
  toComplete: { id: 'c1', title: 'Halloween no-gi open mat', day: 'Sat', date: 31, month: 'Oct', time: '10:00 AM', gym: 'Tidewater BJJ', organizer: 'me', people: { me: 'going', sarah: 'going', alex: 'going', priya: 'going', kenji: 'going' } },
  notifications: [
    { id: 'n1', kind: 'invite', who: 'jamie', session: 's2', time: '20m', unread: true },
    { id: 'n2', kind: 'joined', who: 'alex', text: 'joined Saturday open mat', time: '2h', unread: true },
    { id: 'n3', kind: 'comment', who: 'kenji', text: 'commented on Sunday No-Gi open mat', quote: 'Rematch Thursday?', photo: ph('roll-gi'), time: '16h', unread: true },
    { id: 'n4', kind: 'published', who: 'sarah', text: 'shared Sunday No-Gi open mat. You\'re in it.', photo: ph('roll-gi'), time: '18h' },
    { id: 'n5', kind: 'joined', who: 'sarah', text: 'joined Saturday open mat', time: '1d' },
  ],
  gyms: ['Tidewater BJJ', 'North Shore Grappling', 'Harbor Jiu-Jitsu', 'Eastside MMA'],
  cameraRoll: ['roll-gi-2', 'team-lineup', 'floor-drill', 'grapple-match', 'bw-sweep', 'roll-gi'].map(ph),
};
})();
