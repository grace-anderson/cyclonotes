import UIKit

struct ImageResizer {
    static func compressForEmail(images: [UIImage], maxWidth: CGFloat = 2000, jpegQuality: CGFloat = 0.8) async -> (datas: [Data], failed: Int, totalBytes: Int) {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var datas: [Data] = []
                var failed = 0
                var total = 0
                for img in images {
                    guard let resized = resize(image: img, maxWidth: maxWidth),
                          let data = resized.jpegData(compressionQuality: jpegQuality) else {
                        failed += 1
                        continue
                    }
                    datas.append(data)
                    total += data.count
                }
                continuation.resume(returning: (datas, failed, total))
            }
        }
    }

    private static func resize(image: UIImage, maxWidth: CGFloat) -> UIImage? {
        let size = image.size
        guard size.width > 0 && size.height > 0 else { return nil }
        let scale = min(1.0, maxWidth / size.width)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        if scale == 1.0 { return image }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        let rendered = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return rendered
    }
}
