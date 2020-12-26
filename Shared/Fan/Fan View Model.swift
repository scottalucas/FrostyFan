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
    private let timing = PassthroughSubject<FanConnectionTimers, Never>()
    private let action = CurrentValueSubject<FanModel.Action, Never>(.refresh)
    private var targetSpeed: Int?
    private var lastSpeed: Int?
    
    private var currentAdjuster: AnyCancellable?
    private var bag = Set<AnyCancellable>()
    enum FanConnectionTimers {
        case maintenance, fast, slow, now
        var publisher: AnyPublisher<Date, Never> {
            switch self {
            case .fast:
                return Timer.publish(every: 0.5, on: .main, in: .common).autoconnect().eraseToAnyPublisher()
            case .slow:
                return Timer.publish(every: 5.0, on: .main, in: .common).autoconnect().eraseToAnyPublisher()
            case .maintenance:
                return Timer.publish(every: 10.0, on: .main, in: .common).autoconnect().eraseToAnyPublisher()
            case .now:
                return Just(Date()).eraseToAnyPublisher()
            }
        }
    }
    
    init (forModel model: FanModel) {
        self.model = model
        startSubscribers()
        timing.send(.now)
        action.send(.refresh)
    }
    
    private func fanCommFailed(withError commErr: Error) -> AnyPublisher<Int, AdjustmentError> {
        let err: AdjustmentError = commErr as? AdjustmentError ?? .upstream(commErr)
        return Fail<Int, AdjustmentError>.init(error: err).eraseToAnyPublisher()
    }
    
    func fanConnector(targetSpeed finalTarget: Int?) {
        self.targetSpeed = finalTarget
        if finalTarget == 0 { action.send(.off) }
        timing.send(.now)
    }
    
    func getView () -> some View {
        FanView(fanViewModel: self)
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

}

extension FanViewModel {
    func startSubscribers () {
        
        timing
//            .print("timer source")
            .removeDuplicates()
            .map { timerType in
                timerType.publisher
            }
            .switchToLatest()
            .combineLatest(action.removeDuplicates())
//            .print("actions"))
            .map { (_, act) in return act }
//            .flatMap { $0 }
//            .print("before flat map")
            .map { [weak self] action -> AnyPublisher<Int, AdjustmentError> in
                guard let self = self else {
                    return AdjustmentError.parentOutOfScope.publisher(valueType: Int.self) }
                return Just (action)
                    .adjustFan(at: self.model.ipAddr)
                    .print("adjust fan")
                    .receive(on: DispatchQueue.main)
                    .tryMap { [weak self] in
                        guard let self = self else { throw AdjustmentError.parentOutOfScope }
                        self.model.chars = $0
                        guard let nSpd = FanValue.getValue(forKey: .speed, fromTable: $0), let newSpeed = Int(nSpd) else { throw AdjustmentError.retrievalError(ConnectionError.decodeError("Bad values returned.")) }
                        return newSpeed
                    }
                    .catch { [weak self] e in self?.fanCommFailed(withError: e) ?? AdjustmentError.parentOutOfScope.publisher(valueType: Int.self) }
                    .eraseToAnyPublisher()
            }
            .flatMap { $0 }
            .eraseToAnyPublisher()
//            .print("end of publisher")
            .sink(receiveCompletion: { comp in
                //                guard let self = self else { return }
                if case .failure(let err) = comp {
                    print("Failed timer source, error: \(err.localizedDescription)")
                }
                if case .finished = comp {
                    print ("Unexpected completion.")
                }
                
            }, receiveValue: { [weak self] currentSpeed in
                defer { self?.lastSpeed = currentSpeed }
                guard let self = self else { return }
                guard let target = self.targetSpeed else {
                    self.action.send(.refresh)
                    self.timing.send(.maintenance)
                    return
                }
                guard target != currentSpeed else { // complete
                    self.action.send(.refresh)
                    self.timing.send(.maintenance)
                    return
                }
                // we have a target speed, target speed != current speed
                if currentSpeed == 0 { //fan starting up
                    self.timing.send(.slow)
                } else if self.lastSpeed == nil { //don't have a previous speed, probably first time through
                    self.timing.send(.fast)
                } else if currentSpeed == self.lastSpeed! { //unresponsive fan
                    self.timing.send(.slow)
                } else {
                    self.timing.send(.fast)
                }
                
                switch (target - currentSpeed) {
                case let delta where delta > 0:
                    self.action.send(.faster)
                case let delta where delta < 0:
                    self.action.send(.slower)
                default:
                    self.action.send(.refresh)
                }
            })
            .store(in: &bag)
        
        
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
