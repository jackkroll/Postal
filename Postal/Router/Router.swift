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
            ShipLetterView()
        case .claimBox:
            ClaimMailboxView()
        }
    }
}

enum ViewRoute : Hashable {
    case login
    case landing
    case claimBox
    case track(trackingNum: String?, letter: LetterSummary? = nil)
    case ship
    
    static func == (lhs: ViewRoute, rhs: ViewRoute) -> Bool {
        lhs.hashValue == rhs.hashValue
    }
}
