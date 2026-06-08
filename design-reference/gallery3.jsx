/* ClearScan — gallery part 3: fair assessment, loading states, offline banner, spotlights 1 & 3 */

// ── Fair assessment results (standalone) ────────────────────
function FairAssessScreen() {
  const metrics = metricsFor('fair');
  return (
    <PhoneCard bg={T.appBg}>
      <GBar title="Quality Assessment" />
      <div className="cs-scroll" style={{ flex: 1, overflowY: 'auto', display: 'flex', flexDirection: 'column' }}>
        {/* image panel */}
        <div style={{ padding: '14px 20px 0', flexShrink: 0 }}>
          <div style={{ position: 'relative', borderRadius: 16, overflow: 'hidden', border: '2px solid rgba(21,101,192,0.4)', height: 172 }}>
            <XRay variant="fair" style={{ width: '100%', height: '100%' }} />
            <div style={{ position: 'absolute', top: 10, right: 10, display: 'inline-flex', alignItems: 'center', gap: 5, background: 'rgba(255,255,255,0.95)', border: `1px solid ${T.blue}`, borderRadius: 100, padding: '5px 10px', fontSize: 12, fontWeight: 600, color: T.blue }}>
              <Icon name="cloud" size={14} color={T.blue} /> CNN Mode
            </div>
          </div>
        </div>
        <div style={{ padding: '18px 20px 24px', display: 'flex', flexDirection: 'column', gap: 16 }}>
          <QualityBadge q="fair" confidence={85} />
          <Card>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 12 }}>
              <Icon name="info" size={22} color={T.blue} />
              <span style={{ fontSize: 16, fontWeight: 600, color: T.text }}>Defects Detected</span>
            </div>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
              <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6, height: 36, padding: '0 14px', background: '#FFF3E0', border: '1px solid #E65100', borderRadius: 20, fontSize: 12, fontWeight: 600, color: '#E65100' }}>
                <Icon name="contrast" size={16} color="#E65100" /> Low Contrast
              </span>
            </div>
          </Card>
          <Card>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 6 }}>
              <Icon name="analytics" size={22} color={T.blue} />
              <span style={{ fontSize: 16, fontWeight: 600, color: T.text }}>Image Quality Metrics</span>
            </div>
            {metrics.map(m => <MetricRow key={m.name} {...m} />)}
          </Card>
        </div>
      </div>
      <div style={{ flexShrink: 0, background: '#fff', borderTop: `1px solid ${T.border}`, padding: '12px 20px 26px', display: 'flex', gap: 12 }}>
        <OutlineBtn style={{ height: 48, flex: '0 0 34%', fontSize: 15 }}>New Scan</OutlineBtn>
        <PrimaryBtn style={{ height: 48, flex: 1, fontSize: 15 }} iconAfter="arrow_forward">Enhance Image</PrimaryBtn>
      </div>
    </PhoneCard>
  );
}

// ── App loading (logo + pulsing scan) ───────────────────────
function AppLoadingScreen() {
  return (
    <PhoneCard bg="#fff">
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 22 }}>
        <div style={{ position: 'relative', width: 72, height: 72, borderRadius: 20, overflow: 'hidden' }}>
          <Logo size={72} radius={20} />
          <div style={{ position: 'absolute', left: 0, right: 0, height: 16, top: '42%', background: 'linear-gradient(180deg, transparent, rgba(255,255,255,0.55), transparent)', animation: 'cs-scanline 1.6s ease-in-out infinite' }} />
        </div>
        <div style={{ fontSize: 15, color: T.text2, animation: 'cs-logo-scan 1s ease-in-out infinite' }}>Loading ClearScan…</div>
      </div>
    </PhoneCard>
  );
}

// ── Assessment skeleton (standalone) ────────────────────────
function AssessSkeletonScreen() {
  return (
    <PhoneCard bg={T.appBg}>
      <GBar title="Quality Assessment" />
      <div style={{ padding: '14px 20px 0' }}>
        <div className="cs-shimmer" style={{ height: 172, borderRadius: 16 }} />
      </div>
      <AssessLoading />
    </PhoneCard>
  );
}

// ── Enhancement processing (standalone) ─────────────────────
function EnhanceProcessingScreen() {
  return (
    <PhoneCard bg={T.appBg}>
      <GBar title="Image Enhancement" trailing={<Icon name="info" size={22} color={T.text2} fill={0} />} />
      <div style={{ padding: '16px 16px 24px' }}>
        <div style={{ display: 'flex', gap: 4, padding: 4, background: '#EEF2F6', borderRadius: 100 }}>
          <div style={{ flex: 1, height: 38, borderRadius: 100, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 13.5, fontWeight: 600, color: T.text2 }}>CLAHE Only</div>
          <div style={{ flex: 1, height: 38, borderRadius: 100, background: T.blue, color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 5, fontSize: 13.5, fontWeight: 600 }}>Best Result ✦</div>
        </div>
        <div style={{ position: 'relative', height: 300, borderRadius: 16, overflow: 'hidden', marginTop: 16 }}>
          <XRay variant="orig" style={{ position: 'absolute', inset: 0 }} />
          <div style={{ position: 'absolute', inset: 0, background: 'rgba(0,0,0,0.55)', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 14 }}>
            <span className="msr" style={{ fontSize: 40, color: '#fff', animation: 'cs-spin 0.9s linear infinite' }}>progress_activity</span>
            <span style={{ fontSize: 15, color: '#fff', fontWeight: 500 }}>Enhancing image…</span>
          </div>
        </div>
        <div style={{ display: 'flex', gap: 12, marginTop: 16 }}>
          {[1, 2, 3].map(i => <div key={i} className="cs-shimmer" style={{ flex: 1, height: 74, borderRadius: 14 }} />)}
        </div>
      </div>
    </PhoneCard>
  );
}

// ── Offline banner in context (Home top) ────────────────────
function OfflineBannerScreen() {
  return (
    <PhoneCard bg={T.appBg}>
      <AppBar
        leading={<Logo size={34} radius={10} />}
        title="ClearScan"
        trailing={<React.Fragment>
          <IconButton name="notifications" />
          <div style={{ width: 28, display: 'flex', justifyContent: 'center', paddingRight: 6 }}><ConnectivityBadge online={false} /></div>
        </React.Fragment>}
      />
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, background: '#FFF8E1', padding: '8px 20px' }}>
        <Icon name="wifi_off" size={16} color="#E65100" />
        <span style={{ fontSize: 13, color: '#E65100', fontWeight: 500 }}>Offline — CNN features unavailable. CLAHE mode active.</span>
      </div>
      {/* greeting card for context */}
      <div style={{ height: 80, display: 'flex', alignItems: 'center', gap: 14, padding: '0 20px', background: 'linear-gradient(90deg, #E3F2FD 0%, #FFFFFF 78%)', borderBottom: `1px solid ${T.border}` }}>
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
          <QuickAction icon="upload_file" title="Upload X-Ray" sub="Choose from gallery" cta="Select" />
          <QuickAction icon="camera_alt" title="Capture X-Ray" sub="Use your camera" cta="Open" />
        </div>
      </div>
    </PhoneCard>
  );
}

// ── Spotlight 1 — connectivity badge ────────────────────────
function SpotlightConnectivity() {
  return (
    <PhoneCard bg={T.appBg}>
      <AppBar
        leading={<Logo size={34} radius={10} />}
        title="ClearScan"
        trailing={<React.Fragment>
          <IconButton name="notifications" />
          <div style={{ width: 28, display: 'flex', justifyContent: 'center', paddingRight: 6 }}><ConnectivityBadge online={true} /></div>
        </React.Fragment>}
      />
      <div style={{ height: 80, display: 'flex', alignItems: 'center', gap: 14, padding: '0 20px', background: 'linear-gradient(90deg, #E3F2FD 0%, #FFFFFF 78%)' }}>
        <Icon name="medical_services" size={32} color={T.blue} />
        <div style={{ flex: 1 }}>
          <div style={{ fontSize: 14, fontWeight: 600, color: T.blue }}>Good morning, Doctor</div>
          <div style={{ fontSize: 14, color: T.text2, marginTop: 1 }}>Ready to assess an X-ray?</div>
        </div>
      </div>
      {/* dim overlay with cutout near top-right badge (~ x356 y86) */}
      <div style={{ position: 'absolute', inset: 0, background: 'rgba(0,0,0,0.72)', WebkitMaskImage: 'radial-gradient(circle 34px at 358px 86px, transparent 0 24px, #000 34px)', maskImage: 'radial-gradient(circle 34px at 358px 86px, transparent 0 24px, #000 34px)' }} />
      <div style={{ position: 'absolute', top: 86, left: 358, transform: 'translate(-50%,-50%)', width: 28, height: 28, borderRadius: '50%', border: '3px solid #fff', boxShadow: '0 0 0 4px rgba(21,101,192,0.5)' }} />
      <div style={{ position: 'absolute', top: 130, left: 40, right: 40, background: '#fff', borderRadius: 16, padding: 18, boxShadow: '0 12px 40px rgba(0,0,0,0.35)' }}>
        <div style={{ fontSize: 16, fontWeight: 600, color: T.text }}>Online / Offline Mode</div>
        <div style={{ fontSize: 14, color: T.text2, lineHeight: 1.5, marginTop: 6 }}>This indicator shows your current mode. Green means CNN AI is active. Amber means offline CLAHE mode.</div>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginTop: 16 }}>
          <span style={{ fontSize: 12, color: T.text2 }}>1 of 3</span>
          <button style={{ background: T.blue, color: '#fff', borderRadius: 100, padding: '10px 22px', fontSize: 14, fontWeight: 600 }}>Got it</button>
        </div>
      </div>
    </PhoneCard>
  );
}

// ── Spotlight 3 — Best Result segment ───────────────────────
function SpotlightBestResult() {
  return (
    <PhoneCard bg={T.appBg}>
      <GBar title="Image Enhancement" trailing={<Icon name="info" size={22} color={T.text2} fill={0} />} />
      <div style={{ padding: '16px 16px 0' }}>
        <div style={{ display: 'flex', gap: 4, padding: 4, background: '#EEF2F6', borderRadius: 100 }}>
          <div style={{ flex: 1, height: 38, borderRadius: 100, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 13.5, fontWeight: 600, color: T.text2 }}>CLAHE Only</div>
          <div style={{ flex: 1, height: 38, borderRadius: 100, background: T.blue, color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 5, fontSize: 13.5, fontWeight: 600 }}>Best Result ✦</div>
        </div>
        <div style={{ marginTop: 16, height: 300, borderRadius: 16, overflow: 'hidden' }}><XRay variant="enhanced" style={{ width: '100%', height: '100%' }} /></div>
      </div>
      {/* dim overlay with cutout around the Best Result segment (right half, ~ x290 y95) */}
      <div style={{ position: 'absolute', inset: 0, background: 'rgba(0,0,0,0.72)', WebkitMaskImage: 'radial-gradient(ellipse 100px 30px at 282px 95px, transparent 0 70%, #000 100%)', maskImage: 'radial-gradient(ellipse 100px 30px at 282px 95px, transparent 0 70%, #000 100%)' }} />
      <div style={{ position: 'absolute', top: 95, left: 282, transform: 'translate(-50%,-50%)', width: 168, height: 46, borderRadius: 100, border: '3px solid #fff', boxShadow: '0 0 0 4px rgba(21,101,192,0.5)' }} />
      <div style={{ position: 'absolute', top: 150, left: 40, right: 40, background: '#fff', borderRadius: 16, padding: 18, boxShadow: '0 12px 40px rgba(0,0,0,0.35)' }}>
        <div style={{ fontSize: 16, fontWeight: 600, color: T.text }}>AI-Powered Enhancement</div>
        <div style={{ fontSize: 14, color: T.text2, lineHeight: 1.5, marginTop: 6 }}>Best Result uses our CNN model to find the optimal enhancement — only available online.</div>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginTop: 16 }}>
          <span style={{ fontSize: 12, color: T.text2 }}>3 of 3</span>
          <button style={{ background: T.blue, color: '#fff', borderRadius: 100, padding: '10px 22px', fontSize: 14, fontWeight: 600 }}>Done</button>
        </div>
      </div>
    </PhoneCard>
  );
}

Object.assign(window, {
  FairAssessScreen, AppLoadingScreen, AssessSkeletonScreen, EnhanceProcessingScreen,
  OfflineBannerScreen, SpotlightConnectivity, SpotlightBestResult,
});
