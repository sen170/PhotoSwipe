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
    var onRemoveDelete: (Set<String>) -> Void

    @State private var selectedStat: StatType?
    @State private var showDeleteConfirm = false

    enum StatType: Identifiable {
        case delete, keep, favorite, classify
        var id: Self { self }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                // 顶部返回
                HStack {
                    Button(action: onGoBack) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("继续整理")
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.white.opacity(0.7))
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
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                // 完成图标 + 标题
                VStack(spacing: 14) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 52))
                        .foregroundColor(.green.opacity(0.9))

                    Text("整理完成")
                        .font(.title.weight(.semibold))
                        .foregroundColor(.white)

                    Text("共处理 \(totalCount) 张照片")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.top, 20)

                // 统计卡片
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        statCard(count: keepPhotos.count, label: "已保留", color: .green, icon: "checkmark.circle.fill", action: { selectedStat = .keep })
                        statCard(count: deletePhotos.count, label: "待删除", color: .red, icon: "trash.fill", action: { selectedStat = .delete })
                    }

                    HStack(spacing: 12) {
                        statCard(count: favoritePhotos.count, label: "已收藏", color: .yellow, icon: "star.fill", action: { selectedStat = .favorite })
                        statCard(count: classifyPhotos.count, label: "待分类", color: .orange, icon: "square.grid.2x2", action: { selectedStat = .classify })
                    }
                }
                .padding(.horizontal, 20)

                // 删除提示
                if deletePhotos.count > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.white.opacity(0.4))
                        Text("删除后可在系统「最近删除」中恢复 30 天")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding(.horizontal, 20)
                }

                Spacer(minLength: 20)

                // 按钮组
                VStack(spacing: 10) {
                    if deletePhotos.count > 0 {
                        Button(action: { showDeleteConfirm = true }) {
                            HStack {
                                Image(systemName: "trash.fill")
                                Text("确认删除 \(deletePhotos.count) 张")
                            }
                            .font(.headline.weight(.semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.red.opacity(0.85))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                            )
                        }
                    }

                    if classifyPhotos.count > 0 {
                        Button(action: onClassify) {
                            HStack {
                                Image(systemName: "square.grid.2x2.fill")
                                Text("分类 \(classifyPhotos.count) 张照片")
                            }
                            .font(.headline.weight(.semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.orange.opacity(0.85))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                            )
                        }
                    }

                    Button(action: onRestart) {
                        Text("整理下一组")
                            .font(.headline.weight(.semibold))
                            .foregroundColor(.white.opacity(0.9))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.white.opacity(0.08))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                            )
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 30)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .sheet(item: $selectedStat) { type in
            switch type {
            case .delete:
                StatDetailView(title: "待删除", photos: deletePhotos, onRemove: onRemoveDelete)
            case .keep:
                StatDetailView(title: "已保留", photos: keepPhotos, onRemove: onRemoveKeep)
            case .favorite:
                StatDetailView(title: "已收藏", photos: favoritePhotos, onRemove: onRemoveFavorite)
            case .classify:
                StatDetailView(title: "待分类", photos: classifyPhotos, onRemove: onRemoveClassify)
            }
        }
        .alert("确认删除？", isPresented: $showDeleteConfirm) {
            Button("删除", role: .destructive) {
                onConfirmDelete()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("确定要删除 \(deletePhotos.count) 张照片吗？删除后可在系统「最近删除」中恢复。")
        }
    }

    private var totalCount: Int {
        deletePhotos.count + keepPhotos.count + favoritePhotos.count + classifyPhotos.count
    }

    private func statCard(count: Int, label: String, color: Color, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(color.opacity(0.15))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(count)")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    Text(label)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}
