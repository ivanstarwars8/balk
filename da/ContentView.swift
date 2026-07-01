import SwiftUI

struct ContentView: View {
    @StateObject private var session = AuthSession()
    @State private var authStep: AuthStep = .email
    @State private var pendingEmail: String = ""

    enum AuthStep { case email, password }

    var body: some View {
        ThemeProvider {
            Group {
                if session.bootstrapping {
                    splash
                } else if session.isAuthenticated {
                    MainTabs()
                        .transition(.opacity)
                } else {
                    authFlow
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: session.isAuthenticated)
            .animation(.easeInOut(duration: 0.2), value: session.bootstrapping)
        }
        .environmentObject(session)
    }

    private var splash: some View {
        VStack(spacing: 16) {
            Mark(size: 56)
            ProgressView()
                .tint(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var authFlow: some View {
        switch authStep {
        case .email:
            LoginEmailView(onContinue: { email in
                pendingEmail = email
                withAnimation { authStep = .password }
            })
        case .password:
            LoginPasswordView(
                email: pendingEmail,
                onBack: { withAnimation { authStep = .email } }
            )
        }
    }
}

struct MainTabs: View {
    @Environment(\.theme) var t
    @EnvironmentObject var session: AuthSession

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView {
            ConnectView()
                .tabItem { Label("Подключение", systemImage: "qrcode") }

            SupportView()
                .tabItem { Label("Поддержка", systemImage: "bubble.left.and.bubble.right.fill") }

            ProfileView()
                .tabItem { Label("Профиль", systemImage: "person.fill") }
        }
        .tint(t.accent)
    }
}

#Preview {
    ContentView()
}
