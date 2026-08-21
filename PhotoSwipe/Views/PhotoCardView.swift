import SwiftUI
import Photos
import UIKit

struct PhotoCardView: View {
    let photo: PhotoItem

    @Binding var dragOffset: CGSize
    @Binding var isZoomed: Bool

    var onSwipeUp: () -> Void
    var onSwipeDown: () -> Void
    var onSwipeLeft: () -> Void
    var onSwipeRight: () -> Void

    private let swipeThreshold: CGFloat = 100

    private var direction: SwipeDirection {
        let absX = abs(dragOffset.width)
        let absY = abs(dragOffset.height)

        if absY > swipeThreshold && absY >= absX {
            return dragOffset.height < 0 ? .up : .down
        } else if absX > swipeThreshold && absX > absY {
            return dragOffset.width > 0 ? .right : .left
        }
        return .idle
    }

    private var rotation: Double {
        Double(dragOffset.width) / 25.0
    }

    private var scaleAmount: CGFloat {
        let total = abs(dragOffset.width) + abs(dragOffset.height)
        return 1.0 - min(total / 2000, 0.05)
    }

    var body: some View {
        ZStack {
            if let image = photo.uiImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color(.systemGray5))
            }

            overlay
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(alignment: .bottom) {
            if let date = photo.asset.creationDate {
                Text(Self.dateFormatter.string(from: date))
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white.opacity(0.8))
                    .offset(y: 28)
            }
        }
        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
        .offset(x: dragOffset.width, y: dragOffset.height)
        .rotationEffect(.degrees(-rotation))
        .scaleEffect(scaleAmount)
        .contentShape(Rectangle())
        .gesture(dragGesture)
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                dragOffset = value.translation
            }
            .onEnded { value in
                handleSwipeEnd(value.translation)
            }
    }

    private func handleSwipeEnd(_ translation: CGSize) {
        let absX = abs(translation.width)
        let absY = abs(translation.height)

        if absY > swipeThreshold && absY >= absX {
            if translation.height < 0 {
                onSwipeUp()
            } else {
                onSwipeDown()
            }
        } else if absX > swipeThreshold && absX > absY {
            if translation.width > 0 {
                onSwipeRight()
            } else {
                onSwipeLeft()
            }
        } else {
            // 未达阈值，回弹
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                dragOffset = .zero
            }
        }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy.MM.dd HH:mm"
        return f
    }()

    private var overlay: some View {
        ZStack {
            if direction == .up {
                labelBadge(text: "删除", color: .red, icon: "trash.fill")
                    .transition(.scale.combined(with: .opacity))
            } else if direction == .down {
                labelBadge(text: "保留", color: .green, icon: "checkmark.circle.fill")
                    .transition(.scale.combined(with: .opacity))
            } else if direction == .right {
                labelBadge(text: "收藏", color: .yellow, icon: "star.fill")
                    .transition(.scale.combined(with: .opacity))
            } else if direction == .left {
                labelBadge(text: "待分类", color: .orange, icon: "square.grid.2x2")
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }

    private func labelBadge(text: String, color: Color, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2.weight(.bold))
            Text(text)
                .font(.title2.weight(.bold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(color.opacity(0.85))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1))
    }
}
