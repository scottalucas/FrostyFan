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
    @Published var motor: Motor?
    @Published var fanCharacteristics: FanCharacteristics?
    @Published var commError: ConnectionError?
    @Published var physicalSpeed: Int?
    @Published var targetSpeed: Int?
    @Published var targetTimer: Int?
    @Published var fanLamps = FanLamps()
    @Published var adjustmentStatus = AdjustmentStatus()
    private var lastSpeed: Int?
    private var lastTimer: Int?
    private var bag = Set<AnyCancellable>()

    init(forAddress address: String, usingChars chars: FanCharacteristics? = nil) {
        ipAddr = address
        motor = Motor(fan: self)
        connectFanSubscribers()
        chars.map { fanCharacteristics = $0 } ?? self.getFanStatus(sendingCommand: .refresh)
        print("init fan model \(ipAddr) chars \(chars == nil ? "not " : "")available")
    }
    
    func setFan(toSpeed finalTarget: Int) {
        print("set speed to \(finalTarget)")
        fanLamps.insert(.speedAdjusting)
        adjustmentStatus.insert(.speedAdjusting)
        motor?.setSpeed(to: finalTarget)
            .sink(receiveCompletion: { [weak self] comp in
                if case .failure(let err) = comp {
                    print ("Set fan failed \(err)")
                } else {
                    print("Set fan completed")
                }
                self?.fanLamps.remove(.speedAdjusting)
                self?.adjustmentStatus.remove(.speedAdjusting)
            }, receiveValue: { _ in })
            .store(in: &bag)
    }
    
    func setFan(addHours hours: Int) {
        let current = fanCharacteristics.map { $0.timer } ?? 0
        targetTimer = min (current + hours * 60, 12 * 60) - 10
        print("\(targetTimer)")
    }
    
    func refreshFan () {
        getFanStatus(sendingCommand: .refresh)
    }
}

struct FanCharacteristics: Decodable, Hashable {
    var ipAddr: String?
    var speed: Int
    var damper: DamperStatus = .unknown
    var timer = 0
    var macAddr: String
    var airspaceFanModel: String
    var softwareVersion: String?
    var interlock1 = false
    var interlock2 = false
    var cubicFeetPerMinute: Int?
    var power: Int?
    var insideTemp: Int?
    var dns: String?
    var atticTemp: Int?
    var outsideTemp: Int?
    var serverResponse: String?
    var dipSwitch: String?
    var remoteSwitch: String?
    var setpoint: Int?
    var labelValueDictionary: [String: String] = [:]
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(macAddr)
    }
    
    enum DamperStatus {
        case operating
        case notOperating
        case unknown
    }
    
    enum CodingKeys: String, CodingKey {
        case macaddr
        case fanspd
        case doorinprocess
        case timeremaining
        case ipaddr
        case model
        case softver
        case interlock1
        case interlock2
        case cfm
        case power
        case house_temp
        case DNS1
        case attic_temp
        case oa_temp
        case server_response
        case DIPS
        case switch2
        case Setpoint
    }
    
    enum DecodeError: Error {
        case noValue (CodingKeys)
        case noData
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let speedStr = try container.decode(String.self, forKey: .fanspd)
        labelValueDictionary["Speed"] = speedStr
        let timerStr = try container.decode(String.self, forKey: .timeremaining)
        guard let intSpeed = Int(speedStr) else {throw DecodeError.noValue(.fanspd)}
        guard let intTimer = Int(timerStr) else {throw DecodeError.noValue(.timeremaining)}
        let damperStr = try container.decode(String.self, forKey: .doorinprocess)
        let i1Str = try container.decode(String.self, forKey: .interlock1)
        let i2Str = try container.decode(String.self, forKey: .interlock2)
        macAddr = try container.decode(String.self, forKey: .macaddr)
        airspaceFanModel = try container.decode(String.self, forKey: .model)
        ipAddr = try? container.decode(String.self, forKey: .ipaddr)
        let cfmStr = try? container.decode(String.self, forKey: .cfm)
        cubicFeetPerMinute = cfmStr.map({ Int($0) }) ?? nil
        softwareVersion = try? container.decode(String.self, forKey: .softver)
        dns = try? container.decode(String.self, forKey: .DNS1)
        serverResponse = try? container.decode(String.self, forKey: .server_response)
        dipSwitch = try? container.decode(String.self, forKey: .DIPS)
        remoteSwitch = try? container.decode(String.self, forKey: .switch2)
        let powerStr = try? container.decode(String.self, forKey: .power)
        let insideTempStr = try? container.decode(String.self, forKey: .house_temp)
        let atticTempStr = try? container.decode(String.self, forKey: .attic_temp)
        let outsideTempStr = try? container.decode(String.self, forKey: .oa_temp)
        let setpointStr = try? container.decode(String.self, forKey: .Setpoint)
        damper = damperStr == "1" ? .operating : .notOperating
        interlock1 = i1Str == "1" ? true : false
        interlock2 = i2Str == "1" ? true : false
        speed = intSpeed
        timer = intTimer
        power = powerStr.map { Int($0) } ?? nil
        insideTemp = insideTempStr.map { Int($0) } ?? nil
        atticTemp = atticTempStr.map { Int($0) } ?? nil
        outsideTemp = outsideTempStr.map { Int($0) } ?? nil
        setpoint = setpointStr.map { Int($0) } ?? nil
        labelValueDictionary["Speed"] = speedStr
        labelValueDictionary["Timer"] = timerStr
        labelValueDictionary["Damper"] = damperStr == "1" ? "Opening" : "Not operating"
        labelValueDictionary["Interlock 1"] = i1Str == "1" ? "Active" : "Not active"
        labelValueDictionary["Interlock 2"] = i2Str == "1" ? "Active" : "Not active"
        labelValueDictionary["MAC Address"] = macAddr
        labelValueDictionary["Model"] = airspaceFanModel
        labelValueDictionary["IP Address"] = ipAddr ?? "Not reported"
        labelValueDictionary["Airflow"] = cfmStr.map { "\($0) cfm" } ?? "Not reported"
        labelValueDictionary["Software version"] = softwareVersion ?? "Not reported"
        labelValueDictionary["DNS"] = dns ?? "Not reported"
        labelValueDictionary["DIP Switch"] = dipSwitch ?? "Not reported"
        labelValueDictionary["Remote Switch"] = remoteSwitch ?? "Not reported"
        labelValueDictionary["Power"] = powerStr ?? "Not reported"
        labelValueDictionary["Inside Temp"] = insideTempStr.map { "\($0)˚" } ?? "Not reported"
        labelValueDictionary["Attic Temp"] = atticTempStr.map { "\($0)˚" } ?? "Not reported"
        labelValueDictionary["Outside Temp"] = outsideTempStr.map { "\($0)˚" } ?? "Not reported"
        labelValueDictionary["Setpoint"] = setpointStr ?? "Not reported"
        labelValueDictionary["Speed"] = speedStr
//        print(serverResponse)
    }
    
    init () {
        speed = 0
        macAddr = "BEEF"
        airspaceFanModel = "Whole House Fan"
    }
}

struct FanStatusLoader {
    let loadResults: AnyPublisher<FanCharacteristics, ConnectionError>
    init? (addr ip: String, action: FanModel.Action) {
        guard let url = URL(string: "http://\(ip)/fanspd.cgi?dir=\(action.rawValue)") else { return nil }
        let decoder = JSONDecoder()
        let session = URLSession.shared
        loadResults =
            session.dataTaskPublisher(for: url)
            .filter { (_, response) in
                (response as? HTTPURLResponse).map { (200..<300).contains($0.statusCode) } ?? false
            }
            .map(\.data)
            .map { String(data: $0, encoding: .ascii) ?? "" }
            .map {
                $0.trimmingCharacters(in: .whitespaces)
                .split(separator: "<")
                .filter({ !$0.contains("/") && $0.contains(">") })
                .map ({ $0.split(separator: ">", maxSplits: 1) })
                .map ({ arr -> (String, String?) in
                    let newTuple = (String(arr[0]), arr.count == 2 ? String(arr[1]) : nil)
                    return newTuple
                }) }
            .map { $0.jsonData }
            .decode(type: FanCharacteristics.self, decoder: decoder)
            .mapError({ err in
                ConnectionError.cast(err)
            })
            .eraseToAnyPublisher()
    }
}

extension FanModel {
    convenience init () {
        print("Test fan model init")
        self.init(forAddress: "0.0.0.0:8181")
    }
}

extension FanModel: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(fanCharacteristics?.macAddr)
    }
    
    static func ==(lhs: FanModel, rhs: FanModel) -> Bool {
        guard let leftMac = lhs.fanCharacteristics?.macAddr, let rightMac = rhs.fanCharacteristics?.macAddr else { return false }
        return leftMac == rightMac
    }
}

extension FanModel: Identifiable {
    var id: String {
        fanCharacteristics?.macAddr ?? "invalid"
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
}

extension FanModel {
    fileprivate func getFanStatus(sendingCommand command: FanModel.Action) {
        FanStatusLoader(addr: ipAddr, action: command)?
            .loadResults
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] chars in
                self?.fanCharacteristics = chars
            })
            .store(in: &bag)
    }
    
//    private func adjustSpeed(target: Int, current: Int) {
//        defer {
//            lastSpeed = current
//        }
//        guard target != current else { return }
//
//        var action: Action = .refresh
//        var delay: DispatchTimeInterval = .seconds(1)
//
//        if !adjustmentStatus.isSpeedResponsive && adjustmentStatus.contains(.speedAdjusting) {
//            action = .refresh
//        } else if target == 0 {
//            action = .off
//        } else if target < current {
//            action = .slower
//        } else if target > current {
//            action = .faster
//        }
//
//        if adjustmentStatus.isDisjoint(with: .speedAdjusting) {
//            delay = .seconds(0)
//        } else if adjustmentStatus.isSpeedResponsive && !adjustmentStatus.isBusyForSpeedAdj {
//            delay = .milliseconds(500)
//        } else {
//            delay = .seconds(1)
//        }
//
//        print("\r\rAction: \(action)\rDelay: \(delay)\rLast speed: \(String(describing: lastSpeed))\rCurrent speed: \(String(describing: current))\rRequested speed: \(target)\rResponsive: \(adjustmentStatus.isSpeedResponsive)")
//        adjustmentStatus.labels.forEach({print("\t\($0)")})
//
//        adjustmentStatus.insert(.notAtRequestedSpeed)
//        adjustmentStatus.insert(.speedAdjusting)
//
//        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self, action] in
//            guard let self = self else { return }
//            self.getFanStatus(sendingCommand: action)
//        }
//    }

    private func adjustTimer(target: Int, current: Int) {
        defer {
            lastTimer = current
        }
        guard target > current else { return }
        
        var action: Action = .timer
        var delay: DispatchTimeInterval = .seconds(1)

        if !adjustmentStatus.isTimerResponsive && adjustmentStatus.contains(.timerAdjusting) {
            action = .refresh
        }

        if adjustmentStatus.isDisjoint(with: .timerAdjusting) {
            delay = .seconds(0)
        } else if adjustmentStatus.isTimerResponsive && !adjustmentStatus.isBusyForTimerAdj {
            delay = .milliseconds(500)
        } else {
            delay = .seconds(1)
        }
        
        print("\r\rAction: \(action)\rDelay: \(delay)\rLast timer: \(String(describing: lastTimer))\rCurrent timer: \(String(describing: current))\rRequested timer: \(target)\rResponsive: \(adjustmentStatus.isTimerResponsive)")
        adjustmentStatus.labels.forEach({print("\t\($0)")})

        adjustmentStatus.insert(.notAtRequestedTimer)
        adjustmentStatus.insert(.timerAdjusting)
       
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self, action] in
            guard let self = self else { return }
            self.getFanStatus(sendingCommand: action)
        }
    }

    private func connectFanSubscribers () {
        
        $targetSpeed
            .compactMap { $0 }
            .combineLatest($fanCharacteristics
                            .compactMap { $0 }
                            .map(\.speed))
            .print()
            .sink(receiveValue: { [weak self] (targetSpd, actualSpd) in
                if targetSpd != actualSpd {
                    self?.fanLamps.insert(.physicalSpeedMismatchToRequested)
//                    self?.adjustSpeed(target: targetSpd, current: actualSpd)
                } else {
                    self?.targetSpeed = nil
                    self?.lastSpeed = nil
                    self?.adjustmentStatus.remove(.speedAdjusting)
                    self?.adjustmentStatus.remove(.notAtRequestedSpeed)
                    self?.fanLamps.remove(.physicalSpeedMismatchToRequested)
                }
            })
            .store(in: &bag)
        
        $targetTimer
            .compactMap { $0 }
            .combineLatest($fanCharacteristics
                            .compactMap { $0 }
                            .map(\.timer))
            .sink(receiveValue: { [weak self] (targetTimer, actualTimer) in

                if targetTimer > actualTimer {
                    self?.adjustTimer(target: targetTimer, current: actualTimer)
                } else {
                    self?.targetTimer = nil
                    self?.lastTimer = nil
                    self?.adjustmentStatus.remove(.timerAdjusting)
                    self?.adjustmentStatus.remove(.notAtRequestedTimer)
                }
            })
            .store(in: &bag)

        $fanCharacteristics
            .compactMap { $0 }
            .map(\.speed)
            .sink { [weak self] spd in
                guard let self = self else { return }

                if self.lastSpeed.map ({ $0 != spd }) ?? false {
                    self.adjustmentStatus.insert(.speedChangedSinceLastUpdate)
                } else {
                    self.adjustmentStatus.remove(.speedChangedSinceLastUpdate)
                }

                if spd == 0 {
                    self.adjustmentStatus.insert(.fanOff)
                    self.fanLamps.insert(.fanOff)
                } else {
                    self.adjustmentStatus.remove(.fanOff)
                    self.fanLamps.remove(.fanOff)
                }
            }
            .store(in: &bag)
        
        $fanCharacteristics
            .compactMap { $0 }
            .map(\.timer)
            .sink { [weak self] currentTimer in
                guard let self = self else { return }

                if self.lastTimer.map ({ $0 < currentTimer }) ?? false {
                    self.adjustmentStatus.insert(.timerChangedSinceLastUpdate)
                } else {
                    self.adjustmentStatus.remove(.timerChangedSinceLastUpdate)
                }
            }
            .store(in: &bag)

        $fanCharacteristics
            .compactMap { $0 }
            .map(\.damper)
            .sink(receiveValue: { [weak self] damper in
                switch damper {
                case .operating:
                    self?.fanLamps.insert(.damperOperating)
                    self?.adjustmentStatus.insert(.damperOperating)
                case .notOperating:
                    self?.fanLamps.remove(.damperOperating)
                    self?.adjustmentStatus.remove(.damperOperating)
                case .unknown:
                    self?.fanLamps.remove(.damperOperating)
                    self?.adjustmentStatus.remove(.damperOperating)
                }
            })
            .store(in: &bag)
        
        $fanCharacteristics
            .compactMap { $0 }
            .map(\.speed)
            .map { Optional.some($0) }
            .assign(to: &$physicalSpeed)
    }
}

extension FanModel {
    struct AdjustmentStatus: OptionSet {
        static let speedChangedSinceLastUpdate = AdjustmentStatus(rawValue: 1)
        static let damperOperating = AdjustmentStatus(rawValue: 1 << 2)
        static let timerAdjusting = AdjustmentStatus(rawValue: 1 << 3)
        static let fanOff = AdjustmentStatus(rawValue: 1 << 4)
        static let notAtRequestedSpeed = AdjustmentStatus(rawValue: 1 << 5)
        static let speedAdjusting = AdjustmentStatus(rawValue: 1 << 6)
        static let timerChangedSinceLastUpdate = AdjustmentStatus(rawValue: 1 << 7)
        static let notAtRequestedTimer = AdjustmentStatus(rawValue: 1 << 8)
        
        let rawValue: Int8
        
        var isSpeedResponsive: Bool {
            self.contains(.speedChangedSinceLastUpdate)
        }
        
        var isTimerResponsive: Bool {
            self.contains(.timerChangedSinceLastUpdate)
        }

        var isBusyForSpeedAdj: Bool {
            self.contains(.damperOperating) || self.contains(.timerAdjusting)
        }
        
        var isBusyForTimerAdj: Bool {
            self.contains(.damperOperating) || self.contains(.speedAdjusting)
        }

        var labels: [String] {
            var retVal = Array<String>()
            if self.contains(.speedChangedSinceLastUpdate) { retVal.append("Speed changed from last update") }
            if self.contains(.damperOperating) { retVal.append("Damper operating") }
            if self.contains(.timerAdjusting) { retVal.append("Timer adjusting") }
            if self.contains(.fanOff) { retVal.append("Fan off") }
            if self.contains(.notAtRequestedSpeed) { retVal.append("Not at requested speed") }
            if self.contains(.speedAdjusting) { retVal.append("Speed adjustment in process") }
            if self.contains(.timerChangedSinceLastUpdate) { retVal.append("Timer changed from last update") }
            if self.contains(.notAtRequestedTimer) { retVal.append("Not at requested timer") }
            return retVal
        }

        
        var description: String {
            "Last update successful: \(self.contains(.speedChangedSinceLastUpdate))\rDamper operating: \(self.contains(.damperOperating))\rTimer adjusting: \(self.contains(.timerAdjusting))\rFan off: \(self.contains(.fanOff))\rNot at requested speed: \(self.contains(.notAtRequestedSpeed))\r"
        }
    }
}


class Motor {
    private var fan: FanModel
    private var lastSpeed: Int?
    private var setterSubscription: AnyCancellable?
    private var watchdog = PassthroughSubject<Bool, AdjustmentError>()
    private var bag = Set<AnyCancellable>()
    
    init (fan: FanModel) {
        self.fan = fan
    }
    
    func setSpeed(to target: Int) -> Future<(), AdjustmentError> {
        return Future<(), AdjustmentError> { [weak self] promise in
            guard let self = self else { return }
            self.watchdog = PassthroughSubject<Bool, AdjustmentError>()
            self.lastSpeed = nil
            
            self.watchdog
                .collect(.byTimeOrCount(DispatchQueue.main, .seconds(7.5), 5))
                .timeout(.seconds(8), scheduler: DispatchQueue.main, customError: { .notReady("Timed out") })
                .tryMap { changeTrackerArr in
                    guard changeTrackerArr.contains(false) else {
                        throw AdjustmentError.speedDidNotChange
                    }
                }
                .mapError { $0 as? AdjustmentError ?? .upstream(NSError.init()) }
                .sink (receiveCompletion: { [weak self] comp in
                    if case .failure (let err) = comp {
                        promise(.failure(err))
                    } else {
                        promise(.success(()))
                    }
                    self?.lastSpeed = nil
                    self?.bag.removeAll()
                }, receiveValue: { _ in })
                .store(in: &self.bag)
            
            self.fan.$fanCharacteristics
                .compactMap { $0?.speed }
                .print("in model")
                .map { [weak self] currentSpeed -> AnyPublisher<FanModel.Action, Never> in
                    guard let self = self else {
                        return Empty.init(completeImmediately: true, outputType: FanModel.Action.self, failureType: Never.self).eraseToAnyPublisher()
                    }
                    defer { self.lastSpeed = currentSpeed }
                    self.watchdog.send(self.lastSpeed.map { $0 == currentSpeed } ?? true)
                    switch () {
                    case _ where target == currentSpeed: //finished
                        self.watchdog.send(completion: .finished)
                        return Empty.init(completeImmediately: true, outputType: FanModel.Action.self, failureType: Never.self).eraseToAnyPublisher()
                    case _ where target == 0: //turn off
                        return Just(FanModel.Action.off).eraseToAnyPublisher()
                    case _ where self.lastSpeed == nil && currentSpeed == 0: //startup
                        return Just(FanModel.Action.faster).eraseToAnyPublisher()
                    default: //adjust
                        return Just ( currentSpeed > target ? .slower : .faster).delay(for: .seconds(self.lastSpeed == currentSpeed ? 3.0 : 0.5), scheduler: DispatchQueue.main).eraseToAnyPublisher()
                    }
                }
                .switchToLatest()
                .sink (
                    receiveValue: { [weak self] action in
                        self?.fan.getFanStatus(sendingCommand: action)
                    })
                .store(in: &self.bag)
        }
    }
}

struct Damper {
    enum Status {
        case operating, notOperating
    }
    var status: Status?
}

struct FanTimer {
    enum Status {
        case notSet, countingDown, notUpdating, updating
    }
    var status: Status?
}
