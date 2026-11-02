const { IconButton: PIB, Button: PBtn, Avatar: PAv, Belt: PBelt, Tabs: PTabs, Card: PCard, Tooltip: PTip, Badge: PBadge } = window.MatMonkeysDesignSystem_8b0f80;
function ProfileScreen({ me, week, recent, sessions }) {
  const [range, setRange] = React.useState('Week');
  const max = Math.max(...week); const total = week.reduce((a, b) => a + b, 0);
  const stats = [['Sessions', range === 'Week' ? 5 : range === 'Month' ? 19 : 214], ['Mat hours', range === 'Week' ? (total / 60).toFixed(1) : range === 'Month' ? '27.5' : '311'], ['Rounds', range === 'Week' ? 31 : range === 'Month' ? 118 : 1342], ['Subs', range === 'Week' ? 6 : range === 'Month' ? 21 : 188]];
  return <>
    <ScreenHeader title={me.handle} right={<><PIB icon="share-2" label="Share profile" /><PIB icon="settings" label="Settings" /></>} />
    <div style={{ padding: '4px 16px 24px', display: 'flex', flexDirection: 'column', gap: 16 }}>
      <div style={{ display: 'flex', gap: 16, alignItems: 'center' }}>
        <PAv name={me.name} size={88} belt={me.belt} />
        <div style={{ flex: 1 }}>
          <div style={{ font: '850 26px/1 var(--font-display)', fontStretch: '125%', textTransform: 'uppercase', letterSpacing: '-.02em', color: 'var(--text-primary)' }}>{me.name}</div>
          <div style={{ font: '400 13px/1.4 var(--font-body)', color: 'var(--text-tertiary)', marginTop: 6 }}>{me.gym}</div>
          <div style={{ display: 'flex', gap: 14, marginTop: 8, font: '500 13px var(--font-body)', color: 'var(--text-tertiary)' }}><span><b style={{ font: '700 14px var(--font-mono)', color: 'var(--text-primary)' }}>{me.followers}</b> followers</span><span><b style={{ font: '700 14px var(--font-mono)', color: 'var(--text-primary)' }}>{me.following}</b> following</span></div>
        </div>
      </div>
      <PBelt rank={me.belt} stripes={me.stripes} size="lg" label />
      <div style={{ display: 'flex', gap: 8 }}><PBtn variant="secondary" fullWidth iconLeft="pencil">Edit profile</PBtn><PBtn variant="secondary" fullWidth iconLeft="award">Promotions</PBtn></div>
      <PTabs variant="segmented" items={['Week', 'Month', 'Year']} value={range} onChange={setRange} />
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>{stats.map(([l, v]) => <PCard key={l} style={{ padding: 14 }}><Overline>{l}</Overline><div style={{ font: '850 30px/1 var(--font-display)', fontStretch: '125%', color: 'var(--text-primary)', marginTop: 8 }}>{v}</div></PCard>)}</div>
      <PCard>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline' }}><Overline>Mat time</Overline><span style={{ font: '600 12px var(--font-mono)', color: 'var(--text-secondary)' }}>{total} min</span></div>
        <div style={{ display: 'flex', alignItems: 'flex-end', gap: 10, height: 96, marginTop: 14 }}>{week.map((m, i) => <div key={i} style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6, height: '100%', justifyContent: 'flex-end' }}>
          <PTip content={m ? m + ' min' : 'Rest day'} style={{ width: '100%', flex: 1, alignItems: 'flex-end' }}><div style={{ width: '100%', height: m ? (m / max * 100) + '%' : 4, borderRadius: 4, background: i === 6 ? 'var(--accent)' : m ? 'var(--mat-600)' : 'var(--mat-800)' }}></div></PTip>
          <span style={{ font: '600 10px var(--font-body)', color: 'var(--text-tertiary)' }}>{'MTWTFSS'[i]}</span></div>)}</div>
      </PCard>
      <div><Overline style={{ marginBottom: 4 }}>Recent sessions</Overline>
        {[...sessions, ...recent].map((s, i) => <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '12px 0', boxShadow: 'inset 0 -1px 0 var(--border-subtle)' }}>
          <div style={{ width: 44, font: '700 12px var(--font-body)', color: 'var(--text-secondary)' }}>{s.day}</div>
          <div style={{ flex: 1, minWidth: 0 }}><div style={{ display: 'flex', gap: 8, alignItems: 'center' }}><PBadge>{s.type}</PBadge><span style={{ font: '600 13px var(--font-mono)', color: 'var(--text-primary)' }}>{s.min}m · {s.rounds}R</span></div>
            <div style={{ font: '400 13px/1.4 var(--font-body)', color: 'var(--text-tertiary)', marginTop: 4, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{s.note}</div></div>
        </div>)}
      </div>
    </div>
  </>;
}
Object.assign(window, { ProfileScreen });
