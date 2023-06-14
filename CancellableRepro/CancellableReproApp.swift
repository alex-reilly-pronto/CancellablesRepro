//
//  CancellableReproApp.swift
//  CancellableRepro
//
//  Created by Alex on 6/14/23.
//

import SwiftUI
import ComposableArchitecture

@main
struct CancellableReproApp: App {
    var body: some Scene {
        WindowGroup {
          ContentView(store: Store(
            initialState: AppReducer.State(
              errorLogging: ErrorLoggingReducer.State(currentErrors: [], hostname: "test-hostname")
            ),
            reducer: AppReducer()
          ))
        }
    }
}
