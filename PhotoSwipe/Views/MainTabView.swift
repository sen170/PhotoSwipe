import SwiftUI

struct MainTabView: View {
    @StateObject var service: PhotoService

    var body: some View {
        TabView {
            MonthlyView(service: service)
                .tabItem {
                    Label("月历", systemImage: "calendar")
                }

            RandomView(service: service)
                .tabItem {
                    Label("随机", systemImage: "shuffle")
                }

            SettingsView(service: service)
                .tabItem {
                    Label("设置", systemImage: "gearshape")
                }
        }
        .preferredColorScheme(.dark)
    }
}
