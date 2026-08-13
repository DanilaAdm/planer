import Foundation

/// Разметка недельного дневника: сколько строк-слотов отвести каждому блоку.
///
/// Логика вынесена из вида, потому что от неё зависит вся геометрия разворота:
/// высота блока считается как «число слотов × высота строки», и блоки напротив
/// друг друга обязаны получить одинаковое число слотов. Иначе границы дней на
/// левой и правой странице расходятся, и записи одного дня наезжают на другой.
public enum DiaryLayout {
    /// Минимум строк в блоке: меньше — и вертикальная подпись дня не умещается.
    public static let minRows = 4
    /// Сколько дней недели показывает левая страница разворота (Пн—Ср).
    public static let leftPageDayCount = 3

    /// Слоты одного блока: занятые строки плюс один пустой в конце.
    ///
    /// Свободный слот есть всегда: как только заполнен последний, появляется
    /// следующий, и дню не приходится «переливаться» в соседний блок.
    public static func slots(filled count: Int) -> Int {
        max(minRows, max(0, count) + 1)
    }

    /// Число слотов для семи дней недели и блока заметок.
    ///
    /// `paired == true` — разворот из двух страниц: блоки напротив друг друга
    /// (Пн—Чт, Вт—Пт, Ср—Сб, «Заметки»—Вс) получают одинаковое число слотов и
    /// растут вместе. На узком экране страница одна, выравнивать нечего.
    public static func rowCounts(
        dayEntryCounts: [Int],
        noteCount: Int,
        paired: Bool
    ) -> (days: [Int], notes: Int) {
        var days = dayEntryCounts.map { slots(filled: $0) }
        var notes = slots(filled: noteCount)
        guard paired, days.count == leftPageDayCount * 2 + 1 else { return (days, notes) }

        for left in 0..<leftPageDayCount {
            let right = left + leftPageDayCount
            let shared = max(days[left], days[right])
            days[left] = shared
            days[right] = shared
        }
        // Последний день недели стоит напротив блока заметок.
        let lastDay = days.count - 1
        let shared = max(days[lastDay], notes)
        days[lastDay] = shared
        notes = shared
        return (days, notes)
    }
}
