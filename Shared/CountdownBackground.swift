import SwiftUI

/// The photo for a countdown, or its theme gradient when there is no photo.
struct CountdownBackground: View {
    let countdown: Countdown
    var maxPixel: CGFloat = 1200
    var dimmed = true

    var body: some View {
        ZStack {
            countdown.theme.gradient
            if let key = countdown.imageKey, let image = ImageStore.image(for: key, maxPixel: maxPixel) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                if dimmed {
                    LinearGradient(
                        colors: [.black.opacity(0.05), .black.opacity(0.55)],
                        startPoint: .top, endPoint: .bottom
                    )
                }
            }
        }
    }
}
