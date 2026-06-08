/* ClearScan — app orchestrator: state machine, overlays, demo controls, stage */

const SCREENS = {
  home: HomeScreen, history: HistoryScreen, settings: SettingsScreen,
  preview: PreviewScreen, assess: AssessScreen, enhance: EnhanceScreen, results: ResultsScreen,
};

function ClearScanApp() {
  const [state, setState] = React.useState({
    screen: 'home', stack: [], sheet: null,
    online: true, quality: 'good',
    showOnboarding: true, onbPage: 0,
    assessPhase: 'loading', enhancePhase: 'loading',
    pdf: false, toast: null, dialog: null, offlineModal: false,
  });
  const timers = React.useRef([]);
  const after = (ms, fn) => { const id = setTimeout(fn, ms); timers.current.push(id); };

  // expose imperative API synchronously so child screens can read it on first render
  window.__cs = {
      state,
      go: (screen) => setState(s => ({ ...s, screen, stack: [], sheet: null, dialog: null })),
      back: () => setState(s => {
        if (s.stack.length) { const st = [...s.stack]; const prev = st.pop(); return { ...s, screen: prev, stack: st }; }
        return { ...s, screen: 'home', stack: [] };
      }),
      openSheet: (sheet) => setState(s => ({ ...s, sheet })),
      closeSheet: () => setState(s => ({ ...s, sheet: null })),
      pickSource: () => setState(s => ({ ...s, sheet: null, screen: 'preview', stack: [...s.stack, s.screen] })),
      startAssess: () => {
        setState(s => ({ ...s, screen: 'assess', stack: [...s.stack, s.screen], assessPhase: 'loading' }));
        after(2300, () => setState(s => ({ ...s, assessPhase: 'done' })));
      },
      startEnhance: () => {
        setState(s => ({ ...s, screen: 'enhance', stack: [...s.stack, s.screen], enhancePhase: 'loading' }));
        after(2100, () => setState(s => ({ ...s, enhancePhase: 'done' })));
      },
      openSession: (sess) => {
        setState(s => ({ ...s, screen: 'assess', stack: ['home'], quality: sess.q === 'good' ? 'good' : 'poor', assessPhase: 'done' }));
      },
      dialogPdf: () => {
        setState(s => ({ ...s, sheet: null, pdf: true }));
        after(2200, () => setState(s => ({ ...s, pdf: false, toast: { msg: 'PDF report saved and ready to share', kind: 'success' } })));
        after(5500, () => setState(s => s.toast ? { ...s, toast: null } : s));
      },
      toast: (msg, kind = 'info') => {
        setState(s => ({ ...s, toast: { msg, kind } }));
        after(3000, () => setState(s => ({ ...s, toast: null })));
      },
      dialog: (kind) => setState(s => ({ ...s, dialog: kind })),
      setOnline: (online) => setState(s => ({ ...s, online })),
      setQuality: (quality) => setState(s => ({ ...s, quality })),
      restart: () => { timers.current.forEach(clearTimeout); setState(s => ({ ...s, screen: 'home', stack: [], sheet: null, dialog: null, pdf: false, toast: null, offlineModal: false })); },
      showOffline: () => setState(s => ({ ...s, offlineModal: true })),
      onbGo: (n) => setState(s => ({ ...s, onbPage: n })),
      onbNext: () => setState(s => ({ ...s, onbPage: Math.min(2, s.onbPage + 1) })),
      finishOnboarding: () => setState(s => ({ ...s, showOnboarding: false, onbPage: 0, screen: 'home', stack: [] })),
      resetOnboarding: () => setState(s => ({ ...s, showOnboarding: true, onbPage: 0, screen: 'home', stack: [], sheet: null, dialog: null })),
  };

  const Cur = SCREENS[state.screen] || HomeScreen;

  return (
    <div style={{ position: 'relative', height: '100%', width: '100%', overflow: 'hidden', background: T.appBg }}>
      <div style={{ position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column' }}>
        <Cur />
      </div>

      {state.showOnboarding && <Onboarding />}

      {state.sheet === 'source' && <SourceSheet />}
      {state.sheet === 'export' && <ExportSheet />}
      {state.offlineModal && <OfflineModal onClose={() => setState(s => ({ ...s, offlineModal: false }))} />}
      {state.pdf && <PdfOverlay />}
      {state.dialog && <ConfirmDialog kind={state.dialog}
        onClose={() => setState(s => ({ ...s, dialog: null }))}
        onConfirm={() => setState(s => ({ ...s, dialog: null, toast: { msg: state.dialog === 'clearHistory' ? 'History cleared' : 'Session deleted', kind: 'success' } }))} />}
      {state.toast && <Toast msg={state.toast.msg} kind={state.toast.kind} />}
    </div>
  );
}

// ── Scaled phone stage + demo controls ──────────────────────
function Stage() {
  const [scale, setScale] = React.useState(1);
  React.useEffect(() => {
    const fit = () => setScale(Math.min(1, (window.innerHeight - 48) / 844, (window.innerWidth - 360) / 390));
    fit(); window.addEventListener('resize', fit); return () => window.removeEventListener('resize', fit);
  }, []);
  return (
    <div style={{ minHeight: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 40, background: '#C9D2DB', padding: 24, boxSizing: 'border-box' }}>
      <DemoControls />
      <div style={{ width: 390 * scale, height: 844 * scale, flexShrink: 0 }}>
        <div style={{ width: 390, height: 844, transform: `scale(${scale})`, transformOrigin: 'top left' }}>
          <IOSDevice width={390} height={844}>
            <ClearScanApp />
          </IOSDevice>
        </div>
      </div>
    </div>
  );
}

function DemoControls() {
  const [, force] = React.useReducer(x => x + 1, 0);
  const app = () => window.__cs;
  React.useEffect(() => { const id = setInterval(force, 250); return () => clearInterval(id); }, []);
  const st = app() ? app().state : {};

  const Seg = ({ label, options, value, onPick }) => (
    <div>
      <div style={{ fontSize: 11, fontWeight: 600, color: T.text2, textTransform: 'uppercase', letterSpacing: 1, marginBottom: 6 }}>{label}</div>
      <div style={{ display: 'flex', background: '#EEF2F6', borderRadius: 10, padding: 3 }}>
        {options.map(o => (
          <button key={o.v} onClick={() => onPick(o.v)} style={{
            flex: 1, padding: '8px 10px', borderRadius: 8, fontSize: 13, fontWeight: 600,
            background: value === o.v ? '#fff' : 'transparent', color: value === o.v ? T.blue : T.text2,
            boxShadow: value === o.v ? '0 1px 3px rgba(0,0,0,0.12)' : 'none',
          }}>{o.l}</button>
        ))}
      </div>
    </div>
  );

  const Jump = ({ label, onClick }) => (
    <button onClick={onClick} style={{ textAlign: 'left', padding: '9px 12px', borderRadius: 9, background: '#F4F6F8', fontSize: 13, fontWeight: 500, color: T.text, border: `1px solid ${T.border}` }}>{label}</button>
  );

  return (
    <div style={{ width: 268, flexShrink: 0, background: '#fff', borderRadius: 20, boxShadow: '0 18px 50px rgba(0,0,0,0.18)', padding: 22, display: 'flex', flexDirection: 'column', gap: 16, alignSelf: 'center' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
        <Logo size={36} radius={11} />
        <div>
          <div style={{ fontSize: 16, fontWeight: 700, color: T.text }}>ClearScan</div>
          <div style={{ fontSize: 11, color: T.text2 }}>Interactive prototype</div>
        </div>
      </div>
      <div style={{ height: 1, background: T.border }} />
      <Seg label="Connectivity" value={st.online ? 'on' : 'off'} options={[{ v: 'on', l: 'Online' }, { v: 'off', l: 'Offline' }]} onPick={v => app().setOnline(v === 'on')} />
      <Seg label="Result outcome" value={st.quality} options={[{ v: 'good', l: 'Good' }, { v: 'fair', l: 'Fair' }, { v: 'poor', l: 'Poor' }]} onPick={v => app().setQuality(v)} />
      <div style={{ height: 1, background: T.border }} />
      <div style={{ fontSize: 11, fontWeight: 600, color: T.text2, textTransform: 'uppercase', letterSpacing: 1 }}>Jump to</div>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
        <Jump label="Home" onClick={() => app().go('home')} />
        <Jump label="Scan flow" onClick={() => app().openSheet('source')} />
        <Jump label="History" onClick={() => app().go('history')} />
        <Jump label="Settings" onClick={() => app().go('settings')} />
        <Jump label="Offline modal" onClick={() => app().showOffline()} />
        <Jump label="Reset onboarding" onClick={() => app().resetOnboarding()} />
        <Jump label="Restart" onClick={() => app().restart()} />
      </div>
      <div style={{ fontSize: 11, color: T.text2, lineHeight: 1.5 }}>
        Tip: tap the centre <b>Scan</b> button to start. On the enhancement screen, <b>drag</b> the divider to compare.
      </div>
    </div>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<Stage />);
