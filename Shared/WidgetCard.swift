import SwiftUI

enum Theme {
    static let navy = Color(red: 0.106, green: 0.165, blue: 0.361)      // #1B2A5C
    static let orange = Color(red: 0.933, green: 0.541, blue: 0.137)    // #EE8A23
    static let blue = Color(red: 0.176, green: 0.525, blue: 0.839)      // #2D86D6
    static let strip = Color(red: 0.882, green: 0.910, blue: 0.949)     // #E1E8F2
    static let good = Color(red: 0.180, green: 0.616, blue: 0.420)      // #2E9D6B
    static let skyTop = Color(red: 0.624, green: 0.843, blue: 0.933)
    static let skyBottom = Color(red: 0.914, green: 0.957, blue: 0.914)
}

/// The left panel's wavy right edge.
struct WaveEdge: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let w = r.width, h = r.height
        p.move(to: .zero)
        p.addLine(to: CGPoint(x: w * 0.45, y: 0))
        p.addCurve(to: CGPoint(x: w * 0.30, y: h * 0.52),
                   control1: CGPoint(x: w * 1.05, y: h * 0.22),
                   control2: CGPoint(x: w * 0.0, y: h * 0.32))
        p.addCurve(to: CGPoint(x: w * 0.50, y: h),
                   control1: CGPoint(x: w * 0.62, y: h * 0.74),
                   control2: CGPoint(x: w * 0.12, y: h * 0.86))
        p.addLine(to: CGPoint(x: 0, y: h))
        p.closeSubpath()
        return p
    }
}

/// Wide card in the style of the reference widget: navy half with the next prayer,
/// white half with the countdown, city and Hijri date.
struct WideWidgetCard: View {
    let prayer: Prayer
    let time: Date
    let cityName: String
    let hijri: String
    let settings: AppSettings

    var body: some View {
        GeometryReader { g in
            let lw = g.size.width * 0.46
            ZStack(alignment: .topLeading) {
                Color.white
                WaveEdge().fill(Color.gray.opacity(0.28))
                    .frame(width: 60, height: g.size.height).offset(x: lw - 22)
                WaveEdge().fill(Theme.navy)
                    .frame(width: 60, height: g.size.height).offset(x: lw - 32)
                Theme.navy.frame(width: lw - 30, height: g.size.height)

                VStack(spacing: 2) {
                    Image(systemName: prayer == .fajr || prayer == .isha ? prayer.symbol : "sun.max.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(Theme.orange)
                    Text(prayer.arabicName)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Theme.orange)
                    HStack(spacing: 6) {
                        Text(DateText.time(time, in: settings.timeZone, use24h: settings.use24h))
                            .font(.system(size: 28, weight: .regular).monospacedDigit())
                        if !settings.use24h {
                            Text(DateText.period(time, in: settings.timeZone)).font(.system(size: 22))
                        }
                    }
                    .environment(\.layoutDirection, .rightToLeft)
                    .foregroundStyle(.white)
                }
                .lineLimit(1).minimumScaleFactor(0.6)
                .frame(width: lw - 22, height: g.size.height)

                VStack(spacing: 2) {
                    Text("\(prayer.arabicName) بعد").font(.system(size: 15, weight: .semibold))
                    Text(timerInterval: Date()...max(Date(), time), countsDown: true)
                        .font(.system(size: 38, weight: .medium).monospacedDigit())
                        .multilineTextAlignment(.center)
                    Text(cityName).font(.system(size: 19, weight: .semibold)).foregroundStyle(Theme.blue)
                    Text(hijri).font(.system(size: 12.5)).multilineTextAlignment(.center)
                }
                .foregroundStyle(.black)
                .lineLimit(1).minimumScaleFactor(0.6)
                .padding(.horizontal, 8)
                .frame(width: g.size.width - lw - 12, height: g.size.height)
                .offset(x: lw + 8)
            }
        }
        .environment(\.layoutDirection, .leftToRight)
    }
}

/// Square card: next prayer and countdown on navy.
struct SmallWidgetCard: View {
    let prayer: Prayer
    let time: Date
    let settings: AppSettings

    var body: some View {
        VStack(spacing: 2) {
            Text("\(prayer.arabicName) بعد").font(.system(size: 13)).opacity(0.85)
            Text(timerInterval: Date()...max(Date(), time), countsDown: true)
                .font(.system(size: 30, weight: .medium).monospacedDigit())
                .multilineTextAlignment(.center)
            Text(prayer.arabicName).font(.system(size: 22, weight: .bold)).foregroundStyle(Theme.orange)
            Text(DateText.time(time, in: settings.timeZone, use24h: settings.use24h)
                 + (settings.use24h ? "" : " " + DateText.period(time, in: settings.timeZone)))
                .font(.system(size: 13).monospacedDigit()).opacity(0.85)
        }
        .lineLimit(1).minimumScaleFactor(0.6)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.navy)
    }
}
