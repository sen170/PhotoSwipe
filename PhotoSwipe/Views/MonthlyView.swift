import SwiftUI
import Photos

struct MonthlyView: View {
    @ObservedObject var service: PhotoService

    @State private var groups: [MonthlyGroup] = []
    @State private var isLoading = false
    @State private var selectedGroup: MonthlyGroup?
    @State private var showSwipe = false
    @State private var loadingForSwipe = false

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if groups.isEmpty && !isLoading {
                emptyState
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(groups) { group in
                            monthCard(group)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 100)
                }
            }

            if loadingForSwipe {
                LoadingOverlay(service: service)
            }
        }
        .task { await loadGroups() }
        .fullScreenCover(isPresented: $showSwipe) {
            SwipeView(service: service, onExit: {
                showSwipe = false
                Task { await loadGroups() }
            }, onReload: {
                guard let group = selectedGroup else { return }
                await service.loadPhotosForMonth(
                    year: group.year,
                    month: group.month,
                    swipedIds: swipedSet
                )
            })
        }
    }

    // MARK: - Month Card

    private func monthCard(_ group: MonthlyGroup) -> some View {
        Button {
            selectedGroup = group
            loadingForSwipe = true
            Task {
                await service.loadPhotosForMonth(
                    year: group.year,
                    month: group.month,
                    swipedIds: swipedSet
                )
                loadingForSwipe = false
                showSwipe = true
            }
        } label: {
            ZStack(alignment: .bottom) {
                // Cover photo
                if let image = group.coverImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 150)
                        .clipped()
                } else {
                    LinearGradient(
                        colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(height: 150)
                }

                // Bottom gradient for text readability
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.black.opacity(0.55),
                        Color.black.opacity(0.9)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 80)
                .frame(maxHeight: .infinity, alignment: .bottom)

                // Month info
                VStack(alignment: .leading, spacing: 2) {
                    Text(monthTitle(group))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text("\(group.photoCount) 张")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.4))
            Text("没有可整理的照片")
                .font(.title3.weight(.medium))
                .foregroundColor(.white.opacity(0.6))
        }
    }

    // MARK: - Helpers

    private var swipedSet: Set<String> {
        let saved = UserDefaults.standard.array(forKey: "swipedPhotoIds") as? [String] ?? []
        return Set(saved)
    }

    private func monthTitle(_ group: MonthlyGroup) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月"
        let components = DateComponents(year: group.year, month: group.month)
        if let date = Calendar.current.date(from: components) {
            return formatter.string(from: date)
        }
        return "\(group.year)年\(group.month)月"
    }

    private func loadGroups() async {
        isLoading = true
        groups = await service.getMonthlyGroups(swipedIds: swipedSet)
        isLoading = false
    }
}

// MARK: - Loading Overlay

struct LoadingOverlay: View {
    @ObservedObject var service: PhotoService

    var body: some View {
        ZStack {
            Color.black.opacity(0.9).ignoresSafeArea()

            VStack(spacing: 20) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                    .scaleEffect(1.2)

                Text("正在加载照片…")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .onChange(of: service.isLoading) { _, loading in
            // Parent dismisses this when loading is done
        }
    }
}
