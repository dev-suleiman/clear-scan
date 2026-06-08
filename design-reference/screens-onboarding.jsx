/* ClearScan — interactive onboarding (prototype). Slide bodies w/o device wrapper. */

function OnbDots({ active, onDark }) {
  const activeColor = onDark ? '#fff' : T.blue;
  const inactiveColor = onDark ? 'rgba(255,255,255,0.45)' : '#CBD5E1';
  return (
    <div style={{ display: 'flex', gap: 6, justifyContent: 'center' }}>
      {[0, 1, 2].map(i => (
        <div key={i} style={{ width: i === active ? 24 : 8, height: 8, borderRadius: 100, background: i === active ? activeColor : inactiveColor, transition: 'width 250ms cubic-bezier(.3,1,.5,1)' }} />
      ))}
    </div>
  );
}

function OnbScanLines() {
  return (
    <React.Fragment>
      {[28, 50, 72].map((t, i) => (
        <div key={i} style={{ position: 'absolute', left: '8%', right: '8%', top: `${t}%`, height: 2, background: 'rgba(255,255,255,0.55)', boxShadow: '0 0 8px rgba(255,255,255,0.5)' }} />
      ))}
    </React.Fragment>
  );
}

function OnbNav({ onSkip, onNext }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '0 24px 46px' }}>
      <button className="press" onClick={onSkip} style={{ fontSize: 14, fontWeight: 600, color: T.text2, padding: '8px 4px' }}>Skip</button>
      <button className="press" onClick={onNext} style={{ display: 'flex', alignItems: 'center', gap: 6, background: T.blue, color: '#fff', borderRadius: 100, padding: '12px 22px', fontSize: 15, fontWeight: 600, boxShadow: T.shadowBtn }}>
        Next <Icon name="arrow_forward" size={18} color="#fff" />
      </button>
    </div>
  );
}

function OnbBody1({ onSkip, onNext }) {
  return (
    <div style={{ position: 'relative', height: '100%', display: 'flex', flexDirection: 'column', background: '#F8FAFB' }}>
      <div style={{ position: 'absolute', top: 0, left: 0, right: 0, height: '60%', background: 'linear-gradient(180deg, #1565C0 0%, #2D7DD2 55%, #F8FAFB 100%)' }} />
      <div style={{ position: 'relative', paddingTop: STATUS_INSET + 16, display: 'flex', justifyContent: 'center' }}><OnbDots active={0} onDark /></div>
      <div style={{ position: 'relative', height: 320, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <div style={{ position: 'relative', width: 210, height: 250, background: '#fff', borderRadius: 16, padding: 8, boxShadow: '0 18px 40px rgba(0,0,0,0.28)' }}>
          <XRay variant="good" style={{ width: '100%', height: '100%', borderRadius: 10 }}>
            <OnbScanLines />
            <span style={{ position: 'absolute', top: 8, right: 8, background: T.good, color: '#fff', fontSize: 10, fontWeight: 700, borderRadius: 8, padding: '3px 7px' }}>GOOD</span>
          </XRay>
        </div>
      </div>
      <div style={{ position: 'relative', flex: 1, padding: '8px 28px 0', textAlign: 'center' }}>
        <div style={{ fontSize: 22, fontWeight: 600, color: T.text }}>Know Before You Read</div>
        <div style={{ fontSize: 15, color: T.text2, lineHeight: 1.55, marginTop: 10 }}>ClearScan instantly analyses your chest X-ray images for sharpness, contrast, noise, and exposure — so you never miss a quality issue.</div>
      </div>
      <div style={{ position: 'relative' }}><OnbNav onSkip={onSkip} onNext={onNext} /></div>
    </div>
  );
}

function OnbBody2({ onSkip, onNext }) {
  const phone = (icon, color, label, dotColor, variant) => (
    <div style={{ width: 116, border: `2px solid ${T.border}`, borderRadius: 18, padding: 10, background: '#fff', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 8 }}>
      <XRay variant={variant} style={{ width: '100%', height: 90, borderRadius: 8 }} />
      <div style={{ display: 'flex', alignItems: 'center', gap: 5 }}>
        <Icon name={icon} size={18} color={color} />
        <span style={{ width: 7, height: 7, borderRadius: 4, background: dotColor }} />
      </div>
      <span style={{ fontSize: 10.5, fontWeight: 600, color: T.text2, textAlign: 'center', lineHeight: 1.3 }}>{label}</span>
    </div>
  );
  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', background: '#fff' }}>
      <div style={{ paddingTop: STATUS_INSET + 16, display: 'flex', justifyContent: 'center' }}><OnbDots active={1} /></div>
      <div style={{ height: 320, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 12 }}>
        {phone('wifi', T.good, 'Online — CNN Mode', T.good, 'good')}
        <Icon name="sync_alt" size={22} color={T.text2} />
        {phone('wifi_off', T.fair, 'Offline — CLAHE Mode', T.fair, 'enhanced')}
      </div>
      <div style={{ flex: 1, padding: '8px 28px 0', textAlign: 'center' }}>
        <div style={{ fontSize: 22, fontWeight: 600, color: T.text }}>Works Anywhere</div>
        <div style={{ fontSize: 15, color: T.text2, lineHeight: 1.55, marginTop: 10 }}>Full AI-powered CNN analysis when connected. Automatic CLAHE enhancement and on-device quality assessment when offline. No internet? No problem.</div>
      </div>
      <OnbNav onSkip={onSkip} onNext={onNext} />
    </div>
  );
}

function OnbBody3({ onStart }) {
  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', background: '#fff' }}>
      <div style={{ paddingTop: STATUS_INSET + 16, display: 'flex', justifyContent: 'center' }}><OnbDots active={2} /></div>
      <div style={{ height: 300, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <div style={{ position: 'relative', width: 230, height: 230, borderRadius: 16, overflow: 'hidden' }}>
          <XRay variant="enhanced" style={{ position: 'absolute', inset: 0 }} />
          <div style={{ position: 'absolute', top: 0, left: 0, bottom: 0, width: '50%', overflow: 'hidden' }}>
            <XRay variant="poor" style={{ position: 'absolute', top: 0, left: 0, height: '100%', width: 230 }} />
          </div>
          <span style={{ position: 'absolute', top: 10, left: 10, background: T.poor, color: '#fff', fontSize: 10, fontWeight: 700, borderRadius: 7, padding: '3px 7px' }}>POOR</span>
          <span style={{ position: 'absolute', top: 10, right: 10, background: T.good, color: '#fff', fontSize: 10, fontWeight: 700, borderRadius: 7, padding: '3px 7px' }}>GOOD</span>
          <div style={{ position: 'absolute', top: 0, bottom: 0, left: '50%', width: 3, background: '#fff', transform: 'translateX(-1.5px)' }}>
            <div style={{ position: 'absolute', top: '50%', left: '50%', transform: 'translate(-50%,-50%)', width: 34, height: 34, borderRadius: '50%', background: '#fff', boxShadow: '0 2px 8px rgba(0,0,0,0.3)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <Icon name="swap_horiz" size={18} color={T.blue} />
            </div>
          </div>
        </div>
      </div>
      <div style={{ display: 'flex', gap: 8, justifyContent: 'center', marginTop: 4 }}>
        <MetaChip icon="picture_as_pdf">PDF Report</MetaChip>
        <MetaChip icon="image">Save to Gallery</MetaChip>
      </div>
      <div style={{ flex: 1, padding: '14px 28px 0', textAlign: 'center' }}>
        <div style={{ fontSize: 22, fontWeight: 600, color: T.text }}>Enhance &amp; Report</div>
        <div style={{ fontSize: 15, color: T.text2, lineHeight: 1.55, marginTop: 10 }}>Improve degraded images with our hybrid pipeline, compare enhancement methods, and export professional PDF reports for clinical records.</div>
      </div>
      <div style={{ padding: '0 24px 46px' }}>
        <PrimaryBtn onClick={onStart}>Get Started</PrimaryBtn>
      </div>
    </div>
  );
}

// ── PageView with parallax track ────────────────────────────
function Onboarding() {
  const app = window.__cs;
  const page = app.state.onbPage || 0;
  const W = 390;
  const next = () => app.onbGo(Math.min(2, page + 1));
  const skip = () => app.finishOnboarding();
  return (
    <div style={{ position: 'absolute', inset: 0, zIndex: 50, overflow: 'hidden', background: '#fff' }}>
      <div style={{ display: 'flex', width: W * 3, height: '100%', transform: `translateX(${-page * W}px)`, transition: 'transform 360ms cubic-bezier(.4,0,.2,1)' }}>
        <div style={{ width: W, height: '100%', flexShrink: 0 }}><OnbBody1 onSkip={skip} onNext={next} /></div>
        <div style={{ width: W, height: '100%', flexShrink: 0 }}><OnbBody2 onSkip={skip} onNext={next} /></div>
        <div style={{ width: W, height: '100%', flexShrink: 0 }}><OnbBody3 onStart={skip} /></div>
      </div>
    </div>
  );
}

Object.assign(window, { OnbDots, OnbScanLines, OnbNav, OnbBody1, OnbBody2, OnbBody3, Onboarding });
