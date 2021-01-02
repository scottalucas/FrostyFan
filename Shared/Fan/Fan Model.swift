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
    private var targetTimer: Int?
    private var lastReportedSpeed: Int?
    private var lastReportedTimer: Int?
    private var bag = Set<AnyCancellable>()

    
    init(forAddress address: String) {
        ipAddr = address
        let connectableEmitter = fanEmitter.makeConnectable()
        startSpeedManager(publisher: connectableEmitter.eraseToAnyPublisher())
        startTimerManager(publisher: connectableEmitter.eraseToAnyPublisher())
        startMonitor(publisher: connectableEmitter.eraseToAnyPublisher())
        connectableEmitter.connect().store(in: &bag)
        timing.send(.now)
        print("init fan model \(ipAddr)")
    }
    
    private func fanCommFailed(withError commErr: Error) {
        House.shared.lostFan(atIp: self.ipAddr)
    }
    
    func setFan(toSpeed finalTarget: Int? = nil) {
        self.targetSpeed = finalTarget
        action.send(.refresh)
        timing.send(.now)
    }
    
    func setFan(addHours hours: Int) {
        let baseTime = lastReportedTimer ?? 0 > (60 * 12) - 10 ? (60 * 12) : (hours * 60) - 10 //allow a 10 minutes buffer unless current time's already within 10 minutes of 12 hours
        self.targetTimer = lastReportedTimer ?? 0 + baseTime
        action.send(.refresh)
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
        case speed = "fanspd", model = "model", swVersion = "softver", damper = "doorinprocess", timer = "timeremaining", macAddr = "macaddr", interlock1 = "interlock1", interlock2 = "interlock2", cfm = "cfm", power = "power", houseTemp = "house_temp", atticTemp = "attic_temp", DIPSwitch = "DIPS", remoteSwitch = "switch2", ipAddress = "ipaddr"
        
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
//    private var fanEmitter: ConnectablePublisher {
    private var fanEmitter: AnyPublisher<Dictionary<String, String?>, Never> {
        timing
            .removeDuplicates()
            .map { timerType in
                timerType.publisher
            }
            .switchToLatest()
            .combineLatest(action
                            .removeDuplicates())
            .flatMap { [weak self] (_, action) -> AnyPublisher<Dictionary<String,String?>, AdjustmentError> in
                guard let self = self else {
                    return AdjustmentError.parentOutOfScope.publisher(valueType: Dictionary<String, String?>.self) }
                return Just (action)
                    .adjustPhysicalFan(atNetworkAddr: self.ipAddr)
                    .receive(on: DispatchQueue.main)
                    .eraseToAnyPublisher()
            }
            .catch({ [weak self] err -> Just<Dictionary<String, String?>> in
                self?.fanCommFailed(withError: err)
                return Just ([:])
            })
            .filter { !$0.isEmpty }
            .share()
            .eraseToAnyPublisher()
    }
    
    private func startMonitor (publisher: AnyPublisher<Dictionary<String, String?>, Never>) {
        publisher
            .assign(to: &$chars)
    }
    
    private func startSpeedManager (publisher: AnyPublisher<Dictionary<String, String?>, Never>) {
        publisher
            .map({ dict -> Int? in
                Int(FanModel.FanKey.getValue(forKey: .speed, fromTable: dict) ?? "")
            })
            .sink(receiveValue: { [weak self] currentSpeed in
                guard let self = self, let currentSpeed = currentSpeed else { return }
                defer { self.lastReportedSpeed = currentSpeed }
                guard let target = self.targetSpeed else { //target == nil if user has never set speed
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
                } else if currentSpeed == self.lastReportedSpeed { //unresponsive fan
                    self.timing.send(.slow)
                } else {
                    self.timing.send(.fast)
                }

                switch (target, currentSpeed) {
                case (let t, _) where t == 0:
                    self.action.send(.off)
                case (let t, let c) where t > c:
                    self.action.send(.faster)
                case (let t, let c) where t < c:
                    self.action.send(.slower)
                default:
                    self.action.send(.refresh)
                }
            })
            .store(in: &bag)
    }
    
    private func startTimerManager (publisher: AnyPublisher<Dictionary<String, String?>, Never>) {
        publisher
            .map({ dict -> Int? in
                Int(FanModel.FanKey.getValue(forKey: .timer, fromTable: dict) ?? "")
            })
            .sink(receiveValue: { [weak self] currentTimer in
                guard let self = self, let currentTimer = currentTimer else { return }
                defer { self.lastReportedTimer = currentTimer }
                guard let target = self.targetTimer else { //target == nil if user has never set timer
                    self.action.send(.refresh)
                    self.timing.send(.maintenance)
                    return
                }
                
                guard target != currentTimer else { // complete
                    self.action.send(.refresh)
                    self.timing.send(.maintenance)
                    return
                }
                // we have a target speed, target speed != current speed
                if currentTimer == 0 { //fan starting up
                    self.timing.send(.slow)
                } else if currentTimer == self.lastReportedTimer { //unresponsive fan
                    self.timing.send(.slow)
                } else {
                    self.timing.send(.fast)
                }

                switch (target, currentTimer) {
                case (let t, _) where t == 0:
                    self.setFan(toSpeed: 0)
                case (let t, let c) where t > c:
                    self.action.send(.timer)
                default:
                    self.action.send(.refresh)
                }
            })
            .store(in: &bag)
    }
  
}
