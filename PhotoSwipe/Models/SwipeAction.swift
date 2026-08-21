import Foundation

struct SwipeAction: Identifiable {
    let id = UUID()
    let photoId: String
    let direction: SwipeDirection
    let timestamp: Date
    var undone: Bool = false
}
