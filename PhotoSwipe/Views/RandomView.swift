import SwiftUI
import Photos

struct RandomView: View {
    @ObservedObject var service: PhotoService

    @State private var unorganizedCount = 0
    @State private var loadingForSwipe = false
    @State private var showSwipe = false
    @State private var coverImages: [UIImage] = []

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack {
                Spacer()

                Button {
                    loadingForSwipe = true
                    Task {
                        await service.loadShuffledPhotos(swipedIds: swipedSet)
                        loadingForSwipe = false
                        showSwipe = true
                    }
                } label: {
                    VStack(spacing: 28) {
                        pokerCardCover

                        VStack(spacing: 8) {
                            Text("随机整理")
                                .font(.title2.weight(.semibold))
                                .foregroundColor(.white)

                            if unorganizedCount > 0 {
                                Text("\(unorganizedCount) 张照片待整理")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.5))
                            } else {
                                Text("打乱所有照片的顺序来整理")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 48)
                    .padding(.horizontal, 32)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color.white.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                    )
                    .padding(.horizontal, 40)
                }
                .buttonStyle(.plain)

                Spacer()
            }

            if loadingForSwipe {
                LoadingOverlay(service: service)
            }
        }
        .task { await loadCount() }
        .fullScreenCover(isPresented: $showSwipe) {
            SwipeView(service: service, onExit: {
                showSwipe = false
                Task { await loadCount() }
            }, onReload: {
                await service.loadShuffledPhotos(swipedIds: swipedSet)
            })
        }
    }

    // MARK: - Poker Card Cover

    private var pokerCardCover: some View {
        ZStack {
            if coverImages.count >= 3 {
                // Bottom card (rotated left)
                cardImage(coverImages[2])
                    .rotationEffect(.degrees(-10))
                    .offset(x: -22, y: 6)
                    .zIndex(0)

                // Middle card (centered)
                cardImage(coverImages[1])
                    .zIndex(1)

                // Top card (rotated right)
                cardImage(coverImages[0])
                    .rotationEffect(.degrees(10))
                    .offset(x: 22, y: 6)
                    .zIndex(2)
            } else if coverImages.count >= 1 {
                cardImage(coverImages[0])
            } else {
                // Placeholder while loading
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 110, height: 140)
                    .overlay(
                        Image(systemName: "photo.stack")
                            .font(.title)
                            .foregroundColor(.white.opacity(0.3))
                    )
            }
        }
        .frame(width: 160, height: 160)
    }

    private func cardImage(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: 110, height: 140)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
    }

    private var swipedSet: Set<String> {
        let saved = UserDefaults.standard.array(forKey: "swipedPhotoIds") as? [String] ?? []
        return Set(saved)
    }

    private func loadCount() async {
        let groups = await service.getMonthlyGroups(swipedIds: swipedSet)
        unorganizedCount = groups.reduce(0) { $0 + $1.photoCount }
        coverImages = await service.getRandomCovers(count: 3)
    }
}
