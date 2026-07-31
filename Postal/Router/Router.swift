//
//  Router.swift
//  Postal
//
//  Created by Jack Kroll on 7/9/26.
//

import Foundation
import SwiftUI
import Combine
import Observation

@Observable class Router {
    var path: [ViewRoute] = []
    
    func push(_ route: ViewRoute) {
        path.append(route)
    }
    func pop() {
        path.removeLast()
    }
    func popTo(_ route: ViewRoute) -> Bool {
        if path.contains(route) {
            let backIndex = path.firstIndex(where: { $0 == route })
            if let backIndex = backIndex {
                path.removeLast(path.count - backIndex)
            }
            else {
                return false
            }
        }
        else {
            return false
        }
        return true
    }
    func popToRoot() {
        path.removeLast(path.count)
    }

    /// Replace the stack with the destination for an inbound deep link.
    func open(_ deepLink: DeepLink) {
        popToRoot()
        switch deepLink {
        case let .track(trackingNumber):
            push(.track(trackingNum: trackingNumber))
        }
    }

    @ViewBuilder
    static func view(for route: ViewRoute) -> some View {
        switch route {
        case .login:
            SignInView(viewmodel: .init(auth: AppServices.auth))
        case .track(trackingNum: let trackingNum, letter: let letter, isRecipient: let isRecipient):
            TrackingView(viewmodel: .init(
                apiClient: AppServices.api,
                letterService: LetterContentService(api: AppServices.api),
                trackingNumber: trackingNum,
                letterSummary: letter,
                isRecipient: isRecipient
            ))
        case .landing:
            LettersListView()
        case let .ship(origin, destination, draftID):
            LetterCreationView(viewmodel: .init(
                api: AppServices.api,
                drafts: AppServices.letterDrafts,
                origin: origin,
                destination: destination,
                draftID: draftID
            ))
        case .claimBox:
            ClaimMailboxView()
        case .settings:
            SettingsView(viewmodel: .init(
                api: AppServices.api,
                auth: AppServices.auth,
                push: AppServices.pushNotifications))
        case .addressbook:
            AddressBook(viewmodel: .init(api: AppServices.api))
        case .compose(source: let source, destination: let destination):
            ComposeView(viewmodel: .init(
                api: AppServices.api,
                source: source,
                destination: destination))
        case .read(shipmentID: let shipmentID, metadata: let metadata, service: let service):
            LetterReaderSection(
                shipmentID: shipmentID,
                letterMetadata: metadata,
                letterService: service
            )
        }
    }
}

enum ViewRoute: Hashable {
    case login
    case landing
    case claimBox
    case settings
    case track(trackingNum: String?, letter: LetterSummary? = nil, isRecipient: Bool = false)
    case read(shipmentID: String, metadata: LetterMetadata, service: LetterContentProviding)
    /// Opens letter creation, optionally prefilling return (`origin`) and destination mailboxes,
    /// or resuming a local draft via `draftID`.
    case ship(
        origin: MailboxSummary? = nil,
        destination: MailboxSummary? = nil,
        draftID: UUID? = nil
    )
    case compose(source: MailboxSummary, destination: MailboxSummary)
    case addressbook

    static func == (lhs: ViewRoute, rhs: ViewRoute) -> Bool {
        switch (lhs, rhs) {
        case (.login, .login),
             (.landing, .landing),
             (.claimBox, .claimBox),
             (.settings, .settings),
             (.addressbook, .addressbook):
            return true
        case let (.ship(lo, ld, lid), .ship(ro, rd, rid)):
            return lo?.id == ro?.id && ld?.id == rd?.id && lid == rid
        case let (.track(lt, ll, lr), .track(rt, rl, rr)):
            return lt == rt
                && ((ll == nil && rl == nil) || (ll?.id == rl?.id))
                && lr == rr
        case let (.read(ls, lm, _), .read(rs, rm, _)):
            return ls == rs && lm.hashValue == rm.hashValue
        case let (.compose(ls, ld), .compose(rs, rd)):
            return ls.id == rs.id && ld.id == rd.id
        default:
            return false
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .login:
            hasher.combine(0)
        case .landing:
            hasher.combine(1)
        case .claimBox:
            hasher.combine(2)
        case .settings:
            hasher.combine(3)
        case let .track(trackingNum, letter, isRecipient):
            hasher.combine(4)
            hasher.combine(trackingNum)
            hasher.combine(letter?.id)
            hasher.combine(isRecipient)
        case let .read(shipmentID, metadata, _):
            hasher.combine(5)
            hasher.combine(shipmentID)
            hasher.combine(metadata.byteSize)
            hasher.combine(metadata.filename)
            hasher.combine(metadata.format)
        case let .ship(origin, destination, draftID):
            hasher.combine(6)
            hasher.combine(origin?.id)
            hasher.combine(destination?.id)
            hasher.combine(draftID)
        case let .compose(source, destination):
            hasher.combine(7)
            hasher.combine(source.id)
            hasher.combine(destination.id)
        case .addressbook:
            hasher.combine(8)
        }
    }
}
