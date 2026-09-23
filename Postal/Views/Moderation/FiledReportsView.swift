import SwiftUI

/// The reports this user filed. Read-only: a report cannot be withdrawn, and the
/// moderation outcome is deliberately not exposed to the reporter.
struct FiledReportsView: View {
    @State private var viewmodel: ViewModel
    private let loadsOnAppear: Bool

    init(viewmodel: ViewModel, loadsOnAppear: Bool = true) {
        _viewmodel = State(initialValue: viewmodel)
        self.loadsOnAppear = loadsOnAppear
    }

    var body: some View {
        List {
            reportsSection
        }
        .navigationTitle(ReportText.screenTitle)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await viewmodel.refresh()
        }
        .task {
            guard loadsOnAppear else { return }
            await viewmodel.refresh()
        }
    }

    @ViewBuilder
    private var reportsSection: some View {
        Section {
            if let failure = viewmodel.loadFailure, viewmodel.reports.isEmpty {
                ContentUnavailableView {
                    Label(failure.title(resource: "Reports"), systemImage: failure.systemImage)
                } description: {
                    Text(failure.message)
                } actions: {
                    Button("Try Again") {
                        Task { await viewmodel.refresh() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if !viewmodel.hasLoaded, viewmodel.reports.isEmpty {
                HStack {
                    ProgressView()
                    Text("Loading reports…")
                        .foregroundStyle(.secondary)
                }
            } else if viewmodel.reports.isEmpty {
                ContentUnavailableView {
                    Label(ReportText.emptyTitle, systemImage: "flag")
                } description: {
                    Text(ReportText.emptyBody)
                }
            } else {
                ForEach(viewmodel.reports) { report in
                    FiledReportRow(report: report)
                }
            }
        } footer: {
            if !viewmodel.reports.isEmpty {
                Text(ReportText.listFooter)
            }
        }
    }
}

struct FiledReportRow: View {
    let report: SubmittedReport

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(ReportText.reasonTitle(report.reason))
                .font(.body.weight(.semibold))
            HStack(spacing: 6) {
                Text(targetLabel)
                if let mailboxID = report.mailboxID {
                    Text(mailboxID)
                        .font(.caption.monospaced())
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            Text(ReportText.reportedOn(report.createdAt))
                .font(.caption)
                .foregroundStyle(.tertiary)
            if let details = report.details {
                Text(details)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .padding(.vertical, 2)
    }

    private var targetLabel: String {
        switch report.targetType {
        case .letter: ReportText.letterTargetLabel
        case .mailbox: ReportText.mailboxTargetLabel
        }
    }
}

extension FiledReportsView {
    @Observable
    class ViewModel {
        private let service: ReportService

        init(reports: ReportService = AppServices.reports) {
            service = reports
        }

        var reports: [SubmittedReport] { service.reports }
        var hasLoaded: Bool { service.hasLoaded }
        var loadFailure: PostalLoadFailure? { service.loadFailure }

        @MainActor
        func refresh() async {
            await service.load()
        }
    }
}

#Preview("Filed") {
    NavigationStack {
        FiledReportsView(viewmodel: .preview(), loadsOnAppear: false)
    }
}

#Preview("Empty") {
    NavigationStack {
        FiledReportsView(viewmodel: .preview(reports: []), loadsOnAppear: false)
    }
}
