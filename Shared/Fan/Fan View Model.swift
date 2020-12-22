//
//  Fan Model View.swift
//  whf001
//
//  Created by Scott Lucas on 12/9/20.
//

import Foundation
import SwiftUI
import Combine

class FanViewModel: ObservableObject {
    @ObservedObject var model: FanModel
    @Published var fanRotationDuration: Double = 0.0
    @Published var actualSpeed: Int = -1
    @Published var opening: String = "No"
    @Published var airspaceFanModel: String = "Model number"
    @Published var macAddr: String?
    @Published var name = "Fan"
    @Published var controllerSegments: [String] = ["Off", "On"]
    @Published var interlocked: Bool = false
    private var bag = Set<AnyCancellable>()
    init (forModel model: FanModel) {
        self.model = model
        startSubscribers()
    }
    
    func fanConnector (targetSpeed finalTarget: Int?) {
        enum ConnectTimer { case maintenance, slow, fast
            func timer (sendAction action: @escaping () -> FanModel.Action) -> AnyPublisher<FanModel.Action, Never> {
                switch self {
                case .maintenance:
                    return Timer.publish(every: 60.0, on: .main, in: .common)
                    .autoconnect()
                    .map { _ in action() }
                    .eraseToAnyPublisher()
                case .fast:
                    return Timer.publish(every: 0.5, on: .main, in: .common)
                    .autoconnect()
                    .map { _ in action() }
                    .eraseToAnyPublisher()
                case .slow:
                    return Timer.publish(every: 10.0, on: .main, in: .common)
                    .autoconnect()
                    .map { _ in action() }
                    .eraseToAnyPublisher()
                }
            }
        }
        var previousSpeed: Int? = nil
        var nextAction: FanModel.Action = .refresh
        let timerSource = CurrentValueSubject<AnyPublisher<FanModel.Action, Never>, Never>(ConnectTimer.maintenance.timer { return nextAction })
        
        adjust(usingTimerSource: timerSource.eraseToAnyPublisher())
            .print("Adjust publisher")
            .sink(receiveCompletion: { [weak self] comp in
                guard let self = self else { return }
                switch comp {
                case .failure(let err):
                    print("Failed to adjust, error: \(err.localizedDescription), fan maintenance timer needs to be restarted.")
                case .finished:
                    print("Unexpected completion, requested speed: \(finalTarget?.description ?? "update only"), actual speed: \(self.actualSpeed.description)")
                }
            }, receiveValue: { currentSpeed in
                guard let goal = finalTarget else { return } //maintenance timer should have been set elsewhere, should be safe to return
                
                if currentSpeed == goal { // goal has been met, switch to refresh
                    nextAction = .refresh
                } else if (goal == 0) {
                    nextAction = .off
                } else if ( currentSpeed == previousSpeed ) { //goal not met but speed isn't changing, fan is unresponsive
                    nextAction = .refresh
                } else if ( currentSpeed < goal ) {
                    nextAction = .faster
                } else if ( currentSpeed > goal ) {
                    nextAction = .slower
                }
                
                if currentSpeed == 0 { timerSource.send(ConnectTimer.slow.timer { return nextAction }) }
                
                if (currentSpeed == 1 && previousSpeed == 0) { timerSource.send(ConnectTimer.fast.timer { return nextAction }) }
                
                if (currentSpeed == goal) { timerSource.send(ConnectTimer.maintenance.timer { return nextAction }) }
                
                previousSpeed = currentSpeed
            })
            .store(in: &bag)
        
        timerSource.send(finalTarget == nil ? ConnectTimer.maintenance.timer { return nextAction } : ConnectTimer.fast.timer { return nextAction } ) //starts up here
    }
    
    func getView () -> some View {
        FanView(fanViewModel: self)
    }
    
    private func adjust (usingTimerSource timerSource: AnyPublisher<AnyPublisher<FanModel.Action, Never>, Never>) -> AnyPublisher <Int, FanViewModel.AdjustmentError> {
        typealias err = FanViewModel.AdjustmentError
        
        func fail(withError: Error) -> AnyPublisher<Int, FanViewModel.AdjustmentError> {
            let err: FanViewModel.AdjustmentError = withError as? FanViewModel.AdjustmentError ?? .unknownError(withError.localizedDescription)
            return Fail<Int, FanViewModel.AdjustmentError>.init(error: err).eraseToAnyPublisher()
        }
       
        return timerSource
            .prepend ( Just(.refresh).eraseToAnyPublisher() )
            .switchToLatest()
            .flatMap { [weak self] action -> AnyPublisher<Int, FanViewModel.AdjustmentError> in
                guard let self = self else { return fail(withError: err.parentOutOfScope) }
                return self.model.adjustFan(action: action)
                    .retry(3)
                    .mapError { e in
                        err.retrievalError(e)
                    }
                    .receive(on: DispatchQueue.main)
                    .tryMap {
                        self.model.chars = $0
                        guard let nSpd = FanValue.getValue(forKey: .speed, fromTable: $0), let newSpeed = Int(nSpd) else { throw err.retrievalError(.unknown("Bad values returned.")) }
                        return newSpeed
                    }
                    .catch { e in fail(withError: e) }
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
   
    private func test () -> AnyPublisher<Dictionary<String, String?>, FanModel.ConnectionError> {
        return model.adjustFan(action: .faster).eraseToAnyPublisher()
    }
    
}



extension FanViewModel {
    convenience init () {
        self.init(forModel: FanModel())
    }
}

extension FanViewModel {
    static var speedTable: [String:Int]  = [
        "3.5e" : 7,
        "4.4e" : 7,
        "5.0e" : 7,
        "2.5e" : 5,
        "3200" : 10,
        "3400" : 10,
        "4300" : 10,
        "5300" : 10
    ]
}

extension FanViewModel {
    enum AdjustmentError: Error {
        case notReady (String)
        case notNeeded
        case retrievalError(FanModel.ConnectionError)
        case parentOutOfScope
        case speedDidNotChange
        case unknownError (String)
    }
}

extension FanViewModel {
    func startSubscribers () {
        model.$chars
            .map { FanValue.getValue(forKey: .macAddr, fromTable: $0) ?? "Not found" }
            .map { UserSettings().names[$0] ?? "Fan" }
            .receive(on: DispatchQueue.main)
            .assign(to: &$name)
        
        model.$chars
            .map { FanValue.getValue(forKey: .macAddr, fromTable: $0) ?? "Not found" }
            .receive(on: DispatchQueue.main)
            .assign(to: &$macAddr)
        
        model.$chars
            .map { (FanValue.getValue(forKey: .speed, fromTable: $0) ?? "-1") }
            .map { Int($0) ?? -1 }
            .receive(on: DispatchQueue.main)
            .assign(to: &$actualSpeed)
        
        model.$chars
            .map { (FanValue.getValue(forKey: .speed, fromTable: $0) ?? "0.0") }
            .map { Double($0) ?? 0.0 }
            .map { $0 == 0.0 ? 0.0 : 1.0/$0 }
            .receive(on: DispatchQueue.main)
            .assign(to: &$fanRotationDuration)
        
        model.$chars
            .map { (FanValue.getValue(forKey: .model, fromTable: $0) ?? "") }
            .map { FanViewModel.speedTable[String($0.prefix(4))] ?? 1 }
            .map { count -> [String] in Range(0...count).map { String($0) } }
            .map {
                var newArr = $0
                newArr[$0.startIndex] = "Off"
                newArr[$0.endIndex - 1] = $0.count <= 2 ? "On" : "Max"
                return newArr
            }
            .assign(to: &$controllerSegments)

        model.$chars
            .map { ((FanValue.getValue(forKey: .interlock1, fromTable: $0) ?? "0", FanValue.getValue(forKey: .interlock2, fromTable: $0) ?? "0")) }
            .map { (Int($0) ?? 0) == 1 || (Int($1) ?? 0) == 1 }
            .receive(on: DispatchQueue.main)
            .assign(to: &$interlocked)
    }
}
