import SwiftUI

struct AppTheme {
    let dark: Bool
    let bg: Color
    let surface: Color
    let surface2: Color
    let line: Color
    let lineStrong: Color
    let text: Color
    let muted: Color
    let faint: Color
    let accent: Color
    let accentText: Color
    let accentSoft: Color
    let onAccent: Color
    let success: Color
    let warn: Color
    let danger: Color

    static func make(_ dark: Bool) -> AppTheme {
        AppTheme(
            dark: dark,
            bg:         dark ? Color(hex: 0x141417) : Color(hex: 0xF6F6F4),
            surface:    dark ? Color(hex: 0x1E1E22) : .white,
            surface2:   dark ? Color(hex: 0x27272C) : Color(hex: 0xEFEFEC),
            line:       dark ? Color.white.opacity(0.08) : Color.black.opacity(0.075),
            lineStrong: dark ? Color.white.opacity(0.15) : Color.black.opacity(0.13),
            text:       dark ? Color(hex: 0xF4F4F3) : Color(hex: 0x18181A),
            muted:      dark ? Color(hex: 0x9A9AA0) : Color(hex: 0x6C6C70),
            faint:      dark ? Color(hex: 0x5C5C62) : Color(hex: 0xA6A6A4),
            accent:     dark ? Color(hex: 0x2DD4BF) : Color(hex: 0x0FAE9C),
            accentText: dark ? Color(hex: 0x5EEAD7) : Color(hex: 0x0C8E80),
            accentSoft: dark ? Color(red: 45/255, green: 212/255, blue: 191/255).opacity(0.13)
                             : Color(red: 15/255, green: 174/255, blue: 156/255).opacity(0.11),
            onAccent:   dark ? Color(hex: 0x04211D) : .white,
            success:    dark ? Color(hex: 0x34D399) : Color(hex: 0x0FAE7B),
            warn:       dark ? Color(hex: 0xE6B34D) : Color(hex: 0xC98A1E),
            danger:     dark ? Color(hex: 0xF08A82) : Color(hex: 0xD9544A)
        )
    }
}

private struct ThemeKey: EnvironmentKey {
    static let defaultValue: AppTheme = .make(true)
}

extension EnvironmentValues {
    var theme: AppTheme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

struct ThemeProvider<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    let content: () -> Content
    init(@ViewBuilder content: @escaping () -> Content) { self.content = content }
    var body: some View {
        let t = AppTheme.make(scheme == .dark)
        content()
            .environment(\.theme, t)
            .background(t.bg.ignoresSafeArea())
            .foregroundStyle(t.text)
    }
}

extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

enum AppFont {
    static func ui(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
    static func title(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}
