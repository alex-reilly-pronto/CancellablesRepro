//
//  ContentView.swift
//  CancellableRepro
//
//  Created by Alex on 6/14/23.
//

import SwiftUI
import ComposableArchitecture

struct ContentView: View {
  let store: StoreOf<AppReducer>
  
  struct ViewState: Equatable {
    let errors: IdentifiedArrayOf<String>
    
    init(state: AppReducer.State) {
      self.errors = state.errorLogging?.currentErrors ?? []
    }
  }
  
  var body: some View {
    WithViewStore(store, observe: ViewState.init) { viewStore in
      VStack {
        Image(systemName: "globe")
          .imageScale(.large)
          .foregroundColor(.accentColor)
        Text("Hello, world!")
        
        ForEach(viewStore.errors) { error in
          Text(error)
        }
        
        Button {
          viewStore.send(.errorLogging(action: .newHost(hostname: "other-new-host")))
        } label: {
          Text("Change Host")
        }
      }
      .padding()
      .task {
        await viewStore.send(.errorLogging(action: .task)).finish()
      }
    }
    
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView(store: Store(
      initialState: AppReducer.State(
        errorLogging: ErrorLoggingReducer.State(currentErrors: [], hostname: "test-hostname")
      ),
      reducer: AppReducer()
    ))
  }
}
