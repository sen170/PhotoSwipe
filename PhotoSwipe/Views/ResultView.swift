import SwiftUI

struct ResultView: View {
    let deletePhotos: [PhotoItem]
    let keepPhotos: [PhotoItem]
    let favoritePhotos: [PhotoItem]
    let classifyPhotos: [PhotoItem]
    var onConfirmDelete: () -> Void
    var onRestart: () -> Void
    var onClassify: () -> Void
    var onGoBack: () -> Void
    var onRemoveKeep: (Set<String>) -> Void
    var onRemoveFavorite: (Set<String>) -> Void
    var onRemoveClassify: (Set<String>) -> Void

    @State private var selectedStat: StatType?

    enum StatType: Identifiable {
        case keep, favorite, classify
        var id: Self { self }
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)

                Text("整理完成！")
                    .font(.largeTitle.weight(.bold))
                    .foregroundColor(.white)
            }

            HStack(spacing: 16) {
                statBlock(count: deletePhotos.count, label: "待删除", color: .red, icon: "trash.fill") {
                    onConfirmDelete()
                }
                Divider().frame(height: 60)
                statBlock(count: keepPhotos.count, label: "已保留", color: .green, icon: "checkmark.circle.fill") {
                    selectedStat = .keep
                }
            }

            HStack(spacing: 16) {
                statBlock(count: favoritePhotos.count, label: "已收藏", color: .yellow, icon: "star.fill") {
                    selectedStat = .favorite
                }
                Divider().frame(height: 60)
                statBlock(count: classifyPhotos.count, label: "待分类", color: .orange, icon: "square.grid.2x2") {
                    selectedStat = .classify
                }
            }

            if deletePhotos.count > 0 {
                Text("\(deletePhotos.count) 张照片将被删除\n可在系统「最近删除」中恢复")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            VStack(spacing: 12) {
                if classifyPhotos.count > 0 {
                    Button(action: onClassify) {
                        HStack {
                            Image(systemName: "square.grid.2x2")
                            Text("分类 \(classifyPhotos.count) 张照片")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }

                if deletePhotos.count > 0 {
                    Button(action: onConfirmDelete) {
                        HStack {
                            Image(systemName: "trash.fill")
                            Text("确认删除 \(deletePhotos.count) 张")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.red)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }

                Button(action: onRestart) {
                    Text("整理下组")
                        .font(.headline)
                        .foregroundColor(.purple)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
        .overlay(alignment: .topLeading) {
            Button(action: onGoBack) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("继续整理")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.15))
                .clipShape(Capsule())
            }
            .padding(.leading, 20)
            .padding(.top, 8)
        }
        .sheet(item: $selectedStat) { type in
            switch type {
            case .keep:
                StatDetailView(title: "已保留", photos: keepPhotos, onRemove: onRemoveKeep)
            case .favorite:
                StatDetailView(title: "已收藏", photos: favoritePhotos, onRemove: onRemoveFavorite)
            case .classify:
                StatDetailView(title: "待分类", photos: classifyPhotos, onRemove: onRemoveClassify)
            }
        }
    }

    private func statBlock(count: Int, label: String, color: Color, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
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
}
