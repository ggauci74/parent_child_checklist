import SwiftUI

/// iOS 16-friendly day strip:
/// - Real horizontal ScrollView (native inertia/deceleration)
/// - Tap: selection moves immediately (highlight jumps to tapped day), then we scroll it to center WITH highlight
/// - Swipe: momentum scroll, then snap to nearest day on drag end
/// - Hard swipe: highlight fades out and stays hidden until user taps a day again
struct ScrollableDayStrip: View {
    @Binding var selectedDate: Date
    let calendar: Calendar

    /// How many days to build on each side of "today".
    /// 730 = ~2 years each side (lazy loaded).
    var rangeDaysEachSide: Int = 730

    // MARK: - Tuning

    private let itemSpacing: CGFloat = 10
    private let stripHeight: CGFloat = 78

    /// Programmatic scroll animation
    private let scrollAnimResponse: Double = 0.28
    private let scrollAnimDamping: Double = 0.90

    /// Fade (used only for hard swipe)
    private let fadeOutDuration: Double = 0.12
    private let fadeInDuration: Double = 0.12

    // MARK: - Internal data

    private var baseDate: Date {
        calendar.startOfDay(for: Date())
    }

    private var dates: [Date] {
        (-rangeDaysEachSide...rangeDaysEachSide).compactMap { offset in
            calendar
                .date(byAdding: .day, value: offset, to: baseDate)
                .map { calendar.startOfDay(for: $0) }
        }
    }

    /// Each item's midX in the scroll coordinate space
    @State private var itemMidX: [Date: CGFloat] = [:]

    /// Highlight opacity (for hard swipe fade)
    @State private var highlightOpacity: Double = 1.0

    /// ✅ New: when false, the highlight is not allowed to show (until user taps again)
    @State private var highlightArmed: Bool = true

    /// Avoid duplicate scrollTo from onChange when we already scrolled ourselves
    @State private var suppressNextOnChangeScroll: Bool = false

    /// Prevent drag-end snap from firing during a tap-driven programmatic scroll
    @State private var programmaticScrollInFlight: Bool = false

    private func weekdayShort(_ date: Date) -> String {
        let df = DateFormatter()
        df.calendar = calendar
        df.locale = .current
        df.dateFormat = "EEE"
        return df.string(from: date)
    }

    var body: some View {
        GeometryReader { outerGeo in
            let available = outerGeo.size.width
            let cellWidth = max(44, (available - itemSpacing * 6) / 7) // aim for 7 visible cells
            let centerX = available / 2

            // Consider a "hard swipe" when predicted translation is roughly >= 1 cell
            let hardSwipeThreshold = cellWidth * 0.90

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: itemSpacing) {
                        ForEach(dates, id: \.self) { d in
                            DayCell(
                                isSelected: calendar.isDate(d, inSameDayAs: selectedDate),
                                weekdayText: weekdayShort(d),
                                dayNumber: calendar.component(.day, from: d),
                                highlightOpacity: highlightOpacity,
                                showHighlight: highlightArmed
                            )
                            .frame(width: cellWidth, height: stripHeight)
                            .id(d)
                            // Measure midX in the named coordinate space
                            .background(
                                GeometryReader { geo in
                                    Color.clear.preference(
                                        key: DayMidXPreferenceKey.self,
                                        value: [d: geo.frame(in: .named("DayStripScroll")).midX]
                                    )
                                }
                            )
                            .onTapGesture {
                                handleTap(on: d, proxy: proxy)
                            }
                        }
                    }
                    // Padding so first/last can be centered
                    .padding(.horizontal, (available - cellWidth) / 2)
                }
                .coordinateSpace(name: "DayStripScroll")
                .onPreferenceChange(DayMidXPreferenceKey.self) { value in
                    itemMidX = value
                }

                // Drag end snap (iOS 16 custom)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 10)
                        .onEnded { value in
                            // If a tap triggered a programmatic scroll, don't snap.
                            guard !programmaticScrollInFlight else { return }

                            let predicted = abs(value.predictedEndTranslation.width)
                            let isHardSwipe = predicted >= hardSwipeThreshold

                            // ✅ On hard swipe, permanently hide highlight until user taps again
                            if isHardSwipe {
                                highlightArmed = false
                            }

                            snapToNearest(centerX: centerX, proxy: proxy, hardSwipe: isHardSwipe)
                        }
                )

                // External selectedDate change (e.g. Today button):
                // Show highlight (armed) and center the date.
                .onChange(of: selectedDate) { _, newValue in
                    guard !suppressNextOnChangeScroll else {
                        suppressNextOnChangeScroll = false
                        return
                    }

                    // External change is an explicit selection -> show highlight again
                    highlightArmed = true
                    highlightOpacity = 1.0

                    let d = calendar.startOfDay(for: newValue)
                    withAnimation(.spring(response: scrollAnimResponse, dampingFraction: scrollAnimDamping)) {
                        proxy.scrollTo(d, anchor: .center)
                    }
                }

                .onAppear {
                    let d = calendar.startOfDay(for: selectedDate)
                    DispatchQueue.main.async {
                        proxy.scrollTo(d, anchor: .center)
                    }
                }
            }
        }
        .frame(height: stripHeight)
    }

    // MARK: - Tap: highlight jumps to tapped day immediately, then scroll begins

    private func handleTap(on date: Date, proxy: ScrollViewProxy) {
        let target = calendar.startOfDay(for: date)

        // ✅ Tapping is explicit selection => re-arm highlight and show it immediately
        highlightArmed = true
        highlightOpacity = 1.0

        // Block drag-end snap while we do our programmatic scroll
        programmaticScrollInFlight = true

        // ✅ “Pop” highlight onto tapped day FIRST (no animation)
        withTransaction(Transaction(animation: nil)) {
            selectedDate = target
        }

        // We'll scrollTo manually; avoid duplicate scrollTo from onChange
        suppressNextOnChangeScroll = true

        // Start scroll on next runloop so highlight has rendered on the tapped day
        DispatchQueue.main.async {
            withAnimation(.spring(response: scrollAnimResponse, dampingFraction: scrollAnimDamping)) {
                // Programmatic centering via ScrollViewReader (standard approach) [1](https://stackoverflow.com/questions/64976866/scrollviewreaders-scrollto-does-not-scroll)[2](https://www.createwithswift.com/scroll-to-a-specific-item-using-a-scrollviewreader/)
                proxy.scrollTo(target, anchor: .center)
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + scrollAnimResponse) {
                programmaticScrollInFlight = false
            }
        }
    }

    // MARK: - Swipe end snap:
    // Option A: update selectedDate at end (no live update while dragging)
    // Hard swipe: fade out and KEEP hidden afterwards (until user taps)

    private func snapToNearest(centerX: CGFloat, proxy: ScrollViewProxy, hardSwipe: Bool) {
        guard !itemMidX.isEmpty else { return }

        guard let nearest = itemMidX.min(by: { abs($0.value - centerX) < abs($1.value - centerX) })?.key else {
            return
        }

        let target = calendar.startOfDay(for: nearest)
        if calendar.isDate(target, inSameDayAs: selectedDate) { return }

        // We'll handle scroll + selection update ourselves
        suppressNextOnChangeScroll = true

        if hardSwipe {
            // Fade OUT highlight
            withAnimation(.easeOut(duration: fadeOutDuration)) {
                highlightOpacity = 0.0
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + fadeOutDuration) {
                withAnimation(.spring(response: scrollAnimResponse, dampingFraction: scrollAnimDamping)) {
                    proxy.scrollTo(target, anchor: .center)
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + scrollAnimResponse) {
                    // Update selection at end (Option A)
                    withTransaction(Transaction(animation: nil)) {
                        selectedDate = target
                    }

                    // ✅ Keep highlight hidden after hard swipe until user taps again
                    // (highlightArmed was set to false in drag handler)
                    highlightOpacity = 0.0
                }
            }
        } else {
            // Small drag: snap normally. If highlight is armed, keep it visible.
            withAnimation(.spring(response: scrollAnimResponse, dampingFraction: scrollAnimDamping)) {
                proxy.scrollTo(target, anchor: .center)
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + scrollAnimResponse) {
                withTransaction(Transaction(animation: nil)) {
                    selectedDate = target
                }

                // If highlight is not armed (rare here), keep hidden; otherwise show.
                if highlightArmed {
                    withAnimation(.easeIn(duration: fadeInDuration)) {
                        highlightOpacity = 1.0
                    }
                } else {
                    highlightOpacity = 0.0
                }
            }
        }
    }
}

// MARK: - PreferenceKey (midX positions)

private struct DayMidXPreferenceKey: PreferenceKey {
    static var defaultValue: [Date: CGFloat] = [:]
    static func reduce(value: inout [Date: CGFloat], nextValue: () -> [Date: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

// MARK: - Day cell UI

private struct DayCell: View {
    let isSelected: Bool
    let weekdayText: String
    let dayNumber: Int
    let highlightOpacity: Double
    let showHighlight: Bool

    var body: some View {
        VStack(spacing: 6) {
            Text(weekdayText)
                .font(.caption)
                .foregroundStyle(.secondary)

            ZStack {
                Circle()
                    .fill(Color.accentColor)
                    .opacity((showHighlight && isSelected) ? highlightOpacity : 0.0)

                Text("\(dayNumber)")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle((showHighlight && isSelected && highlightOpacity > 0.01) ? .white : .primary)
            }
            .frame(width: 34, height: 34)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .accessibilityLabel("\(weekdayText) \(dayNumber)")
    }
}
