import SwiftUI
import PlannerCore
#if canImport(AppKit)
import AppKit
#endif

/// Форма создания/редактирования ученика.
struct StudentEditorView: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss

    private let existing: Student?

    @State private var name: String
    @State private var colorHex: String
    @State private var priceText: String
    @State private var workFormat: WorkFormat
    @State private var googleDocURL: String
    @State private var paidLessonsTotal: Int
    @State private var lessonsUsed: Int

    init(student: Student?) {
        self.existing = student
        _name = State(initialValue: student?.name ?? "")
        _colorHex = State(initialValue: student?.colorHex ?? HexColor.palette[0])
        _priceText = State(initialValue: student.map { NSDecimalNumber(decimal: $0.pricePerLesson).stringValue } ?? "")
        _workFormat = State(initialValue: student?.workFormat ?? .postpay)
        _googleDocURL = State(initialValue: student?.googleDocURL?.absoluteString ?? "")
        _paidLessonsTotal = State(initialValue: student?.paidLessonsTotal ?? 0)
        _lessonsUsed = State(initialValue: student?.lessonsUsed ?? 0)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    SectionCard(title: "Основное") {
                        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                            FormFieldRow(title: "Имя ученика", systemImage: "person") {
                                TextField("Имя ученика", text: $name)
                                    .textFieldStyle(.roundedBorder)
                                    .foregroundStyle(Theme.ink)
                                    .accessibilityIdentifier("studentNameField")
                            }
                            RowDivider()
                            FormFieldRow(title: "Цвет", systemImage: "paintpalette") {
                                ColorPalettePicker(selection: $colorHex)
                            }
                        }
                    }

                    SectionCard(title: "Оплата") {
                        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                            FormFieldRow(title: "Стоимость урока", systemImage: "rublesign.circle") {
                                TextField("Стоимость урока", text: $priceText)
                                    .textFieldStyle(.roundedBorder)
                                    .foregroundStyle(Theme.ink)
                                    #if os(iOS)
                                    .keyboardType(.decimalPad)
                                    #endif
                            }
                            RowDivider()
                            FormFieldRow(title: "Формат работы", systemImage: "briefcase") {
                                Picker("Формат работы", selection: $workFormat) {
                                    ForEach(WorkFormat.allCases, id: \.self) { format in
                                        Text(format.localizedTitle).tag(format)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.segmented)
                            }
                            // Счётчики абонемента нужны только для формата «Абонемент».
                            if workFormat == .subscription {
                                RowDivider()
                                countRow("Оплачено уроков", value: $paidLessonsTotal, range: 0...500)
                                countRow("Использовано", value: $lessonsUsed, range: 0...max(0, paidLessonsTotal))
                            }
                        }
                    }

                    SectionCard(title: "Google-документ") {
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            TextField("Ссылка на документ", text: $googleDocURL)
                                .textFieldStyle(.roundedBorder)
                                .foregroundStyle(Theme.ink)
                                .accessibilityIdentifier("studentDocField")
                                #if os(iOS)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                #endif
                            Text("Документ с пройденным материалом и предстоящими темами. Откройте в Google доступ «по ссылке» — тогда он будет читаться прямо в приложении.")
                                .font(.caption)
                                .foregroundStyle(Theme.inkSoft)
                        }
                    }
                }
                .padding(Theme.Spacing.lg)
                .centeredContent(maxWidth: 560)
            }
            .screenBackground()
            .tint(Theme.accent)
            .navigationTitle(existing == nil ? "Новый ученик" : "Редактирование")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                        .accessibilityIdentifier("saveStudentButton")
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 460, idealWidth: 500, minHeight: 560, idealHeight: 640)
        // Закрываем системную палитру цветов вместе с окном редактора.
        .onDisappear { NSColorPanel.shared.close() }
        #endif
    }

    /// Строка ввода количества: прямой ввод числа + шаговый регулятор.
    private func countRow(_ title: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(Theme.ink)
            Spacer()
            HStack(spacing: 8) {
                TextField("0", value: value, format: .number)
                    .labelsHidden()
                    .multilineTextAlignment(.trailing)
                    .frame(width: 64)
                    .textFieldStyle(.roundedBorder)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                Stepper("", value: value, in: range)
                    .labelsHidden()
                    .fixedSize()
            }
        }
    }

    private func save() {
        let price = Decimal(string: priceText.replacingOccurrences(of: ",", with: ".")) ?? 0
        // Счётчики абонемента актуальны только для формата «Абонемент».
        let isSubscription = workFormat == .subscription
        let total = isSubscription ? paidLessonsTotal : 0
        let used = isSubscription ? min(lessonsUsed, paidLessonsTotal) : 0
        let student = Student(
            id: existing?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
            colorHex: HexColor.normalized(colorHex),
            pricePerLesson: price,
            workFormat: workFormat,
            googleDocURL: GoogleDocLink.normalized(googleDocURL),
            paidLessonsTotal: total,
            lessonsUsed: used,
            createdAt: existing?.createdAt ?? Date()
        )
        Task {
            await env.saveStudent(student)
            dismiss()
        }
    }
}

/// Выбор цвета из палитры + возможность задать свой оттенок.
struct ColorPalettePicker: View {
    @Binding var selection: String

    private let columns = [GridItem(.adaptive(minimum: 36), spacing: 10)]

    /// Выбран ли цвет, которого нет в готовой палитре.
    private var isCustom: Bool {
        let norm = HexColor.normalized(selection)
        return !HexColor.palette.contains { HexColor.normalized($0) == norm }
    }

    /// Мост между HEX-строкой и SwiftUI-цветом для системной палитры.
    private var customBinding: Binding<Color> {
        Binding(
            get: { Color(hex: selection) },
            set: { selection = $0.toHex() }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(HexColor.palette, id: \.self) { hex in
                    swatch(hex)
                }
                // Показываем выбранный пользователем оттенок как активную ячейку.
                if isCustom {
                    swatch(HexColor.normalized(selection))
                }
            }

            ColorPicker(selection: customBinding, supportsOpacity: false) {
                Label("Свой цвет…", systemImage: "paintpalette")
                    .font(.subheadline)
            }
            .accessibilityIdentifier("customColorPicker")
        }
        .padding(.vertical, 4)
    }

    private func swatch(_ hex: String) -> some View {
        let isSelected = HexColor.normalized(hex) == HexColor.normalized(selection)
        return Circle()
            .fill(Color(hex: hex))
            .frame(width: 32, height: 32)
            .overlay {
                Circle().strokeBorder(Color.black.opacity(0.08), lineWidth: 0.5)
            }
            .overlay {
                if isSelected {
                    Circle()
                        .stroke(Theme.ink, lineWidth: 2)
                        .padding(-3)
                }
            }
            .onTapGesture { selection = HexColor.normalized(hex) }
    }
}
