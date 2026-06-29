import SwiftUI

// MARK: - Brand mark
struct Mark: View {
    @Environment(\.theme) var t
    var size: CGFloat = 28
    var color: Color? = nil
    var body: some View {
        let c = color ?? t.accent
        let sw = size * 0.085
        ZStack {
            Circle().stroke(c.opacity(0.35), lineWidth: sw).frame(width: size * 13/16, height: size * 13/16)
            Circle().stroke(c, lineWidth: sw).frame(width: size * 7.5/16, height: size * 7.5/16)
            Circle().fill(c).frame(width: size * 2.4/16, height: size * 2.4/16)
        }
        .frame(width: size, height: size)
    }
}

struct Wordmark: View {
    @Environment(\.theme) var t
    var size: CGFloat = 17
    var color: Color? = nil
    var body: some View {
        HStack(spacing: 9) {
            Mark(size: size * 1.25, color: color)
            Text("BADRIMGU")
                .font(AppFont.ui(size, .semibold))
                .tracking(size * 0.16)
                .foregroundStyle(color ?? t.text)
        }
    }
}

// MARK: - Icon (SF Symbol mapping)
struct QXIcon: View {
    let name: String
    var size: CGFloat = 20
    var color: Color = .primary
    var weight: Font.Weight = .regular

    private var symbol: String {
        switch name {
        case "power": return "power"
        case "gear": return "gearshape"
        case "chevR": return "chevron.right"
        case "chevL": return "chevron.left"
        case "chevDown": return "chevron.down"
        case "search": return "magnifyingglass"
        case "globe": return "globe"
        case "shield": return "shield"
        case "shieldCheck": return "checkmark.shield"
        case "layers": return "square.stack.3d.up"
        case "grid": return "qrcode.viewfinder"
        case "cloud": return "cloud"
        case "key": return "key"
        case "doc": return "doc.text"
        case "link": return "link"
        case "user": return "person.fill"
        case "refresh": return "arrow.clockwise"
        case "eye": return "eye"
        case "eyeOff": return "eye.slash"
        case "lock": return "lock"
        case "mail": return "envelope"
        case "check": return "checkmark"
        case "arrowR": return "arrow.right"
        case "sparkle": return "sparkles"
        case "translate": return "character.bubble"
        case "bolt": return "bolt.fill"
        case "download": return "arrow.down.to.line"
        case "devices": return "laptopcomputer.and.iphone"
        case "card": return "creditcard.fill"
        case "logout": return "rectangle.portrait.and.arrow.right"
        case "plus": return "plus"
        case "qr": return "qrcode"
        case "trash": return "trash"
        case "bell": return "bell"
        case "chat": return "bubble.left.and.bubble.right.fill"
        case "send": return "paperplane.fill"
        case "headset": return "headphones"
        case "clock": return "clock"
        case "moon": return "moon.fill"
        case "sun": return "sun.max.fill"
        default: return "questionmark"
        }
    }

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size, weight: weight))
            .foregroundStyle(color)
    }
}

// MARK: - Pill
struct Pill: View {
    @Environment(\.theme) var t
    let text: String
    var tone: Tone = .accent
    var solid: Bool = false

    enum Tone { case accent, success, warn, muted }

    var body: some View {
        let col: Color = {
            switch tone {
            case .accent: return t.accent
            case .success: return t.success
            case .warn: return t.warn
            case .muted: return t.muted
            }
        }()
        let bg: Color = solid ? col : (tone == .muted ? t.surface2 : t.accentSoft)
        let fg: Color = solid ? t.onAccent : col

        Text(text.uppercased())
            .font(AppFont.mono(10.5, .semibold))
            .tracking(0.6)
            .foregroundStyle(fg)
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .background(Capsule().fill(bg))
            .overlay(
                Capsule().strokeBorder(solid ? .clear : col.opacity(0.2), lineWidth: 1)
            )
    }
}

// MARK: - Buttons
struct PrimaryButton: View {
    @Environment(\.theme) var t
    let title: String
    var icon: String? = nil
    var kind: Kind = .primary
    var fullWidth: Bool = true
    var action: () -> Void = {}

    enum Kind { case primary, secondary, ghost }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                if let icon { QXIcon(name: icon, size: 19, color: fg, weight: .medium) }
                Text(title).font(AppFont.ui(16, .semibold)).tracking(0.2)
            }
            .foregroundStyle(fg)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .frame(height: 54)
            .padding(.horizontal, 22)
            .background(bg)
            .overlay(
                RoundedRectangle(cornerRadius: 15).strokeBorder(border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 15))
        }
        .buttonStyle(.plain)
    }

    private var bg: Color {
        switch kind {
        case .primary: return t.accent
        case .secondary: return t.surface
        case .ghost: return .clear
        }
    }
    private var fg: Color {
        switch kind {
        case .primary: return t.onAccent
        case .secondary: return t.text
        case .ghost: return t.muted
        }
    }
    private var border: Color {
        kind == .secondary ? t.lineStrong : .clear
    }
}

// MARK: - Input field
struct InputField: View {
    @Environment(\.theme) var t
    var icon: String? = nil
    var label: String? = nil
    var placeholder: String = ""
    @Binding var value: String
    var mono: Bool = false
    var focused: Bool = false
    var secure: Bool = false
    var trailing: AnyView? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let label {
                Text(label.uppercased())
                    .font(AppFont.ui(11.5, .semibold))
                    .tracking(1)
                    .foregroundStyle(t.faint)
            }
            HStack(spacing: 11) {
                if let icon {
                    QXIcon(name: icon, size: 19, color: focused ? t.accent : t.faint, weight: .medium)
                }
                Group {
                    if secure {
                        SecureField(placeholder, text: $value)
                    } else {
                        TextField(placeholder, text: $value)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                }
                .font(mono ? AppFont.mono(14) : AppFont.ui(15.5))
                .foregroundStyle(t.text)
                .tint(t.accent)
                if let trailing { trailing }
            }
            .padding(.horizontal, 15)
            .frame(height: 54)
            .background(t.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(focused ? t.accent : t.line, lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}

// MARK: - iOS-style toggle
struct AppToggle: View {
    @Environment(\.theme) var t
    @Binding var isOn: Bool
    var body: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            RoundedRectangle(cornerRadius: 14)
                .fill(isOn ? t.accent : t.surface2)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(isOn ? t.accent : t.lineStrong, lineWidth: 1)
                )
                .frame(width: 46, height: 28)
            Circle()
                .fill(isOn ? t.onAccent : (t.dark ? Color(white: 0.91) : .white))
                .frame(width: 22, height: 22)
                .padding(2)
                .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
        }
        .frame(width: 46, height: 28)
        .onTapGesture { withAnimation(.easeOut(duration: 0.2)) { isOn.toggle() } }
    }
}

// MARK: - Group card
struct GroupCard<Content: View>: View {
    @Environment(\.theme) var t
    var label: String? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            if let label {
                Text(label.uppercased())
                    .font(AppFont.ui(11.5, .semibold))
                    .tracking(1.2)
                    .foregroundStyle(t.faint)
                    .padding(.horizontal, 6)
            }
            VStack(spacing: 0) { content() }
                .background(t.surface)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18).strokeBorder(t.line, lineWidth: 1)
                )
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 22)
    }
}

// MARK: - Row
struct RowItem: View {
    @Environment(\.theme) var t
    var icon: String? = nil
    var title: String
    var subtitle: String? = nil
    var value: String? = nil
    var accent: Bool = false
    var last: Bool = false
    var chev: Bool = false
    var toggleOn: Binding<Bool>? = nil
    var trailing: AnyView? = nil
    var onTap: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 14) {
            if let icon {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(accent ? t.accentSoft : t.surface2)
                        .frame(width: 36, height: 36)
                    QXIcon(name: icon, size: 18, color: accent ? t.accent : t.muted, weight: .medium)
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(AppFont.ui(15.5, .medium))
                    .foregroundStyle(t.text)
                if let subtitle {
                    Text(subtitle)
                        .font(AppFont.ui(12.5))
                        .foregroundStyle(t.muted)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
            if let value {
                Text(value)
                    .font(AppFont.mono(12.5))
                    .foregroundStyle(t.muted)
                    .tracking(0.2)
            }
            if let toggleOn { AppToggle(isOn: toggleOn) }
            if let trailing { trailing }
            if chev {
                QXIcon(name: "chevR", size: 17, color: t.faint, weight: .semibold)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
        .overlay(alignment: .bottom) {
            if !last {
                Rectangle().fill(t.line).frame(height: 1)
            }
        }
    }
}

// MARK: - Stat tile
struct StatTile: View {
    @Environment(\.theme) var t
    let icon: String
    let label: String
    let value: String
    var unit: String? = nil
    var tone: Color? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) {
                QXIcon(name: icon, size: 15, color: tone ?? t.muted, weight: .medium)
                Text(label)
                    .font(AppFont.ui(11.5, .medium))
                    .tracking(0.3)
                    .foregroundStyle(t.muted)
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(AppFont.mono(21, .medium))
                    .foregroundStyle(t.text)
                    .tracking(0.2)
                if let unit {
                    Text(unit).font(AppFont.mono(11)).foregroundStyle(t.faint)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(t.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 15).strokeBorder(t.line, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 15))
    }
}

// MARK: - Flag
struct Flag: View {
    let code: String
    var size: CGFloat = 22

    private var stripes: [Color] {
        switch code {
        case "NL": return [Color(hex: 0xAE1C28), .white, Color(hex: 0x21468B)]
        case "DE": return [.black, Color(hex: 0xDD0000), Color(hex: 0xFFCE00)]
        case "US": return [Color(hex: 0xB22234), .white, Color(hex: 0x3C3B6E)]
        case "JP": return [.white, .white, Color(hex: 0xBC002D)]
        case "SG": return [Color(hex: 0xEF3340), Color(hex: 0xEF3340), .white]
        case "GB": return [Color(hex: 0x012169), .white, Color(hex: 0xC8102E)]
        case "SE": return [Color(hex: 0x006AA7), Color(hex: 0xFECC00), Color(hex: 0x006AA7)]
        case "CH": return [Color(hex: 0xD52B1E), .white, Color(hex: 0xD52B1E)]
        case "FR": return [Color(hex: 0x0055A4), .white, Color(hex: 0xEF4135)]
        case "FI": return [.white, Color(hex: 0x003580), .white]
        default: return [.gray, .gray.opacity(0.7), .gray]
        }
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { i in
                    Rectangle().fill(stripes[i])
                }
            }
            if code == "JP" {
                Circle()
                    .fill(Color(hex: 0xBC002D))
                    .frame(width: size * 0.46, height: size * 0.46)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6).strokeBorder(Color.black.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Faux QR
struct FauxQR: View {
    @Environment(\.theme) var t
    var size: CGFloat = 168
    var darkOnLight: Bool = true   // black on white for scanning vibe

    var body: some View {
        Canvas { ctx, _ in
            let n = 21
            let cell = size / CGFloat(n)
            let fg: Color = darkOnLight ? .black : t.text
            var seed: UInt32 = 7
            func rnd() -> Double {
                seed = (seed &* 1103515245 &+ 12345) & 0x7fffffff
                return Double(seed) / Double(0x7fffffff)
            }
            for y in 0..<n {
                for x in 0..<n {
                    let finder = (x < 7 && y < 7) || (x >= n - 7 && y < 7) || (x < 7 && y >= n - 7)
                    if finder { continue }
                    if rnd() > 0.52 {
                        let rect = CGRect(x: CGFloat(x) * cell, y: CGFloat(y) * cell, width: cell, height: cell)
                        ctx.fill(Path(roundedRect: rect, cornerRadius: cell * 0.2), with: .color(fg))
                    }
                }
            }
            for (ex, ey) in [(0, 0), (n - 7, 0), (0, n - 7)] {
                let outer = CGRect(x: CGFloat(ex) * cell, y: CGFloat(ey) * cell,
                                   width: cell * 7, height: cell * 7)
                ctx.stroke(Path(roundedRect: outer, cornerRadius: cell * 1.6),
                           with: .color(fg), lineWidth: cell)
                let inner = CGRect(x: CGFloat(ex) * cell + cell * 2, y: CGFloat(ey) * cell + cell * 2,
                                   width: cell * 3, height: cell * 3)
                ctx.fill(Path(roundedRect: inner, cornerRadius: cell * 0.9), with: .color(fg))
            }
        }
        .frame(width: size, height: size)
    }
}
