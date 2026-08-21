import SwiftUI

/// 新手教程：4 步可交互拖拽教学
/// - 首次用户：isFirstRun = true，完成或跳过 → onFinish()（记录已看过教程）
/// - 老用户重看：isFirstRun = false，右上角为"完成"，关闭 → onFinish()
struct TutorialView: View {
    var isFirstRun: Bool
    var onFinish: () -> Void

    @State private var step = 0
    @State private var dragOffset: CGSize = .zero
    @State private var flyingDirection: SwipeDirection?
    @State private var completed = false   // 当前步骤是否已手势成功
    @State private var phase = 0           // 盖戳动画相位

    private let threshold: CGFloat = 80
    private let cardWidth = UIScreen.main.bounds.width - 64

    private let steps: [TutorialStep] = TutorialStep.shortSteps

    var body: some View {
        ZStack {
            // 毛玻璃背景：把当前示例照片放大模糊成背景
            sampleImage
                .scaleEffect(1.45)
                .blur(radius: 38)
                .overlay(Color.black.opacity(0.55))
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                Spacer()
                stepIndicator
                    .padding(.top, 8)
                tutorialCard
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                instructionFooter
                    .padding(.bottom, 40)
            }
        }
        .preferredColorScheme(.dark)
        .animation(.spring(response: 0.5, dampingFraction: 0.6), value: step)
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Text("新手教程")
                .font(.headline)
                .foregroundColor(.white)

            Spacer()

            Button(action: onFinish) {
                Text(isFirstRun ? "跳过" : "完成")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<steps.count, id: \.self) { i in
                Capsule()
                    .fill(i <= step ? Color.blue : Color.white.opacity(0.2))
                    .frame(width: i == step ? 24 : 8, height: 8)
                    .animation(.easeInOut(duration: 0.25), value: step)
            }
        }
    }

    // MARK: - Interactive Card

    private var tutorialCard: some View {
        ZStack {
            sampleImage
                .frame(width: cardWidth, height: cardWidth * 1.35)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.4), radius: 10, x: 0, y: 6)
                // 当前步骤的识别标签（跟手显示）
                .overlay(directionOverlay)
                // 封面分类盖戳演示
                .overlay(alignment: .topTrailing) {
                    if step == 3 && phase > 0 {
                        stampView
                            .padding(14)
                            .scaleEffect(phase == 1 ? 1.0 : 2.2)
                            .rotationEffect(.degrees(phase == 1 ? 0 : -12))
                            .opacity(phase == 1 ? 1 : 0)
                            .animation(.spring(response: 0.45, dampingFraction: 0.5), value: phase)
                    }
                }
                .offset(x: isActive ? dragOffset.width : 0, y: isActive ? dragOffset.height : 0)
                .rotationEffect(
                    .degrees(isActive ? Double(dragOffset.width / 25) : 0)
                )
                .opacity(flyingDirection != nil ? 0.05 : 1)
                .scaleEffect(flyingDirection != nil ? 0.6 : 1)
                .gesture(isActive && flyingDirection == nil ? dragGesture : nil)
        }
        .padding(.vertical, 20)
    }

    private var isActive: Bool {
        !completed && flyingDirection == nil
    }

    private var sampleImage: some View {
        ZStack {
            LinearGradient(
                colors: steps[step].gradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: 14) {
                Image(systemName: "photo.fill")
                    .font(.system(size: 56))
                    .foregroundColor(.white.opacity(0.85))
                Text("示例照片")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }

    // MARK: - Direction Overlay

    @ViewBuilder
    private var directionOverlay: some View {
        let dir = currentDirection
        switch step {
        case 0:
            labelBadge(text: "删除", icon: "trash.fill", color: .red, show: dir == .up)
        case 1:
            labelBadge(text: "保留", icon: "checkmark.circle.fill", color: .green, show: dir == .down)
        case 2:
            labelBadge(text: "收藏", icon: "star.fill", color: .yellow, show: dir == .right)
        case 3:
            labelBadge(text: "待分类", icon: "square.grid.2x2", color: .orange, show: dir == .left)
        default:
            EmptyView()
        }
    }

    private func labelBadge(text: String, icon: String, color: Color, show: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.title3.weight(.bold))
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(color)
        .clipShape(Capsule())
        .opacity(show ? 1 : 0)
        .scaleEffect(show ? 1 : 0.6)
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: show)
    }

    private var stampView: some View {
        ZStack {
            Circle()
                .stroke(Color(red: 0.65, green: 0.08, blue: 0.08), lineWidth: 2.5)
            Text("分类")
                .font(.system(size: 18, weight: .heavy))
                .foregroundColor(Color(red: 0.55, green: 0.05, blue: 0.05))
        }
        .frame(width: 68, height: 68)
    }

    // MARK: - Direction Detection

    private var currentDirection: SwipeDirection? {
        let absX = abs(dragOffset.width)
        let absY = abs(dragOffset.height)
        guard absX > threshold || absY > threshold else { return nil }

        if absY >= absX {
            return dragOffset.height < 0 ? .up : .down
        }
        return dragOffset.width > 0 ? .right : .left
    }

    private var expectedDirection: SwipeDirection {
        switch step {
        case 0: return .up
        case 1: return .down
        case 2: return .right
        case 3: return .left
        default: return .up
        }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                dragOffset = value.translation
            }
            .onEnded { value in
                guard let dir = currentDirection, dir == expectedDirection else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        dragOffset = .zero
                    }
                    return
                }
                completeStep(dir: dir)
            }
    }

    private func completeStep(dir: SwipeDirection) {
        completed = true
        flyingDirection = dir

        if step == 2 { SoundManager.shared.playFavorite() }
        else if step == 3 { playClassifyWithStamp() }
        else if step == 0 { SoundManager.shared.playDelete() }
        else { SoundManager.shared.playKeep() }

        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
            switch dir {
            case .up: dragOffset.height = -UIScreen.main.bounds.height
            case .down: dragOffset.height = UIScreen.main.bounds.height
            case .left: dragOffset.width = -UIScreen.main.bounds.width
            case .right: dragOffset.width = UIScreen.main.bounds.width
            default: break
            }
        }

        let delay = step == 3 ? 1.2 : 0.45
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            if step == 3 {
                // 第 4 步还在盖戳展示，盖戳动画在本步内，用额外时间后进入结束
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    advanceOrFinish()
                }
            } else {
                advanceOrFinish()
            }
        }
    }

    private func playClassifyWithStamp() {
        SoundManager.shared.playClassify()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.5)) {
            phase = 1
        }
    }

    private func advanceOrFinish() {
        if step < steps.count - 1 {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                step += 1
                completed = false
                flyingDirection = nil
                dragOffset = .zero
                phase = 0
            }
        } else {
            onFinish()
        }
    }

    // MARK: - Footer

    private var instructionFooter: some View {
        VStack(spacing: 10) {
            Image(systemName: steps[step].directionIcon)
                .font(.system(size: 30))
                .foregroundColor(.blue)
                .padding(.bottom, 4)

            Text(steps[step].title)
                .font(.title3.weight(.bold))
                .foregroundColor(.white)

            Text(steps[step].instruction)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            if completed {
                Label("做对了！", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.green)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: completed)
    }
}

// MARK: - Tutorial Step Data

struct TutorialStep {
    let gradient: [Color]
    let directionIcon: String
    let title: String
    let instruction: String

    static let shortSteps: [TutorialStep] = [
        TutorialStep(
            gradient: [Color.red.opacity(0.35), Color.orange.opacity(0.45)],
            directionIcon: "arrow.up.circle.fill",
            title: "上滑 = 删除",
            instruction: "把「示例照片」向上滑，删除不需要的照片。删除后可在系统「最近删除」恢复 30 天，别怕误删。"
        ),
        TutorialStep(
            gradient: [Color.green.opacity(0.35), Color.teal.opacity(0.45)],
            directionIcon: "arrow.down.circle.fill",
            title: "下滑 = 保留",
            instruction: "把卡片向下滑，保留你喜欢的照片，它会留在相册里。"
        ),
        TutorialStep(
            gradient: [Color.yellow.opacity(0.35), Color.orange.opacity(0.5)],
            directionIcon: "arrow.right.circle.fill",
            title: "右滑 = 收藏",
            instruction: "向右滑进黄色星星，照片会被标记为「个人收藏」并吸入星星。"
        ),
        TutorialStep(
            gradient: [Color.purple.opacity(0.35), Color.blue.opacity(0.45)],
            directionIcon: "arrow.left.circle.fill",
            title: "左滑 = 待分类 + 盖戳",
            instruction: "向左滑进入待分类。整理完删除后，可在相簿页给照片盖戳分类到指定相簿。"
        ),
    ]
}
