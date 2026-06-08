/* ClearScan — enhancement screen + before/after comparison slider */

function ComparisonSlider({ height = 300, leftVar = 'orig', rightVar = 'enhanced' }) {
  const ref = React.useRef(null);
  const [w, setW] = React.useState(358);
  const [pos, setPos] = React.useState(50);
  const drag = React.useRef(false);
  const hinted = React.useRef(false);

  React.useEffect(() => {
    if (ref.current) setW(ref.current.getBoundingClientRect().width);
  }, []);

  // first-load drag hint: 50 -> 35 -> 50
  React.useEffect(() => {
    let raf, start;
    const dur = 1200;
    const tick = (t) => {
      if (hinted.current) return;
      if (!start) start = t;
      const p = Math.min(1, (t - start) / dur);
      const tri = p < 0.5 ? p * 2 : (1 - p) * 2;        // 0->1->0
      setPos(50 - tri * 15);
      if (p < 1) raf = requestAnimationFrame(tick); else setPos(50);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, []);

  const update = (clientX) => {
    const r = ref.current.getBoundingClientRect();
    const pct = ((clientX - r.left) / r.width) * 100;
    setPos(Math.max(2, Math.min(98, pct)));
  };
  const down = (e) => { hinted.current = true; drag.current = true; update(e.clientX); };
  const move = (e) => { if (drag.current) update(e.clientX); };
  const up = () => { drag.current = false; };

  return (
    <div ref={ref} onPointerDown={down} onPointerMove={move} onPointerUp={up} onPointerLeave={up}
      style={{ position: 'relative', height, borderRadius: 16, overflow: 'hidden', background: '#0A0A0A', touchAction: 'none', cursor: 'ew-resize', userSelect: 'none' }}>
      {/* enhanced (right, full) */}
      <XRay variant={rightVar} style={{ position: 'absolute', inset: 0 }} />
      {/* original (left, clipped) */}
      <div style={{ position: 'absolute', top: 0, left: 0, bottom: 0, width: `${pos}%`, overflow: 'hidden' }}>
        <XRay variant={leftVar} style={{ position: 'absolute', top: 0, left: 0, height: '100%', width: w }} />
      </div>
      {/* labels */}
      <span style={{ position: 'absolute', left: 10, bottom: 10, background: 'rgba(0,0,0,0.5)', color: '#fff', borderRadius: 100, padding: '4px 10px', fontSize: 11, fontWeight: 600 }}>Original</span>
      <span style={{ position: 'absolute', right: 10, bottom: 10, background: 'rgba(21,101,192,0.85)', color: '#fff', borderRadius: 100, padding: '4px 10px', fontSize: 11, fontWeight: 600 }}>Enhanced</span>
      {/* divider + handle */}
      <div style={{ position: 'absolute', top: 0, bottom: 0, left: `${pos}%`, width: 3, background: T.blue, transform: 'translateX(-1.5px)' }}>
        <div style={{
          position: 'absolute', top: '50%', left: '50%', transform: 'translate(-50%,-50%)',
          width: 44, height: 44, borderRadius: '50%', background: T.blue, border: '2px solid #fff',
          boxShadow: '0 2px 8px rgba(0,0,0,0.3)', display: 'flex', alignItems: 'center', justifyContent: 'center',
        }}>
          <Icon name="swap_horiz" size={24} color="#fff" />
        </div>
      </div>
    </div>
  );
}

function SegToggle({ value, online, onChange, onBlocked }) {
  if (!online) {
    return (
      <div style={{ display: 'inline-flex', alignItems: 'center', gap: 6, background: '#FFF8E1', borderRadius: 100, padding: '8px 14px', fontSize: 13, fontWeight: 600, color: '#E65100' }}>
        <Icon name="offline_bolt" size={16} color="#E65100" /> Offline — CLAHE only
      </div>
    );
  }
  const seg = (key, label, sparkle) => {
    const on = value === key;
    return (
      <button key={key} className="press" onClick={() => onChange(key)} style={{
        flex: 1, height: 38, borderRadius: 100, background: on ? T.blue : 'transparent',
        color: on ? '#fff' : T.text2, fontSize: 13.5, fontWeight: 600,
        display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 5,
      }}>{label}{sparkle && <span style={{ fontSize: 13 }}>✦</span>}</button>
    );
  };
  return (
    <div style={{ display: 'flex', gap: 4, padding: 4, background: '#EEF2F6', borderRadius: 100 }}>
      {seg('clahe', 'CLAHE Only')}
      {seg('best', 'Best Result', true)}
    </div>
  );
}

function EnhanceScreen() {
  const app = window.__cs;
  const { enhancePhase, online } = app.state;
  const [mode, setMode] = React.useState('best');
  const effMode = online ? mode : 'clahe';

  React.useEffect(() => { if (!online) setMode('clahe'); }, [online]);

  return (
    <React.Fragment>
      <BackBar title="Image Enhancement" trailing={<IconButton name="info" />} />
      <div className="cs-scroll" style={{ flex: 1, overflowY: 'auto', background: T.appBg, padding: '16px 16px 24px' }}>
        <SegToggle value={mode} online={online} onChange={setMode} />

        {enhancePhase === 'loading' ? (
          <React.Fragment>
            <div style={{ position: 'relative', height: 300, borderRadius: 16, overflow: 'hidden', marginTop: 16 }}>
              <XRay variant="orig" style={{ position: 'absolute', inset: 0 }} />
              <div style={{ position: 'absolute', inset: 0, background: 'rgba(0,0,0,0.55)', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 14 }}>
                <span className="msr" style={{ fontSize: 40, color: '#fff', animation: 'cs-spin 0.9s linear infinite' }}>progress_activity</span>
                <span style={{ fontSize: 15, color: '#fff', fontWeight: 500 }}>
                  <EnhanceMsg />
                </span>
              </div>
            </div>
            <div style={{ display: 'flex', gap: 12, marginTop: 16 }}>
              {[1, 2, 3].map(i => <div key={i} className="cs-shimmer" style={{ flex: 1, height: 74, borderRadius: 14 }} />)}
            </div>
          </React.Fragment>
        ) : (
          <React.Fragment>
            <div style={{ marginTop: 16 }}>
              <ComparisonSlider />
            </div>
            <Card style={{ marginTop: 16 }}>
              <div style={{ fontSize: 16, fontWeight: 600, color: T.text, marginBottom: 14 }}>Enhancement Metrics</div>
              <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                <EnhMetric name="SSIM" before="0.62" after="0.88" up />
                <EnhMetric name="PSNR (dB)" before="22.4" after="31.7" up />
                <EnhMetric name="BRISQUE" before="48.1" after="19.6" up={false} />
              </div>
            </Card>

            {effMode === 'best' && online && (
              <div style={{
                marginTop: 16, borderRadius: 12, padding: 16, display: 'flex', alignItems: 'center', gap: 12,
                background: 'linear-gradient(120deg, #1565C0, #0D47A1)',
              }}>
                <Icon name="emoji_events" size={28} color="#FFD54F" />
                <div style={{ flex: 1 }}>
                  <div style={{ fontSize: 14, fontWeight: 600, color: '#fff' }}>Best Method: CNN Enhanced</div>
                  <div style={{ fontSize: 12, color: 'rgba(255,255,255,0.7)', marginTop: 2 }}>Composite score: 0.847</div>
                </div>
                <span style={{ fontSize: 13, fontWeight: 600, color: '#fff' }}>Details →</span>
              </div>
            )}
          </React.Fragment>
        )}
      </div>

      {enhancePhase === 'done' && (
        <div style={{ flexShrink: 0, background: '#fff', borderTop: `1px solid ${T.border}`, padding: '12px 16px 26px', display: 'flex', alignItems: 'center', gap: 10 }}>
          <ActionIcon icon="save_alt" label="Save" onClick={() => app.toast('Image saved to gallery', 'success')} />
          <ActionIcon icon="picture_as_pdf" label="Report" onClick={() => app.dialogPdf()} />
          <PrimaryBtn style={{ height: 48, flex: 1, fontSize: 14 }} iconAfter="arrow_forward" onClick={() => app.go('results')}>View Full Results</PrimaryBtn>
        </div>
      )}
    </React.Fragment>
  );
}

function ActionIcon({ icon, label, onClick }) {
  return (
    <button className="press" onClick={onClick} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 2, width: 52 }}>
      <Icon name={icon} size={24} color={T.blue} />
      <span style={{ fontSize: 11, fontWeight: 600, color: T.blue }}>{label}</span>
    </button>
  );
}

function EnhMetric({ name, before, after, up }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 2, flex: 1 }}>
      <span style={{ fontSize: 11, color: T.text2 }}>{name}</span>
      <span style={{ fontSize: 13, color: T.text2, textDecoration: 'line-through' }}>{before}</span>
      <div style={{ display: 'flex', alignItems: 'center', gap: 3 }}>
        <Icon name={up ? 'arrow_upward' : 'arrow_downward'} size={14} color={T.good} />
        <span style={{ fontSize: 15, fontWeight: 600, color: T.blue }}>{after}</span>
      </div>
    </div>
  );
}

function EnhanceMsg() {
  const msgs = ['Applying CLAHE…', 'Reducing noise…', 'Sharpening edges…'];
  const [i, setI] = React.useState(0);
  React.useEffect(() => {
    const id = setInterval(() => setI(p => (p + 1) % msgs.length), 1000);
    return () => clearInterval(id);
  }, []);
  return <span key={i} style={{ animation: 'cs-fade-in 300ms ease' }}>{msgs[i]}</span>;
}

Object.assign(window, {
  ComparisonSlider, SegToggle, EnhanceScreen, ActionIcon, EnhMetric, EnhanceMsg,
});
