import SwiftUI
import Photos

struct RootView: View {
    @StateObject private var service = PhotoService()
    @State private var showOnboarding = true
    @State private var showOnboardingTutorial = false
    @State private var showPermissionDenied = false
    @State private var loadFinished = false

    private var hasCompletedTutorial: Bool {
        UserDefaults.standard.bool(forKey: "hasCompletedTutorial")
    }

    var body: some View {
        Group {
            if showPermissionDenied {
                PermissionDeniedView(isLimited: service.isLimited)
            } else if showOnboarding {
                OnboardingView(
                    onStart: startOrganizing,
                    onShowTutorial: { showOnboardingTutorial = true }
                )
            } else if !loadFinished {
                LoadingView(service: service) {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        loadFinished = true
                    }
                }
            } else if !hasCompletedTutorial {
                TutorialView(
                    isFirstRun: true,
                    onFinish: {
                        UserDefaults.standard.set(true, forKey: "hasCompletedTutorial")
                    }
                )
            } else {
                SwipeView(service: service)
            }
        }
        // 「新手教程」按钮：以全屏浮现的方式播放教程，结束后回到本页
        .fullScreenCover(isPresented: $showOnboardingTutorial) {
            TutorialView(
                isFirstRun: true,
                onFinish: {
                    UserDefaults.standard.set(true, forKey: "hasCompletedTutorial")
                    showOnboardingTutorial = false
                }
            )
        }
        .task {
            // 只读取当前权限状态，不在启动时加载照片
            service.checkPermission()
        }
    }

    // 「开始整理」：申请权限 → 挂载加载页 → 加载照片 → 进入主流程
    private func startOrganizing() {
        Task {
            await service.requestPermission()
            guard service.hasPermission else {
                showOnboarding = false
                showPermissionDenied = true
                return
            }

            // 先挂载 LoadingView，再开始加载，确保其能监听到 isLoading 变化并退出
            withAnimation(.easeInOut(duration: 0.4)) {
                showOnboarding = false
            }
            // 等一拍让加载页完成渲染，再触发加载
            try? await Task.sleep(nanoseconds: 80_000_000)

            let saved = UserDefaults.standard.array(forKey: "swipedPhotoIds") as? [String] ?? []
            await service.loadPhotos(swipedIds: Set(saved))
        }
    }
}

struct OnboardingView: View {
    var onStart: () -> Void
    var onShowTutorial: () -> Void

    private let bgTop = Color(red: 0.965, green: 0.957, blue: 0.937)   // 暖白
    private let bgBottom = Color(red: 0.878, green: 0.878, blue: 0.858) // 浅烟灰
    private let ink = Color(red: 0.16, green: 0.16, blue: 0.16)        // 深炭灰
    private let inkSoft = Color(red: 0.42, green: 0.41, blue: 0.39)    // 暖灰
    private let circleBg = Color.black.opacity(0.05)

    @State private var revealCount = 0       // 逐行渐入：已经显示到第几块
    @State private var floatMove = false     // 背景光斑浮动

    var body: some View {
        ZStack {
            // 灰白背景
            LinearGradient(
                colors: [bgTop, bgBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // 背景浮动光斑
            GeometryReader { geo in
                floatingOrb(size: 320, tint: Color(red: 0.92, green: 0.90, blue: 0.84).opacity(0.5))
                    .position(x: geo.size.width * 0.16, y: geo.size.height * 0.20)
                floatingOrb(size: 280, tint: Color(red: 0.82, green: 0.88, blue: 0.90).opacity(0.45))
                    .position(x: geo.size.width * 0.85, y: geo.size.height * 0.76)
            }
            .ignoresSafeArea()

            // 内容（逐块渐入）
            VStack(spacing: 18) {
                Spacer()

                revealedBlock(0) { brandBlock }

                revealedBlock(1) { featureList }
                    .padding(.horizontal, 32)

                Spacer()

                revealedBlock(2) { buttonStack }
                    .padding(.horizontal, 40)

                revealedBlock(3) { trustFooter }
            }
        }
        .preferredColorScheme(.light)
        .onAppear {
            floatMove = true
            runReveal()
        }
    }

    // MARK: - 内容分区

    private var brandBlock: some View {
        VStack(spacing: 14) {
            Image("AppIconLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 132, height: 132)
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                .shadow(color: ink.opacity(0.16), radius: 14, x: 0, y: 8)

            Text("留光")
                .font(.largeTitle.weight(.bold))
                .foregroundColor(ink)

            Text("手指一滑，只留下值得的时光～")
                .font(.subheadline)
                .italic()
                .foregroundColor(inkSoft.opacity(0.9))
        }
    }

    private var featureList: some View {
        VStack(spacing: 10) {
            tipRow(icon: "arrow.up", color: .red, title: "上滑", desc: "删除不需要的照片")
            tipRow(icon: "arrow.down", color: .green, title: "下滑", desc: "保留喜欢的照片")
            tipRow(icon: "arrow.right", color: .yellow, title: "右滑", desc: "收藏喜欢的照片")
            tipRow(icon: "arrow.left", color: .orange, title: "左滑", desc: "加入待分类，可放到指定相簿")
            tipRow(icon: "lock.fill", color: .blue, title: "隐私安全", desc: "所有操作仅在本地完成")
        }
    }

    private var buttonStack: some View {
        VStack(spacing: 12) {
            Button(action: onStart) {
                Text("开始整理")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.black.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
            }

            Button(action: onShowTutorial) {
                Text("新手教程")
                    .font(.headline)
                    .foregroundColor(ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.white.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(ink.opacity(0.25), lineWidth: 1.5)
                    )
            }
        }
    }

    private var trustFooter: some View {
        Text("数据仅在本机处理 · 删除可在「最近删除」恢复")
            .font(.caption2)
            .foregroundColor(inkSoft.opacity(0.75))
            .multilineTextAlignment(.center)
            .padding(.top, 2)
            .padding(.bottom, 18)
    }

    // MARK: - 动效

    private func floatingOrb(size: CGFloat, tint: Color) -> some View {
        Circle()
            .fill(tint)
            .frame(width: size, height: size)
            .blur(radius: 55)
            .offset(x: floatMove ? -26 : 22, y: floatMove ? -18 : 16)
            .animation(.easeInOut(duration: 7).repeatForever(autoreverses: true), value: floatMove)
    }

    private func revealedBlock<Content: View>(_ i: Int, @ViewBuilder content: () -> Content) -> some View {
        content()
            .opacity(revealCount > i ? 1 : 0)
            .offset(y: revealCount > i ? 0 : 22)
            .animation(.easeOut(duration: 0.5), value: revealCount)
    }

    private func runReveal() {
        revealCount = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) { revealCount = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { revealCount = 2 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.60) { revealCount = 3 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.82) { revealCount = 4 }
    }

    private func tipRow(icon: String, color: Color, title: String, desc: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 44, height: 44)
                .background(Circle().fill(circleBg))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(ink)
                Text(desc)
                    .font(.subheadline)
                    .foregroundColor(inkSoft.opacity(0.9))
            }
            Spacer()
        }
    }
}

struct PermissionDeniedView: View {
    var isLimited: Bool

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: isLimited ? "photo.badge.exclamationmark" : "lock.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text(isLimited ? "需要完全访问权限" : "需要相册权限")
                .font(.title2.weight(.medium))

            Text(isLimited
                ? "留光 需要「完全访问」权限才能直接删除照片。请在设置中选择「允许所有照片」。"
                : "请在设置中允许 留光 访问你的相册")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button("去设置") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
    }
}

struct LoadingView: View {
    @ObservedObject var service: PhotoService
    var onFinished: () -> Void

    @State private var isLoading = true
    @State private var floating = false
    @State private var exited = [false, false, false, false]
    @State private var fadeOut = false
    @State private var didFinish = false
    @State private var pulse = false

    // 每支箭头指向自己要飞出的方向
    private let arrows: [(angle: Double, pos: CGSize, float: CGSize, fly: CGSize)] = [
        (angle: -90, pos: CGSize(width: 0, height: -100), float: CGSize(width: 4, height: -10), fly: CGSize(width: 0, height: -600)),
        (angle: 90,  pos: CGSize(width: 0, height: 100),  float: CGSize(width: -4, height: 10),  fly: CGSize(width: 0, height: 600)),
        (angle: 180, pos: CGSize(width: -100, height: 0), float: CGSize(width: -10, height: 4), fly: CGSize(width: -600, height: 0)),
        (angle: 0,   pos: CGSize(width: 100, height: 0),  float: CGSize(width: 10, height: -4), fly: CGSize(width: 600, height: 0)),
    ]

    var body: some View {
        ZStack {
            // 深色背景
            Color.black.ignoresSafeArea()

            // 中心柔和光晕
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.08),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 10,
                        endRadius: 180
                    )
                )
                .scaleEffect(pulse ? 1.1 : 0.9)
                .opacity(pulse ? 1 : 0.6)
                .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: pulse)

            // 四支箭头
            ForEach(arrows.indices, id: \.self) { i in
                arrowView(i)
            }

            // 中心图标
            Image(systemName: "photo.stack")
                .font(.system(size: 38, weight: .light))
                .foregroundColor(.white.opacity(0.6))
                .opacity(fadeOut ? 0 : 1)
                .animation(.easeInOut(duration: 0.4), value: fadeOut)

            // 底部进度
            VStack {
                Spacer()
                VStack(spacing: 12) {
                    // 进度环
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.1), lineWidth: 2)
                            .frame(width: 36, height: 36)

                        Circle()
                            .trim(from: 0, to: progressValue)
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.8), .white.opacity(0.4)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                style: StrokeStyle(lineWidth: 2, lineCap: .round)
                            )
                            .frame(width: 36, height: 36)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeOut(duration: 0.2), value: progressValue)
                    }
                    .opacity(fadeOut ? 0 : 1)

                    Text(statusText)
                        .font(.caption.weight(.medium))
                        .foregroundColor(.white.opacity(0.5))
                        .opacity(fadeOut ? 0 : 1)
                        .animation(.easeInOut(duration: 0.3), value: isLoading)
                }
            }
            .padding(.bottom, 80)
        }
        .opacity(fadeOut ? 0 : 1)
        .preferredColorScheme(.dark)
        .onAppear {
            pulse = true
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                floating = true
            }
        }
        .onChange(of: service.isLoading) { _, nowLoading in
            if !nowLoading {
                startExitSequence()
            }
        }
    }

    private var progressValue: Double {
        guard service.totalCount > 0 else { return 0 }
        return Double(service.loadedCount) / Double(service.totalCount)
    }

    private var statusText: String {
        if isLoading {
            return "正在整理照片 \(service.loadedCount) / \(service.totalCount)"
        } else {
            return "准备就绪"
        }
    }

    private func arrowView(_ i: Int) -> some View {
        let a = arrows[i]
        let baseFloat = floating ? a.float : .zero
        let flyOffset = exited[i] ? a.fly : .zero

        return SlimArrow()
            .frame(width: 28, height: 14)
            .rotationEffect(.degrees(a.angle))
            .offset(x: a.pos.width + baseFloat.width + flyOffset.width,
                    y: a.pos.height + baseFloat.height + flyOffset.height)
            .opacity(exited[i] ? 0 : 0.7)
            .animation(.easeOut(duration: 0.7), value: exited[i])
    }

    private func startExitSequence() {
        guard !didFinish else { return }
        didFinish = true
        isLoading = false

        for i in 0..<arrows.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.15) {
                withAnimation(.easeOut(duration: 0.8)) {
                    exited[i] = true
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.easeInOut(duration: 0.5)) { fadeOut = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            onFinished()
        }
    }
}

/// 简约精致的箭头：线性渐变，纤细优雅，指向右侧
struct SlimArrow: View {
    private let gradient = LinearGradient(
        colors: [
            Color.white.opacity(0.5),
            Color.white.opacity(0.9)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    var body: some View {
        ArrowShape()
            .fill(gradient)
            .shadow(color: .white.opacity(0.3), radius: 6, x: 0, y: 0)
    }
}

/// 纤细箭头形状
struct ArrowShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let midY = h / 2

        var path = Path()
        path.move(to: CGPoint(x: 0, y: midY))
        path.addLine(to: CGPoint(x: w * 0.65, y: midY))
        path.addLine(to: CGPoint(x: w * 0.65, y: 0))
        path.addLine(to: CGPoint(x: w, y: midY))
        path.addLine(to: CGPoint(x: w * 0.65, y: h))
        path.addLine(to: CGPoint(x: w * 0.65, y: midY))
        path.closeSubpath()
        return path
    }
}
