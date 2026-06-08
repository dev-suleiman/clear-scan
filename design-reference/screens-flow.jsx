/* ClearScan — scan flow: source sheet, preview, assessment, enhancement */

// metric sets
function metricsFor(q) {
  if (q === 'poor') return [
    { icon: 'blur_on', name: 'Sharpness', value: '0.15', pct: 15, warn: true },
    { icon: 'contrast', name: 'Contrast', value: '0.21', pct: 20, warn: true },
    { icon: 'data_usage', name: 'Entropy', value: '4.1', pct: 42 },
    { icon: 'tune', name: 'Histogram Spread', value: '0.30', pct: 30, warn: true },
    { icon: 'grain', name: 'Noise Level', value: 'High', pct: 78, warn: true },
  ];
  if (q === 'fair') return [
    { icon: 'blur_on', name: 'Sharpness', value: '0.62', pct: 60 },
    { icon: 'contrast', name: 'Contrast', value: '0.41', pct: 38, warn: true },
    { icon: 'data_usage', name: 'Entropy', value: '5.6', pct: 58 },
    { icon: 'tune', name: 'Histogram Spread', value: '0.55', pct: 55 },
    { icon: 'grain', name: 'Noise Level', value: 'Moderate', pct: 52, warn: true },
  ];
  return [
    { icon: 'blur_on', name: 'Sharpness', value: '0.81', pct: 80 },
    { icon: 'contrast', name: 'Contrast', value: '0.74', pct: 75 },
    { icon: 'data_usage', name: 'Entropy', value: '6.8', pct: 70 },
    { icon: 'tune', name: 'Histogram Spread', value: '0.68', pct: 68 },
    { icon: 'grain', name: 'Noise Level', value: 'Low', pct: 22 },
  ];
}

// ── Bottom sheet shell ──────────────────────────────────────
function Sheet({ children, onClose }) {
  const on = useEntered();
  return (
    <div onClick={onClose} style={{
      position: 'absolute', inset: 0, zIndex: 70, display: 'flex', flexDirection: 'column',
      justifyContent: 'flex-end', background: `rgba(0,0,0,${on ? 0.4 : 0})`, transition: 'background 250ms ease',
    }}>
      <div onClick={e => e.stopPropagation()} style={{
        background: '#fff', borderRadius: '24px 24px 0 0', boxShadow: '0 -4px 24px rgba(0,0,0,0.10)',
        padding: '8px 20px 30px', transform: on ? 'translateY(0)' : 'translateY(100%)',
        transition: 'transform 400ms cubic-bezier(.2,.9,.3,1)',
      }}>
        <div style={{ width: 32, height: 4, borderRadius: 100, background: T.border, margin: '0 auto 8px' }} />
        {children}
      </div>
    </div>
  );
}

function OptionTile({ icon, iconColor, title, sub, onClick }) {
  return (
    <div className="press" onClick={onClick} style={{
      display: 'flex', alignItems: 'center', gap: 14, padding: 16,
      border: `2px solid ${T.border}`, borderRadius: 16, background: '#fff',
    }}>
      <div style={{ width: 52, height: 52, borderRadius: 14, background: T.surfaceBlue, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
        <Icon name={icon} size={30} color={iconColor || T.blue} />
      </div>
      <div style={{ flex: 1 }}>
        <div style={{ fontSize: 16, fontWeight: 600, color: T.text }}>{title}</div>
        <div style={{ fontSize: 13, color: T.text2, marginTop: 2, lineHeight: 1.4 }}>{sub}</div>
      </div>
      <Icon name="chevron_right" size={22} color={T.text2} fill={0} />
    </div>
  );
}

function SourceSheet() {
  const app = window.__cs;
  return (
    <Sheet onClose={() => app.closeSheet()}>
      <div style={{ fontSize: 18, fontWeight: 600, color: T.text, textAlign: 'center', padding: '14px 0 18px' }}>Choose Image Source</div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
        <OptionTile icon="photo_library" title="Upload from Gallery" sub="Choose an existing X-ray image" onClick={() => app.pickSource('gallery')} />
        <OptionTile icon="camera_alt" title="Capture with Camera" sub="Take a photo of the X-ray on the lightbox" onClick={() => app.pickSource('camera')} />
      </div>
      <TextBtn style={{ width: '100%', marginTop: 16, textAlign: 'center' }} onClick={() => app.closeSheet()}>Cancel</TextBtn>
    </Sheet>
  );
}

// ── Preview & confirm (Screen 5) ────────────────────────────
function PreviewScreen() {
  const app = window.__cs;
  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', background: '#0A0A0A' }}>
      <div style={{ flexShrink: 0, paddingTop: STATUS_INSET, background: '#0A0A0A' }}>
        <div style={{ height: 52, display: 'flex', alignItems: 'center', padding: '0 12px' }}>
          <IconButton name="arrow_back" color="#fff" onClick={() => app.back()} />
          <div style={{ flex: 1, textAlign: 'center', fontSize: 18, fontWeight: 600, color: '#fff' }}>Preview Image</div>
          <IconButton name="crop_rotate" color="rgba(255,255,255,0.35)" />
        </div>
      </div>
      <div style={{ flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center', overflow: 'hidden' }}>
        <XRay variant={app.state.quality === 'poor' ? 'poor' : 'orig'} style={{ width: '100%', height: '92%' }} />
      </div>
      <div style={{ background: '#fff', borderRadius: '24px 24px 0 0', padding: '18px 20px 30px', flexShrink: 0 }}>
        <div style={{ fontSize: 16, fontWeight: 600, color: T.text, marginBottom: 12 }}>X-Ray Image</div>
        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', marginBottom: 18 }}>
          <MetaChip icon="local_hospital">Chest X-Ray</MetaChip>
          <MetaChip icon="calendar_today" tone="grey">Jun 7, 2026</MetaChip>
          <MetaChip icon="photo_size_select_large" tone="grey">2048 × 1680</MetaChip>
        </div>
        <PrimaryBtn iconAfter="arrow_forward" onClick={() => app.startAssess()}>Analyse This Image</PrimaryBtn>
        <TextBtn style={{ width: '100%', textAlign: 'center', marginTop: 6 }} onClick={() => app.back()}>Retake / Reselect</TextBtn>
      </div>
    </div>
  );
}

// ── Mode chip overlay ───────────────────────────────────────
function ModeChip({ online }) {
  return (
    <div style={{
      position: 'absolute', top: 10, right: 10, display: 'inline-flex', alignItems: 'center', gap: 5,
      background: online ? 'rgba(255,255,255,0.95)' : '#FFF8E1', border: `1px solid ${online ? T.blue : T.fair}`,
      borderRadius: 100, padding: '5px 10px', fontSize: 12, fontWeight: 600, color: online ? T.blue : T.fair,
    }}>
      <Icon name={online ? 'cloud' : 'offline_bolt'} size={14} color={online ? T.blue : T.fair} />
      {online ? 'CNN Mode' : 'Offline Mode'}
    </div>
  );
}

function ImagePanel({ q, online }) {
  return (
    <div style={{ padding: '14px 20px 0', flexShrink: 0 }}>
      <div style={{ position: 'relative', borderRadius: 16, overflow: 'hidden', border: `2px solid rgba(21,101,192,0.4)`, height: 188 }}>
        <XRay variant={q === 'poor' ? 'poor' : 'good'} style={{ width: '100%', height: '100%' }} />
        <ModeChip online={online} />
      </div>
    </div>
  );
}

// ── Assessment screen (loading + results) ───────────────────
function AssessScreen() {
  const app = window.__cs;
  const { assessPhase, quality, online } = app.state;
  return (
    <React.Fragment>
      <BackBar title="Quality Assessment" />
      <div className="cs-scroll" style={{ flex: 1, overflowY: 'auto', background: T.appBg, display: 'flex', flexDirection: 'column' }}>
        <ImagePanel q={quality} online={online} />
        {assessPhase === 'loading'
          ? <AssessLoading />
          : <AssessResults quality={quality} />}
      </div>
      {assessPhase === 'done' && (
        <div style={{ flexShrink: 0, background: '#fff', borderTop: `1px solid ${T.border}`, padding: '12px 20px 26px', display: 'flex', gap: 12 }}>
          <OutlineBtn style={{ height: 48, flex: '0 0 34%', fontSize: 15 }} onClick={() => app.go('home')}>New Scan</OutlineBtn>
          <PrimaryBtn style={{ height: 48, flex: 1, fontSize: 15 }} glow={quality === 'poor'} iconAfter="arrow_forward" onClick={() => app.startEnhance()}>Enhance Image</PrimaryBtn>
        </div>
      )}
    </React.Fragment>
  );
}

function AssessLoading() {
  const cards = [100, 80, 140];
  return (
    <div style={{ padding: '18px 20px 24px' }}>
      <div style={{ textAlign: 'center', fontSize: 14, color: T.text2, marginBottom: 18 }}>
        Analysing image quality<span className="cs-dots" />
      </div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
        {cards.map((h, i) => <div key={i} className="cs-shimmer" style={{ height: h, borderRadius: 16 }} />)}
        <div style={{ display: 'flex', gap: 12, marginTop: 4 }}>
          <div className="cs-shimmer" style={{ height: 48, flex: '0 0 34%', borderRadius: 100 }} />
          <div className="cs-shimmer" style={{ height: 48, flex: 1, borderRadius: 100 }} />
        </div>
      </div>
    </div>
  );
}

function AssessResults({ quality }) {
  const metrics = metricsFor(quality);
  return (
    <div style={{ padding: '18px 20px 24px', display: 'flex', flexDirection: 'column', gap: 16 }}>
      <PopIn>
        <QualityBadge q={quality} confidence={quality === 'poor' ? 78 : quality === 'fair' ? 85 : 94} />
      </PopIn>

      {/* defects */}
      <Card>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 12 }}>
          <Icon name="info" size={22} color={T.blue} />
          <span style={{ fontSize: 16, fontWeight: 600, color: T.text }}>Defects Detected</span>
        </div>
        {quality === 'poor' ? <PoorDefects /> : quality === 'fair' ? <FairDefects /> : (
          <div style={{ display: 'flex', gap: 10, alignItems: 'flex-start' }}>
            <Icon name="check_circle" size={22} color={T.good} />
            <span style={{ fontSize: 15, color: T.text, lineHeight: 1.5 }}>No defects detected — image meets diagnostic quality standards.</span>
          </div>
        )}
      </Card>

      {/* metrics */}
      <Card>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 6 }}>
          <Icon name="analytics" size={22} color={T.blue} />
          <span style={{ fontSize: 16, fontWeight: 600, color: T.text }}>Image Quality Metrics</span>
        </div>
        {metrics.map((m, i) => <MetricRow key={m.name} {...m} animateKey={quality} />)}
      </Card>
    </div>
  );
}

function PopIn({ children }) {
  const on = useEntered();
  return (
    <div style={{ transform: on ? 'scale(1)' : 'scale(0.7)', transformOrigin: 'center', transition: 'transform 520ms cubic-bezier(.34,1.56,.64,1)' }}>
      {children}
    </div>
  );
}

function FairDefects() {
  return (
    <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
      <span style={{
        display: 'inline-flex', alignItems: 'center', gap: 6, height: 36, padding: '0 14px',
        background: '#FFF3E0', border: '1px solid #E65100', borderRadius: 20,
        fontSize: 12, fontWeight: 600, color: '#E65100',
      }}>
        <Icon name="contrast" size={16} color="#E65100" /> Low Contrast
      </span>
    </div>
  );
}

function PoorDefects() {
  const defects = [
    { icon: 'blur_on', label: 'Motion Blur' },
    { icon: 'brightness_low', label: 'Underexposure' },
    { icon: 'grain', label: 'Excessive Noise' },
  ];
  return (
    <React.Fragment>
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
        {defects.map(d => (
          <span key={d.label} style={{
            display: 'inline-flex', alignItems: 'center', gap: 6, height: 36, padding: '0 14px',
            background: '#FFF3E0', border: '1px solid #E65100', borderRadius: 20,
            fontSize: 12, fontWeight: 600, color: '#E65100',
          }}>
            <Icon name={d.icon} size={16} color="#E65100" /> {d.label}
          </span>
        ))}
      </div>
      <div style={{
        display: 'flex', gap: 10, alignItems: 'flex-start', marginTop: 14, padding: '12px 14px',
        background: '#FFF8E1', borderLeft: '3px solid #F57F17', borderRadius: 8,
      }}>
        <Icon name="info" size={20} color="#E65100" />
        <span style={{ fontSize: 13.5, color: '#E65100', lineHeight: 1.45 }}>This image may not meet diagnostic standards. Enhancement recommended.</span>
      </div>
    </React.Fragment>
  );
}

Object.assign(window, {
  metricsFor, Sheet, OptionTile, SourceSheet, PreviewScreen, ModeChip, ImagePanel,
  AssessScreen, AssessLoading, AssessResults, PoorDefects, FairDefects, PopIn,
});
