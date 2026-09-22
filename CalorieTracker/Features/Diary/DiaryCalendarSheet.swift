import SwiftUI

struct DiaryCalendarSheet: View {
    @Binding var selectedDate: Date
    @Environment(UserDataStore.self) private var userData
    @Environment(LocalizationStore.self) private var localization
    @Environment(\.dismiss) private var dismiss

    @State private var monthAnchor = Date()

    private var calendar: Calendar { Calendar.current }

    private var monthDates: [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: monthAnchor) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: interval.start)
        let leadingBlanks = (firstWeekday - calendar.firstWeekday + 7) % 7
        var days: [Date?] = Array(repeating: nil, count: leadingBlanks)
        var day = interval.start
        while day < interval.end {
            days.append(day)
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
        return days
    }

    private var canGoForward: Bool {
        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthAnchor) else { return false }
        return calendar.compare(nextMonth, to: Date(), toGranularity: .month) != .orderedDescending
    }

    private var streak: Int {
        var count = 0
        var cursor = Date()
        while !userData.dayLog(DateKey.string(for: cursor)).meals.isEmpty {
            count += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor)!
        }
        return count
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                HStack {
                    Image(systemName: "flame.fill").foregroundStyle(Theme.calorie)
                    Text("\(streak) " + localization.t("diary.streak"))
                        .fontWeight(.semibold)
                    Spacer()
                    Button(localization.t("common.today")) {
                        monthAnchor = Date()
                        selectedDate = Date()
                        dismiss()
                    }
                    .font(.footnote)
                }

                HStack {
                    Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left") }
                    Spacer()
                    Text(monthAnchor, format: .dateTime.month(.wide).year())
                        .font(.headline)
                    Spacer()
                    Button { shiftMonth(1) } label: { Image(systemName: "chevron.right") }
                        .disabled(!canGoForward)
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 12) {
                    ForEach(Array(monthDates.enumerated()), id: \.offset) { _, date in
                        if let date {
                            dayCell(date)
                        } else {
                            Color.clear.frame(height: 36)
                        }
                    }
                }
            }
            .padding(24)
            .navigationTitle(localization.t("diary.calendar"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localization.t("common.done")) { dismiss() }
                }
            }
            .onAppear { monthAnchor = selectedDate }
        }
    }

    private func dayCell(_ date: Date) -> some View {
        let key = DateKey.string(for: date)
        let log = userData.dayLog(key)
        let energy = log.meals.reduce(0) { $0 + $1.energy }
        let goal = userData.profile.target ?? 2000
        let isFuture = date > Date()
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)

        let color: Color = {
            if log.meals.isEmpty { return .gray.opacity(0.25) }
            return energy <= goal ? Theme.success : Theme.danger
        }()

        return Button {
            guard !isFuture else { return }
            selectedDate = date
            dismiss()
        } label: {
            VStack(spacing: 4) {
                Text(date, format: .dateTime.day())
                    .font(.caption)
                    .fontWeight(isSelected ? .bold : .regular)
                Circle()
                    .strokeBorder(color, lineWidth: 3)
                    .frame(width: 22, height: 22)
            }
            .opacity(isFuture ? 0.3 : 1)
        }
        .disabled(isFuture)
        .foregroundStyle(.primary)
    }

    private func shiftMonth(_ delta: Int) {
        if let next = calendar.date(byAdding: .month, value: delta, to: monthAnchor) {
            monthAnchor = next
        }
    }
}
