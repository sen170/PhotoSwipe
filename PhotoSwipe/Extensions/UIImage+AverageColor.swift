import UIKit

extension UIImage {
    /// 提取图片的平均主色，用于背景渐变
    var averageColor: UIColor {
        guard let cgImage = cgImage else { return .systemBackground }

        let width = 40
        let height = 40
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8

        var pixels = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return .systemBackground }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var totalRed: Int = 0
        var totalGreen: Int = 0
        var totalBlue: Int = 0
        var count: Int = 0

        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                totalRed += Int(pixels[offset])
                totalGreen += Int(pixels[offset + 1])
                totalBlue += Int(pixels[offset + 2])
                count += 1
            }
        }

        let avgRed = CGFloat(totalRed) / CGFloat(count) / 255.0
        let avgGreen = CGFloat(totalGreen) / CGFloat(count) / 255.0
        let avgBlue = CGFloat(totalBlue) / CGFloat(count) / 255.0

        return UIColor(red: avgRed, green: avgGreen, blue: avgBlue, alpha: 1.0)
    }
}
