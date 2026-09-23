import SwiftUI

/// Mon–Sun week strip with a dot under days that have a log, matching the diary screen's
/// week selector. Paging is capped so you can't page into the future.
struct WeekStrip: View {
    @Binding var selectedDate: Date
    let hasLog: (Date) -> Bool

    @State private var weekAnchor: Date = Date()
    @Namespace private var selection

    private var calendar: Calendar { Calendar.current }

    private var weekDates: [Date] {
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: weekAnchor)?.start ?? weekAnchor
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: startOfWeek) }
    }

    private var canGoForward: Bool {
        guard let nextWeekStart = calendar.date(byAdding: .day, value: 7, to: weekDates.first ?? Date()) else { return false }
        return nextWeekStart <= Date()
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Button { shiftWeek(by: -1) } label: {
                    Image(systemName: "chevron.left")
                }
                Spacer()
                Button { shiftWeek(by: 1) } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(!canGoForward)
            }
            .foregroundStyle(.secondary)
            .font(.subheadline)

            HStack(spacing: 4) {
                ForEach(weekDates, id: \.self) { date in
                    dayColumn(date)
                }
            }
        }
        .onAppear { weekAnchor = selectedDate }
    }

    private func dayColumn(_ date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(date)
        let isFuture = date > Date()

        return Button {
            guard !isFuture else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { selectedDate = date }
        } label: {
            VStack(spacing: 6) {
                Text(date, format: .dateTime.weekday(.narrow))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("\(Calendar.current.component(.day, from: date))") // not .dateTime.day(): that is "23日" in Chinese and overflows the circle
                    .font(.callout.weight(isSelected ? .bold : .regular))
                    .frame(width: 30, height: 30)
                    .background {
                        // one shared circle that glides between days (matchedGeometryEffect)
                        if isSelected {
                            Circle().fill(Theme.calorie).matchedGeometryEffect(id: "selectedDay", in: selection)
                        }
                    }
                    .foregroundStyle(isSelected ? Color.white : (isFuture ? Color(.tertiaryLabel) : Color.primary))
                    .overlay {
                        if isToday && !isSelected {
                            Circle().strokeBorder(Theme.calorie, lineWidth: 1)
                        }
                    }
                Circle()
                    .fill(hasLog(date) ? Theme.calorie : .clear)
                    .frame(width: 4, height: 4)
            }
            .frame(maxWidth: .infinity)
        }
        .disabled(isFuture)
        .sensoryFeedback(.selection, trigger: isSelected) { _, nowSelected in nowSelected }
    }

    private func shiftWeek(by weeks: Int) {
        if let newAnchor = calendar.date(byAdding: .weekOfYear, value: weeks, to: weekAnchor) {
            withAnimation(.snappy) { weekAnchor = newAnchor }
        }
    }
}
