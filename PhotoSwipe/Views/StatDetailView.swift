import SwiftUI
import Photos
import UIKit

struct StatDetailView: View {
    let title: String
    let photos: [PhotoItem]
    var onRemove: ((Set<String>) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var selectedIds: Set<String>
    @State private var zoomedPhoto: PhotoItem?

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM.dd HH:mm"
        return f
    }()

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 4), count: 3)
    }

    private var cellSize: CGFloat {
        (UIScreen.main.bounds.width - 8) / 3
    }

    private var uncheckedCount: Int {
        photos.count - selectedIds.count
    }

    init(title: String, photos: [PhotoItem], onRemove: ((Set<String>) -> Void)? = nil) {
        self.title = title
        self.photos = photos
        self.onRemove = onRemove
        _selectedIds = State(initialValue: Set(photos.map { $0.id }))
    }

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(photos) { photo in
                        cell(for: photo)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.top, 8)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(onRemove != nil ? "\(title) \(selectedIds.count)/\(photos.count)" : title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if onRemove != nil {
                        Button(action: confirmRemove) {
                            Text(uncheckedCount > 0 ? "移除 \(uncheckedCount) 张" : "完成")
                                .font(.headline)
                                .foregroundColor(uncheckedCount > 0 ? .red : .white)
                        }
                    } else {
                        Button("完成") { dismiss() }
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(item: $zoomedPhoto) { photo in
            ZStack {
                Color.black.ignoresSafeArea()
                if let image = photo.uiImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding(.horizontal, 8)
                        .ignoresSafeArea()
                }
                VStack {
                    HStack {
                        Spacer()
                        Button(action: { zoomedPhoto = nil }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title)
                                .foregroundColor(.white.opacity(0.6))
                                .padding()
                        }
                    }
                    Spacer()
                }
            }
            .onTapGesture { zoomedPhoto = nil }
        }
    }

    private func confirmRemove() {
        let uncheckedIds = Set(photos.map { $0.id }).subtracting(selectedIds)
        if !uncheckedIds.isEmpty {
            onRemove?(uncheckedIds)
        }
        dismiss()
    }

    private func cell(for photo: PhotoItem) -> some View {
        let isSelected = selectedIds.contains(photo.id)

        return ZStack {
            if let image = photo.uiImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: cellSize, height: cellSize)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: cellSize, height: cellSize)
            }

            VStack {
                Spacer()
                HStack {
                    if let date = photo.asset.creationDate {
                        Text(Self.dateFormatter.string(from: date))
                            .font(.system(size: 9))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Capsule())
                    }
                    Spacer()
                }
                .padding(.bottom, 4)
                .padding(.leading, 4)
            }

            if onRemove != nil && !isSelected {
                Color.black.opacity(0.45)
            }

            if onRemove != nil {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .white.opacity(0.6))
                    .shadow(color: .black.opacity(0.3), radius: 2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(6)
            }
        }
        .frame(width: cellSize, height: cellSize)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onTapGesture {
            if onRemove != nil {
                withAnimation(.easeInOut(duration: 0.15)) {
                    if isSelected {
                        selectedIds.remove(photo.id)
                    } else {
                        selectedIds.insert(photo.id)
                    }
                }
            }
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            zoomedPhoto = photo
        }
    }
}
