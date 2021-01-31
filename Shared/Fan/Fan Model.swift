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
    @Published var fanCharacteristics = FanCharacteristics()
    @Published var targetSpeed: Int?
    @Published var commError: Bool = false
    private var targetTimer: Int?
    private var lastReportedSpeed: Int?
    private var lastReportedTimer: Int?
    private var loaderPublisher = PassthroughSubject<AnyPublisher<FanCharacteristics, ConnectionError>, Never>()
    private var fanContactTimer = Timer()
    private var bag = Set<AnyCancellable>()

    init(forAddress address: String, usingChars chars: FanCharacteristics? = nil) {
        ipAddr = address
        connectFanSubscribers()
        chars.map { fanCharacteristics = $0 } ?? self.getFanStatus(sendingCommand: .refresh)
        print("init fan model ip address in chars: \(ipAddr) from init: \(address)")
    }
    
    func setFan(toSpeed finalTarget: Int? = nil) {
        targetSpeed = finalTarget
        lastReportedSpeed = nil
        getFanStatus(sendingCommand: .refresh)
    }
    
    func setFan(addHours hours: Int) {
        guard hours > 0 else { return }
        let baseTime = lastReportedTimer ?? 0 > (60 * 12) - 10 ? (60 * 12) : (hours * 60) - 10 //allow a 10 minutes buffer unless current time's already within 10 minutes of 12 hours
        self.targetTimer = (lastReportedTimer ?? 0) + baseTime
        getFanStatus(sendingCommand: .refresh)
    }
}

struct FanCharacteristics: Decodable, Hashable {
    var ipAddr: String?
    var speed: Int
    var damper = false
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
       damper = damperStr == "1" ? true : false
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
        loadResults = session.dataTaskPublisher(for: url)
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
        hasher.combine(fanCharacteristics.macAddr)
    }
    
    static func ==(lhs: FanModel, rhs: FanModel) -> Bool {
        return lhs.fanCharacteristics.macAddr == rhs.fanCharacteristics.macAddr
    }
}

extension FanModel: Identifiable {
    var id: String {
        fanCharacteristics.macAddr
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
    private func getFanStatus(sendingCommand command: FanModel.Action, withDelay delay: Double = 0) {
        let delayMSec = Int(delay * 1000)
        print("action \(command)")
        if let loader = FanStatusLoader(addr: ipAddr, action: command)?
            .loadResults
            .share()
            .eraseToAnyPublisher() {
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(delayMSec)) { [loaderPublisher] in
                loaderPublisher.send (loader)
            }
        } else {
            commError = true
        }
    }

    private func connectFanSubscribers () {
        
        //char loader
        loaderPublisher
            .switchToLatest()
//            .print("char loader")
            .sink(receiveCompletion: { [weak self] (comp) in
                if case .failure = comp {
                    self?.commError = true
                }
                print("Unexpected completion in characteristics listener \(comp)")
            }, receiveValue: { [weak self] chars in
                self?.fanCharacteristics = chars
            })
            .store(in: &bag)
        
        //watchdog
        loaderPublisher
            .switchToLatest()
            .map { _ in "query"}
            .merge(with: Timer.publish(every: 20, on: .main, in: .common)
                    .autoconnect()
                    .map { _ in "watchdog"}
                    .setFailureType(to: ConnectionError.self)
                    .eraseToAnyPublisher())
//            .print("watchdog")
            .collect(.byTime(DispatchQueue.main, .seconds(60)))
            .filter({ !$0.contains("query") })
            .sink(receiveCompletion: {_ in}, receiveValue: { [weak self] _ in
                self?.getFanStatus(sendingCommand: .refresh)
            })
            .store(in: &bag)
        
        //speed setter
        loaderPublisher
            .switchToLatest()
            .map { $0.speed }
//            .print("speed controller \(self.targetSpeed.debugDescription)")
            .sink(receiveCompletion: { comp in
            }, receiveValue: { [weak self] speed in
                guard let self = self else { return }
                defer { self.lastReportedSpeed = speed }
                guard let target = self.targetSpeed, speed != target else {
                    self.targetSpeed = nil
                    return
                }
                guard target != 0 else { self.getFanStatus(sendingCommand: .off); return}
                let action: FanModel.Action = (target < speed) ? .slower : .faster
                let delay = self.lastReportedSpeed.map { $0 == speed } ?? false ? 5.0 : 0.5
                self.getFanStatus(sendingCommand: action, withDelay: delay)
            })
            .store(in: &bag)
        
        //timer setter
        loaderPublisher
            .switchToLatest()
            .map { $0.timer }
//            .print("timer controller")
            .sink(receiveCompletion: { comp in
            }, receiveValue: { [weak self] timer in
                defer { self?.lastReportedTimer = timer }
                guard let target = self?.targetTimer, timer < target else {
                    self?.targetTimer = nil
                    return
                }
                self?.getFanStatus(sendingCommand: .timer, withDelay: 0.5)
            })
            .store(in: &bag)
    }
}
