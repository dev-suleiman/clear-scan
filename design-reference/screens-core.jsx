/* ClearScan — app chrome (AppBar, BottomNav) + core screens (Home, History, Settings) */

const STATUS_INSET = 52;   // clears IOSDevice status bar
const NAV_HEIGHT = 64;

const SESSIONS = [
  { id: 14, label: 'Chest PA — Session 14', time: 'Today, 09:41 AM', q: 'good', v: 'good' },
  { id: 13, label: 'Chest AP — Session 13', time: 'Today, 08:12 AM', q: 'poor', v: 'poor' },
  { id: 12, label: 'Chest PA — Session 12', time: 'Yesterday, 04:53 PM', q: 'fair', v: 'fair' },
  { id: 11, label: 'Chest Lateral — Session 11', time: 'Yesterday, 02:20 PM', q: 'good', v: 'good' },
  { id: 10, label: 'Chest PA — Session 10', time: 'Jun 5, 11:08 AM', q: 'good', v: 'good' },
  { id: 9,  label: 'Chest AP — Session 09', time: 'Jun 4, 03:44 PM', q: 'poor', v: 'poor' },
];

// ── App bar ─────────────────────────────────────────────────
function AppBar({ leading, title, trailing, border = true }) {
  return (
    <div style={{
      flexShrink: 0, background: '#fff', paddingTop: STATUS_INSET,
      borderBottom: border ? `1px solid ${T.border}` : 'none', zIndex: 5,
    }}>
      <div style={{
        height: 52, display: 'flex', alignItems: 'center', padding: '0 12px', gap: 4,
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, minWidth: 44 }}>{leading}</div>
        <div style={{ flex: 1, textAlign: 'center', fontSize: 18, fontWeight: 600, color: T.text }}>{title}</div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 6, justifyContent: 'flex-end', minWidth: 44 }}>{trailing}</div>
      </div>
    </div>
  );
}

function IconButton({ name, color = T.text2, size = 24, onClick, badge }) {
  return (
    <button className="press" onClick={onClick} style={{
      width: 40, height: 40, borderRadius: 12, display: 'flex',
      alignItems: 'center', justifyContent: 'center', position: 'relative',
    }}>
      <Icon name={name} size={size} color={color} fill={0} weight={500} />
      {badge && <span style={{ position: 'absolute', top: 8, right: 9, width: 7, height: 7, borderRadius: 4, background: T.poor, border: '1.5px solid #fff' }} />}
    </button>
  );
}

function BackBar({ title, online, trailing }) {
  const app = window.__cs;
  return (
    <AppBar
      leading={<IconButton name="arrow_back" color={T.text} onClick={() => app.back()} />}
      title={title}
      trailing={trailing}
    />
  );
}

// ── Bottom navigation w/ centre FAB ─────────────────────────
function BottomNav({ active, onTab, onScan }) {
  const tab = (key, icon, label) => {
    const on = active === key;
    return (
      <button key={key} className="press" onClick={() => onTab(key)} style={{
        flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center',
        gap: 3, paddingTop: 8,
      }}>
        <Icon name={icon} size={24} fill={on ? 1 : 0} color={on ? T.blue : T.text2} />
        <span style={{ fontSize: 11, fontWeight: on ? 600 : 500, color: on ? T.blue : T.text2 }}>{label}</span>
      </button>
    );
  };
  return (
    <div style={{
      flexShrink: 0, background: '#fff', borderTop: `1px solid ${T.border}`,
      paddingBottom: 22, position: 'relative', zIndex: 6,
    }}>
      <div style={{ display: 'flex', alignItems: 'flex-start', height: NAV_HEIGHT, padding: '0 4px' }}>
        {tab('home', 'home', 'Home')}
        {tab('history', 'history', 'History')}
        {/* FAB slot */}
        <div style={{ width: 72, position: 'relative', flexShrink: 0 }}>
          <button className="press" onClick={onScan} style={{
            position: 'absolute', top: -22, left: '50%', transform: 'translateX(-50%)',
            width: 56, height: 56, borderRadius: 18, background: T.blue,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            boxShadow: '0 4px 16px rgba(21,101,192,0.4)',
          }}>
            <Icon name="document_scanner" size={28} color="#fff" />
          </button>
          <div style={{ textAlign: 'center', paddingTop: 40, fontSize: 11, fontWeight: 500, color: T.text2 }}>Scan</div>
        </div>
        {tab('settings', 'settings', 'Settings')}
        <div style={{ flex: 1 }} />
      </div>
    </div>
  );
}

// ── Session card (used in Home + History) ───────────────────
function SessionCard({ s, onOpen, thumb = 52, trailing }) {
  return (
    <div className="press" onClick={onOpen} style={{
      background: '#fff', borderRadius: 16, boxShadow: T.shadowCard,
      padding: '12px 14px', display: 'flex', alignItems: 'center', gap: 12,
    }}>
      <XRay variant={s.v} style={{ width: thumb, height: thumb, borderRadius: 12, flexShrink: 0 }} />
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: 15, fontWeight: 500, color: T.text, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{s.label}</div>
        <div style={{ fontSize: 11, color: T.text2, marginTop: 3, display: 'flex', alignItems: 'center', gap: 6 }}>
          <QualityPill q={s.q} />
          <span>{s.time}</span>
        </div>
      </div>
      {trailing || <Icon name="chevron_right" size={22} color={T.text2} fill={0} />}
    </div>
  );
}

// ── HOME ────────────────────────────────────────────────────
function HomeScreen() {
  const app = window.__cs;
  const { online } = app.state;
  return (
    <React.Fragment>
      <AppBar
        leading={<Logo size={34} radius={10} />}
        title="ClearScan"
        trailing={<React.Fragment>
          <IconButton name="notifications" onClick={() => {}} badge />
          <div style={{ width: 28, display: 'flex', justifyContent: 'center', paddingRight: 6 }}>
            <ConnectivityBadge online={online} />
          </div>
        </React.Fragment>}
      />
      <div className="cs-scroll" style={{ flex: 1, overflowY: 'auto', background: T.appBg }}>
        {!online && (
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, background: '#FFF8E1', padding: '8px 20px' }}>
            <Icon name="wifi_off" size={16} color="#E65100" />
            <span style={{ fontSize: 13, color: '#E65100', fontWeight: 500 }}>Offline — CNN features unavailable. CLAHE mode active.</span>
          </div>
        )}
        {/* hero greeting */}
        <div className="press" onClick={() => app.openSheet('source')} style={{
          height: 80, display: 'flex', alignItems: 'center', gap: 14, padding: '0 20px',
          background: 'linear-gradient(90deg, #E3F2FD 0%, #FFFFFF 78%)',
          borderBottom: `1px solid ${T.border}`,
        }}>
          <Icon name="medical_services" size={32} color={T.blue} />
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 14, fontWeight: 600, color: T.blue }}>Good morning, Doctor</div>
            <div style={{ fontSize: 14, color: T.text2, marginTop: 1 }}>Ready to assess an X-ray?</div>
          </div>
          <Icon name="chevron_right" size={24} color={T.accent} fill={0} />
        </div>

        <div style={{ padding: 20 }}>
          <SectionLabel>Quick Actions</SectionLabel>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginTop: 12 }}>
            <QuickAction icon="upload_file" title="Upload X-Ray" sub="Choose from gallery" cta="Select" onClick={() => app.pickSource('gallery')} />
            <QuickAction icon="camera_alt" title="Capture X-Ray" sub="Use your camera" cta="Open" onClick={() => app.pickSource('camera')} />
          </div>

          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginTop: 26, marginBottom: 12 }}>
            <span style={{ fontSize: 16, fontWeight: 600, color: T.text }}>Recent Sessions</span>
            <TextBtn color={T.blue} style={{ padding: '4px 4px' }} onClick={() => app.go('history')}>View All</TextBtn>
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {SESSIONS.slice(0, 4).map(s => (
              <SessionCard key={s.id} s={s} onOpen={() => app.openSession(s)} />
            ))}
          </div>
          <div style={{ height: 12 }} />
        </div>
      </div>
      <BottomNav active="home" onTab={app.go} onScan={() => app.openSheet('source')} />
    </React.Fragment>
  );
}

function QuickAction({ icon, title, sub, cta, onClick }) {
  return (
    <div className="press" onClick={onClick} style={{
      background: '#fff', borderRadius: 16, boxShadow: T.shadowCard, padding: 16,
      display: 'flex', flexDirection: 'column', gap: 4,
    }}>
      <div style={{
        width: 56, height: 56, borderRadius: 14, background: T.surfaceBlue,
        display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: 8,
      }}>
        <Icon name={icon} size={32} color={T.blue} />
      </div>
      <div style={{ fontSize: 16, fontWeight: 500, color: T.text }}>{title}</div>
      <div style={{ fontSize: 13, color: T.text2, lineHeight: 1.4 }}>{sub}</div>
      <div style={{ fontSize: 12, fontWeight: 600, color: T.blue, marginTop: 6, display: 'flex', alignItems: 'center', gap: 2 }}>
        {cta} <Icon name="arrow_forward" size={13} color={T.blue} />
      </div>
    </div>
  );
}

// ── HISTORY ─────────────────────────────────────────────────
function HistoryScreen() {
  const app = window.__cs;
  const [filter, setFilter] = React.useState('All');
  const [menu, setMenu] = React.useState(null);
  const filters = ['All', 'Good', 'Fair', 'Poor', 'Today', 'This Week'];
  const list = SESSIONS.filter(s => {
    if (filter === 'All') return true;
    if (['Good', 'Fair', 'Poor'].includes(filter)) return s.q === filter.toLowerCase();
    if (filter === 'Today') return s.time.startsWith('Today');
    if (filter === 'This Week') return true;
    return true;
  });
  return (
    <React.Fragment>
      <AppBar
        leading={<Logo size={34} radius={10} />}
        title="Scan History"
        trailing={<React.Fragment>
          <IconButton name="search" />
          <IconButton name="filter_list" />
        </React.Fragment>}
      />
      <div className="cs-scroll" style={{ flex: 1, overflowY: 'auto', background: T.appBg }}>
        {/* filter chips */}
        <div className="cs-scroll" style={{ display: 'flex', gap: 8, padding: '14px 20px', overflowX: 'auto' }}>
          {filters.map(f => {
            const on = filter === f;
            return (
              <button key={f} className="press" onClick={() => setFilter(f)} style={{
                flexShrink: 0, height: 36, padding: '0 16px', borderRadius: 100,
                background: on ? T.blue : '#fff', color: on ? '#fff' : T.text2,
                border: on ? 'none' : `1px solid ${T.border}`,
                fontSize: 13, fontWeight: 600,
              }}>{f}</button>
            );
          })}
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12, padding: '4px 20px 16px' }}>
          {list.map(s => (
            <SessionCard key={s.id} s={s} thumb={64} onOpen={() => app.openSession(s)}
              trailing={<button className="press" onClick={(e) => { e.stopPropagation(); setMenu(menu === s.id ? null : s.id); }} style={{ position: 'relative', width: 36, height: 36, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                <Icon name="more_vert" size={22} color={T.text2} fill={0} />
                {menu === s.id && <PopupMenu onClose={() => setMenu(null)} />}
              </button>}
            />
          ))}
          {list.length === 0 && <EmptyState icon="search_off" title="No sessions found" sub="Your scan history will appear here after your first analysis." />}
        </div>
      </div>
      <BottomNav active="history" onTab={app.go} onScan={() => app.openSheet('source')} />
    </React.Fragment>
  );
}

function PopupMenu({ onClose }) {
  const row = (icon, label, color) => (
    <div className="press" onClick={(e) => { e.stopPropagation(); onClose(); }} style={{
      display: 'flex', alignItems: 'center', gap: 10, padding: '11px 14px', fontSize: 14, fontWeight: 500, color: color || T.text,
    }}>
      <Icon name={icon} size={20} color={color || T.text2} fill={0} /> {label}
    </div>
  );
  return (
    <div style={{
      position: 'absolute', top: 34, right: 4, width: 184, background: '#fff', borderRadius: 12,
      boxShadow: '0 8px 28px rgba(0,0,0,0.18)', overflow: 'hidden', zIndex: 30, textAlign: 'left',
      animation: 'cs-fade-in 120ms ease',
    }}>
      {row('open_in_new', 'View Details')}
      <div style={{ height: 1, background: T.border }} />
      {row('share', 'Share Report')}
      <div style={{ height: 1, background: T.border }} />
      {row('delete', 'Delete', T.destructive)}
    </div>
  );
}

function EmptyState({ icon, title, sub, action }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', textAlign: 'center', padding: '48px 30px', gap: 6 }}>
      <Icon name={icon} size={72} color="#D1D5DB" />
      <div style={{ fontSize: 18, fontWeight: 600, color: T.text, marginTop: 6 }}>{title}</div>
      <div style={{ fontSize: 14, color: T.text2, lineHeight: 1.5, maxWidth: 240 }}>{sub}</div>
      {action}
    </div>
  );
}

Object.assign(window, {
  STATUS_INSET, NAV_HEIGHT, SESSIONS, AppBar, IconButton, BackBar, BottomNav,
  SessionCard, HomeScreen, QuickAction, HistoryScreen, PopupMenu, EmptyState,
});
