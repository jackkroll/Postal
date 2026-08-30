//
//  AdaptiveStack.swift
//  Postal
//
//  Created by Jack Kroll on 8/30/26.
//

import SwiftUI

struct AdaptiveStack<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    let content: () -> Content
    
    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }
    
    var body: some View {
        Group {
            if dynamicTypeSize > .large {
                VStack(spacing: 16) { content() }
            } else {
                HStack(spacing: 16) { content() }
            }
        }
    }
}
