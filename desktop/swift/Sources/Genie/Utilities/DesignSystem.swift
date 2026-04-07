import SwiftUI
import AppKit

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - Genie Design System
// ══════════════════════════════════════════════════════════════════════════════
//
// Centralized design tokens and reusable glass-morphism components for
// the Genie macOS app.  Dark-first, JellyJelly palette, macOS 13+.
//
// Techniques used:
//   - NSVisualEffectView bridged via NSViewRepresentable  (macOS 10.10+)
//   - .ultraThinMaterial / .thinMaterial backgrounds      (macOS 12+)
//   - Multi-layered shadows for glow                      (macOS 13+)
//   - Spring animations                                   (macOS 13+)
//
// References:
//   Linear, Raycast, Arc Browser — dark chrome, colored accents,
//   glass panels with subtle borders + shadows.
// ══════════════════════════════════════════════════════════════════════════════

// MARK: - Color Palette

/// Centralized color tokens — JellyJelly dark palette.
/// Import anywhere:  `DS.Colors.blue`
enum DS {

    enum Colors {
        // ── Backgrounds ──────────────────────────────────────────────
        static let black      = Color(red: 0, green: 0, blue: 0)                  // #000000
        static let charcoal   = Color(red: 0.078, green: 0.078, blue: 0.086)      // #141416
        static let grayDark   = Color(red: 0.118, green: 0.118, blue: 0.129)      // #1E1E21
        static let surface    = Color(red: 0.098, green: 0.098, blue: 0.110)      // #191920  (card bg)

        // ── Text ─────────────────────────────────────────────────────
        static let textPrimary = Color(red: 0.949, green: 0.922, blue: 0.969)     // #F2EBF7
        static let textSecondary = Color(red: 0.612, green: 0.639, blue: 0.686)   // #9CA3AF
        static let textTertiary  = Color(red: 0.420, green: 0.443, blue: 0.498)   // #6B7180

        // ── Accents ──────────────────────────────────────────────────
        static let blue       = Color(red: 0.545, green: 0.671, blue: 0.953)      // #8BABF3
        static let blueAccent = Color(red: 0.310, green: 0.545, blue: 1.0)        // #4F8BFF
        static let blueLight  = Color(red: 0.812, green: 0.890, blue: 1.0)        // #CFE3FF
        static let teal       = Color(red: 0, green: 0.831, blue: 0.667)          // #00D4AA
        static let green      = Color(red: 0.133, green: 0.773, blue: 0.369)      // #22C55E
        static let red        = Color(red: 0.937, green: 0.267, blue: 0.267)      // #EF4444
        static let yellow     = Color(red: 0.980, green: 0.737, blue: 0.020)      // #FABE05
        static let purple     = Color(red: 0.635, green: 0.490, blue: 0.945)      // #A27DF1

        // ── Glass Primitives ─────────────────────────────────────────
        static let glassBg       = blue.opacity(0.06)
        static let glassBorder   = blue.opacity(0.18)
        static let glassBorderHi = blue.opacity(0.35)
        static let glassOverlay  = Color.white.opacity(0.04)
    }

    // MARK: - Radii

    enum Radii {
        static let xs:  CGFloat = 4
        static let sm:  CGFloat = 8
        static let md:  CGFloat = 12
        static let lg:  CGFloat = 14
        static let xl:  CGFloat = 20
        static let pill: CGFloat = 999
    }

    // MARK: - Spacing

    enum Spacing {
        static let xs:  CGFloat = 4
        static let sm:  CGFloat = 8
        static let md:  CGFloat = 12
        static let lg:  CGFloat = 16
        static let xl:  CGFloat = 20
        static let xxl: CGFloat = 24
        static let section: CGFloat = 32
    }

    // MARK: - Typography

    enum Typography {
        static let hero      = Font.system(size: 44, weight: .bold)
        static let title     = Font.system(size: 26, weight: .bold)
        static let heading   = Font.system(size: 18, weight: .semibold)
        static let body      = Font.system(size: 14, weight: .regular)
        static let bodyMedium = Font.system(size: 14, weight: .medium)
        static let caption   = Font.system(size: 12, weight: .medium)
        static let label     = Font.system(size: 10, weight: .bold)
        static let mono      = Font.system(size: 13, design: .monospaced)
        static let monoSmall = Font.system(size: 11, design: .monospaced)
    }

    // MARK: - Gradients

    enum Gradients {
        static let blueButton = LinearGradient(
            colors: [Colors.blueAccent, Colors.blue],
            startPoint: .leading,
            endPoint: .trailing
        )

        static let tealButton = LinearGradient(
            colors: [Colors.teal, Colors.green],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let horizontalFade = LinearGradient(
            colors: [Color.clear, Colors.blue.opacity(0.2), Color.clear],
            startPoint: .leading,
            endPoint: .trailing
        )

        static let blueGlow = RadialGradient(
            colors: [Colors.blue.opacity(0.25), Color.clear],
            center: .center,
            startRadius: 5,
            endRadius: 60
        )

        static let topAmbient = RadialGradient(
            colors: [Colors.blue.opacity(0.06), Color.clear],
            center: .top,
            startRadius: 10,
            endRadius: 400
        )
    }

    // MARK: - Animations

    enum Animations {
        static let snappy = Animation.spring(response: 0.3, dampingFraction: 0.8)
        static let smooth = Animation.spring(response: 0.45, dampingFraction: 0.85)
        static let quick  = Animation.easeInOut(duration: 0.2)
        static let pulse  = Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true)
    }
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - NSVisualEffectView Bridge
// ══════════════════════════════════════════════════════════════════════════════
//
// Provides real macOS vibrancy blur that bleeds through the window.
// `.ultraThinMaterial` only approximates this; NSVisualEffectView is the
// real thing and works on macOS 10.10+.
//
// Usage:
//   VisualEffectBackground(material: .hudWindow, blendingMode: .behindWindow)

struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    var state: NSVisualEffectView.State = .active
    var isEmphasized: Bool = false

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        view.isEmphasized = isEmphasized
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
        nsView.isEmphasized = isEmphasized
    }
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - GlassCard ViewModifier
// ══════════════════════════════════════════════════════════════════════════════
//
// Applies a frosted glass effect: tinted background + subtle border + shadow.
// Two variants:
//   .glassCard()               — standard (blue-tinted, rounded 14pt)
//   .glassCard(prominent: true) — brighter border, stronger shadow
//
// macOS 13+: uses .ultraThinMaterial for real blur when `useBlur` is true.

struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = DS.Radii.lg
    var prominent: Bool = false
    var useBlur: Bool = false
    var padding: CGFloat = DS.Spacing.lg

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(backgroundLayer)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        prominent ? DS.Colors.glassBorderHi : DS.Colors.glassBorder,
                        lineWidth: 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(
                color: DS.Colors.black.opacity(prominent ? 0.4 : 0.2),
                radius: prominent ? 16 : 8,
                y: prominent ? 6 : 3
            )
    }

    @ViewBuilder
    private var backgroundLayer: some View {
        if useBlur {
            ZStack {
                // Real vibrancy behind window
                VisualEffectBackground(
                    material: .hudWindow,
                    blendingMode: .behindWindow
                )
                // Tinted overlay for the JellyJelly brand color
                DS.Colors.glassBg
            }
        } else {
            DS.Colors.glassBg
        }
    }
}

extension View {
    /// Apply a glass card effect with tinted bg, subtle border, and shadow.
    func glassCard(
        cornerRadius: CGFloat = DS.Radii.lg,
        prominent: Bool = false,
        useBlur: Bool = false,
        padding: CGFloat = DS.Spacing.lg
    ) -> some View {
        modifier(GlassCardModifier(
            cornerRadius: cornerRadius,
            prominent: prominent,
            useBlur: useBlur,
            padding: padding
        ))
    }
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - GlowButton
// ══════════════════════════════════════════════════════════════════════════════
//
// A capsule button with gradient fill and a soft glow shadow underneath.
// Inspired by Linear and Raycast CTAs.
//
// Usage:
//   GlowButton("Save", icon: "checkmark") { save() }
//   GlowButton("Delete", gradient: dangerGradient, icon: "trash") { delete() }

struct GlowButton: View {
    let title: String
    var gradient: LinearGradient = DS.Gradients.blueButton
    var glowColor: Color = DS.Colors.blue
    var icon: String? = nil
    var isCompact: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: isCompact ? 10 : 14))
                }
                Text(title)
                    .font(.system(
                        size: isCompact ? 12 : 16,
                        weight: .semibold
                    ))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, isCompact ? 14 : 32)
            .padding(.vertical, isCompact ? 8 : 12)
            .background(isDisabled ? AnyShapeStyle(DS.Colors.grayDark) : AnyShapeStyle(gradient))
            .clipShape(Capsule())
            .shadow(
                color: isDisabled ? Color.clear : glowColor.opacity(0.3),
                radius: 16,
                y: 4
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - GlassTextField
// ══════════════════════════════════════════════════════════════════════════════
//
// A text field styled to sit inside glass cards: black bg, blue-tinted
// border that brightens on focus, monospaced text.
//
// Usage:
//   GlassTextField("API Key", text: $apiKey, placeholder: "sk-or-...")
//   GlassTextField("Token", text: $token, isSecure: true)

struct GlassTextField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var isSecure: Bool = false
    var isRequired: Bool = false
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            // Label row
            HStack(spacing: DS.Spacing.xs) {
                Text(label)
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.textSecondary)
                if isRequired {
                    Text("*")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(DS.Colors.red.opacity(0.7))
                }
            }

            // Input
            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .textFieldStyle(.plain)
            .font(DS.Typography.mono)
            .padding(10)
            .background(DS.Colors.black)
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radii.sm, style: .continuous)
                    .stroke(
                        isFocused
                            ? DS.Colors.blue.opacity(0.5)
                            : DS.Colors.glassBorder,
                        lineWidth: 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.Radii.sm, style: .continuous))
            .focused($isFocused)
            .animation(DS.Animations.quick, value: isFocused)
        }
    }
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - StatusDot
// ══════════════════════════════════════════════════════════════════════════════
//
// A small circle indicator with an ambient glow.  3 states:
//   .active   — green/teal with glow
//   .warning  — yellow with glow
//   .inactive — gray, no glow
//   .error    — red with glow
//
// Usage:
//   StatusDot(.active)
//   StatusDot(.error, size: 12)

struct StatusDot: View {
    enum Status {
        case active
        case warning
        case inactive
        case error
    }

    let status: Status
    var size: CGFloat = 10
    var animated: Bool = true

    @State private var isGlowing = false

    var body: some View {
        Circle()
            .fill(dotColor)
            .frame(width: size, height: size)
            .shadow(color: glowColor, radius: glowRadius, x: 0, y: 0)
            .shadow(color: glowColor, radius: glowRadius * 0.5, x: 0, y: 0) // double layer = richer glow
            .opacity(animated && shouldPulse ? (isGlowing ? 1.0 : 0.7) : 1.0)
            .animation(
                animated && shouldPulse ? DS.Animations.pulse : .default,
                value: isGlowing
            )
            .onAppear {
                if animated && shouldPulse {
                    isGlowing = true
                }
            }
    }

    private var dotColor: Color {
        switch status {
        case .active:   return DS.Colors.teal
        case .warning:  return DS.Colors.yellow
        case .inactive: return DS.Colors.textTertiary
        case .error:    return DS.Colors.red
        }
    }

    private var glowColor: Color {
        switch status {
        case .active:   return DS.Colors.teal.opacity(0.5)
        case .warning:  return DS.Colors.yellow.opacity(0.4)
        case .inactive: return Color.clear
        case .error:    return DS.Colors.red.opacity(0.5)
        }
    }

    private var glowRadius: CGFloat {
        status == .inactive ? 0 : 4
    }

    private var shouldPulse: Bool {
        status == .active || status == .warning
    }
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - SectionHeader
// ══════════════════════════════════════════════════════════════════════════════
//
// All-caps label in the accent color with letter spacing, matching the
// existing "TELEGRAM" / "AI & SERVICES" section headers.
//
// Usage:
//   SectionHeader("API KEYS")
//   SectionHeader("Server", icon: "server.rack")

struct SectionHeader: View {
    let title: String
    var icon: String? = nil
    var color: Color = DS.Colors.blue

    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(color)
            }
            Text(title.uppercased())
                .font(DS.Typography.label)
                .foregroundStyle(color)
                .kerning(1.4)
        }
    }
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - GhostButton
// ══════════════════════════════════════════════════════════════════════════════
//
// Outlined capsule button — used for secondary actions like "Test", "View Logs".
// Tinted background on hover, colored border.
//
// Usage:
//   GhostButton("Test", icon: "play.fill", color: .teal) { test() }

struct GhostButton: View {
    let title: String
    var icon: String? = nil
    var color: Color = DS.Colors.blue
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 10))
                }
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(color)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(color.opacity(isHovered ? 0.15 : 0.1))
            .overlay(
                Capsule()
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - Divider Line
// ══════════════════════════════════════════════════════════════════════════════
//
// Horizontal gradient divider that fades at edges — matches the existing
// SettingsView tab divider.

struct GlassDivider: View {
    var color: Color = DS.Colors.blue
    var opacity: Double = 0.2

    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [Color.clear, color.opacity(opacity), Color.clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 1)
    }
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - KeyCap
// ══════════════════════════════════════════════════════════════════════════════
//
// Small keyboard shortcut badge (e.g. Cmd, Shift, G).

struct KeyCap: View {
    let key: String

    var body: some View {
        Text(key)
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(DS.Colors.textPrimary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(DS.Colors.grayDark)
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radii.xs, style: .continuous)
                    .stroke(DS.Colors.glassBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.Radii.xs, style: .continuous))
    }
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - PulseGlow Animation Modifier
// ══════════════════════════════════════════════════════════════════════════════
//
// Extracted from OnboardingView — reusable pulsing glow for hero icons.
//
// Usage:
//   Circle().fill(gradient).modifier(PulseGlowModifier())

struct PulseGlowModifier: ViewModifier {
    @State private var isGlowing = false

    var minOpacity: Double = 0.5
    var maxScale: CGFloat = 1.1
    var minScale: CGFloat = 0.9

    func body(content: Content) -> some View {
        content
            .opacity(isGlowing ? 1.0 : minOpacity)
            .scaleEffect(isGlowing ? maxScale : minScale)
            .animation(DS.Animations.pulse, value: isGlowing)
            .onAppear { isGlowing = true }
    }
}

extension View {
    /// Add a looping pulse-glow effect (scale + opacity).
    func pulseGlow(
        minOpacity: Double = 0.5,
        maxScale: CGFloat = 1.1,
        minScale: CGFloat = 0.9
    ) -> some View {
        modifier(PulseGlowModifier(
            minOpacity: minOpacity,
            maxScale: maxScale,
            minScale: minScale
        ))
    }
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - ProcessStatusCard
// ══════════════════════════════════════════════════════════════════════════════
//
// Reusable status row: StatusDot + label + trailing info.
// Extracted from SettingsView `processStatusCard`.

struct ProcessStatusCard: View {
    let label: String
    let statusText: String
    let dot: StatusDot.Status

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            StatusDot(status: dot)

            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(DS.Colors.textPrimary)

            Spacer()

            Text(statusText)
                .font(DS.Typography.monoSmall)
                .foregroundStyle(DS.Colors.textSecondary)
        }
        .glassCard(cornerRadius: DS.Radii.md, padding: DS.Spacing.lg)
    }
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - SummaryPill
// ══════════════════════════════════════════════════════════════════════════════
//
// Small pill badge with icon + text, used in the onboarding "ready" step.

struct SummaryPill: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(DS.Colors.blue)
            Text(text)
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.textPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(DS.Colors.glassBg)
        .overlay(
            Capsule()
                .stroke(DS.Colors.glassBorder, lineWidth: 1)
        )
        .clipShape(Capsule())
    }
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - G Convenience Namespace
// ══════════════════════════════════════════════════════════════════════════════
//
// Short aliases so new views can write `G.bg` instead of `DS.Colors.black`.
// Maps 1:1 to DS.Colors with names matching the design spec.

enum G {
    // Backgrounds
    static let bg         = DS.Colors.black
    static let surface    = DS.Colors.charcoal
    static let surfaceAlt = DS.Colors.grayDark

    // Text
    static let textPrimary   = DS.Colors.textPrimary
    static let textSecondary = DS.Colors.textSecondary
    static let textTertiary  = DS.Colors.textTertiary

    // Accent
    static let blue       = DS.Colors.blue
    static let blueAccent = DS.Colors.blueAccent
    static let blueLight  = DS.Colors.blueLight
    static let teal       = DS.Colors.teal
    static let green      = DS.Colors.green
    static let red        = DS.Colors.red
    static let amber      = DS.Colors.yellow

    // Glass
    static let glassBg       = DS.Colors.glassBg
    static let glassBorder   = DS.Colors.glassBorder
    static let glassBorderHi = DS.Colors.glassBorderHi

    // Gradients
    static let ctaGradient = DS.Gradients.blueButton
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - GlowButtonStyle
// ══════════════════════════════════════════════════════════════════════════════

struct GlowButtonStyle: ButtonStyle {
    var color: Color = G.blueAccent
    var maxWidth: CGFloat? = 280

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: maxWidth)
            .frame(height: 48)
            .background(
                LinearGradient(
                    colors: [color, G.blue],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(Capsule())
            .shadow(color: G.blue.opacity(configuration.isPressed ? 0.1 : 0.3), radius: 16, y: 4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - GlassTextField Modifier
// ══════════════════════════════════════════════════════════════════════════════

struct GlassTextFieldModifier: ViewModifier {
    var isFocused: Bool = false

    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .font(.system(size: 14, design: .monospaced))
            .padding(12)
            .background(G.bg)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isFocused ? G.blue.opacity(0.5) : G.glassBorder,
                        lineWidth: 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

extension View {
    func glassTextField(isFocused: Bool = false) -> some View {
        modifier(GlassTextFieldModifier(isFocused: isFocused))
    }
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - SectionLabel
// ══════════════════════════════════════════════════════════════════════════════

struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(G.blue)
            .kerning(1.4)
    }
    init(_ text: String) {
        self.text = text
    }
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - PillBadge
// ══════════════════════════════════════════════════════════════════════════════

struct PillBadge: View {
    let text: String
    var color: Color = G.blue
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - StatusDot ProcessStatus Init
// ══════════════════════════════════════════════════════════════════════════════

extension StatusDot {
    init(processStatus: GenieState.ProcessStatus, size: CGFloat = 10) {
        switch processStatus {
        case .running: self.init(status: .active, size: size)
        case .starting: self.init(status: .warning, size: size)
        case .stopped: self.init(status: .inactive, size: size)
        case .failed: self.init(status: .error, size: size)
        }
    }
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - PulseGlow (alias for PulseGlowModifier)
// ══════════════════════════════════════════════════════════════════════════════

typealias PulseGlow = PulseGlowModifier
