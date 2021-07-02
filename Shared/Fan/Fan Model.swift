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
    @Published var fanCharacteristics: FanCharacteristics?
    @Published var commError: ConnectionError?
    @Published var notifier: String?
    @Published var currentSpeed: Int?
    @Published var targetSpeed: Int?
    @Published var timerBusy = TimerBusy()
    private var responsive = Responsive()
    private var lastSpeed: Int?
    private var loaderPublisher = PassthroughSubject<AnyPublisher<FanCharacteristics, ConnectionError>, Never>()
    private var bag = Set<AnyCancellable>()

    init(forAddress address: String, usingChars chars: FanCharacteristics? = nil) {
        ipAddr = address
        connectFanSubscribers()
        chars.map { fanCharacteristics = $0 } ?? self.getFanStatus(sendingCommand: .refresh)
        print("init fan model \(ipAddr) chars \(chars == nil ? "not " : "")available")
    }
    
    func setFan(toSpeed finalTarget: Int? = nil) {
        responsive.insert(.firstTry)
        targetSpeed = finalTarget
//        lastReportedSpeed = nil
    }
    
    func setFan(addHours hours: Int) {
        guard hours > 0, let timeLeftOnFan = fanCharacteristics?.timer else {
            timerBusy.remove(.timerAdjusting)
            return
        }
        timerBusy.insert(.timerAdjusting)
        let targetThreshold = min (720, timeLeftOnFan + ( 60 * hours )) - 10
        for increment in (0..<hours) {
            DispatchQueue.main.asyncAfter(deadline: (.now() + .seconds(1)) + .seconds(increment)) { [weak self] in
                guard let self = self, let current = self.fanCharacteristics?.timer else { return }
                if current < targetThreshold {
                    self.getFanStatus(sendingCommand: .timer)
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(hours * 500) + .seconds(5) ) {
         [weak self] in
            guard let self = self else { return }
            guard let current = self.fanCharacteristics?.timer else {
                self.timerBusy.remove(.timerAdjusting)
                return
            }

            if current < targetThreshold {
                self.setFan(addHours: 1)
            } else {
                self.timerBusy.remove(.timerAdjusting)
            }
        }
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
//            .handleEvents(receiveOutput: { out in
//                print("\(ip)\r\((out.response as? HTTPURLResponse)?.statusCode)")
//            })
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
//            .handleEvents(receiveOutput: {out in
//                print("Address: \(ip) \r\(out)")
//            })
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
    private func getFanStatus(sendingCommand command: FanModel.Action) {
//        print("action \(command)")
        FanStatusLoader(addr: ipAddr, action: command)?
            .loadResults
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] chars in
                self?.fanCharacteristics = chars
            })
            .store(in: &bag)
    }
    
    private func adjustSpeed(target: Int, current: Int) {
        defer {
            lastSpeed = current
            responsive.remove(.firstTry)
        }
        var action: Action = .refresh
        var delay: DispatchTimeInterval = .seconds(1)

        if current == lastSpeed {
            action = .refresh
        } else if target == 0 {
            action = .off
        } else if target < current {
            action = .slower
        } else if target > current {
            action = .faster
        }

        if responsive.contains(.firstTry) {
            delay = .seconds(0)
        } else if !responsive.isEmpty {
            delay = .milliseconds(500)
        }
        
        print("\rAction: \(action)\rDelay: \(delay)\rLast speed: \(String(describing: lastSpeed))\rCurrent speed: \(String(describing: current))\rRequested speed: \(target)\rResponsive:\r \(responsive.description)\r")
       
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self, action] in
            guard let self = self else { return }
            self.getFanStatus(sendingCommand: action)
        }
    }

//    private func adjustTime(to time: Int) {
//        guard time > (fanCharacteristics?.timer ?? 0 - 10) else {
//            targetTimer.send(nil)
//            return
//        }
//
//        let delay: DispatchTimeInterval = .milliseconds(fanCharacteristics?.damper ?? .unknown != .operating ? 500 : 2000)
//
//        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
//            guard let self = self else { return }
//            self.getFanStatus(sendingCommand: .timer)
//        }
//    }

    private func connectFanSubscribers () {
        
        $targetSpeed
            .compactMap { $0 }
            .combineLatest($fanCharacteristics
                            .compactMap { $0 }
                            .map(\.speed))
            .sink(receiveValue: { [weak self] (targetSpd, actualSpd) in

                if self?.lastSpeed.map ({ $0 != actualSpd }) ?? false {
                    self?.responsive.insert(.lastUpdateSuccessful)
                } else {
                    self?.responsive.remove(.lastUpdateSuccessful)
                }

                if targetSpd != actualSpd {
                    self?.timerBusy.insert(.speedAdjusting)
                    self?.adjustSpeed(target: targetSpd, current: actualSpd)
                } else {
                    self?.targetSpeed = nil
                    self?.timerBusy.remove(.speedAdjusting)
                }
            })
            .store(in: &bag)
        
        $fanCharacteristics
            .compactMap { $0 }
            .map(\.speed)
            .sink { [weak self] spd in
                guard let self = self else { return }
                if spd == 0 {
                    self.timerBusy.insert(.fanOff)
                } else {
//                    self.timerBusy.insert(.fanOff)
                    self.timerBusy.remove(.fanOff)
                }
            }
            .store(in: &bag)
        
        $fanCharacteristics
            .compactMap { $0 }
            .map(\.damper)
            .sink(receiveValue: { [weak self] damper in
                switch damper {
                case .operating:
                    self?.timerBusy.insert(.damperOperating)
                    self?.responsive.remove(.damperNotOperating)
                case .notOperating:
                    self?.timerBusy.remove(.damperOperating)
                    self?.responsive.insert(.damperNotOperating)
                case .unknown:
                    self?.timerBusy.remove(.damperOperating)
                    self?.responsive.insert(.damperNotOperating)
                }
            })
            .store(in: &bag)
        
        $fanCharacteristics
            .compactMap { $0 }
            .map(\.speed)
            .map { Optional.some($0) }
            .assign(to: &$currentSpeed)
        
        $fanCharacteristics
            .compactMap { $0 }
            .map(\.timer)
            .sink { [weak self] time in
                guard self != nil else { return }
//                print("Received time \(time)")
//                self.targetTimer.value.map { self.adjustTime(to: $0) }
            }
            .store(in: &bag)
//
//        targetTimer
//            .compactMap { $0 }
//            .sink(receiveValue: { [weak self] timerTarget in
//                self?.adjustTime(to: timerTarget)
//            })
//            .store(in: &bag)
        
        //char loader
//        loaderPublisher
//            .switchToLatest()
////            .print("char loader")
//            .sink(receiveCompletion: { [weak self] (comp) in
//                if case .failure(let err) = comp {
//                    self?.commError = err
//                    self?.notifier = err.localizedDescription
//                    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(5)) { [weak self] in
//                        self?.notifier = nil
//                    }
//                }
//                print("Unexpected completion in characteristics listener \(comp)")
//            }, receiveValue: { [weak self] chars in
//                self?.fanCharacteristics = chars
//            })
//            .store(in: &bag)
        
        //watchdog
//        loaderPublisher
//            .switchToLatest()
//            .map { _ in "query"}
//            .merge(with: Timer.publish(every: 20, on: .main, in: .common)
//                    .autoconnect()
//                    .map { _ in "watchdog"}
//                    .setFailureType(to: ConnectionError.self)
//                    .eraseToAnyPublisher())
////            .print("watchdog")
//            .collect(.byTime(DispatchQueue.main, .seconds(60)))
//            .filter({ !$0.contains("query") })
//            .sink(receiveCompletion: {_ in}, receiveValue: { [weak self] _ in
//                self?.getFanStatus(sendingCommand: .refresh)
//            })
//            .store(in: &bag)

        //speed setter
//        loaderPublisher
//            .switchToLatest()
//            .map { ($0.speed, $0.damper) }
////            .print("speed controller \(self.targetSpeed.debugDescription)")
//            .sink(receiveCompletion: { [weak self] comp in
//                if case .failure(let err) = comp {
//                    self?.notifier = err.localizedDescription
//                    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(5)) { [weak self] in
//                        self?.notifier = nil
//                    }
//
//                }
//            }, receiveValue: { [weak self] (speed, damper) in
//                guard let self = self else { return }
//                defer { self.lastReportedSpeed = speed }
//                guard let target = self.targetSpeed else { return }
//                if speed == target {
//                    self.targetSpeed = nil
//                } else if target == 0 {
//                    self.getFanStatus(sendingCommand: .off, withDelay: 1.0)
//                } else {
//                    let action: FanModel.Action = (target < speed) ? .slower : .faster
//                    let delay = self.lastReportedSpeed.map { $0 == speed } ?? false ? 5.0 : 0.5
//                    self.getFanStatus(sendingCommand: action, withDelay: delay)
//                }
//                if damper { self.getFanStatus(sendingCommand: .refresh, withDelay: 1.0) }
//                return
//                }
////                guard target != 0 else { self.getFanStatus(sendingCommand: .off); return}
//            )
//            .store(in: &bag)
        
        //timer setter
//        loaderPublisher
//            .switchToLatest()
//            .map { $0.timer }
////            .print("timer controller")
//            .sink(receiveCompletion: { comp in
//            }, receiveValue: { [weak self] timer in
//                defer { self?.lastReportedTimer = timer }
//                guard let target = self?.targetTimer, timer < target else {
//                    self?.targetTimer = nil
//                    return
//                }
//                self?.getFanStatus(sendingCommand: .timer, withDelay: 0.5)
//            })
//            .store(in: &bag)
    }
}

extension FanModel {
    struct TimerBusy: OptionSet {
        static let timerAdjusting = TimerBusy(rawValue: 1)
        static let fanOff = TimerBusy(rawValue: 1 << 1)
        static let damperOperating = TimerBusy(rawValue: 1 << 2)
        static let speedAdjusting = TimerBusy(rawValue: 1 << 3)
        
        let rawValue: Int8
    }
    struct Responsive: OptionSet {
        static let lastUpdateSuccessful = Responsive(rawValue: 1)
//        static let fanOff = Responsive(rawValue: 1 << 1)
        static let damperNotOperating = Responsive(rawValue: 1 << 2)
        static let firstTry = Responsive(rawValue: 1 << 3)
        
        let rawValue: Int8
        
        var description: String {
            "Last update successful: \(self.contains(.lastUpdateSuccessful))\rDamper not operating: \(self.contains(.damperNotOperating))\rFirst try: \(self.contains(.firstTry))"
        }
    }
}
