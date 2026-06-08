/* ClearScan — shared UI primitives + X-ray texture. Exports to window. */

const T = {
  blue: '#1565C0', blueDark: '#0D47A1', accent: '#42A5F5',
  surfaceBlue: '#E3F2FD', appBg: '#F8FAFB', white: '#FFFFFF',
  good: '#2E7D32', goodBg: '#E8F5E9', fair: '#F57F17', fairBg: '#FFF8E1',
  poor: '#C62828', poorBg: '#FFEBEE', text: '#1A1A2E', text2: '#6B7280',
  border: '#E5E7EB', destructive: '#B00020',
  shadowCard: '0 4px 16px rgba(21,101,192,0.08)',
  shadowBtn: '0 4px 12px rgba(21,101,192,0.30)',
};

// ── Material Symbols icon ───────────────────────────────────
function Icon({ name, size = 24, fill = 1, weight = 500, grade = 0, color, style }) {
  return (
    <span className="msr" style={{
      fontSize: size, color,
      fontVariationSettings: `'FILL' ${fill}, 'wght' ${weight}, 'opsz' ${Math.min(48, Math.max(20, size))}, 'GRAD' ${grade}`,
      ...style,
    }}>{name}</span>
  );
}

// ── X-ray texture (abstract greyscale, not a real scan) ─────
function XRay({ variant = 'orig', style, children }) {
  // filters tune the same texture to read as before/after/good/poor
  const filters = {
    orig:     'contrast(0.86) brightness(0.9) blur(0.4px)',
    enhanced: 'contrast(1.22) brightness(1.12) saturate(0)',
    good:     'contrast(1.12) brightness(1.04)',
    poor:     'contrast(0.72) brightness(0.82) blur(1.3px)',
    fair:     'contrast(0.95) brightness(0.95) blur(0.7px)',
    plain:    'contrast(1) brightness(1)',
  };
  return (
    <div style={{ position: 'relative', overflow: 'hidden', background: '#0a0c0e', ...style }}>
      <div style={{
        position: 'absolute', inset: 0,
        filter: filters[variant] || filters.plain,
        backgroundColor: '#0c0f12',
        backgroundImage: [
          // shoulders / clavicle glow
          'radial-gradient(ellipse 78% 26% at 50% 20%, rgba(206,214,222,0.30), transparent 60%)',
          // central spine / mediastinum column
          'radial-gradient(ellipse 16% 64% at 50% 56%, rgba(214,222,230,0.42), transparent 72%)',
          // left lung field (radiolucent, darker)
          'radial-gradient(ellipse 30% 42% at 30% 54%, rgba(40,48,55,0.55), transparent 70%)',
          // right lung field
          'radial-gradient(ellipse 30% 42% at 70% 54%, rgba(40,48,55,0.55), transparent 70%)',
          // rib-cage striations (very faint arcs)
          'repeating-radial-gradient(ellipse 60% 50% at 50% 46%, rgba(190,200,210,0.07) 0 3px, transparent 3px 22px)',
          // diaphragm base glow
          'radial-gradient(ellipse 64% 22% at 50% 86%, rgba(150,160,170,0.22), transparent 70%)',
          // vignette
          'radial-gradient(ellipse 80% 86% at 50% 50%, transparent 42%, rgba(0,0,0,0.7) 100%)',
        ].join(','),
      }} />
      {children}
    </div>
  );
}

// ── ClearScan logomark (document + signal-wave) ─────────────
function Logo({ size = 72, radius }) {
  const r = radius != null ? radius : Math.round(size * 0.28);
  const s = size * 0.5;
  return (
    <div style={{
      width: size, height: size, borderRadius: r, background: T.blue,
      display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
      boxShadow: size >= 56 ? '0 6px 18px rgba(21,101,192,0.32)' : 'none',
    }}>
      <svg width={s} height={s} viewBox="0 0 24 24" fill="none">
        <path d="M6 3.2h7.2L19 9v11.4a1.4 1.4 0 0 1-1.4 1.4H6A1.4 1.4 0 0 1 4.6 20.4V4.6A1.4 1.4 0 0 1 6 3.2Z"
          stroke="#fff" strokeWidth="1.5" fill="none"/>
        <path d="M12.8 3.4V8.6h5.2" stroke="#fff" strokeWidth="1.5" fill="none" strokeLinejoin="round"/>
        <path d="M7.4 15.2c1-2.6 1.7-2.6 2.5 0 .8 2.6 1.6 2.6 2.4 0 .8-2.6 1.6-2.6 2.4 0"
          stroke="#fff" strokeWidth="1.5" fill="none" strokeLinecap="round" strokeLinejoin="round"/>
      </svg>
    </div>
  );
}

// ── Buttons ─────────────────────────────────────────────────
function PrimaryBtn({ children, onClick, icon, iconAfter, glow, style, disabled }) {
  return (
    <button className="press" onClick={disabled ? undefined : onClick} disabled={disabled} style={{
      display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
      height: 52, borderRadius: 100, width: '100%',
      background: disabled ? '#A9C4E6' : T.blue, color: '#fff',
      fontFamily: 'DM Sans', fontWeight: 600, fontSize: 16,
      boxShadow: disabled ? 'none' : T.shadowBtn,
      animation: glow && !disabled ? 'cs-glow-pulse 2s ease-in-out infinite' : 'none',
      ...style,
    }}>
      {icon && <Icon name={icon} size={20} color="#fff" />}
      {children}
      {iconAfter && <Icon name={iconAfter} size={20} color="#fff" />}
    </button>
  );
}
function OutlineBtn({ children, onClick, style }) {
  return (
    <button className="press" onClick={onClick} style={{
      display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
      height: 52, borderRadius: 100, width: '100%',
      background: '#fff', color: T.blue, border: `1.5px solid ${T.blue}`,
      fontFamily: 'DM Sans', fontWeight: 600, fontSize: 16, ...style,
    }}>{children}</button>
  );
}
function TextBtn({ children, onClick, color = T.text2, style }) {
  return (
    <button className="press" onClick={onClick} style={{
      color, fontFamily: 'DM Sans', fontWeight: 600, fontSize: 14,
      padding: '10px 12px', ...style,
    }}>{children}</button>
  );
}

// ── Quality badge (pill) ────────────────────────────────────
const QUAL = {
  good: { label: 'GOOD', bg: T.goodBg, fg: T.good, icon: 'check_circle' },
  fair: { label: 'FAIR', bg: T.fairBg, fg: T.fair, icon: 'warning' },
  poor: { label: 'POOR', bg: T.poorBg, fg: T.poor, icon: 'cancel' },
};
function QualityPill({ q = 'good' }) {
  const c = QUAL[q];
  return (
    <span style={{
      display: 'inline-flex', alignItems: 'center', gap: 4,
      background: c.fg, color: '#fff', borderRadius: 10,
      padding: '4px 8px', fontSize: 11, fontWeight: 600, letterSpacing: 0.3,
    }}>{c.label}</span>
  );
}

// ── Big quality badge for results ───────────────────────────
function QualityBadge({ q = 'good', confidence = 94 }) {
  const c = QUAL[q];
  return (
    <div style={{
      display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 2,
      background: c.bg, border: `1.5px solid ${c.fg}`, borderRadius: 100,
      padding: '14px 28px', margin: '0 auto', width: 'fit-content',
    }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
        <Icon name={c.icon} size={26} color={c.fg} />
        <span style={{ fontSize: 22, fontWeight: 700, color: c.fg, letterSpacing: 0.2 }}>
          {c.label} QUALITY
        </span>
      </div>
      <span style={{ fontSize: 14, fontWeight: 500, color: c.fg, opacity: 0.85 }}>
        {confidence}% confident
      </span>
    </div>
  );
}

// ── Connectivity badge (pulsing) ────────────────────────────
function ConnectivityBadge({ online = true }) {
  return (
    <div title={online ? 'CNN Mode — Online' : 'CLAHE Mode — Offline'}
      style={{ position: 'relative', width: 12, height: 12, display: 'inline-flex' }}>
      {online && (
        <span style={{
          position: 'absolute', inset: 0, borderRadius: '50%', background: T.good,
          animation: 'cs-pulse-ring 1.5s ease-out infinite',
        }} />
      )}
      <span style={{
        position: 'relative', width: 12, height: 12, borderRadius: '50%',
        background: online ? T.good : T.fair,
      }} />
    </div>
  );
}

// ── Metric row with animated bar ────────────────────────────
function MetricRow({ icon, name, value, pct, warn, animateKey }) {
  const [w, setW] = React.useState(0);
  React.useEffect(() => {
    const id = requestAnimationFrame(() => setTimeout(() => setW(pct), 60));
    return () => cancelAnimationFrame(id);
  }, [pct, animateKey]);
  const barColor = warn ? '#EF9A9A' : T.blue;
  return (
    <div style={{ padding: '10px 0' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
        <Icon name={icon} size={20} color={T.text2} />
        <span style={{ flex: 1, fontSize: 15, color: T.text }}>{name}</span>
        {warn && <Icon name="warning" size={15} color={T.fair} style={{ marginRight: 2 }} />}
        <span style={{ fontSize: 14, fontWeight: 600, color: warn ? T.fair : T.blue }}>{value}</span>
      </div>
      <div style={{ height: 4, borderRadius: 4, background: T.surfaceBlue, marginTop: 8, overflow: 'hidden' }}>
        <div style={{
          height: '100%', width: `${w}%`, borderRadius: 4, background: barColor,
          transition: 'width 800ms cubic-bezier(.2,.8,.2,1)',
        }} />
      </div>
    </div>
  );
}

// ── Generic card ────────────────────────────────────────────
function Card({ children, style, onClick, pressable }) {
  return (
    <div className={pressable ? 'press' : ''} onClick={onClick} style={{
      background: '#fff', borderRadius: 16, boxShadow: T.shadowCard,
      padding: 16, ...style,
    }}>{children}</div>
  );
}

function SectionLabel({ children, style }) {
  return (
    <div style={{
      fontSize: 12, fontWeight: 600, color: T.text2, textTransform: 'uppercase',
      letterSpacing: 1.2, ...style,
    }}>{children}</div>
  );
}

// ── Metadata chip ───────────────────────────────────────────
function MetaChip({ icon, children, tone = 'blue' }) {
  const tones = {
    blue: { bg: T.surfaceBlue, fg: T.blue },
    grey: { bg: '#F1F3F5', fg: T.text2 },
  };
  const c = tones[tone];
  return (
    <span style={{
      display: 'inline-flex', alignItems: 'center', gap: 5,
      background: c.bg, color: c.fg, borderRadius: 100,
      padding: '6px 12px', fontSize: 12, fontWeight: 500,
    }}>
      {icon && <Icon name={icon} size={15} color={c.fg} />}
      {children}
    </span>
  );
}

// ── Reveal: transition-based entrance (rasterizer/print safe) ─
function useEntered() {
  const [on, setOn] = React.useState(false);
  React.useEffect(() => {
    const t = setTimeout(() => setOn(true), 24);
    return () => clearTimeout(t);
  }, []);
  return on;
}
function Reveal({ children, delay = 0, mode = 'up', dur, style }) {
  const on = useEntered();
  const hidden = mode === 'spring' ? 'scale(0.62)' : mode === 'up' ? 'translateY(12px)' : 'none';
  const d = dur || (mode === 'spring' ? 520 : 380);
  const ease = mode === 'spring' ? 'cubic-bezier(.34,1.56,.64,1)' : 'cubic-bezier(.2,.8,.2,1)';
  return (
    <div style={{
      opacity: on ? 1 : 0, transform: on ? 'none' : hidden,
      transition: `opacity ${d}ms ease ${delay}ms, transform ${d}ms ${ease} ${delay}ms`,
      ...style,
    }}>{children}</div>
  );
}

Object.assign(window, {
  T, Icon, XRay, Logo, PrimaryBtn, OutlineBtn, TextBtn,
  QualityPill, QualityBadge, QUAL, ConnectivityBadge, MetricRow, Card, SectionLabel, MetaChip,
  useEntered, Reveal,
});
