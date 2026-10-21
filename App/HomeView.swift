import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var model: AppModel
    @State private var dayOffset = 0

    private var s: AppSettings { model.settings }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                dateBar
                prayerStrip
                VStack(spacing: 16) {
                    features
                    DeedsCard()
                    widgetPreview
                    verse
                }
                .padding(16)
            }
        }
        .background(Color(.systemGroupedBackground))
        .ignoresSafeArea(edges: .top)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: Header

    private var header: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            let next = s.calculator.nextPrayer(after: ctx.date)
            ZStack(alignment: .top) {
                LinearGradient(colors: [Theme.skyTop, Theme.skyBottom], startPoint: .top, endPoint: .bottom)
                MosqueScene().frame(maxHeight: .infinity, alignment: .bottom)
                VStack(spacing: 4) {
                    Text("\(next.prayer.arabicName) بعد")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Theme.navy)
                    Text(Self.hms(next.time.timeIntervalSince(ctx.date)))
                        .font(.system(size: 58, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.black)
                        .environment(\.layoutDirection, .leftToRight)
                    NavigationLink { SettingsView() } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text(s.cityName).fontWeight(.semibold)
                            Image(systemName: "plus")
                        }
                        .font(.system(size: 16))
                        .padding(.horizontal, 16).padding(.vertical, 7)
                        .background(Theme.navy, in: Capsule())
                        .foregroundStyle(.white)
                    }
                }
                .padding(.top, 70)
            }
            .frame(height: 380)
        }
    }

    static func hms(_ interval: TimeInterval) -> String {
        let t = max(0, Int(interval))
        return String(format: "%02d:%02d:%02d", t / 3600, t % 3600 / 60, t % 60)
    }

    // MARK: Date bar

    private var viewedDay: DayKey { DayKey.local(Date(), in: s.timeZone).adding(days: dayOffset) }

    private var dateBar: some View {
        HStack {
            Button { dayOffset -= 1 } label: { Image(systemName: "chevron.right") }
                .accessibilityLabel("اليوم السابق")
            Spacer()
            VStack(spacing: 2) {
                HStack(spacing: 6) {
                    Text(DateText.hijri(viewedDay, offset: s.hijriOffset))
                    Text("–").foregroundStyle(Theme.orange)
                    Text(DateText.gregorian(viewedDay))
                }
                .font(.system(size: 14.5, weight: .semibold))
                .lineLimit(1).minimumScaleFactor(0.7)
                if dayOffset != 0 {
                    Button("العودة لليوم") { dayOffset = 0 }.font(.caption.weight(.semibold))
                }
            }
            Spacer()
            Button { dayOffset += 1 } label: { Image(systemName: "chevron.left") }
                .accessibilityLabel("اليوم التالي")
        }
        .font(.title3.weight(.semibold))
        .foregroundStyle(Theme.blue)
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(Color(.systemBackground))
    }

    // MARK: Prayer strip

    private var prayerStrip: some View {
        TimelineView(.everyMinute) { ctx in
            let calc = s.calculator
            let day = calc.times(for: viewedDay)
            let next = calc.nextPrayer(after: ctx.date)
            let night = calc.nightMarks(for: day)
            VStack(spacing: 10) {
                HStack(spacing: 0) {
                    ForEach(Prayer.allCases) { p in
                        let current = dayOffset == 0 && p == next.prayer && day[p] == next.time
                        VStack(spacing: 8) {
                            Text(p.arabicName).font(.system(size: 15, weight: .bold))
                            Image(systemName: p.symbol)
                                .symbolRenderingMode(.multicolor)
                                .font(.system(size: 20))
                                .frame(width: 40, height: 40)
                                .background(Color(.systemBackground), in: Circle())
                            Text(DateText.time(day[p], in: s.timeZone, use24h: s.use24h))
                                .font(.system(size: 16, weight: .semibold).monospacedDigit())
                        }
                        .foregroundStyle(current ? Theme.orange : .primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(current ? Color(.systemBackground) : .clear,
                                    in: UnevenRoundedRectangle(bottomLeadingRadius: 18, bottomTrailingRadius: 18))
                    }
                }
                HStack(spacing: 10) {
                    nightPill("منتصف الليل", night.midnight)
                    Rectangle().fill(.secondary).frame(width: 1, height: 20)
                    nightPill("الثلث الأخير", night.lastThird)
                }
                .padding(.horizontal, 12)
            }
            .padding(.bottom, 12)
            .background(Theme.strip)
        }
    }

    private func nightPill(_ title: String, _ date: Date) -> some View {
        HStack(spacing: 4) {
            Text(title + ":")
            Text(DateText.time(date, in: s.timeZone, use24h: s.use24h)).foregroundStyle(Theme.blue).monospacedDigit()
        }
        .font(.system(size: 14.5, weight: .semibold))
        .frame(maxWidth: .infinity).padding(.vertical, 6)
        .background(Color(.systemBackground), in: Capsule())
    }

    // MARK: Features

    private var features: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 14) {
            feature("الأذكار", "book.pages.fill", Theme.blue) { AdhkarView() }
            feature("السبحة", "circle.hexagongrid.circle.fill", Theme.navy) { TasbihView() }
            feature("القبلة", "location.north.circle.fill", .black) { QiblaView() }
            feature("جدول الأسبوع", "calendar", Theme.orange) { WeekView() }
            feature("حاسبة الزكاة", "percent", Theme.good) { ZakatView() }
            feature("الدعاء", "hands.sparkles.fill", Theme.blue) { DuaView() }
            feature("الودجت", "rectangle.split.2x1.fill", Theme.navy) { WidgetGalleryView() }
            feature("الإعدادات", "gearshape.fill", .gray) { SettingsView() }
        }
        .padding(16)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    private func feature<D: View>(_ title: String, _ symbol: String, _ color: Color, @ViewBuilder _ dest: @escaping () -> D) -> some View {
        NavigationLink(destination: dest) {
            VStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 22))
                    .foregroundStyle(.white)
                    .frame(width: 54, height: 54)
                    .background(color, in: Circle())
                Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(.primary)
                    .multilineTextAlignment(.center).lineLimit(2)
            }
        }
    }

    // MARK: Widget preview & verse

    private var widgetPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("الودجت").font(.headline)
            TimelineView(.everyMinute) { ctx in
                let next = s.calculator.nextPrayer(after: ctx.date)
                WideWidgetCard(prayer: next.prayer, time: next.time, cityName: s.cityName,
                               hijri: DateText.hijri(DayKey.local(ctx.date, in: s.timeZone), offset: s.hijriOffset),
                               settings: s)
                    .frame(height: 158)
                    .clipShape(RoundedRectangle(cornerRadius: 26))
                    .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
            }
        }
    }

    private var verse: some View {
        VStack(spacing: 4) {
            Text("إِنَّ الصَّلَاةَ كَانَتْ عَلَى الْمُؤْمِنِينَ كِتَابًا مَّوْقُوتًا")
                .font(.system(size: 20, weight: .medium, design: .serif))
                .multilineTextAlignment(.center)
            Text("سورة النساء، الآية 103").font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 18))
    }
}

/// Simple illustrated mosque drawn on a 480×250 grid.
struct MosqueScene: View {
    var body: some View {
        Canvas { ctx, size in
            let sx = size.width / 480, sy = size.height / 250
            func rect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> Path {
                Path(CGRect(x: x * sx, y: y * sy, width: w * sx, height: h * sy))
            }
            func pt(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x * sx, y: y * sy) }
            let wall = Color(red: 0.965, green: 0.957, blue: 0.980)
            let shade = Color(red: 0.788, green: 0.784, blue: 0.910)
            let dome = Theme.orange
            let sand = Color(red: 0.910, green: 0.824, blue: 0.604)

            var dune = Path()
            dune.move(to: pt(0, 150))
            dune.addQuadCurve(to: pt(240, 140), control: pt(120, 115))
            dune.addQuadCurve(to: pt(480, 140), control: pt(360, 120))
            dune.addLine(to: pt(480, 250)); dune.addLine(to: pt(0, 250)); dune.closeSubpath()
            ctx.fill(dune, with: .color(sand))

            for x in [52.0, 412.0] {
                ctx.fill(rect(x, 88, 16, 132), with: .color(shade))
                ctx.fill(rect(x - 4, 112, 24, 7), with: .color(wall))
                var cap = Path()
                cap.move(to: pt(x - 2, 88)); cap.addQuadCurve(to: pt(x + 18, 88), control: pt(x + 8, 62)); cap.closeSubpath()
                ctx.fill(cap, with: .color(dome))
            }
            ctx.fill(rect(80, 160, 320, 60), with: .color(wall))
            ctx.fill(rect(80, 156, 320, 6), with: .color(shade))
            ctx.fill(rect(120, 112, 74, 108), with: .color(wall))
            var arch = Path()
            arch.move(to: pt(132, 220)); arch.addLine(to: pt(132, 150))
            arch.addQuadCurve(to: pt(182, 150), control: pt(157, 110))
            arch.addLine(to: pt(182, 220)); arch.closeSubpath()
            ctx.fill(arch, with: .color(shade))
            ctx.fill(rect(276, 128, 98, 34), with: .color(wall))
            var big = Path()
            big.move(to: pt(270, 132)); big.addQuadCurve(to: pt(380, 132), control: pt(325, 30)); big.closeSubpath()
            ctx.fill(big, with: .color(dome))
            ctx.fill(rect(323.5, 56, 3, 22), with: .color(dome))
            for x in stride(from: 96.0, through: 378, by: 22) where x < 120 || x > 200 {
                ctx.fill(Path(roundedRect: CGRect(x: x * sx, y: 176 * sy, width: 10 * sx, height: 22 * sy), cornerRadius: 5 * sx),
                         with: .color(dome.opacity(0.85)))
            }
            var hill = Path()
            hill.move(to: pt(0, 215))
            hill.addQuadCurve(to: pt(240, 210), control: pt(120, 190))
            hill.addQuadCurve(to: pt(480, 206), control: pt(360, 222))
            hill.addLine(to: pt(480, 250)); hill.addLine(to: pt(0, 250)); hill.closeSubpath()
            ctx.fill(hill, with: .color(Color(red: 0.498, green: 0.647, blue: 0.322)))
        }
        .aspectRatio(480 / 250, contentMode: .fit)
    }
}
