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
            newPhotos[i].thumbnailImage = await requestThumbnail(for: newPhotos[i].asset)
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

    /// 加载小尺寸缩略图（用于背景模糊，性能开销极小）
    private func requestThumbnail(for asset: PHAsset) async -> UIImage? {
        let imageManager = PHImageManager.default()
        let targetSize = CGSize(width: 80, height: 80)

        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .fastFormat
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

    /// 中等尺寸图（用于月历封面，300x300）
    func requestMediumImage(for asset: PHAsset) async -> UIImage? {
        let imageManager = PHImageManager.default()
        let targetSize = CGSize(width: 300, height: 300)

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

    // MARK: - Monthly Groups

    func getMonthlyGroups(swipedIds: Set<String> = []) async -> [MonthlyGroup] {
        guard hasPermission else { return [] }

        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        let result = PHAsset.fetchAssets(with: .image, options: fetchOptions)

        var monthMap: [String: (assets: [PHAsset], count: Int)] = [:]
        var monthOrder: [String] = []

        result.enumerateObjects { asset, _, _ in
            guard let date = asset.creationDate else { return }
            let cal = Calendar.current
            let year = cal.component(.year, from: date)
            let month = cal.component(.month, from: date)
            let key = String(format: "%d-%02d", year, month)

            if monthMap[key] == nil {
                monthMap[key] = (assets: [], count: 0)
                monthOrder.append(key)
            }
            monthMap[key]?.assets.append(asset)
            monthMap[key]?.count += 1
        }

        var groups: [MonthlyGroup] = []
        for key in monthOrder {
            let parts = key.split(separator: "-")
            guard parts.count == 2,
                  let year = Int(parts[0]),
                  let month = Int(parts[1]) else { continue }

            let assets = monthMap[key]?.assets ?? []
            let unswipedCount = assets.filter { !swipedIds.contains($0.localIdentifier) }.count
            guard unswipedCount > 0 else { continue }

            let coverAsset = assets.first
            var coverImage: UIImage?
            if let cover = coverAsset {
                coverImage = await requestMediumImage(for: cover)
            }

            groups.append(MonthlyGroup(
                id: key,
                year: year,
                month: month,
                photoCount: unswipedCount,
                coverImage: coverImage,
                coverAsset: coverAsset
            ))
        }

        return groups
    }

    func loadPhotosForMonth(year: Int, month: Int, swipedIds: Set<String> = []) async {
        guard hasPermission else { return }

        isLoading = true

        let cal = Calendar.current
        let components = DateComponents(year: year, month: month)
        guard let startOfMonth = cal.date(from: components),
              let endOfMonth = cal.date(byAdding: .month, value: 1, to: startOfMonth) else {
            isLoading = false
            return
        }

        let fetchOptions = PHFetchOptions()
        let predicate = NSPredicate(format: "creationDate >= %@ AND creationDate < %@",
                                    startOfMonth as NSDate, endOfMonth as NSDate)
        fetchOptions.predicate = predicate
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        let result = PHAsset.fetchAssets(with: .image, options: fetchOptions)

        var assets: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }

        let unswipedAssets = assets.filter { !swipedIds.contains($0.localIdentifier) }
        let batchAssets = Array(unswipedAssets.prefix(batchSize))

        await loadLazy(batchAssets)
    }

    func loadShuffledPhotos(swipedIds: Set<String> = []) async {
        guard hasPermission else { return }

        isLoading = true

        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        let result = PHAsset.fetchAssets(with: .image, options: fetchOptions)

        var assets: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }

        let unswipedAssets = assets.filter { !swipedIds.contains($0.localIdentifier) }
        let shuffled = unswipedAssets.shuffled()
        let batchAssets = Array(shuffled.prefix(batchSize))

        await loadLazy(batchAssets)
    }

    func getRandomCovers(count: Int = 3) async -> [UIImage] {
        guard hasPermission else { return [] }

        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        let result = PHAsset.fetchAssets(with: .image, options: fetchOptions)

        var assets: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }

        let shuffled = assets.shuffled()
        let covers = Array(shuffled.prefix(count))

        var images: [UIImage] = []
        for asset in covers {
            if let image = await requestMediumImage(for: asset) {
                images.append(image)
            }
        }

        return images
    }

    private func loadLazy(_ assets: [PHAsset]) async {
        guard !assets.isEmpty else {
            isLoading = false
            return
        }

        let initialCount = min(10, assets.count)
        let initialAssets = Array(assets.prefix(initialCount))
        let remainingAssets = Array(assets.dropFirst(initialCount))

        var initialPhotos = initialAssets.map { asset -> PhotoItem in
            let pw = asset.pixelWidth
            let ph = asset.pixelHeight
            let ratio = ph > 0 ? CGFloat(pw) / CGFloat(ph) : 3.0 / 4.0
            return PhotoItem(id: asset.localIdentifier, asset: asset, uiImage: nil, aspectRatio: ratio)
        }

        totalCount = assets.count
        loadedCount = 0

        for i in 0..<initialPhotos.count {
            initialPhotos[i].uiImage = await requestImage(for: initialPhotos[i].asset)
            initialPhotos[i].thumbnailImage = await requestThumbnail(for: initialPhotos[i].asset)
            loadedCount = i + 1
        }

        photos = initialPhotos
        isLoading = false

        Task { @MainActor [weak self] in
            guard let self = self else { return }
            for asset in remainingAssets {
                let pw = asset.pixelWidth
                let ph = asset.pixelHeight
                let ratio = ph > 0 ? CGFloat(pw) / CGFloat(ph) : 3.0 / 4.0
                var photo = PhotoItem(id: asset.localIdentifier, asset: asset, uiImage: nil, aspectRatio: ratio)
                photo.uiImage = await self.requestImage(for: asset)
                photo.thumbnailImage = await self.requestThumbnail(for: asset)

                self.photos.append(photo)
                self.loadedCount += 1
            }
        }
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
