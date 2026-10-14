import SwiftUI

/// A 1080×1350 image of a countdown, sized for Messages and Instagram.
struct ShareCardView: View {
    let countdown: Countdown

    var body: some View {
        let days = countdown.daysRemaining()
        ZStack(alignment: .bottomLeading) {
            CountdownBackground(countdown: countdown, maxPixel: 1400)
            VStack(alignment: .leading, spacing: 12) {
                if let emoji = countdown.emoji { Text(emoji).font(.system(size: 120)) }
                Spacer()
                Text(days == 0 ? "Today!" : "\(abs(days))")
                    .font(.system(size: 260, weight: .heavy, design: .rounded))
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                if days != 0 {
                    Text(DayMath.caption(for: days))
                        .font(.system(size: 52, weight: .bold))
                        .textCase(.uppercase)
                        .opacity(0.9)
                }
                Text(countdown.title)
                    .font(.system(size: 76, weight: .bold))
                    .lineLimit(2)
                Text(countdown.nextDate(), format: .dateTime.weekday(.wide).month(.wide).day().year())
                    .font(.system(size: 40, weight: .medium))
                    .opacity(0.9)
                HStack(spacing: 12) {
                    Image("Logo").resizable().frame(width: 48, height: 48)
                    Text("Jack's Day Counter").font(.system(size: 32, weight: .semibold))
                }
                .opacity(0.85)
                .padding(.top, 24)
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.3), radius: 8)
            .padding(80)
        }
        .frame(width: 1080, height: 1350)
    }

    @MainActor
    static func render(_ countdown: Countdown) -> UIImage? {
        let renderer = ImageRenderer(content: ShareCardView(countdown: countdown))
        renderer.scale = 1
        return renderer.uiImage
    }
}
