/* ClearScan — Settings screen + offline modal */

function Switch({ on, onChange }) {
  return (
    <button className="press" onClick={() => onChange(!on)} style={{
      width: 46, height: 28, borderRadius: 100, padding: 3, flexShrink: 0,
      background: on ? T.blue : '#CBD2D9', transition: 'background 180ms', position: 'relative',
    }}>
      <span style={{
        position: 'absolute', top: 3, left: on ? 21 : 3, width: 22, height: 22, borderRadius: '50%',
        background: '#fff', boxShadow: '0 1px 3px rgba(0,0,0,0.3)', transition: 'left 180ms cubic-bezier(.3,1.3,.6,1)',
      }} />
    </button>
  );
}

function SettingsGroup({ header, children, tint }) {
  return (
    <div style={{ marginBottom: 22 }}>
      <SectionLabel style={{ padding: '0 20px 8px' }}>{header}</SectionLabel>
      <div style={{
        background: tint || '#fff', margin: '0 16px', borderRadius: 16,
        boxShadow: tint ? 'none' : T.shadowCard, overflow: 'hidden',
        border: tint ? `1px solid #FCEFC7` : 'none',
      }}>{children}</div>
    </div>
  );
}

function SettingsRow({ icon, iconColor, title, sub, trailing, onClick, last }) {
  return (
    <div className={onClick ? 'press' : ''} onClick={onClick} style={{
      display: 'flex', alignItems: 'center', gap: 14, padding: '13px 16px',
      borderBottom: last ? 'none' : `1px solid ${T.border}`, minHeight: 56,
    }}>
      {icon && <Icon name={icon} size={22} color={iconColor || T.text2} fill={0} />}
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: 15, fontWeight: 500, color: T.text }}>{title}</div>
        {sub && <div style={{ fontSize: 12.5, color: T.text2, marginTop: 2, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{sub}</div>}
      </div>
      {trailing}
    </div>
  );
}

function SettingsScreen() {
  const app = window.__cs;
  const [test, setTest] = React.useState('idle'); // idle|loading
  const [sw, setSw] = React.useState({ cnn: true, autoEnh: false, haptic: true });
  const forceOffline = !app.state.online;

  const testConn = () => {
    setTest('loading');
    setTimeout(() => {
      setTest('idle');
      app.toast(app.state.online ? 'Connection OK — CNN backend reachable' : 'No connection — offline mode active', app.state.online ? 'success' : 'error');
    }, 1800);
  };

  return (
    <React.Fragment>
      <AppBar leading={<Logo size={34} radius={10} />} title="Settings" trailing={<div style={{ width: 40 }} />} />
      <div className="cs-scroll" style={{ flex: 1, overflowY: 'auto', background: T.appBg, paddingTop: 16, paddingBottom: 20 }}>
        {/* profile */}
        <div className="press" style={{
          background: '#fff', margin: '0 16px 22px', borderRadius: 16, boxShadow: T.shadowCard,
          padding: 16, display: 'flex', alignItems: 'center', gap: 14,
        }}>
          <div style={{ width: 56, height: 56, borderRadius: '50%', background: T.surfaceBlue, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
            <Icon name="person" size={32} color={T.blue} />
          </div>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 16, fontWeight: 600, color: T.text }}>Dr. User</div>
            <div style={{ fontSize: 13, color: T.text2, marginTop: 1 }}>Tap to edit profile</div>
          </div>
          <Icon name="edit" size={20} color={T.text2} fill={0} />
        </div>

        <SettingsGroup header="Connection">
          <SettingsRow icon="dns" title="Backend Server" sub="https://clearscan.onrender.com" trailing={<Icon name="edit" size={20} color={T.text2} fill={0} />} />
          <SettingsRow icon="wifi_find" iconColor={T.blue} title="Test Connection" sub="Verify API connectivity" last
            onClick={test === 'idle' ? testConn : undefined}
            trailing={test === 'loading'
              ? <span className="msr" style={{ fontSize: 22, color: T.blue, animation: 'cs-spin 0.8s linear infinite' }}>progress_activity</span>
              : <Icon name="wifi_find" size={22} color={T.blue} />} />
        </SettingsGroup>

        <SettingsGroup header="Processing">
          <SettingsRow title="Prefer CNN when Online" trailing={<Switch on={sw.cnn} onChange={v => setSw({ ...sw, cnn: v })} />} />
          <SettingsRow title="Auto-enhance Poor Images" last trailing={<Switch on={sw.autoEnh} onChange={v => setSw({ ...sw, autoEnh: v })} />} />
        </SettingsGroup>

        <SettingsGroup header="Storage">
          <SettingsRow icon="sd_storage" title="Cache Size" sub="14.2 MB" trailing={<Icon name="delete_sweep" size={22} color={T.text2} fill={0} />} />
          <SettingsRow icon="history" title="Clear History" sub="Remove all session records" last onClick={() => app.dialog('clearHistory')} trailing={<Icon name="chevron_right" size={22} color={T.text2} fill={0} />} />
        </SettingsGroup>

        <SettingsGroup header="Appearance">
          <SettingsRow icon="language" title="App Language" sub="English" trailing={<Icon name="chevron_right" size={22} color={T.text2} fill={0} />} />
          <SettingsRow icon="vibration" title="Haptic Feedback" last trailing={<Switch on={sw.haptic} onChange={v => setSw({ ...sw, haptic: v })} />} />
        </SettingsGroup>

        <SettingsGroup header="About">
          <SettingsRow icon="info" title="App Version" sub="ClearScan v1.0.0" trailing={null} />
          <SettingsRow icon="school" title="Project Info" sub="KNUST — Computer Science — Group 6" trailing={null} />
          <SettingsRow icon="gavel" title="Licences" last trailing={<Icon name="open_in_new" size={20} color={T.text2} fill={0} />} />
        </SettingsGroup>

        <SettingsGroup header="Debug" tint="#FFF8E1">
          <SettingsRow icon="warning" iconColor={T.fair} title="Force Offline Mode" last
            trailing={<Switch on={forceOffline} onChange={v => app.setOnline(!v)} />} />
        </SettingsGroup>
      </div>
      <BottomNav active="settings" onTab={app.go} onScan={() => app.openSheet('source')} />
    </React.Fragment>
  );
}

// ── Offline modal (Screen 15) ───────────────────────────────
function OfflineModal({ onClose }) {
  const app = window.__cs;
  const on = useEntered();
  return (
    <div onClick={onClose} style={{
      position: 'absolute', inset: 0, zIndex: 80, display: 'flex', alignItems: 'center', justifyContent: 'center',
      background: `rgba(10,10,10,${on ? 0.55 : 0})`, backdropFilter: 'blur(3px)', WebkitBackdropFilter: 'blur(3px)',
      padding: 32, transition: 'background 220ms ease',
    }}>
      <div onClick={e => e.stopPropagation()} style={{
        background: '#fff', borderRadius: 24, padding: '32px 24px', width: '100%',
        opacity: 1, transform: on ? 'scale(1)' : 'scale(0.9)',
        transition: 'transform 360ms cubic-bezier(.34,1.4,.64,1)', textAlign: 'center',
      }}>
        <Icon name="wifi_off" size={64} color={T.fair} style={{ background: '#FFF8E1', padding: 14, borderRadius: 20 }} />
        <div style={{ fontSize: 22, fontWeight: 700, color: T.text, marginTop: 16 }}>You're Offline</div>
        <div style={{ fontSize: 14, color: T.text2, lineHeight: 1.55, marginTop: 8, padding: '0 8px' }}>
          CNN-powered enhancement is unavailable. ClearScan will use the CLAHE offline pipeline — you'll still get high-quality enhancement.
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, margin: '22px 0 16px' }}>
          <div style={{ flex: 1, height: 1, background: T.border }} />
          <span style={{ fontSize: 11, color: T.text2 }}>Your options</span>
          <div style={{ flex: 1, height: 1, background: T.border }} />
        </div>
        <OfflineOption icon="auto_fix_high" title="Continue Offline" sub="Use CLAHE enhancement on-device — no internet needed" accent
          action={<PrimaryBtn style={{ height: 44, fontSize: 14 }} iconAfter="arrow_forward" onClick={onClose}>Proceed</PrimaryBtn>} />
        <div style={{ height: 12 }} />
        <OfflineOption icon="wifi_find" title="Check Connection" sub="Retry connecting to the server"
          action={<OutlineBtn style={{ height: 44, fontSize: 14 }} onClick={() => { app.setOnline(true); onClose(); }}>Retry</OutlineBtn>} />
        <TextBtn color={T.blue} style={{ marginTop: 14 }}>Learn more about offline mode</TextBtn>
      </div>
    </div>
  );
}

function OfflineOption({ icon, title, sub, action, accent }) {
  return (
    <div style={{
      textAlign: 'left', background: '#fff', borderRadius: 12, padding: 16,
      border: accent ? 'none' : `1px solid ${T.border}`,
      borderLeft: accent ? `3px solid ${T.blue}` : `1px solid ${T.border}`,
      boxShadow: accent ? T.shadowCard : 'none',
    }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 4 }}>
        <Icon name={icon} size={22} color={accent ? T.blue : T.text2} />
        <span style={{ fontSize: 15, fontWeight: 600, color: T.text }}>{title}</span>
      </div>
      <div style={{ fontSize: 13, color: T.text2, lineHeight: 1.45, marginBottom: 12 }}>{sub}</div>
      {action}
    </div>
  );
}

Object.assign(window, {
  Switch, SettingsGroup, SettingsRow, SettingsScreen, OfflineModal, OfflineOption,
});
