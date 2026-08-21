import Photos
import UIKit
import Combine

final class PhotoService: ObservableObject {

    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @Published var photos: [PhotoItem] = []
    @Published var isLoading = false
    @Published var pendingDeletes: [PhotoItem] = []
    @Published var loadedCount = 0
    @Published var totalCount = 0

    private var allAssets: [PHAsset] = []
    private let batchSize = 100

    func requestPermission() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        authorizationStatus = status
    }

    func checkPermission() {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    var hasPermission: Bool {
        authorizationStatus == .authorized
    }

    var isLimited: Bool {
        authorizationStatus == .limited
    }

    func loadPhotos(swipedIds: Set<String> = []) async {
        guard hasPermission else { return }

        isLoading = true

        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        let result = PHAsset.fetchAssets(with: .image, options: fetchOptions)

        allAssets.removeAll()
        result.enumerateObjects { asset, _, _ in
            self.allAssets.append(asset)
        }

        let unswipedAssets = allAssets.filter { !swipedIds.contains($0.localIdentifier) }
        let batchAssets = Array(unswipedAssets.prefix(batchSize))

        var newPhotos = batchAssets.map { asset in
            let ratio: CGFloat
            let pw = asset.pixelWidth
            let ph = asset.pixelHeight
            ratio = ph > 0 ? CGFloat(pw) / CGFloat(ph) : 3.0 / 4.0
            return PhotoItem(id: asset.localIdentifier, asset: asset, uiImage: nil, aspectRatio: ratio)
        }

        totalCount = newPhotos.count
        loadedCount = 0

        for i in 0..<newPhotos.count {
            newPhotos[i].uiImage = await requestImage(for: newPhotos[i].asset)
            loadedCount = i + 1
        }

        photos = newPhotos
        isLoading = false
    }

    func loadImage(for index: Int) async {
        guard index >= 0 && index < photos.count else { return }
        guard photos[index].uiImage == nil else { return }

        let asset = photos[index].asset
        let image = await requestImage(for: asset)
        photos[index].uiImage = image
    }

    func preloadNext(currentIndex: Int) async {
        let nextIndex = currentIndex + 1
        if nextIndex < photos.count && photos[nextIndex].uiImage == nil {
            await loadImage(for: nextIndex)
        }
    }

    private func requestImage(for asset: PHAsset) async -> UIImage? {
        let imageManager = PHImageManager.default()
        let screenWidth = UIScreen.main.bounds.width
        let targetSize = CGSize(width: screenWidth, height: screenWidth * 1.5)

        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true

        return await withCheckedContinuation { continuation in
            imageManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }

    func markForDeletion(_ item: PhotoItem) {
        pendingDeletes.append(item)
    }

    func removeFromPendingDeletes(_ ids: Set<String>) {
        pendingDeletes.removeAll { ids.contains($0.id) }
    }

    func batchDelete() async -> Bool {
        guard !pendingDeletes.isEmpty else { return true }

        let assetsToDelete = pendingDeletes.map { $0.asset } as NSArray

        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(assetsToDelete)
            }
            pendingDeletes.removeAll()
            return true
        } catch {
            return false
        }
    }

    // MARK: - Favorite

    func markAsFavorite(_ asset: PHAsset) async {
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest(for: asset).isFavorite = true
            }
        } catch {}
    }

    func unmarkAsFavorite(_ asset: PHAsset) async {
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest(for: asset).isFavorite = false
            }
        } catch {}
    }

    // MARK: - Albums

    func fetchAlbums() -> [AlbumInfo] {
        var albums: [AlbumInfo] = []
        let result = PHAssetCollection.fetchAssetCollections(
            with: .album,
            subtype: .albumRegular,
            options: nil
        )
        result.enumerateObjects { collection, _, _ in
            let name = collection.localizedTitle ?? "未命名"
            albums.append(AlbumInfo(
                id: collection.localIdentifier,
                name: name,
                collection: collection
            ))
        }
        return albums
    }

    func addToAlbum(_ asset: PHAsset, album: PHAssetCollection) async -> Bool {
        do {
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCollectionChangeRequest(for: album)
                request?.addAssets([asset] as NSArray)
            }
            return true
        } catch {
            return false
        }
    }

    func createAlbum(name: String) async -> PHAssetCollection? {
        var placeholder: PHObjectPlaceholder?

        do {
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: name)
                placeholder = request.placeholderForCreatedAssetCollection
            }
        } catch {
            return nil
        }

        guard let placeholderId = placeholder?.localIdentifier else { return nil }
        return PHAssetCollection.fetchAssetCollections(
            withLocalIdentifiers: [placeholderId],
            options: nil
        ).firstObject
    }
}
