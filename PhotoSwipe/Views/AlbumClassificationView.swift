import SwiftUI
import Photos

struct AlbumClassificationView: View {
    let photos: [PhotoItem]
    let service: PhotoService

    @Environment(\.dismiss) private var dismiss

    @State private var currentIndex = 0
    @State private var albums: [AlbumInfo] = []
    @State private var selectedAlbumIndex = 0
    @State private var stampedAlbumName: String? = nil
    @State private var stamping = false
    @State private var advancing = false
    @State private var dragOffset: CGSize = .zero
    @State private var assignedCount = 0
    @State private var skippedCount = 0
    @State private var assignmentResults: [(photo: PhotoItem, albumName: String)] = []
    @State private var showNewAlbumAlert = false
    @State private var newAlbumName = ""
    @State private var isLoadingAlbums = true

    private let cardWidth: CGFloat = UIScreen.main.bounds.width - 48
    private var maxCardHeight: CGFloat { UIScreen.main.bounds.height * 0.48 }
    private let swipeThreshold: CGFloat = 100

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if isLoadingAlbums {
                ProgressView("加载相簿...")
                    .tint(.white)
                    .foregroundColor(.white)
            } else if currentIndex >= photos.count {
                completionView
            } else if albums.isEmpty {
                noAlbumView
            } else {
                contentView
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            loadAlbums()
        }
        .alert("新建相簿", isPresented: $showNewAlbumAlert) {
            TextField("相簿名称", text: $newAlbumName)
            Button("取消", role: .cancel) { newAlbumName = "" }
            Button("创建") { createNewAlbum() }
        }
    }

    // MARK: - Content

    private var contentView: some View {
        ZStack {
            photoCardStack
            albumStrip
            topBar
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: dragOffset)
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: currentIndex)
        .animation(.spring(response: 0.45, dampingFraction: 0.5), value: stamping)
        .animation(.easeInOut(duration: 0.3), value: advancing)
    }

    // MARK: - Top Bar

    private var topBar: some View {
        VStack {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.gray)
                }

                Spacer()

                Text("\(currentIndex + 1) / \(photos.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Capsule())

                Spacer()

                Button(action: { skipPhoto() }) {
                    Text("跳过")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .disabled(stamping || advancing)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)

            Spacer()
        }
    }

    // MARK: - Photo Card Stack

    private var photoCardStack: some View {
        ZStack {
            ForEach(
                Array(photos.enumerated().reversed()),
                id: \.element.id
            ) { index, photo in
                let depth = index - currentIndex
                if depth >= 0 && depth <= 2 {
                    cardView(photo: photo, depth: depth)
                }
            }
        }
        .offset(y: -40)
    }

    /// 分类页：宽固定，高度按照片比例适配（横图矮、竖图高），完整显示不裁剪
    private func fittedCardHeight(_ photo: PhotoItem) -> CGFloat {
        let r = min(max(photo.aspectRatio, 0.6), 1.6)
        return min(cardWidth / r, maxCardHeight)
    }

    private func cardView(photo: PhotoItem, depth: Int) -> some View {
        let isActive = depth == 0

        return ZStack {
            if let image = photo.uiImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Rectangle().fill(Color(.systemGray5))
            }
        }
        .frame(width: cardWidth, height: fittedCardHeight(photo))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .overlay(alignment: .topTrailing) {
            if isActive && stampedAlbumName != nil {
                stampView(name: stampedAlbumName ?? "")
                    .padding(12)
                    .scaleEffect(stamping ? 1.0 : 2.5)
                    .rotationEffect(.degrees(stamping ? 0 : -12))
                    .opacity(stamping ? 1.0 : 0)
            }
        }
        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
        .scaleEffect(depth == 0 ? 1.0 : 1.0 - CGFloat(depth) * 0.05)
        .offset(
            x: isActive ? dragOffset.width + (advancing ? UIScreen.main.bounds.width : 0) : 0,
            y: isActive ? dragOffset.height : CGFloat(depth) * 12
        )
        .opacity(depth == 0 ? 1.0 : (depth == 1 ? 0.7 : 0.4))
        .zIndex(Double(10 - depth))
        .allowsHitTesting(depth == 0)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if !stamping && !advancing {
                        dragOffset = value.translation
                    }
                }
                .onEnded { value in
                    if !stamping && !advancing {
                        handleDragEnd(value.translation)
                    }
                }
        )
    }

    // MARK: - Stamp

    private func stampView(name: String) -> some View {
        let ink = Color(red: 0.72, green: 0.10, blue: 0.08)
        return ZStack {
            // 墨印底：半透明红盘，模拟印章沾墨后压下的浓淡
            Circle()
                .fill(ink.opacity(0.16))

            // 外圈
            Circle()
                .stroke(ink, lineWidth: 3)

            // 内圈
            Circle()
                .stroke(ink, lineWidth: 1.5)
                .padding(5)

            Text(truncateName(name))
                .font(.system(size: stampFontSize(name), weight: .black))
                .foregroundColor(ink)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.bottom, 4)
        }
        .frame(width: 88, height: 88)
    }

    private func stampFontSize(_ name: String) -> CGFloat {
        let count = name.count
        if count <= 2 { return 26 }
        if count <= 4 { return 19 }
        return 14
    }

    private func truncateName(_ name: String) -> String {
        if name.count <= 4 { return name }
        return String(name.prefix(4))
    }

    // MARK: - Album Strip

    private var albumStrip: some View {
        VStack(spacing: 8) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(albums.enumerated()), id: \.element.id) { index, album in
                            albumChip(album: album, index: index)
                                .id(index)
                        }

                        Button(action: { showNewAlbumAlert = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill")
                                Text("新建相簿")
                            }
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Capsule())
                        }
                        .disabled(stamping || advancing)
                    }
                    .padding(.horizontal, 16)
                }
                .onChange(of: selectedAlbumIndex) { _, newIndex in
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
            }

            Text("点击相簿盖戳分类 · 上滑跳过")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, 30)
    }

    private func albumChip(album: AlbumInfo, index: Int) -> some View {
        let isSelected = index == selectedAlbumIndex

        return Button(action: {
            handleAlbumTap(index)
        }) {
            HStack(spacing: 6) {
                Image(systemName: isSelected ? "folder.fill" : "folder")
                    .font(.subheadline)
                Text(album.name)
                    .font(.subheadline.weight(isSelected ? .bold : .medium))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isSelected ? Color.blue.opacity(0.8) : Color.white.opacity(0.1))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.white.opacity(0.5) : Color.clear, lineWidth: 1.5)
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(stamping || advancing)
    }

    // MARK: - Logic

    private func handleDragEnd(_ translation: CGSize) {
        let absY = abs(translation.height)

        if absY > swipeThreshold && translation.height < 0 {
            skipPhoto()
        } else {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                dragOffset = .zero
            }
        }
    }

    private func handleAlbumTap(_ index: Int) {
        guard !stamping && !advancing else { return }
        guard currentIndex < photos.count, index < albums.count else { return }

        selectedAlbumIndex = index
        let album = albums[index]
        let photo = photos[currentIndex]

        assignmentResults.append((photo, album.name))
        assignedCount += 1

        stampedAlbumName = album.name
        stamping = false

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.5)) {
                stamping = true
            }
            SoundManager.shared.playClassify()
        }

        Task {
            _ = await service.addToAlbum(photo.asset, album: album.collection)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.easeInOut(duration: 0.3)) {
                advancing = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                stampedAlbumName = nil
                stamping = false
                advancing = false
                dragOffset = .zero
                currentIndex += 1
            }
        }
    }

    private func skipPhoto() {
        guard !stamping && !advancing else { return }
        skippedCount += 1

        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
            dragOffset = CGSize(width: 0, height: -UIScreen.main.bounds.height)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            dragOffset = .zero
            currentIndex += 1
        }
    }

    // MARK: - Album Loading

    private func loadAlbums() {
        isLoadingAlbums = true
        albums = service.fetchAlbums()
        isLoadingAlbums = false
    }

    private func createNewAlbum() {
        let name = newAlbumName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        Task {
            if let collection = await service.createAlbum(name: name) {
                let newAlbum = AlbumInfo(
                    id: collection.localIdentifier,
                    name: name,
                    collection: collection
                )
                await MainActor.run {
                    albums.append(newAlbum)
                    selectedAlbumIndex = albums.count - 1
                    newAlbumName = ""
                }
            }
        }
    }

    // MARK: - Completion

    private var completionView: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)

                Text("分类完成！")
                    .font(.largeTitle.weight(.bold))
                    .foregroundColor(.white)
            }

            HStack(spacing: 16) {
                statBlock(count: assignedCount, label: "已分类", color: .blue, icon: "folder.fill")
                Divider().frame(height: 60)
                statBlock(count: skippedCount, label: "已跳过", color: .gray, icon: "arrow.up.circle.fill")
            }

            if !assignmentResults.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(assignmentResults.enumerated()), id: \.offset) { _, result in
                            VStack(spacing: 4) {
                                if let image = result.photo.uiImage {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 60, height: 60)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                Text(result.albumName)
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                    .lineLimit(1)
                            }
                            .frame(width: 70)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .frame(maxHeight: 100)
            }

            Spacer()

            Button(action: { dismiss() }) {
                Text("完成")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }

    private var noAlbumView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "folder.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("还没有相簿")
                .font(.title3.weight(.medium))
                .foregroundColor(.gray)

            Text("创建一个相簿来开始分类照片")
                .font(.subheadline)
                .foregroundColor(.gray.opacity(0.7))

            Button(action: { showNewAlbumAlert = true }) {
                HStack {
                    Image(systemName: "plus")
                    Text("新建相簿")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
                .background(Color.blue)
                .clipShape(Capsule())
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func statBlock(count: Int, label: String, color: Color, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            Text("\(count)")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(label)
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(width: 100)
    }
}
