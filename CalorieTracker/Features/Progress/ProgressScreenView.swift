import SwiftUI
import Charts

struct DayTrendPoint: Identifiable {
    let date: Date
    let protein: Double
    let carbs: Double
    let fat: Double
    var energy: Double { protein * 4 + carbs * 4 + fat * 9 }
    var id: Date { date }
}

struct ProgressScreenView: View {
    @Environment(UserDataStore.self) private var userData
    @Environment(LocalizationStore.self) private var localization

    private var calendar: Calendar { Calendar.current }
    private var goal: Double { userData.profile.target ?? 2000 }

    private var trackedDates: [String] {
        userData.dailyLogs.filter { !$0.value.meals.isEmpty }.keys.sorted()
    }

    private var daysTracked: Int { trackedDates.count }

    private var currentStreak: Int {
        var count = 0
        var cursor = Date()
        while !userData.dayLog(DateKey.string(for: cursor)).meals.isEmpty {
            count += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor)!
        }
        return count
    }

    private var firstTrackedDateText: String {
        guard let first = trackedDates.first, let date = DateKey.date(from: first) else { return "—" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private var averages: (energy: Double, protein: Double, carbs: Double, fat: Double) {
        guard !trackedDates.isEmpty else { return (0, 0, 0, 0) }
        let totals = trackedDates.reduce((0.0, 0.0, 0.0, 0.0)) { acc, date in
            let t = userData.dayTotals(date)
            return (acc.0 + t.energy, acc.1 + t.protein, acc.2 + t.carbs, acc.3 + t.fat)
        }
        let n = Double(trackedDates.count)
        return (totals.0 / n, totals.1 / n, totals.2 / n, totals.3 / n)
    }

    private var adherenceRate: Double {
        guard !trackedDates.isEmpty else { return 0 }
        let onTarget = trackedDates.filter { userData.dayTotals($0).energy <= goal }.count
        return Double(onTarget) / Double(trackedDates.count)
    }

    private var weightChange: Double? {
        guard let firstKey = trackedDates.first,
              let firstWeight = userData.dayLog(firstKey).weight,
              let currentWeight = userData.profile.weight else { return nil }
        return currentWeight - firstWeight
    }

    private var last7Days: [DayTrendPoint] {
        (0..<7).reversed().map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: Date())!
            let totals = userData.dayTotals(DateKey.string(for: date))
            return DayTrendPoint(date: date, protein: totals.protein, carbs: totals.carbs, fat: totals.fat)
        }
    }

    private var trendTotal: Double { last7Days.reduce(0) { $0 + $1.energy } }
    private var trendAverage: Double { last7Days.isEmpty ? 0 : trendTotal / Double(last7Days.count) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if daysTracked == 0 {
                        Text(localization.t("progress.empty"))
                            .foregroundStyle(.secondary)
                            .padding(.top, 60)
                    } else {
                        overallCard
                        todayCard
                        trendCard
                    }
                }
                .padding(16)
            }
            .background(Theme.screenBackground)
            .navigationTitle(localization.t("tab.progress"))
        }
    }

    private var overallCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(localization.t("progress.overall")).font(.headline)

            HStack {
                metric(localization.t("progress.daysTracked"), "\(daysTracked)")
                metric(localization.t("progress.currentStreak"), "\(currentStreak)")
            }
            HStack {
                metric("Since", firstTrackedDateText)
                metric(localization.t("progress.avgIntake"), "\(Int(averages.energy)) kcal")
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(localization.t("progress.adherence"))
                    Spacer()
                    Text(adherenceRate, format: .percent.precision(.fractionLength(0)))
                }
                .font(.subheadline)
                ProgressView(value: adherenceRate)
                    .tint(Theme.success)
            }

            if let weightChange {
                let matchesGoal = (userData.profile.goal == .bulk && weightChange > 0) || (userData.profile.goal == .cut && weightChange < 0) || (userData.profile.goal == .maintain && abs(weightChange) < 1)
                HStack {
                    Text(localization.t("progress.weightChange"))
                    Spacer()
                    Text(weightChange, format: .number.precision(.fractionLength(1)).sign(strategy: .always()))
                        .foregroundStyle(matchesGoal ? Theme.success : Theme.danger)
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
            }
        }
        .cardStyle()
    }

    private var todayCard: some View {
        let todayTotals = userData.dayTotals(DateKey.today())
        return VStack(alignment: .leading, spacing: 8) {
            Text(localization.t("progress.todaySummary")).font(.headline)
            HStack {
                metric(localization.t("diary.eaten"), "\(Int(todayTotals.energy)) kcal")
                metric(localization.t("diary.left"), "\(Int(max(goal - todayTotals.energy, 0))) kcal")
            }
        }
        .cardStyle()
    }

    private var trendCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localization.t("progress.sevenDayTrend")).font(.headline)

            Chart {
                ForEach(last7Days) { point in
                    BarMark(x: .value("Day", point.date, unit: .day), y: .value("Protein", point.protein * 4))
                        .foregroundStyle(Theme.protein)
                    BarMark(x: .value("Day", point.date, unit: .day), y: .value("Carbs", point.carbs * 4))
                        .foregroundStyle(Theme.carbs)
                    BarMark(x: .value("Day", point.date, unit: .day), y: .value("Fat", point.fat * 9))
                        .foregroundStyle(Theme.fat)
                }
                RuleMark(y: .value("Goal", goal))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                    .foregroundStyle(.secondary)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { AxisValueLabel(format: .dateTime.weekday(.narrow)) }
            }
            .frame(height: 180)

            HStack {
                Text(localization.t("progress.total") + ": \(Int(trendTotal)) kcal")
                Spacer()
                Text(localization.t("progress.average") + ": \(Int(trendAverage)) kcal")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .cardStyle()
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.title3.bold())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
