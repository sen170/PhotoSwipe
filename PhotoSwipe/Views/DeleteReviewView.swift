import SwiftUI
import Photos
import UIKit

struct DeleteReviewView: View {
    let photos: [PhotoItem]
    var onConfirm: (Set<String>) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedIds: Set<String>
    @State private var zoomedPhoto: PhotoItem?

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM.dd HH:mm"
        return f
    }()

    init(photos: [PhotoItem], onConfirm: @escaping (Set<String>) -> Void) {
        self.photos = photos
        self.onConfirm = onConfirm
        _selectedIds = State(initialValue: Set(photos.map { $0.id }))
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 4), count: 3)
    }

    private var cellSize: CGFloat {
        (UIScreen.main.bounds.width - 8) / 3
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
            .navigationTitle("待删除 \(selectedIds.count)/\(photos.count)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                        .foregroundColor(.white)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        onConfirm(selectedIds)
                        dismiss()
                    }) {
                        Text("删除 \(selectedIds.count) 张")
                            .font(.headline)
                            .foregroundColor(selectedIds.isEmpty ? .gray : .red)
                    }
                    .disabled(selectedIds.isEmpty)
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
            .onTapGesture {
                zoomedPhoto = nil
            }
        }
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

            if !isSelected {
                Color.black.opacity(0.45)
            }

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundColor(isSelected ? .red : .white.opacity(0.6))
                .shadow(color: .black.opacity(0.3), radius: 2)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(6)
        }
        .frame(width: cellSize, height: cellSize)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.15)) {
                if isSelected {
                    selectedIds.remove(photo.id)
                } else {
                    selectedIds.insert(photo.id)
                }
            }
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            zoomedPhoto = photo
        }
    }
}
