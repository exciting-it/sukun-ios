import SukunKit
import SwiftUI

@main
struct SukunApp: App {
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .tint(Palette.accent)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: model.sceneDidBecomeActive()
            case .background: BackgroundRefresh.schedule()
            default: break
            }
        }
        .backgroundTask(.appRefresh(BackgroundRefresh.identifier)) {
            await BackgroundRefresh.perform()
        }
    }
}

enum AppTab: String, Hashable {
    case today, qibla, settings
}

struct RootView: View {
    @Environment(AppModel.self) private var model
    @State private var tab: AppTab = .today

    var body: some View {
        Group {
            if model.location == nil {
                LocationSetupView()
            } else {
                TabView(selection: $tab) {
                    TodayView()
                        .tabItem { Label("Today", systemImage: "clock") }
                        .tag(AppTab.today)
                    QiblaView()
                        .tabItem { Label("Qibla", systemImage: "location.north.circle") }
                        .tag(AppTab.qibla)
                    SettingsView()
                        .tabItem { Label("Settings", systemImage: "slider.horizontal.3") }
                        .tag(AppTab.settings)
                }
            }
        }
        // Widgets deep-link with sukun://today and sukun://qibla.
        .onOpenURL { url in
            guard url.scheme == "sukun", let target = url.host().flatMap(AppTab.init(rawValue:)) else { return }
            tab = target
        }
    }
}
