//
//  Fan Model.swift
//  whf001
//
//  Created by Scott Lucas on 12/9/20.
//

import Foundation
import Combine
import SwiftUI

struct FanModel {
    var fanCharacteristics: CurrentValueSubject<FanCharacteristics, Never>
    var motorContext = CurrentValueSubject<Motor.Context, Never>(.standby)
    var timerContext = CurrentValueSubject<FanTimer.Context, Never>(.standby)
    private var motor: MotorDelegate!
    private var timer: TimerDelegate!
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var ipAddr: String
//    private var monitorTask: Task<(), Never>?
    
    init(usingChars chars: FanCharacteristics) {
        motor = Motor(atAddr: chars.ipAddr)
        timer = FanTimer(atAddr: chars.ipAddr)
        ipAddr = chars.ipAddr
        fanCharacteristics = CurrentValueSubject<FanCharacteristics, Never>.init(chars)
//        print("init fan model \(chars.ipAddr)")
    }
    
    mutating func setFan(toSpeed finalTarget: Int) async {
        motorContext.send(.adjusting)
        print("start motor adjust")
        do {
            for try await char in motor.setSpeedAsync(to: finalTarget) {
                print( "In loop with speed \(char.speed)" )
                fanCharacteristics.send(char)
            }
            motorContext.send(.standby)
        } catch {
            motorContext.send(.fault)
            print("error setting speed \(error)")
        }
    }
    
    mutating func setFan(addHours hours: Int) async {
        guard hours > 0 else {
            timerContext.send(.fault)
            return
        }
        timerContext.send(.adjusting)
        let current = fanCharacteristics.value.timer
        let target = min (current + hours * 60, 12 * 60) - 10
        print("timer target \(target)")
        do {
            for try await char in timer.setTimerAsync(to: target) {
                fanCharacteristics.send(char)
            }
            timerContext.send(.standby)
        } catch {
            timerContext.send(.fault)
            print("Error setting timer \(error)")
        }
    }
    
    mutating func refresh() async throws {
        let newChars = try await motor.refresh()
        fanCharacteristics.send(newChars)
    }
    
//    private func fanMonitor () async {
//        let interval = TimeInterval( 5 * 60 ) //5 minute loop interval
//        while true {
//            do {
//                guard let cancelled = monitorTask?.isCancelled, !cancelled else {
//                    throw BackgroundTaskError.taskCancelled
//                }
//                print("Fan monitor loop @ \(Date.now.formatted()), last update \(Storage.lastForecastUpdate.formatted())")
//                try await Task.sleep(interval: interval) //run the loop every 5 minutes to respond as conditions change
//                try await refresh()
//            } catch {
//                let e = error as? BackgroundTaskError ?? error
//                print("exited fan monitor loop @ \(Date.now.formatted()), error: \(e.localizedDescription)")
//                break
//            }
//        }
//    }
//
//    mutating private func registerBackgroundTask() {
//        //        print("BG task started")
//        backgroundTask = UIApplication.shared.beginBackgroundTask {
//            //            print("BG task expired")
//            endBackgroundTask()
//        }
//        assert(backgroundTask != .invalid)
//    }
//
//    mutating private func endBackgroundTask() {
//        //        print("Background task ended.")
//        UIApplication.shared.endBackgroundTask(backgroundTask)
//        backgroundTask = .invalid
//    }
}

extension FanModel {
    init () {
        print("Test fan model init")
        self.init(usingChars: FanCharacteristics())
    }
}

extension FanModel: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(fanCharacteristics.value.macAddr)
    }
    
    static func ==(lhs: FanModel, rhs: FanModel) -> Bool {
        return lhs.fanCharacteristics.value.macAddr == rhs.fanCharacteristics.value.macAddr
    }
}

extension FanModel: Identifiable {
    var id: String {
        fanCharacteristics.value.macAddr
    }
}

extension FanModel {
    
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

struct FanCharacteristics: Decodable, Hashable {
    var ipAddr: String
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
    var labelValueDictionary: [String: String] {
        let iT = insideTemp.map ({
            Measurement<UnitTemperature>(value: Double($0), unit: .fahrenheit).formatted(Measurement<UnitTemperature>.FormatStyle.truncatedTemp)
        }) ?? "Not reported"
        
        let oT = outsideTemp.map ({
            Measurement<UnitTemperature>(value: Double($0), unit: .fahrenheit).formatted(Measurement<UnitTemperature>.FormatStyle.truncatedTemp)
        }) ?? "Not reported"
        
        let aT = atticTemp.map ({
            Measurement<UnitTemperature>(value: Double($0), unit: .fahrenheit).formatted(Measurement<UnitTemperature>.FormatStyle.truncatedTemp)
        }) ?? "Not reported"
        
        return [
            "Speed" : String(speed),
            "Timer" : String(timer),
            "Damper" : damper == .operating ? "Opening" : "Not operating",
            "Interlock 1" : interlock1 ? "Active" : "Not active",
            "Interlock 2" : interlock2 ? "Active" : "Not active",
            "MAC Address" : macAddr,
            "Model" : airspaceFanModel,
            "IP Address" : ipAddr,
            "Airflow": cubicFeetPerMinute.map { "\($0) cfm" } ?? "Not reported",
            "Software version" : softwareVersion ?? "Not reported",
            "DNS" : dns ?? "Not reported",
            "DIP Switch" : dipSwitch ?? "Not reported",
            "Remote Switch" : remoteSwitch ?? "Not reported",
            "Power" : power.map { String($0) } ?? "Not reported",
            "Inside Temp" : iT,
            "Attic Temp" : aT,
            "Outside Temp" : oT,
            "Setpoint" : setpoint.map { String($0) } ?? "Not reported"
        ]
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(macAddr)
    }
    
    static func ==(lhs: FanCharacteristics, rhs: FanCharacteristics) -> Bool {
        return lhs.macAddr == rhs.macAddr
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
        let timerStr = try container.decode(String.self, forKey: .timeremaining)
        guard let intSpeed = Int(speedStr) else {throw DecodeError.noValue(.fanspd)}
        guard let intTimer = Int(timerStr) else {throw DecodeError.noValue(.timeremaining)}
        let damperStr = try container.decode(String.self, forKey: .doorinprocess)
        let i1Str = try container.decode(String.self, forKey: .interlock1)
        let i2Str = try container.decode(String.self, forKey: .interlock2)
        macAddr = try container.decode(MACAddr.self, forKey: .macaddr)
        airspaceFanModel = try container.decode(String.self, forKey: .model)
        do {
            ipAddr = try container.decode(IPAddr.self, forKey: .ipaddr)
        } catch {
            ipAddr = UUID.init().uuidString
        }
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
        insideTemp = insideTempStr.map {
            guard $0 != "-99" else { return nil }
            return Int($0) } ?? nil
        atticTemp = atticTempStr.map {
            guard $0 != "-99" else { return nil }
            return Int($0) } ?? nil
        outsideTemp = outsideTempStr.map {
            guard $0 != "-99" else { return nil }
            return Int($0) } ?? nil
        setpoint = setpointStr.map { Int($0) } ?? nil
    }
    
    init (data: Data?) throws {
        guard let data = data else { throw ConnectionError.decodeError("Data was nil.")}
        guard let tupleSource = String(data: data, encoding: .ascii) else { throw ConnectionError.decodeError("Data could not be encoded to ASCII") }
        let s = tupleSource
            .trimmingCharacters(in: .whitespaces)
            .split(separator: "<")
            .filter({ !$0.contains("/") && $0.contains(">") })
            .map ({ $0.split(separator: ">", maxSplits: 1) })
            .map ({ arr -> (String, String?) in
                let newTuple = (String(arr[0]), arr.count == 2 ? String(arr[1]) : nil)
                return newTuple
            })
        let decoder = JSONDecoder()
        guard let chars = try? decoder.decode(FanCharacteristics.self, from: s.jsonData) else { throw ConnectionError.decodeError("Decoder failed to parse FanCharacteristics from data of length \(data.count) bytes.") }
        self = chars
    }
    
    init () {
        speed = 0
        macAddr = UUID.init().uuidString.appending("BEEF")
        airspaceFanModel = "Whole House Fan"
        ipAddr = UUID.init().uuidString
    }
}

extension FanCharacteristics: Identifiable {
    var id: MACAddr { macAddr }
}

struct FanStatusLoader {
    typealias OutputPublisher = AnyPublisher<FanCharacteristics, ConnectionError>
    private var ip: IPAddr
    
    init (addr ip: IPAddr) {
        self.ip = ip
    }
    
    func loadResultsAsync (action: FanModel.Action) async throws -> FanCharacteristics {
        guard let url = URL(string: "http://\(ip)/fanspd.cgi?dir=\(action.rawValue)") else {
            throw ConnectionError.badUrl
        }
        let config = URLSession.shared.configuration
        config.timeoutIntervalForRequest = 10
        let session = URLSession.init(configuration: config)
        let (data, response) = try await session.data(from: url)
        guard let r = (response as? HTTPURLResponse) else {
            throw ConnectionError.serverError("Server error: could not interpret server response.")
        }
        guard (200..<300).contains(r.statusCode) else {
            throw ConnectionError.serverError("Server error, code \(r.statusCode)")
        }
        let results = try FanCharacteristics(data: data)
        return results
    }
    
    //    func loadResultsPublished (action: FanModel.Action) throws -> AnyPublisher<FanCharacteristics, ConnectionError> {
    //        guard let url = URL(string: "http://\(ip)/fanspd.cgi?dir=\(action.rawValue)") else {
    //            throw ConnectionError.badUrl
    //        }
    //        let decoder = JSONDecoder()
    //        let config = URLSession.shared.configuration
    //        config.timeoutIntervalForRequest = 10
    //        let session = URLSession.init(configuration: config)
    //        return session
    //            .dataTaskPublisher(for: url)
    //            .tryMap { (data, response) -> FanCharacteristics in
    //                guard let r = (response as? HTTPURLResponse) else {
    //                    throw ConnectionError.serverError("Server error: could not interpret server response.")
    //                }
    //                guard (200..<300).contains(r.statusCode) else {
    //                    throw ConnectionError.serverError("Server error, code \(r.statusCode)")
    //                }
    //                return try decoder.decode(FanCharacteristics.self, from:
    //                                            (String(data: data, encoding: .ascii) ?? "")
    //                                            .trimmingCharacters(in: .whitespaces)
    //                                            .split(separator: "<")
    //                                            .filter({ !$0.contains("/") && $0.contains(">") })
    //                                            .map ({ $0.split(separator: ">", maxSplits: 1) })
    //                                            .map ({ arr -> (String, String?) in
    //                    let newTuple = (String(arr[0]), arr.count == 2 ? String(arr[1]) : nil)
    //                    return newTuple
    //                }).jsonData )
    //            }
    //            .mapError {
    //                ($0 as? ConnectionError) ?? ConnectionError.cast($0)
    //            }
    //            .eraseToAnyPublisher()
    //    }
}

struct Motor: MotorDelegate {
    
    enum Context { case adjusting, standby, fault }
    private var ipAddr: IPAddr
    private var context: Context = .standby
    
    init (atAddr addr: IPAddr) {
        ipAddr = addr
    }
    
    func refresh () async throws -> FanCharacteristics {
        let getter = FanStatusLoader(addr: ipAddr)
        return try await getter.loadResultsAsync(action: .refresh)
    }
    
    func setSpeedAsync(to target: Int) -> AsyncThrowingStream<FanCharacteristics, Error> {
        return AsyncThrowingStream<FanCharacteristics, Error> { continuation in
            Task {
                let getter = FanStatusLoader(addr: ipAddr)
                var chars: FanCharacteristics
                chars = try await getter.loadResultsAsync(action: .refresh) //get chars to start
                continuation.yield( chars )//send chars back to fan model
                guard chars.speed != target else { continuation.finish() ; return } // preliminary check to see if we're already at target
                for _ in (0..<12) { //try 12 times to reach target
                    var preAdjustSpeed = chars.speed // take note of speed before adjustment
                    chars = try await getter.loadResultsAsync(action: target == 0 ? .off : target > chars.speed ? .faster : .slower) //make a speed adjustment
                    continuation.yield(chars) //send new chars to fan model
                    guard chars.speed != target else { continuation.finish() ; return } //finish if we hit the target speed
                    for _ in (0..<3) { //loop to wait when fan is unresponsive. Will send .refresh at 4 second intervals and see if the fan speed changes. If it does, break out of the loop. If not, try again for up to 3 times.
                        guard preAdjustSpeed == chars.speed else { break } //check if fan is responsive. If so, break out of the unresponsive wait look
                        try await Task.sleep(nanoseconds: UInt64(4.0 * 1_000_000_000)) //wait for 4 seconds
                        preAdjustSpeed = chars.speed // take note of the speed before getting a refresh. Note we should have a pending adjustment at this point.
                        chars = try await getter.loadResultsAsync(action: .refresh) //check the chars
                        continuation.yield (chars) // send new chars to model
                    } //end unresponsive loop
                    try await Task.sleep(nanoseconds: UInt64(1.0 * 1_000_000_000)) //wait between adjustment attempts to avoid swamping the fan.
                } //end of adjust loop
                continuation.finish(throwing: AdjustmentError.fanNotResponsive )//if successful, function will exit out of the function. If not, we will hit this statement after 12 tries.
            }
        }
    }
    
}

struct FanTimer: TimerDelegate {
    enum Context { case adjusting, standby, fault }
    private var ipAddr: IPAddr
    private var context: Context = .standby
    
    init (atAddr: IPAddr) {
        ipAddr = atAddr
    }
    
    func setTimerAsync (to target: Int) -> AsyncThrowingStream<FanCharacteristics, Error> {
        let getter = FanStatusLoader(addr: ipAddr)
        return AsyncThrowingStream<FanCharacteristics, Error> { continuation in
            Task {
                var chars: FanCharacteristics
                chars = try await getter.loadResultsAsync(action: .refresh)
                continuation.yield(chars)
                guard chars.timer < target else { continuation.finish(); return }
                for _ in (0..<17) {
                    var preAdjustTimer = chars.timer
                    chars = try await getter.loadResultsAsync(action: .timer)
                    continuation.yield(chars)
                    guard chars.timer < target else { continuation.finish(); return }
                    for _ in (0..<3) {
                        guard preAdjustTimer < chars.timer else { break }
                        try await Task.sleep(nanoseconds: UInt64(3.0 * 1_000_000_000)) //wait for 3 seconds
                        preAdjustTimer = chars.timer
                        chars = try await getter.loadResultsAsync(action: .refresh)
                        continuation.yield(chars)
                    }
                    try await Task.sleep(nanoseconds: UInt64(1.0 * 1_000_000_000)) //wait between adjustment attempts to avoid swamping the fan.
                }
                continuation.finish(throwing: AdjustmentError.fanNotResponsive)
            }
        }
    }
}

protocol MotorDelegate {
    func refresh () async throws -> FanCharacteristics
    mutating func setSpeedAsync (to: Int) -> AsyncThrowingStream<FanCharacteristics, Error>
    init(atAddr: IPAddr)
}

protocol TimerDelegate {
    func setTimerAsync (to: Int) -> AsyncThrowingStream<FanCharacteristics, Error>
    init(atAddr: IPAddr)
}
