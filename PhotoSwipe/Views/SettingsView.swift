import SwiftUI

struct SettingsView: View {
    @ObservedObject var service: PhotoService

    @State private var showTutorial = false
    @AppStorage("hasCompletedTutorial") private var hasCompletedTutorial = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Title
                Text("设置")
                    .font(.title.weight(.bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                // Member placeholder card
                memberCard

                // Settings sections
                settingsSection

                // App info
                appInfo

                Spacer(minLength: 40)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .fullScreenCover(isPresented: $showTutorial) {
            TutorialView(
                isFirstRun: false,
                onFinish: { showTutorial = false }
            )
        }
    }

    // MARK: - Member Card

    private var memberCard: some View {
        ZStack(alignment: .leading) {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.15, green: 0.1, blue: 0.25),
                    Color(red: 0.08, green: 0.08, blue: 0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "crown.fill")
                        .font(.title3)
                        .foregroundColor(.yellow.opacity(0.8))
                    Text("留光会员")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Text("即将推出")
                        .font(.caption2.weight(.medium))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.white.opacity(0.1)))
                }

                Text("解锁无限整理、iCloud 同步等高级功能")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(20)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
        .padding(.horizontal, 20)
    }

    // MARK: - Settings Section

    private var settingsSection: some View {
        VStack(spacing: 0) {
            // Tutorial replay
            Button {
                showTutorial = true
            } label: {
                HStack {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 32)
                    Text("新手教程")
                        .font(.body)
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.3))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .buttonStyle(.plain)

            Divider()
                .background(Color.white.opacity(0.08))
                .padding(.leading, 52)

            // Privacy
            Button {
                if let url = URL(string: "https://trae-api-cn.mchost.guru/api/ide/v1/privacy-policy") {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack {
                    Image(systemName: "lock.fill")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 32)
                    Text("隐私政策")
                        .font(.body)
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.3))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .buttonStyle(.plain)
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
        )
        .padding(.horizontal, 20)
    }

    // MARK: - App Info

    private var appInfo: some View {
        VStack(spacing: 4) {
            Text("留光")
                .font(.caption.weight(.medium))
                .foregroundColor(.white.opacity(0.4))
            Text("版本 \(appVersion)")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.3))
        }
        .padding(.top, 20)
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return version
    }
}
