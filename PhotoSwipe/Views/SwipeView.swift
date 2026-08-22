import SwiftUI
import UIKit

struct SwipeView: View {
    @ObservedObject var service: PhotoService

    @State private var dragOffset: CGSize = .zero
    @State private var currentIndex: Int = 0
    @State private var actions: [SwipeAction] = []
    @State private var flyingDirection: SwipeDirection = .idle
    @State private var showDeleteConfirm = false
    @State private var swipedIds: Set<String> = []
    @State private var favoriteIds: Set<String> = []
    @State private var classifyIds: Set<String> = []
    @State private var classifySession: ClassifySession?
    @State private var showEarlyFinishConfirm = false
    @State private var showTutorial = false
    @State private var showLoadingOverlay = false
    @State private var showShareSheet = false
    @State private var isPhotoZoomed = false

    private let swipeThreshold: CGFloat = 100
    private let swipedKey = "swipedPhotoIds"
    private let favoriteKey = "favoritePhotoIds"
    private let classifyKey = "classifyPhotoIds"

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            gradientBackground

            if service.photos.isEmpty {
                emptyState
            } else if currentIndex >= service.photos.count {
                resultView
            } else {
                ZStack(alignment: .center) {
                    cardStack

                    // 顶部按钮栏
                    VStack {
                        topBar
                            .padding(.top, 16)
                        Spacer()
                    }

                    // 底部按钮栏
                    VStack {
                        Spacer()
                        bottomBar
                            .padding(.bottom, 24)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            loadSwipedState()
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: dragOffset)
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: currentIndex)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: service.pendingDeletes.count)
        .animation(.easeInOut(duration: 0.2), value: actions.count)
        .animation(.easeInOut(duration: 0.2), value: flyingDirection)
        .fullScreenCover(isPresented: $showTutorial) {
            TutorialView(
                isFirstRun: false,
                onFinish: { showTutorial = false }
            )
        }
        .alert("提前结束整理？", isPresented: $showEarlyFinishConfirm) {
            Button("提前结束", role: .destructive) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    currentIndex = service.photos.count
                }
            }
            Button("继续整理", role: .cancel) {}
        } message: {
            Text("已整理的 \(actions.count) 张照片将保留处理，剩余照片下次继续。")
        }
        .alert("确认删除？", isPresented: $showDeleteConfirm) {
            Button("删除", role: .destructive) {
                Task {
                    _ = await service.batchDelete()
                    actions.removeAll { $0.direction == .up }
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("确定要删除选中的 \(service.pendingDeletes.count) 张照片吗？删除后无法恢复。")
        }
        .sheet(item: $classifySession) { session in
            AlbumClassificationView(photos: session.photos, service: service)
        }
        .sheet(isPresented: $showShareSheet) {
            if currentIndex < service.photos.count,
               let image = service.photos[currentIndex].uiImage {
                ShareSheet(items: [image])
            }
        }
        .overlay {
            if showLoadingOverlay {
                LoadingView(
                    service: service,
                    onFinished: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showLoadingOverlay = false
                        }
                    }
                )
                .zIndex(100)
            }
        }
    }

    // MARK: - 模糊照片背景（苹果壁纸风格）

    @ViewBuilder
    private var gradientBackground: some View {
        if currentIndex < service.photos.count,
           let image = service.photos[currentIndex].thumbnailImage {
            GeometryReader { geo in
                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .scaleEffect(1.2)
                        .blur(radius: 40, opaque: true)
                        .opacity(0.7)

                    // 暗色叠加，保证内容清晰
                    Color.black.opacity(0.4)

                    // 顶部渐暗，增加层次感
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.25),
                            Color.clear,
                            Color.black.opacity(0.15)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .ignoresSafeArea()
            .id(currentIndex)
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.45), value: currentIndex)
        }
    }

    // MARK: - Top Bar

    private var canUndo: Bool {
        flyingDirection == .idle && !actions.isEmpty && currentIndex < service.photos.count
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            Button(action: { showEarlyFinishConfirm = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "flag.checkered")
                    Text("提前结束")
                }
                .font(.subheadline.weight(.medium))
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                )
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                )
            }

            Spacer()

            if service.pendingDeletes.count > 0 {
                Button(action: { showDeleteConfirm = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "trash.fill")
                        Text("\(service.pendingDeletes.count)")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(
                        Capsule()
                            .fill(Color.red.opacity(0.7))
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                    )
                }
                .transition(.opacity.combined(with: .scale))
            }

            Button(action: { showTutorial = true }) {
                Image(systemName: "questionmark")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.08))
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                    )
            }

            Button(action: { showShareSheet = true }) {
                Image(systemName: "square.and.arrow.up")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.08))
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                    )
            }
        }
        .padding(.horizontal, 20)
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            if canUndo {
                Button(action: undoLastAction) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.white.opacity(0.75))
                        .frame(width: 42, height: 42)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.08))
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                        )
                }
                .transition(.scale.combined(with: .opacity))
            }

            Text("\(currentIndex + 1) / \(service.photos.count)")
                .font(.caption.weight(.medium))
                .foregroundColor(.white.opacity(0.45))
                .monospacedDigit()

            Spacer()
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Card Stack

    private var cardStack: some View {
        ZStack {
            ForEach(
                Array(service.photos.enumerated().reversed()),
                id: \.element.id
            ) { index, photo in
                let depth = index - currentIndex
                if depth == 0 && !swipedIds.contains(photo.id) {
                    PhotoCardView(
                        photo: photo,
                        dragOffset: $dragOffset,
                        isZoomed: $isPhotoZoomed,
                        onSwipeUp: { handleSwipe(.up) },
                        onSwipeDown: { handleSwipe(.down) },
                        onSwipeLeft: { handleSwipe(.left) },
                        onSwipeRight: { handleSwipe(.right) }
                    )
                    .frame(width: fittedCardWidth(photo), height: fittedCardHeight(photo))
                    .scaleEffect(flyScale(for: depth))
                    .offset(x: flyOffset(for: depth).width, y: flyOffset(for: depth).height)
                    .opacity(flyOpacity(for: depth))
                    .zIndex(10)
                    .transition(.opacity)
                }
            }
        }
    }

    private var cardMaxWidth: CGFloat {
        UIScreen.main.bounds.width - 40
    }

    private var cardMaxHeight: CGFloat {
        UIScreen.main.bounds.height * 0.67
    }

    private func fittedCardWidth(_ photo: PhotoItem) -> CGFloat {
        let ratio = clampedRatio(photo.aspectRatio)
        if ratio >= 1 {
            let w = cardMaxWidth
            let h = w / ratio
            return h <= cardMaxHeight ? w : cardMaxHeight * ratio
        } else {
            let h = cardMaxHeight
            let w = h * ratio
            return w <= cardMaxWidth ? w : cardMaxWidth
        }
    }

    private func fittedCardHeight(_ photo: PhotoItem) -> CGFloat {
        let ratio = clampedRatio(photo.aspectRatio)
        if ratio >= 1 {
            let w = fittedCardWidth(photo)
            return w / ratio
        } else {
            return cardMaxHeight
        }
    }

    private func clampedRatio(_ r: CGFloat) -> CGFloat {
        min(max(r, 0.5), 2.4)
    }

    // MARK: - Empty & Result

    private var currentGroupDeletePhotos: [PhotoItem] {
        let ids = Set(actions.filter { $0.direction == .up }.map { $0.photoId })
        return service.photos.filter { ids.contains($0.id) }
    }

    private var currentGroupKeepPhotos: [PhotoItem] {
        let ids = Set(actions.filter { $0.direction == .down }.map { $0.photoId })
        return service.photos.filter { ids.contains($0.id) }
    }

    private var currentGroupFavoritePhotos: [PhotoItem] {
        let ids = Set(actions.filter { $0.direction == .right }.map { $0.photoId })
        return service.photos.filter { ids.contains($0.id) }
    }

    private var currentGroupClassifyPhotos: [PhotoItem] {
        let ids = Set(actions.filter { $0.direction == .left }.map { $0.photoId })
        return service.photos.filter { ids.contains($0.id) }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 54))
                .foregroundColor(.white.opacity(0.5))
            Text("相册是空的")
                .font(.title3.weight(.medium))
                .foregroundColor(.white.opacity(0.6))
        }
    }

    private var resultView: some View {
        ResultView(
            deletePhotos: currentGroupDeletePhotos,
            keepPhotos: currentGroupKeepPhotos,
            favoritePhotos: currentGroupFavoritePhotos,
            classifyPhotos: currentGroupClassifyPhotos,
            onConfirmDelete: {
                Task {
                    let success = await service.batchDelete()
                    if success {
                        actions.removeAll { $0.direction == .up }
                    }
                }
            },
            onRestart: restart,
            onClassify: {
                classifySession = ClassifySession(photos: currentGroupClassifyPhotos)
            },
            onGoBack: goBackToSwipe,
            onRemoveKeep: { ids in
                actions.removeAll { $0.direction == .down && ids.contains($0.photoId) }
            },
            onRemoveFavorite: { ids in
                actions.removeAll { $0.direction == .right && ids.contains($0.photoId) }
                for photo in service.photos.filter({ ids.contains($0.id) }) {
                    Task { await service.unmarkAsFavorite(photo.asset) }
                }
            },
            onRemoveClassify: { ids in
                actions.removeAll { $0.direction == .left && ids.contains($0.photoId) }
            },
            onRemoveDelete: { ids in
                actions.removeAll { $0.direction == .up && ids.contains($0.photoId) }
                service.removeFromPendingDeletes(ids)
            },
        )
    }

    // MARK: - Logic

    private func handleSwipe(_ direction: SwipeDirection) {
        guard currentIndex < service.photos.count else { return }

        let photo = service.photos[currentIndex]
        let action = SwipeAction(
            photoId: photo.id,
            direction: direction,
            timestamp: Date()
        )
        actions.append(action)
        swipedIds.insert(photo.id)
        saveSwipedState()
        flyingDirection = direction

        switch direction {
        case .up:
            SoundManager.shared.playDelete()
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            service.markForDeletion(photo)
        case .down:
            SoundManager.shared.playKeep()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .right:
            SoundManager.shared.playFavorite()
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            favoriteIds.insert(photo.id)
            saveFavoriteState()
            Task {
                await service.markAsFavorite(photo.asset)
            }
        case .left:
            SoundManager.shared.playClassify()
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            classifyIds.insert(photo.id)
            saveClassifyState()
        case .idle:
            break
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            dragOffset = .zero
            flyingDirection = .idle
            currentIndex += 1
            Task {
                await service.preloadNext(currentIndex: currentIndex)
            }
        }
    }

    private func undoLastAction() {
        guard canUndo, let lastAction = actions.last else { return }
        guard let photo = service.photos.first(where: { $0.id == lastAction.photoId }) else { return }

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            currentIndex -= 1
            swipedIds.remove(lastAction.photoId)
            actions.removeLast()
            flyingDirection = .idle
            dragOffset = .zero
        }

        switch lastAction.direction {
        case .up:
            service.removeFromPendingDeletes([lastAction.photoId])
        case .right:
            favoriteIds.remove(lastAction.photoId)
            saveFavoriteState()
            Task { await service.unmarkAsFavorite(photo.asset) }
        case .left:
            classifyIds.remove(lastAction.photoId)
            saveClassifyState()
        case .down, .idle:
            break
        }

        saveSwipedState()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func restart() {
        currentIndex = 0
        actions = []
        showLoadingOverlay = true
        Task {
            await service.loadPhotos(swipedIds: swipedIds)
        }
    }

    private func goBackToSwipe() {
        if let firstUnswiped = service.photos.firstIndex(where: { !swipedIds.contains($0.id) }) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                currentIndex = firstUnswiped
            }
        }
    }

    // MARK: - Persistence

    private func loadSwipedState() {
        if let saved = UserDefaults.standard.array(forKey: swipedKey) as? [String] {
            swipedIds = Set(saved)
        }
        if let saved = UserDefaults.standard.array(forKey: favoriteKey) as? [String] {
            favoriteIds = Set(saved)
        }
        if let saved = UserDefaults.standard.array(forKey: classifyKey) as? [String] {
            classifyIds = Set(saved)
        }
    }

    private func saveSwipedState() {
        UserDefaults.standard.set(Array(swipedIds), forKey: swipedKey)
    }

    private func saveFavoriteState() {
        UserDefaults.standard.set(Array(favoriteIds), forKey: favoriteKey)
    }

    private func saveClassifyState() {
        UserDefaults.standard.set(Array(classifyIds), forKey: classifyKey)
    }

    // MARK: - Flying Animation

    private func flyOffset(for depth: Int) -> CGSize {
        guard depth == 0 && flyingDirection != .idle else { return .zero }
        switch flyingDirection {
        case .up:
            return CGSize(width: 0, height: -UIScreen.main.bounds.height)
        case .down:
            return CGSize(width: 0, height: UIScreen.main.bounds.height)
        case .left:
            return CGSize(width: -UIScreen.main.bounds.width, height: 0)
        case .right:
            return CGSize(width: UIScreen.main.bounds.width, height: 0)
        case .idle:
            return .zero
        }
    }

    private func flyOpacity(for depth: Int) -> Double {
        guard depth == 0 && flyingDirection != .idle else { return 1.0 }
        return 0
    }

    private func flyScale(for depth: Int) -> CGFloat {
        guard depth == 0 && (flyingDirection == .right || flyingDirection == .left) else { return 1.0 }
        return 0.01
    }
}

/// 分类会话：承载待分类照片，用于 sheet 呈现
struct ClassifySession: Identifiable {
    let id = UUID()
    let photos: [PhotoItem]
}

/// iOS 系统分享面板桥接组件
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
