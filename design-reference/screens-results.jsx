/* ClearScan — results summary, export sheet, PDF flow, toast, dialogs */

function CheckDraw({ size = 64, color = T.good }) {
  const [on, setOn] = React.useState(false);
  React.useEffect(() => { const t = setTimeout(() => setOn(true), 80); return () => clearTimeout(t); }, []);
  const C = 2 * Math.PI * 28;
  return (
    <svg width={size} height={size} viewBox="0 0 64 64">
      <circle cx="32" cy="32" r="28" fill="none" stroke={color} strokeWidth="5" strokeLinecap="round"
        strokeDasharray={C} strokeDashoffset={on ? 0 : C}
        style={{ transition: 'stroke-dashoffset 520ms ease', transform: 'rotate(-90deg)', transformOrigin: 'center' }} />
      <path d="M19 33 l9 9 l17-19" fill="none" stroke={color} strokeWidth="5" strokeLinecap="round" strokeLinejoin="round"
        strokeDasharray="48" strokeDashoffset={on ? 0 : 48}
        style={{ transition: 'stroke-dashoffset 360ms ease 340ms' }} />
    </svg>
  );
}

function ResultsScreen() {
  const app = window.__cs;
  return (
    <React.Fragment>
      <BackBar title="Analysis Complete" trailing={<IconButton name="share" onClick={() => app.toast('Sharing report…', 'info')} />} />
      <div className="cs-scroll" style={{ flex: 1, overflowY: 'auto', background: T.appBg, padding: '0 20px 24px' }}>
        {/* success header */}
        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', textAlign: 'center', padding: '22px 0 18px' }}>
          <CheckDraw />
          <div style={{ fontSize: 22, fontWeight: 700, color: T.text, marginTop: 10 }}>Analysis Complete</div>
          <div style={{ fontSize: 14, color: T.text2, marginTop: 2 }}>Jun 7, 2026 · 09:41 AM</div>
        </div>

        {/* before / after thumbs */}
        <div style={{ display: 'flex', gap: 12 }}>
          <ThumbLabeled v="orig" label="Before" />
          <ThumbLabeled v="enhanced" label="After" />
        </div>

        {/* metrics table */}
        <Card style={{ marginTop: 18, padding: 0, overflow: 'hidden' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '14px 16px 10px' }}>
            <Icon name="table_chart" size={22} color={T.blue} />
            <span style={{ fontSize: 16, fontWeight: 600, color: T.text }}>Metrics Comparison</span>
          </div>
          <Table />
        </Card>

        {/* method performance */}
        <Card style={{ marginTop: 16 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 16 }}>
            <Icon name="bar_chart" size={22} color={T.blue} />
            <span style={{ fontSize: 16, fontWeight: 600, color: T.text }}>Method Performance</span>
          </div>
          <PerfBar label="CNN" value={0.88} color={T.blue} />
          <PerfBar label="CLAHE" value={0.79} color={T.accent} />
        </Card>

        {/* winner */}
        <div style={{ marginTop: 16, background: '#fff', borderRadius: 16, boxShadow: T.shadowCard, borderLeft: `4px solid ${T.blue}`, padding: 16, display: 'flex', alignItems: 'center', gap: 14 }}>
          <Icon name="emoji_events" size={32} color="#FFD54F" />
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 12, fontWeight: 600, color: T.text2, textTransform: 'uppercase', letterSpacing: 0.8 }}>Best Enhancement Method</div>
            <div style={{ fontSize: 18, fontWeight: 600, color: T.blue, marginTop: 2 }}>CNN Enhanced</div>
            <div style={{ fontSize: 13, color: T.text2 }}>Composite Score: 0.847</div>
          </div>
        </div>

        <div style={{ marginTop: 22 }}>
          <PrimaryBtn icon="upload" onClick={() => app.openSheet('export')}>Export Report</PrimaryBtn>
        </div>
      </div>
    </React.Fragment>
  );
}

function ThumbLabeled({ v, label }) {
  return (
    <div style={{ flex: 1, position: 'relative', height: 120, borderRadius: 12, overflow: 'hidden' }}>
      <XRay variant={v} style={{ width: '100%', height: '100%' }} />
      <span style={{ position: 'absolute', left: 8, bottom: 8, background: 'rgba(0,0,0,0.55)', color: '#fff', borderRadius: 8, padding: '3px 8px', fontSize: 11, fontWeight: 600 }}>{label}</span>
    </div>
  );
}

function Table() {
  const rows = [
    { m: 'SSIM', o: '0.62', e: '0.88', c: '+0.26', up: true },
    { m: 'PSNR', o: '22.4', e: '31.7', c: '+9.3', up: true },
    { m: 'BRISQUE', o: '48.1', e: '19.6', c: '−28.5', up: true },
  ];
  const cell = { flex: 1, fontSize: 13.5, textAlign: 'right' };
  return (
    <div>
      <div style={{ display: 'flex', padding: '8px 16px', background: '#F0F4F8' }}>
        <span style={{ flex: 1.4, fontSize: 12, fontWeight: 600, color: T.text2 }}>Metric</span>
        <span style={{ ...cell, fontSize: 12, fontWeight: 600, color: T.text2 }}>Original</span>
        <span style={{ ...cell, fontSize: 12, fontWeight: 600, color: T.text2 }}>Enhanced</span>
        <span style={{ ...cell, fontSize: 12, fontWeight: 600, color: T.text2 }}>Change</span>
      </div>
      {rows.map((r, i) => (
        <div key={r.m} style={{ display: 'flex', alignItems: 'center', padding: '11px 16px', background: i % 2 ? '#F8FAFB' : '#fff' }}>
          <span style={{ flex: 1.4, fontSize: 14, fontWeight: 500, color: T.text }}>{r.m}</span>
          <span style={{ ...cell, color: T.text2 }}>{r.o}</span>
          <span style={{ ...cell, color: T.text, fontWeight: 600 }}>{r.e}</span>
          <span style={{ ...cell, color: T.good, fontWeight: 600 }}>{r.c} ▲</span>
        </div>
      ))}
      <div style={{ display: 'flex', alignItems: 'center', padding: '11px 16px', background: '#fff', borderTop: `1px solid ${T.border}` }}>
        <span style={{ flex: 1.4, fontSize: 14, fontWeight: 500, color: T.text }}>Quality Class</span>
        <div style={{ flex: 3, display: 'flex', alignItems: 'center', justifyContent: 'flex-end', gap: 8 }}>
          <QualityPill q="poor" /><Icon name="arrow_forward" size={16} color={T.text2} /><QualityPill q="good" />
        </div>
      </div>
    </div>
  );
}

function PerfBar({ label, value, color }) {
  const [w, setW] = React.useState(0);
  React.useEffect(() => { const t = setTimeout(() => setW(value * 100), 80); return () => clearTimeout(t); }, [value]);
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 12 }}>
      <span style={{ width: 46, fontSize: 13, fontWeight: 600, color: T.text }}>{label}</span>
      <div style={{ flex: 1, height: 22, background: '#EEF2F6', borderRadius: 6, overflow: 'hidden', position: 'relative' }}>
        <div style={{ height: '100%', width: `${w}%`, background: color, borderRadius: 6, transition: 'width 800ms cubic-bezier(.2,.8,.2,1)', display: 'flex', alignItems: 'center', justifyContent: 'flex-end' }}>
          <span style={{ fontSize: 11, fontWeight: 700, color: '#fff', paddingRight: 8 }}>{value.toFixed(2)}</span>
        </div>
      </div>
    </div>
  );
}

// ── Export sheet ────────────────────────────────────────────
function ExportSheet() {
  const app = window.__cs;
  return (
    <Sheet onClose={() => app.closeSheet()}>
      <div style={{ fontSize: 18, fontWeight: 600, color: T.text, textAlign: 'center', padding: '14px 0 16px' }}>Export Options</div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
        <ExportTile icon="photo_library" iconColor={T.blue} title="Save to Gallery" sub="Save original and enhanced images to your device" onClick={() => { app.closeSheet(); app.toast('Images saved to gallery', 'success'); }} />
        <ExportTile icon="picture_as_pdf" iconColor={T.poor} title="Export PDF Report" sub="Professional clinical report with all metrics and images" onClick={() => app.dialogPdf()} />
        <ExportTile icon="content_copy" iconColor={T.text2} title="Copy Metrics to Clipboard" sub="Copy all quality metrics as formatted text" onClick={() => { app.closeSheet(); app.toast('Metrics copied to clipboard', 'success'); }} />
      </div>
      <div style={{ height: 1, background: T.border, margin: '16px 0 4px' }} />
      <TextBtn style={{ width: '100%', textAlign: 'center' }} onClick={() => app.closeSheet()}>Cancel</TextBtn>
    </Sheet>
  );
}

function ExportTile({ icon, iconColor, title, sub, onClick }) {
  return (
    <div className="press" onClick={onClick} style={{ display: 'flex', alignItems: 'center', gap: 14, padding: 14, border: `1px solid ${T.border}`, borderRadius: 12 }}>
      <div style={{ width: 48, height: 48, borderRadius: 12, background: T.surfaceBlue, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
        <Icon name={icon} size={26} color={iconColor} />
      </div>
      <div style={{ flex: 1 }}>
        <div style={{ fontSize: 15, fontWeight: 600, color: T.text }}>{title}</div>
        <div style={{ fontSize: 12.5, color: T.text2, marginTop: 2, lineHeight: 1.4 }}>{sub}</div>
      </div>
      <Icon name="chevron_right" size={22} color={T.text2} fill={0} />
    </div>
  );
}

// ── PDF generating overlay ──────────────────────────────────
function PdfOverlay() {
  const on = useEntered();
  return (
    <div style={{ position: 'absolute', inset: 0, zIndex: 90, display: 'flex', alignItems: 'center', justifyContent: 'center', background: `rgba(0,0,0,${on ? 0.5 : 0})`, transition: 'background 200ms ease' }}>
      <div style={{ background: '#fff', borderRadius: 20, padding: 32, display: 'flex', flexDirection: 'column', alignItems: 'center', width: 240 }}>
        <span className="msr" style={{ fontSize: 40, color: T.blue, animation: 'cs-spin 0.9s linear infinite' }}>progress_activity</span>
        <div style={{ fontSize: 16, fontWeight: 600, color: T.text, marginTop: 16 }}>Generating Report…</div>
        <div style={{ fontSize: 13, color: T.text2, marginTop: 4 }}>This may take a moment</div>
      </div>
    </div>
  );
}

// ── Toast ───────────────────────────────────────────────────
function Toast({ msg, kind }) {
  const on = useEntered();
  const map = {
    success: { icon: 'check_circle', color: T.good },
    error: { icon: 'error', color: T.poor },
    info: { icon: 'info', color: T.blue },
  };
  const c = map[kind] || map.info;
  return (
    <div style={{ position: 'absolute', left: 16, right: 16, bottom: 30, zIndex: 95, display: 'flex', alignItems: 'center', gap: 10, background: '#fff', borderRadius: 12, boxShadow: '0 4px 16px rgba(0,0,0,0.16)', padding: '14px 16px', opacity: 1, transform: on ? 'none' : 'translateY(16px)', transition: 'transform 280ms cubic-bezier(.2,.8,.2,1)' }}>
      <Icon name={c.icon} size={20} color={c.color} />
      <span style={{ flex: 1, fontSize: 14, color: T.text }}>{msg}</span>
      <span style={{ fontSize: 13, fontWeight: 600, color: T.blue }}>OK</span>
    </div>
  );
}

// ── Confirmation dialogs ────────────────────────────────────
const DIALOGS = {
  deleteSession: { title: 'Delete Session?', body: 'This will permanently remove this scan session and its results. This action cannot be undone.', confirm: 'Delete Session' },
  clearHistory: { title: 'Clear All History?', body: 'This will permanently delete all scan sessions. Your exported reports will not be affected.', confirm: 'Clear All History' },
  unsaved: { title: 'Discard Changes?', body: 'You have unsaved changes. Are you sure you want to leave?', confirm: 'Discard', cancel: 'Keep Editing' },
};
function ConfirmDialog({ kind, onClose, onConfirm }) {
  const d = DIALOGS[kind];
  const on = useEntered();
  return (
    <div onClick={onClose} style={{ position: 'absolute', inset: 0, zIndex: 88, display: 'flex', alignItems: 'center', justifyContent: 'center', background: `rgba(0,0,0,${on ? 0.4 : 0})`, padding: 40, transition: 'background 180ms ease' }}>
      <div onClick={e => e.stopPropagation()} style={{ background: '#fff', borderRadius: 20, padding: '26px 22px', width: '100%', textAlign: 'center', opacity: 1, transform: on ? 'scale(1)' : 'scale(0.9)', transition: 'transform 240ms cubic-bezier(.34,1.3,.64,1)' }}>
        <div style={{ fontSize: 18, fontWeight: 600, color: T.text }}>{d.title}</div>
        <div style={{ fontSize: 14, color: T.text2, lineHeight: 1.5, margin: '10px 0 22px' }}>{d.body}</div>
        <PrimaryBtn style={{ background: T.poor, boxShadow: 'none', height: 48 }} onClick={onConfirm}>{d.confirm}</PrimaryBtn>
        <div style={{ height: 10 }} />
        <OutlineBtn style={{ height: 48 }} onClick={onClose}>{d.cancel || 'Cancel'}</OutlineBtn>
      </div>
    </div>
  );
}

Object.assign(window, {
  CheckDraw, ResultsScreen, ThumbLabeled, Table, PerfBar, ExportSheet, ExportTile,
  PdfOverlay, Toast, ConfirmDialog, DIALOGS,
});
