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
    @State private var exited = [false, false, false, false]   // 依次飞出
    @State private var fadeOut = false
    @State private var didFinish = false

    // 每支箭头指向自己要飞出的方向；fly 沿箭头指向直线飞出
    private let arrows: [(angle: Double, pos: CGSize, float: CGSize, fly: CGSize)] = [
        (angle: -90, pos: CGSize(width: 0, height: -120), float: CGSize(width: 6, height: -14), fly: CGSize(width: 0, height: -720)),
        (angle: 90,  pos: CGSize(width: 0, height: 120),  float: CGSize(width: -6, height: 14),  fly: CGSize(width: 0, height: 720)),
        (angle: 180, pos: CGSize(width: -120, height: 0), float: CGSize(width: -14, height: 6), fly: CGSize(width: -720, height: 0)),
        (angle: 0,   pos: CGSize(width: 120, height: 0),  float: CGSize(width: 14, height: -6), fly: CGSize(width: 720, height: 0)),
    ]

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            // 四支玻璃箭头，指向各自飞出方向
            ForEach(arrows.indices, id: \.self) { i in
                arrowView(i)
            }

            // 底部进度文字
            VStack {
                Spacer()
                Text(isLoading ? "正在加载照片 \(service.loadedCount) / \(service.totalCount)" : "准备就绪…")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.black.opacity(isLoading ? 0.45 : 0))
                    .opacity(fadeOut ? 0 : 1)
                    .animation(.easeInOut(duration: 0.3), value: isLoading)
            }
            .padding(.bottom, 56)
        }
        .opacity(fadeOut ? 0 : 1)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                floating = true
            }
        }
        .onChange(of: service.isLoading) { _, nowLoading in
            if !nowLoading {
                startExitSequence()
            }
        }
    }

    private func arrowView(_ i: Int) -> some View {
        let a = arrows[i]
        let baseFloat = floating ? a.float : .zero
        let flyOffset = exited[i] ? a.fly : .zero

        return FatArrow()
            .frame(width: 64, height: 74)
            .rotationEffect(.degrees(a.angle))
            .offset(x: a.pos.width + baseFloat.width + flyOffset.width,
                    y: a.pos.height + baseFloat.height + flyOffset.height)
            .opacity(exited[i] ? 0 : 1)
            .animation(.easeOut(duration: 0.9), value: exited[i])
    }

    private func startExitSequence() {
        guard !didFinish else { return }
        didFinish = true
        isLoading = false

        // 一个一个依次沿箭头指向方向直线飞出（0.2s 一个）
        for i in 0..<arrows.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.2) {
                withAnimation(.easeInOut(duration: 0.6)) {
                    exited[i] = true
                }
            }
        }

        // 全程约 0.2*3+0.6 ≈ 1.2s，之后渐隐
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            withAnimation(.easeInOut(duration: 0.4)) { fadeOut = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            onFinished()
        }
    }
}

/// 厚实立体的箭头：靛青渐变 + 顶部高光 + 白描边，圆润精致，默认指向右侧
struct FatArrow: View {
    private let gradient = LinearGradient(
        colors: [
            Color(red: 0.20, green: 0.50, blue: 0.98),
            Color(red: 0.24, green: 0.82, blue: 0.94)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    private let gloss = LinearGradient(
        stops: [
            .init(color: Color.white.opacity(0.35), location: 0),
            .init(color: .white.opacity(0.0), location: 0.60),
            .init(color: .white.opacity(0.0), location: 1)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    private let rim = Color.white.opacity(0.85)
    private let shadow = Color(red: 0.15, green: 0.42, blue: 0.90).opacity(0.32)

    var body: some View {
        ZStack {
            // 主色 + 顶部高光，都裁剪到箭头轮廓，保证渐变与光泽连续无接缝
            Rectangle().fill(gradient).mask(Arrow())
            Rectangle().fill(gloss).mask(Arrow())
            Arrow().stroke(rim, lineWidth: 1.6)
        }
        .frame(width: 58, height: 48)
        .shadow(color: shadow, radius: 9, x: 0, y: 5)
    }
}

/// 单支标准箭头：头部为清晰 V 形，箭杆偏细且带圆润尾端
struct Arrow: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let mid = h / 2
        let hx = w * 0.60        // 头部基底横坐标
        let top = h * 0.06       // 头部上角
        let bot = h * 0.94       // 头部下角
        let sy = h * 0.33        // 箭杆上沿
        let sbot = h * 0.67      // 箭杆下沿
        let tx = w * 0.07        // 箭杆尾端横坐标
        let r = min(w * 0.05, h * 0.12)   // 尾端圆角半径

        var p = Path()
        p.move(to: CGPoint(x: w, y: mid))                  // 尖端
        p.addLine(to: CGPoint(x: hx, y: top))              // 头部上沿
        p.addLine(to: CGPoint(x: hx, y: sy))               // 头→杆台阶
        p.addLine(to: CGPoint(x: tx, y: sy))               // 箭杆上沿
        p.addQuadCurve(to: CGPoint(x: tx, y: sbot),
                       control: CGPoint(x: tx - r, y: mid)) // 圆润尾端
        p.addLine(to: CGPoint(x: hx, y: sbot))             // 箭杆下沿
        p.addLine(to: CGPoint(x: hx, y: bot))              // 头→杆台阶
        p.closeSubpath()                                    // 头部下沿 → 尖端
        return p
    }
}
