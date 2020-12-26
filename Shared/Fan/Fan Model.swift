//
//  Fan Model.swift
//  whf001
//
//  Created by Scott Lucas on 12/9/20.
//

import Foundation
import Combine
import SwiftUI



class FanModel: ObservableObject {
    var ipAddr: String
    @Published var chars : Dictionary<String, String?> = [:]
    private let timing = PassthroughSubject<FanConnectionTimers, Never>()
    private let action = CurrentValueSubject<FanModel.Action, Never>(.refresh)
    private var targetSpeed: Int?
    private var lastSpeed: Int?
    private var bag = Set<AnyCancellable>()

    
    init(forAddress address: String) {
        ipAddr = address
        emit()
        timing.send(.now)
        print("init fan model \(ipAddr)")
    }
    
    private func fanCommFailed(withError commErr: Error) -> AnyPublisher<Int, AdjustmentError> {
        let err: AdjustmentError = commErr as? AdjustmentError ?? .upstream(commErr)
        return Fail<Int, AdjustmentError>.init(error: err).eraseToAnyPublisher()
    }
    
    func setFan(toSpeed finalTarget: Int? = nil) {
        self.targetSpeed = finalTarget
        if finalTarget == 0 { action.send(.off) }
        if finalTarget == nil { action.send(.refresh) }
        timing.send(.now)
    }
    
    func getView () -> some View {
        FanViewModel(forModel: self).getView()
    }
}

extension FanModel {
    convenience init () {
        self.init(forAddress: "0.0.0.0:8181")
    }
}

extension FanModel {
    
    enum FanKey : String {
        case speed = "fanspd", model = "model", swVersion = "softver", damper = "doorinprocess", timer = "timeremaining", macAddr = "macaddr", interlock1 = "interlock1", interlock2 = "interlock2", cfm = "cfm", power = "power", houseTemp = "house_temp", atticTemp = "attic_temp", DIPSwitch = "DIPS", remoteSwitch = "switch2"
        
        static func getValue(forKey key: FanModel.FanKey, fromTable table: [String : String?]) -> String? {
            return table[key.rawValue] ?? nil
        }
        
        static var requiredKeys: Set<String> = ["fanspd", "doorinprocess", "timeremaining", "macaddr", "ipaddr", "model", "softver", "interlock1", "interlock2", "cfm", "power" , "house_temp", "attic_temp", "DIPS", "switch2"]
    }
    enum Action: Int {
        case refresh = 0
        case faster = 1
        case timer = 2
        case slower = 3
        case off = 4

        var description: String {
            switch self {
            case .refresh:
                return "refresh"
            case .faster:
                return "faster"
            case .timer:
                return "timer"
            case .slower:
                return "slower"
            case .off:
                return "off"
            }
        }
    }
    enum FanConnectionTimers {
        case maintenance, fast, slow, now
        var publisher: AnyPublisher<Date, Never> {
            switch self {
            case .fast:
                return Timer.publish(every: 0.5, on: .main, in: .common).autoconnect().eraseToAnyPublisher()
            case .slow:
                return Timer.publish(every: 5.0, on: .main, in: .common).autoconnect().eraseToAnyPublisher()
            case .maintenance:
                return Timer.publish(every: 30, on: .main, in: .common).autoconnect().eraseToAnyPublisher()
            case .now:
                return Just(Date()).eraseToAnyPublisher()
            }
        }
    }
}

extension FanModel {
    func emit () {
        timing
            .removeDuplicates()
            .map { timerType in
                timerType.publisher
            }
            .switchToLatest()
            .combineLatest(action.removeDuplicates())
            .map { [weak self] (_, action) -> AnyPublisher<Int, AdjustmentError> in
                guard let self = self else {
                    return AdjustmentError.parentOutOfScope.publisher(valueType: Int.self) }
                return Just (action)
                    .adjustFan(at: self.ipAddr)
                    .receive(on: DispatchQueue.main)
                    .flatMap { [weak self] chars -> AnyPublisher<Int, AdjustmentError> in
                        guard let self = self else { return AdjustmentError.parentOutOfScope.publisher(valueType: Int.self) }
                        self.chars = chars
                        guard let nSpd = FanModel.FanKey.getValue(forKey: .speed, fromTable: chars), let newSpeed = Int(nSpd) else { return AdjustmentError.retrievalError(ConnectionError.decodeError("Bad values returned.")).publisher(valueType: Int.self) }
                        return Just.init(newSpeed).setFailureType(to: AdjustmentError.self).eraseToAnyPublisher()
                    }
                    .eraseToAnyPublisher()
            }
            .flatMap { $0 }
            .sink(receiveCompletion: { comp in
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
    }
  
}
