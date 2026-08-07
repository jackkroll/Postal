import SwiftUI

/// Explicit delivery timing chosen on the send confirmation sheet.
///
/// A choice is required before send — nothing is pre-selected.
enum LetterSendTimingOption: Hashable, Identifiable {
    /// Natural route delivery with no hold (`schedule_preset` / `deliver_at` omitted).
    case natural
    case preset(SchedulePreset)
    /// Plus-only exact datetime (`deliver_at`).
    case custom

    var id: String {
        switch self {
        case .natural: "natural"
        case let .preset(preset): preset.rawValue
        case .custom: "custom"
        }
    }

    var title: String {
        switch self {
        case .natural: PromoText.sendTimingNatural
        case let .preset(preset): PromoText.sendTimingPreset(preset)
        case .custom: PromoText.sendTimingCustom
        }
    }

    func subtitle(customDeliverAtEnabled: Bool) -> String? {
        switch self {
        case .natural: PromoText.sendTimingNaturalDetail
        case .preset: PromoText.sendTimingPresetDetail
        case .custom:
            customDeliverAtEnabled
                ? PromoText.sendTimingCustomDetail
                : PromoText.sendTimingCustomLockedDetail
        }
    }
}

/// Review postage and choose delivery timing before the letter is sent.
struct SendConfirmationSheet: View {
    @Environment(\.dismiss) private var dismiss

    let stampCost: Int
    let stampBalance: Int?
    let unlimitedSends: Bool
    let scheduling: SchedulingEntitlements
    let routeEstimate: ShipmentEstimate?
    let isLoadingEstimate: Bool
    let estimateError: String?

    @Binding var selectedTiming: LetterSendTimingOption?
    @Binding var customDeliverAt: Date

    var onConfirm: () -> Void
    var onUpgrade: (() -> Void)?

    private var availableOptions: [LetterSendTimingOption] {
        var options: [LetterSendTimingOption] = [.natural]
        options += scheduling.presets.map(LetterSendTimingOption.preset)
        // Always show Plus custom timing; Free sees it disabled.
        options.append(.custom)
        return options
    }

    private var canUseCustomDeliverAt: Bool {
        scheduling.customDeliverAt
    }

    /// Earliest valid unlock time — natural ETA when known, otherwise now.
    private var minimumCustomDate: Date {
        let eta = routeEstimate?.expectedDeliveryTime ?? .now
        return max(eta, .now)
    }

    private var canConfirm: Bool {
        guard let selectedTiming else { return false }
        switch selectedTiming {
        case .custom:
            guard canUseCustomDeliverAt else { return false }
            // Reject holds earlier than natural arrival.
            return customDeliverAt >= minimumCustomDate
        case .natural, .preset:
            return true
        }
    }

    var body: some View {
        NavigationStack {
            List {
                billingSection
                scheduleSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle(PromoText.sendConfirmationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if #available(iOS 26.0, *) {
                        Button(role: .cancel) { dismiss() }
                    } else {
                        Button("Cancel") { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if #available(iOS 26.0, *) {
                        Button(role: .confirm) {
                            guard canConfirm else { return }
                            onConfirm()
                        }
                        .disabled(!canConfirm)
                    } else {
                        Button(PromoText.sendConfirmationAction) {
                            guard canConfirm else { return }
                            onConfirm()
                        }
                        .disabled(!canConfirm)
                    }
                }
            }
            .onAppear {
                clampCustomDeliverAt()
            }
            .onChange(of: minimumCustomDate) { _, _ in
                clampCustomDeliverAt()
            }
            .onChange(of: customDeliverAt) { _, newValue in
                // DatePicker should already clamp; enforce if a stale value sneaks through.
                if selectedTiming == .custom, newValue < minimumCustomDate {
                    customDeliverAt = minimumCustomDate
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var billingSection: some View {
        Section {
            if unlimitedSends {
                billingRow(
                    title: PromoText.sendBillingPostage,
                    value: PromoText.unlimitedSendsWithPlus,
                    valueColor: .secondary
                )
            } else {
                billingRow(
                    title: PromoText.sendBillingPostage,
                    value: PromoText.stampCostForLetter(max(stampCost, 1)),
                    valueColor: .primary
                )
                if let stampBalance {
                    billingRow(
                        title: PromoText.sendBillingBalance,
                        value: PromoText.stampBalance(stampBalance),
                        valueColor: stampBalance >= stampCost ? .secondary : .red
                    )
                    if stampCost > 0, stampBalance >= stampCost {
                        billingRow(
                            title: PromoText.sendBillingAfterSend,
                            value: PromoText.stampBalance(stampBalance - stampCost),
                            valueColor: .secondary
                        )
                    }
                }
            }
        } header: {
            Text(PromoText.sendBillingSection)
        } footer: {
            if !unlimitedSends, let onUpgrade {
                Button(PromoText.upgradeToPlus, action: onUpgrade)
                    .font(.footnote.weight(.semibold))
            }
        }
    }

    private var scheduleSection: some View {
        Section {
            ForEach(availableOptions) { option in
                timingRow(option)
            }

            if selectedTiming == .custom, canUseCustomDeliverAt {
                DatePicker(
                    PromoText.sendTimingCustomPicker,
                    selection: $customDeliverAt,
                    in: minimumCustomDate...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .accessibilityHint(PromoText.sendTimingHoldTooEarly)
            }
        } header: {
            Text(PromoText.sendTimingSection)
        } footer: {
            timingFooter
        }
    }

    @ViewBuilder
    private var timingFooter: some View {
        if isLoadingEstimate {
            Text(PromoText.sendTimingEstimateLoading)
        } else if let estimateError {
            Text(estimateError)
                .foregroundStyle(.red)
        } else if let eta = routeEstimate?.expectedDeliveryTime {
            Text(PromoText.sendTimingNaturalETA(eta))
        } else if selectedTiming == nil {
            Text(PromoText.sendTimingRequired)
        } else if selectedTiming == .custom, canUseCustomDeliverAt {
            Text(PromoText.sendTimingHoldTooEarly)
        }
    }

    private func billingRow(title: String, value: String, valueColor: Color) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(valueColor)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }

    private func timingRow(_ option: LetterSendTimingOption) -> some View {
        let isCustomLocked = option == .custom && !canUseCustomDeliverAt
        let isSelected = selectedTiming == option

        return Button {
            if isCustomLocked {
                onUpgrade?()
                return
            }
            selectedTiming = option
            if option == .custom {
                clampCustomDeliverAt()
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: rowSymbol(isSelected: isSelected, isLocked: isCustomLocked))
                    .font(.title3)
                    .foregroundStyle(rowSymbolColor(isSelected: isSelected, isLocked: isCustomLocked))

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(option.title)
                            .foregroundStyle(isCustomLocked ? .secondary : .primary)
                        if isCustomLocked {
                            Text(PromoText.plusShort)
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.15), in: Capsule())
                                .foregroundStyle(.secondary)
                        }
                    }
                    if let subtitle = option.subtitle(customDeliverAtEnabled: canUseCustomDeliverAt) {
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .opacity(isCustomLocked ? 0.85 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(isCustomLocked ? PromoText.upgradeToPlus : "")
    }

    private func rowSymbol(isSelected: Bool, isLocked: Bool) -> String {
        if isLocked { return "lock.fill" }
        return isSelected ? "checkmark.circle.fill" : "circle"
    }

    private func rowSymbolColor(isSelected: Bool, isLocked: Bool) -> Color {
        if isLocked { return .secondary }
        return isSelected ? Color.accentColor : Color.secondary
    }

    private func clampCustomDeliverAt() {
        if customDeliverAt < minimumCustomDate {
            customDeliverAt = minimumCustomDate
        }
    }
}

#Preview("Free") {
    @Previewable @State var timing: LetterSendTimingOption?
    @Previewable @State var customDate = Date()

    SendConfirmationSheet(
        stampCost: 2,
        stampBalance: 5,
        unlimitedSends: false,
        scheduling: .freeDefaults,
        routeEstimate: nil,
        isLoadingEstimate: false,
        estimateError: nil,
        selectedTiming: $timing,
        customDeliverAt: $customDate,
        onConfirm: {},
        onUpgrade: {}
    )
}

#Preview("Plus") {
    @Previewable @State var timing: LetterSendTimingOption?
    @Previewable @State var customDate = Date().addingTimeInterval(86_400 * 10)

    SendConfirmationSheet(
        stampCost: 0,
        stampBalance: nil,
        unlimitedSends: true,
        scheduling: .plusDefaults,
        routeEstimate: nil,
        isLoadingEstimate: false,
        estimateError: nil,
        selectedTiming: $timing,
        customDeliverAt: $customDate,
        onConfirm: {}
    )
}
