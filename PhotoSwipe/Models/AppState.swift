import SwiftUI
import Photos
import UIKit

enum SwipeDirection {
    case up
    case down
    case left
    case right
    case idle
}

struct PhotoItem: Identifiable {
    let id: String
    let asset: PHAsset
    var uiImage: UIImage?
    var thumbnailImage: UIImage?
    var aspectRatio: CGFloat = 3.0 / 4.0   // 宽/高，默认接近屏幕卡片
}

struct AlbumInfo: Identifiable {
    let id: String
    let name: String
    let collection: PHAssetCollection
}
