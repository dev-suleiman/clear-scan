/* ClearScan — gallery part 2: notifications, spotlight, image viewer + canvas assembly */

// ── Notification component cards ────────────────────────────
function SnackBar({ icon, color, msg, action }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 10, background: '#fff', borderRadius: 12, boxShadow: '0 4px 16px rgba(0,0,0,0.12)', padding: '14px 16px' }}>
      <Icon name={icon} size={20} color={color} />
      <span style={{ flex: 1, fontSize: 14, color: T.text }}>{msg}</span>
      {action && <span style={{ fontSize: 13, fontWeight: 600, color: T.blue }}>{action}</span>}
    </div>
  );
}

function ToastPill({ icon, msg }) {
  return (
    <div style={{ display: 'inline-flex', alignItems: 'center', gap: 8, background: '#fff', borderRadius: 100, boxShadow: '0 4px 16px rgba(0,0,0,0.14)', padding: '12px 18px', margin: '0 auto' }}>
      <Icon name={icon} size={20} color={T.blue} />
      <span style={{ fontSize: 14, color: T.text }}>{msg}</span>
    </div>
  );
}

function Banner({ tone, icon, msg }) {
  const tones = {
    warn: { bg: '#FFF8E1', br: '#F57F17', fg: '#E65100' },
    info: { bg: '#E3F2FD', br: T.blue, fg: T.blue },
  };
  const c = tones[tone];
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 10, background: c.bg, borderLeft: `4px solid ${c.br}`, borderRadius: 8, padding: '12px 14px' }}>
      <Icon name={icon} size={20} color={c.fg} />
      <span style={{ fontSize: 13.5, color: c.fg, lineHeight: 1.4 }}>{msg}</span>
    </div>
  );
}

function NotifCard({ children }) {
  return <div style={{ background: T.appBg, borderRadius: 20, padding: 22, height: '100%', display: 'flex', flexDirection: 'column', justifyContent: 'center', gap: 14 }}>{children}</div>;
}

// ── Feature spotlight (Screen 21) ───────────────────────────
function SpotlightScreen() {
  return (
    <PhoneCard bg="#0A0A0A">
      {/* dimmed enhancement-ish backdrop */}
      <GBar title="Image Enhancement" dark />
      <div style={{ position: 'relative', margin: '16px 16px 0', height: 300, borderRadius: 16, overflow: 'hidden' }}>
        <XRay variant="enhanced" style={{ position: 'absolute', inset: 0 }} />
        <div style={{ position: 'absolute', top: 0, left: 0, bottom: 0, width: '50%', overflow: 'hidden' }}>
          <XRay variant="orig" style={{ position: 'absolute', top: 0, left: 0, height: '100%', width: 358 }} />
        </div>
        <div style={{ position: 'absolute', top: 0, bottom: 0, left: '50%', width: 3, background: T.blue, transform: 'translateX(-1.5px)' }} />
      </div>
      {/* dark overlay with a transparent ring cutout over the handle */}
      <div style={{ position: 'absolute', inset: 0, background: 'rgba(0,0,0,0.72)', WebkitMaskImage: 'radial-gradient(circle 52px at 50% 290px, transparent 0 44px, #000 52px)', maskImage: 'radial-gradient(circle 52px at 50% 290px, transparent 0 44px, #000 52px)' }} />
      {/* highlighted handle */}
      <div style={{ position: 'absolute', top: 290, left: '50%', transform: 'translate(-50%,-50%)', width: 44, height: 44, borderRadius: '50%', background: T.blue, border: '3px solid #fff', display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: '0 0 0 4px rgba(21,101,192,0.5)' }}>
        <Icon name="swap_horiz" size={24} color="#fff" />
      </div>
      {/* tooltip */}
      <div style={{ position: 'absolute', top: 360, left: 40, right: 40, background: '#fff', borderRadius: 16, padding: 18, boxShadow: '0 12px 40px rgba(0,0,0,0.35)' }}>
        <div style={{ fontSize: 16, fontWeight: 600, color: T.text }}>Drag to Compare</div>
        <div style={{ fontSize: 14, color: T.text2, lineHeight: 1.5, marginTop: 6 }}>Drag this handle left or right to compare the original and enhanced X-ray images side by side.</div>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginTop: 16 }}>
          <span style={{ fontSize: 12, color: T.text2 }}>2 of 3</span>
          <button style={{ background: T.blue, color: '#fff', borderRadius: 100, padding: '10px 22px', fontSize: 14, fontWeight: 600 }}>Got it</button>
        </div>
      </div>
    </PhoneCard>
  );
}

// ── Full-screen image viewer (Screen 16) ────────────────────
function ImageViewerScreen() {
  return (
    <PhoneCard bg="#0A0A0A" dark>
      <div style={{ position: 'absolute', inset: 0 }}>
        <XRay variant="good" style={{ width: '100%', height: '100%' }} />
      </div>
      {/* top gradient + appbar */}
      <div style={{ position: 'absolute', top: 0, left: 0, right: 0, height: 130, background: 'linear-gradient(180deg, rgba(0,0,0,0.6), transparent)' }} />
      <div style={{ position: 'relative', paddingTop: STATUS_INSET, display: 'flex', alignItems: 'center', padding: `${STATUS_INSET}px 12px 0` }}>
        <Icon name="arrow_back" size={24} color="#fff" fill={0} />
        <div style={{ flex: 1, textAlign: 'center', fontSize: 17, fontWeight: 600, color: '#fff' }}>X-Ray Image</div>
        <div style={{ display: 'flex', gap: 14 }}><Icon name="share" size={22} color="#fff" fill={0} /><Icon name="download" size={22} color="#fff" fill={0} /></div>
      </div>
      {/* bottom metadata */}
      <div style={{ position: 'absolute', bottom: 0, left: 0, right: 0, height: 120, background: 'linear-gradient(0deg, rgba(0,0,0,0.7), transparent)' }} />
      <div style={{ position: 'absolute', bottom: 40, left: 20, right: 20, display: 'flex', alignItems: 'center', gap: 10 }}>
        <span style={{ fontSize: 13, color: 'rgba(255,255,255,0.85)' }}>2048 × 1680</span>
        <QualityPill q="good" />
        <span style={{ fontSize: 13, color: 'rgba(255,255,255,0.85)', marginLeft: 'auto' }}>Today, 09:41 AM</span>
      </div>
    </PhoneCard>
  );
}

// ── Canvas assembly ─────────────────────────────────────────
const PH = { w: 390, h: 844 };

function GalleryApp() {
  return (
    <DesignCanvas>
      <DCSection id="firstrun" title="First Run" subtitle="Splash & 3-slide onboarding">
        <DCArtboard id="splash" label="Splash" width={PH.w} height={PH.h}><SplashScreen /></DCArtboard>
        <DCArtboard id="onb1" label="Onboarding · Know Before You Read" width={PH.w} height={PH.h}><OnbSlide1 /></DCArtboard>
        <DCArtboard id="onb2" label="Onboarding · Works Anywhere" width={PH.w} height={PH.h}><OnbSlide2 /></DCArtboard>
        <DCArtboard id="onb3" label="Onboarding · Enhance & Report" width={PH.w} height={PH.h}><OnbSlide3 /></DCArtboard>
      </DCSection>

      <DCSection id="permissions" title="Permissions" subtitle="Pre-prompt interstitials">
        <DCArtboard id="perm-cam" label="Camera Access" width={PH.w} height={PH.h}>
          <PermissionScreen icon="camera_alt" title="Camera Access Needed" body="ClearScan uses your camera to capture X-ray images from a lightbox. Your images stay on your device and are never shared without your consent." />
        </DCArtboard>
        <DCArtboard id="perm-lib" label="Photo Library Access" width={PH.w} height={PH.h}>
          <PermissionScreen icon="photo_library" title="Photo Library Access" body="ClearScan needs access to your photo library to select and save chest X-ray images. Only the images you choose are accessed." />
        </DCArtboard>
      </DCSection>

      <DCSection id="states" title="Empty & Error States" subtitle="What users see when there's nothing — or something went wrong">
        <DCArtboard id="empty-history" label="No Scans Yet" width={PH.w} height={PH.h}>
          <StateScreen barTitle="Scan History" icon="document_scanner" heading="No Scans Yet" body="Start your first quality assessment by uploading or capturing a chest X-ray." primary="Start Scanning" />
        </DCArtboard>
        <DCArtboard id="err-failed" label="Analysis Failed" width={PH.w} height={PH.h}>
          <StateScreen barTitle="Quality Assessment" icon="error" iconColor={T.poor} heading="Analysis Failed" body="Something went wrong during processing. Please try again or check your connection." primary="Try Again" secondary="Report Issue" />
        </DCArtboard>
        <DCArtboard id="err-model" label="CNN Unavailable" width={PH.w} height={PH.h}>
          <StateScreen barTitle="Image Enhancement" icon="model_training" iconColor={T.fair} heading="CNN Model Unavailable" body="The AI model could not be loaded on this device. CLAHE offline mode is still available." primary="Use Offline Mode" secondary="Contact Support" />
        </DCArtboard>
      </DCSection>

      <DCSection id="assessment-states" title="Assessment States" subtitle="Quality outcomes the radiographer sees">
        <DCArtboard id="assess-fair" label="Assessment · Fair Quality" width={PH.w} height={PH.h}><FairAssessScreen /></DCArtboard>
      </DCSection>

      <DCSection id="loading" title="Loading States" subtitle="Never a blank screen">
        <DCArtboard id="load-app" label="App Loading" width={PH.w} height={PH.h}><AppLoadingScreen /></DCArtboard>
        <DCArtboard id="load-assess" label="Assessment Skeleton" width={PH.w} height={PH.h}><AssessSkeletonScreen /></DCArtboard>
        <DCArtboard id="load-enhance" label="Enhancement Processing" width={PH.w} height={PH.h}><EnhanceProcessingScreen /></DCArtboard>
      </DCSection>

      <DCSection id="dialogs" title="Confirmation Dialogs" subtitle="Destructive actions ask first">
        <DCArtboard id="dlg-delete" label="Delete Session" width={PH.w} height={PH.h}>
          <DialogCard title="Delete Session?" body="This will permanently remove this scan session and its results. This action cannot be undone." confirm="Delete Session" cancel="Cancel" />
        </DCArtboard>
        <DCArtboard id="dlg-clear" label="Clear History" width={PH.w} height={PH.h}>
          <DialogCard title="Clear All History?" body="This will permanently delete all scan sessions. Your exported reports will not be affected." confirm="Clear All History" cancel="Cancel" />
        </DCArtboard>
        <DCArtboard id="dlg-discard" label="Discard Changes" width={PH.w} height={PH.h}>
          <DialogCard title="Discard Changes?" body="You have unsaved changes. Are you sure you want to leave?" confirm="Discard" cancel="Keep Editing" />
        </DCArtboard>
      </DCSection>

      <DCSection id="notifications" title="Notifications & Feedback" subtitle="SnackBars, toast, inline banners">
        <DCArtboard id="snacks" label="SnackBars" width={420} height={320}>
          <NotifCard>
            <SnackBar icon="check_circle" color={T.good} msg="PDF report saved and ready to share" action="Open" />
            <SnackBar icon="error" color={T.poor} msg="Couldn't reach the server. Try again." action="Dismiss" />
            <SnackBar icon="info" color={T.blue} msg="Offline mode active — using CLAHE." />
          </NotifCard>
        </DCArtboard>
        <DCArtboard id="toast-banner" label="Toast & Banners" width={420} height={320}>
          <NotifCard>
            <ToastPill icon="save_alt" msg="Image saved to gallery" />
            <Banner tone="warn" icon="warning" msg="This image may not meet diagnostic standards. Enhancement recommended." />
            <Banner tone="info" icon="info" msg="CNN analysis complete. Review the metrics below." />
          </NotifCard>
        </DCArtboard>
        <DCArtboard id="offline-banner" label="Offline Banner in Context" width={PH.w} height={PH.h}><OfflineBannerScreen /></DCArtboard>
      </DCSection>

      <DCSection id="guidance" title="Guidance & Viewer" subtitle="Feature spotlight & full-screen image viewer">
        <DCArtboard id="spotlight1" label="Spotlight · 1 of 3" width={PH.w} height={PH.h}><SpotlightConnectivity /></DCArtboard>
        <DCArtboard id="spotlight" label="Spotlight · 2 of 3" width={PH.w} height={PH.h}><SpotlightScreen /></DCArtboard>
        <DCArtboard id="spotlight3" label="Spotlight · 3 of 3" width={PH.w} height={PH.h}><SpotlightBestResult /></DCArtboard>
        <DCArtboard id="viewer" label="Full-Screen Viewer" width={PH.w} height={PH.h}><ImageViewerScreen /></DCArtboard>
      </DCSection>
    </DesignCanvas>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<GalleryApp />);
