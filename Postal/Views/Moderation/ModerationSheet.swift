import SwiftUI

/// The one presentation for reporting and blocking. Both actions and both success
/// pages live here so each can hand off to the other in place — see `ModerationFlow`.
struct ModerationSheet: View {
    var flow: ModerationFlow

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        dismissButton
                    }
                }
                .interactiveDismissDisabled(flow.isSubmitting)
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private var content: some View {
        switch flow.page {
        case let .report(target):
            ReportFormPage(
                target: target,
                isSubmitting: flow.isSubmitting,
                errorMessage: flow.sheetErrorMessage
            ) { reason, details in
                Task { await flow.submitReport(target, reason: reason, details: details) }
            }
        case let .reportFiled(submission, blockOffer):
            ReportFiledPage(
                submission: submission,
                blockOffer: blockOffer,
                onBlock: { flow.continueToBlock() },
                onDone: { flow.finish() }
            )
        case let .block(mailbox):
            BlockConfirmationPage(
                mailbox: mailbox,
                isSubmitting: flow.isSubmitting,
                errorMessage: flow.sheetErrorMessage
            ) {
                Task { await flow.confirmBlock(mailbox) }
            }
        case let .blocked(block, requested, reportTarget):
            BlockedPage(
                block: block,
                requested: requested,
                reportTarget: reportTarget,
                onReport: { flow.continueToReport() },
                onDone: { flow.finish() }
            )
        case .none:
            EmptyView()
        }
    }

    private var title: String {
        switch flow.page {
        case let .report(target):
            switch target {
            case .letter: ReportText.letterFormTitle
            case .mailbox: ReportText.mailboxFormTitle
            }
        case let .reportFiled(submission, _):
            submission.wasAlreadyFiled ? ReportText.alreadyFiledTitle : ReportText.filedTitle
        case .block:
            BlockText.confirmTitle
        case .blocked:
            BlockText.badge
        case .none:
            ""
        }
    }

    /// Cancel while something is still being decided; Done once it is recorded and
    /// closing the sheet loses nothing.
    @ViewBuilder
    private var dismissButton: some View {
        switch flow.page {
        case .report, .block, .none:
            if #available(iOS 26.0, *) {
                Button(role: .cancel) { flow.finish() }
                    .disabled(flow.isSubmitting)
            } else {
                Button("Cancel") { flow.finish() }
                    .disabled(flow.isSubmitting)
            }
        case .reportFiled, .blocked:
            Button(ReportText.doneAction) { flow.finish() }
        }
    }
}

// MARK: - Report form

private struct ReportFormPage: View {
    let target: ReportTarget
    let isSubmitting: Bool
    let errorMessage: String?
    let onSubmit: (ReportReason, String) -> Void

    @State private var reason: ReportReason?
    @State private var details = ""

    var body: some View {
        VStack(spacing: 0) {
            Form {
                ModerationTargetSection(target: target)

                Section {
                    ForEach(ReportReason.allCases) { option in
                        Button {
                            reason = option
                        } label: {
                            reasonRow(option)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text(ReportText.reasonSectionTitle)
                }

                Section {
                    TextField(
                        ReportText.detailsPlaceholder,
                        text: $details,
                        axis: .vertical
                    )
                    .lineLimit(3...8)
                    .onChange(of: details) { _, newValue in
                        // Over-long details are a 422, so clamp rather than round-trip.
                        if newValue.count > ReportLimits.detailsMaxLength {
                            details = String(newValue.prefix(ReportLimits.detailsMaxLength))
                        }
                    }
                } header: {
                    Text(ReportText.detailsSectionTitle)
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(ReportText.detailsFooter)
                        if remainingDetailCharacters <= 200 {
                            Text(ReportText.detailsRemaining(remainingDetailCharacters))
                        }
                    }
                }

                Section {
                    Text(ReportText.independenceNote)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .disabled(isSubmitting)

            submitButton
        }
    }

    @ViewBuilder
    private func reasonRow(_ option: ReportReason) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(ReportText.reasonTitle(option))
                Text(ReportText.reasonDetail(option))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
            if reason == option {
                Image(systemName: "checkmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.tint)
            }
        }
        .contentShape(Rectangle())
        .accessibilityAddTraits(reason == option ? [.isSelected] : [])
    }

    private var submitButton: some View {
        Button {
            guard let reason else { return }
            onSubmit(reason, details)
        } label: {
            if isSubmitting {
                HStack {
                    ProgressView()
                    Text(ReportText.submittingLabel)
                }
                .frame(maxWidth: .infinity)
            } else {
                Text(ReportText.submitAction)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.borderedProminent)
        .disabled(isSubmitting || reason == nil)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private var remainingDetailCharacters: Int {
        ReportLimits.detailsMaxLength - details.count
    }
}

// MARK: - Report filed

private struct ReportFiledPage: View {
    let submission: ReportSubmission
    let blockOffer: ModerationFlow.Page.BlockOffer
    let onBlock: () -> Void
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    Label(
                        submission.wasAlreadyFiled ? ReportText.alreadyFiledBody : ReportText.filedBody,
                        systemImage: "checkmark.circle.fill"
                    )
                    .foregroundStyle(.secondary)
                }

                Section {
                    LabeledContent(
                        ReportText.reasonSectionTitle,
                        value: ReportText.reasonTitle(submission.report.reason)
                    )
                    LabeledContent(
                        "Filed",
                        value: submission.report.createdAt.formatted(date: .abbreviated, time: .shortened)
                    )
                    if let details = submission.report.details {
                        Text(details)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }

                blockOfferSection
            }

            ModerationDoneButton(action: onDone)
        }
    }

    /// Reporting deliberately changes nothing about mail flow, so the block is
    /// offered here rather than left for the user to go find in Settings.
    @ViewBuilder
    private var blockOfferSection: some View {
        switch blockOffer {
        case .available:
            Section {
                Text(ReportText.alsoBlockBody)
                Button(role: .destructive, action: onBlock) {
                    Label(ReportText.alsoBlockAction, systemImage: "hand.raised")
                }
            } header: {
                Text(ReportText.alsoBlockTitle)
            }
        case .unknownSender:
            Section {
                Text(ReportText.alsoBlockUnavailable)
                    .foregroundStyle(.secondary)
            }
        case .unnecessary:
            EmptyView()
        }
    }
}

// MARK: - Block confirmation

/// Blocking cancels mail in flight, so it is always confirmed before it happens.
private struct BlockConfirmationPage: View {
    let mailbox: MailboxSummary
    let isSubmitting: Bool
    let errorMessage: String?
    let onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    LabeledContent("Location", value: mailbox.locationLabel)
                    LabeledContent("Code", value: mailbox.id.code)
                } header: {
                    Text("Address")
                }

                Section {
                    Text(BlockText.confirmBody)
                    Text(BlockText.confirmScope)
                } header: {
                    Text("What Happens")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .disabled(isSubmitting)

            VStack(spacing: 8) {
                Button(role: .destructive, action: onConfirm) {
                    if isSubmitting {
                        HStack {
                            ProgressView()
                            Text("Blocking…")
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        Text(BlockText.confirmAction)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(isSubmitting)

                Text(BlockText.confirmUndo)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }
}

// MARK: - Blocked

private struct BlockedPage: View {
    let block: BlockedAddress
    let requested: MailboxSummary
    let reportTarget: ReportTarget?
    let onReport: () -> Void
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    Label(confirmation, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.secondary)
                }

                if reportTarget != nil {
                    Section {
                        Text(ReportText.alsoReportBody)
                        Button(action: onReport) {
                            Label(ReportText.alsoReportAction, systemImage: "flag")
                        }
                    } header: {
                        Text(ReportText.alsoReportTitle)
                    }
                }
            }

            ModerationDoneButton(action: onDone)
        }
    }

    /// Re-blocking returns the original record, which may name another of that
    /// person's mailboxes — say so, or the count reads as wrong.
    private var confirmation: String {
        block.matches(requested.id)
            ? BlockText.blockedConfirmation(cancelledLetters: block.cancelledLetters ?? 0)
            : BlockText.alreadyBlocked(as: block.mailboxID)
    }
}

// MARK: - Shared

/// Sits below the `Form` on the two success pages, matching where the block
/// confirmation puts its primary action.
private struct ModerationDoneButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(ReportText.doneAction)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}

private struct ModerationTargetSection: View {
    let target: ReportTarget

    var body: some View {
        Section {
            switch target {
            case let .letter(_, sender, senderLabel):
                LabeledContent("Reporting", value: ReportText.letterTargetLabel)
                LabeledContent("From", value: senderLabel ?? sender?.rawValue ?? ReportText.unknownSender)
            case let .mailbox(mailbox):
                LabeledContent("Reporting", value: ReportText.mailboxTargetLabel)
                LabeledContent("Location", value: mailbox.locationLabel)
                LabeledContent("Code", value: mailbox.id.code)
            }
        }
    }
}

#Preview("Report Letter") {
    ModerationSheet(flow: .preview(.report(PreviewData.letterReportTarget)))
}

#Preview("Report Address") {
    ModerationSheet(flow: .preview(.report(.mailbox(PreviewData.destinationMailboxes[4]))))
}

#Preview("Report Failed") {
    ModerationSheet(flow: .preview(
        .report(PreviewData.letterReportTarget),
        errorMessage: ReportText.notArrived
    ))
}

#Preview("Filed, Block Offered") {
    ModerationSheet(flow: .preview(.reportFiled(
        ReportSubmission(report: PreviewData.filedReports[0], wasAlreadyFiled: false),
        blockOffer: .available(PreviewData.destinationMailboxes[3])
    )))
}

#Preview("Already Filed") {
    ModerationSheet(flow: .preview(.reportFiled(
        ReportSubmission(report: PreviewData.filedReports[0], wasAlreadyFiled: true),
        blockOffer: .unknownSender
    )))
}

#Preview("Confirm Block") {
    ModerationSheet(flow: .preview(.block(PreviewData.destinationMailboxes[3])))
}

#Preview("Blocked, Report Offered") {
    ModerationSheet(flow: .preview(.blocked(
        PreviewData.blockedAddresses[0],
        requested: PreviewData.destinationMailboxes[4],
        reportTarget: .mailbox(PreviewData.destinationMailboxes[4])
    )))
}
