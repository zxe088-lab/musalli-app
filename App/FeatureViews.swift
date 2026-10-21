import SwiftUI

// MARK: - Daily storage helper

/// Small per-day progress stored in UserDefaults, keyed by local date.
enum DailyStore {
    static func key(_ name: String, _ tz: TimeZone) -> String {
        "\(name):\(DayKey.local(Date(), in: tz).storageKey)"
    }
    static func ints(_ name: String, _ tz: TimeZone) -> [Int: Int] {
        let raw = UserDefaults.standard.dictionary(forKey: key(name, tz)) as? [String: Int] ?? [:]
        return Dictionary(uniqueKeysWithValues: raw.compactMap { k, v in Int(k).map { ($0, v) } })
    }
    static func setInts(_ value: [Int: Int], _ name: String, _ tz: TimeZone) {
        UserDefaults.standard.set(Dictionary(uniqueKeysWithValues: value.map { (String($0.key), $0.value) }), forKey: key(name, tz))
    }
}

// MARK: - Adhkar

struct AdhkarView: View {
    @EnvironmentObject private var model: AppModel
    @State private var kind: AdhkarKind = {
        let h = Calendar.current.component(.hour, from: Date())
        return h >= 15 || h < 3 ? .evening : .morning
    }()
    @State private var progress: [Int: Int] = [:]

    private var list: [Dhikr] { Library.adhkar(kind) }
    private var storeName: String { "adhkar-\(kind.rawValue)" }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Picker("النوع", selection: $kind) {
                    ForEach(AdhkarKind.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                ProgressView(value: Double(list.filter { (progress[$0.id] ?? 0) >= $0.count }.count), total: Double(list.count))
                    .tint(Theme.orange)
                ForEach(list) { d in
                    let count = progress[d.id] ?? 0
                    let done = count >= d.count
                    VStack(alignment: .leading, spacing: 10) {
                        Text(d.text)
                            .font(.system(size: 19, design: .serif))
                            .lineSpacing(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        HStack {
                            Text([d.source, d.count > 1 ? "التكرار: \(d.count)" : ""].filter { !$0.isEmpty }.joined(separator: " · "))
                                .font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Button {
                                guard !done else { return }
                                progress[d.id] = count + 1
                                DailyStore.setInts(progress, storeName, model.settings.timeZone)
                                UIImpactFeedbackGenerator(style: count + 1 == d.count ? .medium : .light).impactOccurred()
                            } label: {
                                Text(done ? "✓ تم" : "\(count) / \(d.count)")
                                    .font(.system(.body, design: .rounded).weight(.bold).monospacedDigit())
                                    .frame(minWidth: 84).padding(.vertical, 7)
                                    .background(done ? Theme.good : Theme.navy, in: Capsule())
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .padding(16)
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16))
                    .opacity(done ? 0.55 : 1)
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("الأذكار")
        .toolbar {
            Button("إعادة") {
                progress = [:]
                DailyStore.setInts([:], storeName, model.settings.timeZone)
            }
        }
        .onAppear(perform: load)
        .onChange(of: kind) { _, _ in load() }
    }

    private func load() { progress = DailyStore.ints(storeName, model.settings.timeZone) }
}

// MARK: - Tasbih

struct TasbihView: View {
    @AppStorage("tasbih.phrase") private var phrase = 0
    @AppStorage("tasbih.target") private var target = 33
    @AppStorage("tasbih.count") private var count = 0
    @AppStorage("tasbih.total") private var total = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text(Library.tasbihPhrases[phrase % Library.tasbihPhrases.count])
                    .font(.system(size: 28, weight: .bold, design: .serif))
                Button(action: tap) {
                    VStack {
                        Text("\(count)").font(.system(size: 64, weight: .semibold, design: .rounded).monospacedDigit())
                        Text(target > 0 ? "من \(target)" : "بدون حد").font(.subheadline).opacity(0.7)
                    }
                    .foregroundStyle(.white)
                    .frame(width: 230, height: 230)
                    .background(RadialGradient(colors: [Color(red: 0.17, green: 0.25, blue: 0.5), Theme.navy], center: .top, startRadius: 10, endRadius: 200), in: Circle())
                    .shadow(color: Theme.navy.opacity(0.35), radius: 16, y: 8)
                }
                .buttonStyle(.plain)
                chips(Library.tasbihPhrases.indices.map { ($0, Library.tasbihPhrases[$0]) }, selected: phrase) { phrase = $0; count = 0 }
                chips([(33, "33"), (100, "100"), (0, "∞")], selected: target) { target = $0; count = 0 }
                Text("المجموع: \(total)").font(.footnote).foregroundStyle(.secondary)
            }
            .padding(16)
        }
        .navigationTitle("السبحة")
        .toolbar { Button("تصفير") { count = 0 } }
    }

    private func tap() {
        count += 1
        total += 1
        if target > 0 && count >= target {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            count = 0
            phrase = (phrase + 1) % Library.tasbihPhrases.count
        } else {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    private func chips(_ items: [(Int, String)], selected: Int, onPick: @escaping (Int) -> Void) -> some View {
        FlowRow(items.map { item in
            AnyView(Button(item.1) { onPick(item.0) }
                .font(.subheadline)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(item.0 == selected ? Theme.navy : Color(.secondarySystemBackground), in: Capsule())
                .foregroundStyle(item.0 == selected ? Color.white : Color.primary))
        })
    }
}

/// Wrapping row of small views.
struct FlowRow: View {
    let views: [AnyView]
    init(_ views: [AnyView]) { self.views = views }
    var body: some View {
        FlowLayout(spacing: 8) { ForEach(views.indices, id: \.self) { views[$0] } }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(proposal.width ?? .infinity, subviews)
        return CGSize(width: proposal.width ?? rows.map { $0.width }.max() ?? 0,
                      height: rows.map { $0.height }.reduce(0, +) + spacing * CGFloat(max(0, rows.count - 1)))
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(bounds.width, subviews) {
            var x = bounds.midX - row.width / 2
            for i in row.items {
                let s = subviews[i].sizeThatFits(.unspecified)
                subviews[i].place(at: CGPoint(x: x, y: y), proposal: .unspecified)
                x += s.width + spacing
            }
            y += row.height + spacing
        }
    }
    private func arrange(_ maxWidth: CGFloat, _ subviews: Subviews) -> [(items: [Int], width: CGFloat, height: CGFloat)] {
        var rows: [(items: [Int], width: CGFloat, height: CGFloat)] = [([], 0, 0)]
        for i in subviews.indices {
            let s = subviews[i].sizeThatFits(.unspecified)
            let extra = rows[rows.count - 1].items.isEmpty ? s.width : s.width + spacing
            if rows[rows.count - 1].width + extra > maxWidth && !rows[rows.count - 1].items.isEmpty {
                rows.append(([i], s.width, s.height))
            } else {
                rows[rows.count - 1].items.append(i)
                rows[rows.count - 1].width += extra
                rows[rows.count - 1].height = max(rows[rows.count - 1].height, s.height)
            }
        }
        return rows
    }
}

// MARK: - Qibla

struct QiblaView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        let bearing = Qibla.bearing(from: model.settings.coordinates)
        let heading = model.heading ?? 0
        let diff = abs(((bearing - heading) + 540).truncatingRemainder(dividingBy: 360) - 180)
        let aligned = model.heading != nil && diff < 5
        ScrollView {
            VStack(spacing: 20) {
                ZStack {
                    Circle().fill(Color(.systemBackground)).overlay(Circle().stroke(aligned ? Theme.good : Color(.separator), lineWidth: aligned ? 4 : 2))
                    ForEach(0..<36) { i in
                        Rectangle().fill(.secondary)
                            .frame(width: i % 9 == 0 ? 3 : 1.2, height: i % 9 == 0 ? 16 : 8)
                            .offset(y: -128)
                            .rotationEffect(.degrees(Double(i) * 10))
                    }
                    ForEach(0..<4, id: \.self) { i in
                        let label = ["N", "E", "S", "W"][i]
                        let deg = Double(i) * 90
                        Text(label).font(.headline.bold()).foregroundStyle(i == 0 ? Color.red : Color.primary)
                            .rotationEffect(.degrees(-deg))
                            .offset(y: -100)
                            .rotationEffect(.degrees(deg))
                    }
                    // Qibla needle with the Kaaba at its tip.
                    VStack(spacing: 4) {
                        Image(systemName: "cube.fill").font(.system(size: 26)).foregroundStyle(.black)
                        Capsule().fill(Theme.orange).frame(width: 8, height: 96)
                        Spacer().frame(height: 110)
                    }
                    .rotationEffect(.degrees(bearing))
                    Circle().fill(Theme.navy).frame(width: 14, height: 14)
                }
                .frame(width: 290, height: 290)
                .rotationEffect(.degrees(-heading))
                .animation(.easeOut(duration: 0.2), value: heading)
                .onChange(of: aligned) { _, now in if now { UINotificationFeedbackGenerator().notificationOccurred(.success) } }

                HStack(spacing: 10) {
                    info("\(Int(bearing.rounded()))°", "من الشمال")
                    info(Int(Qibla.distanceKm(from: model.settings.coordinates)).formatted(), "كم إلى مكة المكرمة")
                }
                Text(model.heading == nil
                     ? "البوصلة غير متاحة. وجّه أعلى الجوال نحو الشمال ثم اتجه نحو رمز الكعبة."
                     : (aligned ? "أنت متجه إلى القبلة" : "أدر الجوال حتى يصير رمز الكعبة في الأعلى"))
                    .font(.subheadline).foregroundStyle(aligned ? Theme.good : .secondary)
                    .multilineTextAlignment(.center)
                Text("ابعد الجوال عن المعادن والمغناطيس لدقة أفضل.").font(.caption).foregroundStyle(.secondary)
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("القبلة")
        .onAppear { model.startHeading() }
        .onDisappear { model.stopHeading() }
    }

    private func info(_ value: String, _ label: String) -> some View {
        VStack {
            Text(value).font(.system(size: 24, weight: .semibold, design: .rounded)).foregroundStyle(Theme.navy)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(12)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Week

struct WeekView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        let s = model.settings
        let today = DayKey.local(Date(), in: s.timeZone)
        List {
            Section {
                ForEach(0..<7, id: \.self) { i in
                    let day = today.adding(days: i)
                    let t = s.calculator.times(for: day)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(DateText.weekday(day) + " · " + DateText.hijri(day, offset: s.hijriOffset, weekday: false))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(i == 0 ? Theme.orange : .primary)
                        HStack {
                            ForEach(Prayer.allCases) { p in
                                VStack(spacing: 2) {
                                    Text(p.arabicName).font(.caption2).foregroundStyle(.secondary)
                                    Text(DateText.time(t[p], in: s.timeZone, use24h: s.use24h)).font(.footnote.monospacedDigit())
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
            } footer: {
                Text("\(s.cityName) · \(s.method.arabicName)")
            }
        }
        .navigationTitle("جدول الأسبوع")
    }
}

// MARK: - Zakat

struct ZakatView: View {
    @State private var cash: Double = 0
    @State private var trade: Double = 0
    @State private var goldGrams: Double = 0
    @State private var debts: Double = 0
    @AppStorage("zakat.goldPrice") private var goldPrice: Double = 0

    var body: some View {
        let total = cash + trade + goldGrams * goldPrice - debts
        let nisab = 85 * goldPrice
        Form {
            Section {
                field("النقد والأرصدة", $cash)
                field("عروض التجارة", $trade)
                field("ذهب (جرام عيار 24)", $goldGrams)
                field("ديون حالّة عليك", $debts)
            }
            Section {
                field("سعر جرام الذهب عيار 24 اليوم", $goldPrice)
            } footer: {
                Text("اكتب سعر الذهب الحالي من مصدر موثوق. النصاب = 85 جرام ذهب.")
            }
            Section("النتيجة") {
                if goldPrice <= 0 {
                    Text("أدخل سعر جرام الذهب لحساب النصاب.").foregroundStyle(.secondary)
                } else if total >= nisab && total > 0 {
                    Text((total * 0.025).formatted(.number.precision(.fractionLength(0...2))))
                        .font(.system(size: 34, weight: .bold, design: .rounded)).foregroundStyle(Theme.good)
                    Text("المال فوق النصاب (\(Int(nisab).formatted())). تجب الزكاة بعد مرور حول هجري كامل عليه.")
                        .font(.footnote).foregroundStyle(.secondary)
                } else {
                    Text("لا زكاة: المال أقل من النصاب (\(Int(nisab).formatted())).")
                }
            }
        }
        .navigationTitle("حاسبة الزكاة")
    }

    private func field(_ title: String, _ value: Binding<Double>) -> some View {
        HStack {
            Text(title)
            TextField("0", value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.leading)
        }
    }
}

// MARK: - Dua

struct DuaView: View {
    var body: some View {
        List(Library.duas.indices, id: \.self) { i in
            let dua = Library.duas[i]
            VStack(alignment: .leading, spacing: 6) {
                Text(dua.0).font(.system(size: 19, design: .serif)).lineSpacing(6)
                Text(dua.1).font(.caption).foregroundStyle(.secondary)
            }
            .padding(.vertical, 6)
            .contextMenu { Button("نسخ") { UIPasteboard.general.string = dua.0 } }
        }
        .navigationTitle("الدعاء")
    }
}

// MARK: - Deeds card

struct DeedsCard: View {
    @EnvironmentObject private var model: AppModel
    @State private var done: [Int: Int] = [:]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "sun.and.horizon.fill").font(.system(size: 30)).symbolRenderingMode(.multicolor)
                    .frame(width: 46, height: 46).background(.white, in: Circle())
                VStack(alignment: .leading) {
                    Text("عمل اليوم والليلة").font(.title3.bold())
                    Text("نرجو أن نكون خير معين لك في طريقك إلى الله").font(.footnote).opacity(0.9)
                }
                Spacer()
            }
            .foregroundStyle(.white)
            .padding(16)
            .background(LinearGradient(colors: [Color(red: 0.29, green: 0.64, blue: 0.85), Color(red: 0.49, green: 0.77, blue: 0.92)], startPoint: .leading, endPoint: .trailing))

            ForEach(Library.deeds.indices, id: \.self) { i in
                let on = done[i] != nil
                Button {
                    if on { done[i] = nil } else { done[i] = 1 }
                    DailyStore.setInts(done, "deeds", model.settings.timeZone)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: on ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 26)).foregroundStyle(on ? Theme.good : Theme.blue)
                        Text(Library.deeds[i])
                            .strikethrough(on).foregroundStyle(on ? Color.secondary : Color.primary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(i.isMultiple(of: 2) ? Theme.strip.opacity(0.6) : .clear)
                }
                .buttonStyle(.plain)
            }
            HStack {
                ProgressView(value: Double(done.count), total: Double(Library.deeds.count)).tint(Theme.orange)
                Text("\(done.count)/\(Library.deeds.count)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            .padding(16)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .onAppear { done = DailyStore.ints("deeds", model.settings.timeZone) }
    }
}

// MARK: - Widget gallery

struct WidgetGalleryView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        let s = model.settings
        let next = s.calculator.nextPrayer(after: Date())
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("الحجم العريض").font(.headline)
                WideWidgetCard(prayer: next.prayer, time: next.time, cityName: s.cityName,
                               hijri: DateText.hijri(DayKey.local(Date(), in: s.timeZone), offset: s.hijriOffset), settings: s)
                    .frame(height: 158).clipShape(RoundedRectangle(cornerRadius: 26))
                Text("الحجم الصغير").font(.headline)
                SmallWidgetCard(prayer: next.prayer, time: next.time, settings: s)
                    .frame(width: 158, height: 158).clipShape(RoundedRectangle(cornerRadius: 26))
                VStack(alignment: .leading, spacing: 6) {
                    Text("طريقة الإضافة").font(.headline)
                    Text("1. اضغط مطولًا على مكان فاضي في الشاشة الرئيسية.\n2. اضغط زر «تعديل» ثم «إضافة ودجت».\n3. ابحث عن «المؤذّن» واختر الحجم.\n\nوتقدر تضيفه لشاشة القفل من: اضغط مطولًا على شاشة القفل ← تخصيص.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("الودجت")
    }
}
