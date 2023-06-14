import ComposableArchitecture
import Foundation

public struct AppReducer: ReducerProtocol {
  public struct State: Codable, Sendable, Equatable {
    public var errorLogging: ErrorLoggingReducer.State?
  }
  
  public enum Action: Equatable {
    case errorLogging(action: ErrorLoggingReducer.Action)
  }
  
  public var body: some ReducerProtocol<State, Action> {
    CombineReducers {
      Reduce { state, action in
        switch action {
        case .errorLogging:
          return .none
        }
      }.ifLet(\.errorLogging, action: /Action.errorLogging) {
        ErrorLoggingReducer()
      }
    }
  }
}

public struct ErrorLoggingReducer: ReducerProtocol, Sendable {
  public struct State: Codable, Equatable, Sendable {
    public var currentErrors: IdentifiedArrayOf<String>
    public var hostname: String
    
    public init(currentErrors: IdentifiedArrayOf<String>, hostname: String) {
      self.currentErrors = currentErrors
      self.hostname = hostname
    }
  }
  
  public enum Action: Sendable, Equatable {
    case task
    case onResponse(CatFactModel)
    case onError(LoggingError)
    
    case newHost(hostname: String)
  }
  
  @Dependency(\.fetchButtons) var fetchButtons
  
  public var body: some ReducerProtocol<State, Action> {
    Reduce { state, action in
      switch action {
      case .task:
        let state = state
        return .run { send in
          while !Task.isCancelled {
            let action = await makeRequest(state: state)
            await send(action)
            try await Task.sleep(nanoseconds: 1000000000)
          }
          
          print()
        } catch: { error, send in
          print(error)
        }.cancellable(id: Cancellables.polling)
        
      case .onResponse(let response):
        if response.isEmpty {
          return .send(.onError(LoggingError.missingRulesCategory))
        } else {
          state.currentErrors = [response]
          return .none
        }
        
      case let .newHost(hostname):
        state.hostname = hostname
        
        return .concatenate(.cancel(id: Cancellables.polling), .send(.task))
      case let .onError(error):
        print(error)
        return .none
      }
    }
  }
  
  private func makeRequest(state: State) async -> Action {
    do {
      let categories = try await fetchButtons(state.hostname)
      
      return .onResponse(categories)
    } catch {
      return .onError(.arbitraryError(error.localizedDescription))
    }
  }
}

extension String: Identifiable, Sendable {
  public var id: String {
    self
  }
}

private enum Cancellables: String {
  case polling
}

public enum LoggingError: Error, Equatable {
  case missingRulesCategory
  case arbitraryError(String)
}

private enum FetchButtonsKey: DependencyKey {
  static let liveValue: @Sendable (String) async throws -> String = { hostname in
    let url = URL(string: "https://catfact.ninja/fact")!
    let request = URLRequest(url: url)
    let (data, _) = try await URLSession.shared.data(for: request)
    let catfactResponse = try JSONDecoder().decode(CatFactModel.self, from: data)
    return catfactResponse.fact
  }
  
  static var testValue: @Sendable (String) async throws -> String = unimplemented("fetch buttons")
}

public extension DependencyValues {
  var fetchButtons: @Sendable (String) async throws -> String {
    get { self[FetchButtonsKey.self] }
    set { self[FetchButtonsKey.self] = newValue }
  }
}

enum SendKeyPressError: Error {
  case serverError(statusCode: Int, data: Data)
}

func urlEncodedStreampadEndpoint(
  hostname: String,
  userEmail: String,
  category: String,
  index: Int
) -> URL {
  let urlString = "\(userEmail)/\(category)/\(index)/push"
    .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!
  return URL(string: "http://\(hostname):8000/buttons/\(urlString)")!
}

struct CatFactModel: Codable, Equatable, Sendable {
  let fact: String
  let length: Int
}

