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
    
    @ViewBuilder
    static func view(for route: ViewRoute) -> some View {
        switch route {
        case .login:
            SignInView(viewmodel: .init(auth: AppServices.auth))
        case .track(trackingNum: let trackingNum, letter: let letter):
            TrackingView(viewmodel: .init(
                apiClient: AppServices.api,
                letterService: LetterContentService(api: AppServices.api),
                trackingNumber: trackingNum,
                letterSummary: letter
            ))
        case .landing:
            LettersListView()
        case .ship:
            LetterCreationView(viewmodel: .init(api: AppServices.api))
        case .claimBox:
            ClaimMailboxView()
        case .settings:
            SettingsView(viewmodel: .init(
                api: AppServices.api,
                auth: AppServices.auth,
                push: AppServices.pushNotifications))
        case .addressbook:
            ContentUnavailableView("Coming Soon", systemImage: "clock.fill")
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
    case track(trackingNum: String?, letter: LetterSummary? = nil)
    case read(shipmentID: String, metadata: LetterMetadata, service: LetterContentProviding)
    case ship
    case compose(source: MailboxSummary, destination: MailboxSummary)
    case addressbook

    static func == (lhs: ViewRoute, rhs: ViewRoute) -> Bool {
        switch (lhs, rhs) {
        case (.login, .login),
             (.landing, .landing),
             (.claimBox, .claimBox),
             (.settings, .settings),
             (.ship, .ship),
             (.addressbook, .addressbook):
            return true
        case let (.track(lt, ll), .track(rt, rl)):
            return lt == rt && ((ll == nil && rl == nil) || (ll?.id == rl?.id))
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
        case let .track(trackingNum, letter):
            hasher.combine(4)
            hasher.combine(trackingNum)
            hasher.combine(letter?.id)
        case let .read(shipmentID, metadata, _):
            hasher.combine(5)
            hasher.combine(shipmentID)
            hasher.combine(metadata.byteSize)
            hasher.combine(metadata.filename)
            hasher.combine(metadata.format)
        case .ship:
            hasher.combine(6)
        case let .compose(source, destination):
            hasher.combine(7)
            hasher.combine(source.id)
            hasher.combine(destination.id)
        case .addressbook:
            hasher.combine(8)
        }
    }
}
