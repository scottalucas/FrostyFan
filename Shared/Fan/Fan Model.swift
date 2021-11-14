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
    @Published var fanCharacteristics: FanCharacteristics?
    @Published var fanStatus = FanStatus()
    private var motor: MotorDelegate!
    private var timer: TimerDelegate!
    private var motorContext: Motor.Context = .standby {
        didSet {
            switch motorContext {
                case .standby:
                    fanStatus.remove(.speedAdjusting)
                    if timerContext == .standby { startKeepalive() }
                case .adjusting:
                    fanStatus.insert(.speedAdjusting)
                    stopKeepalive()
                case .fault:
                    fanStatus.remove(.speedAdjusting)
                    stopKeepalive()
            }
        }
    }
    private var timerContext: FanTimer.Context = .standby {
        didSet {
            switch timerContext {
                case .standby:
                    fanStatus.remove(.timerAdjusting)
                    if motorContext == .standby { startKeepalive() }
                case .adjusting:
                    fanStatus.insert(.timerAdjusting)
                    startKeepalive()
                case .fault:
                    fanStatus.remove(.timerAdjusting)
                    stopKeepalive()
            }
        }
    }
    private var updateTimer: Timer?
    private var bag = Set<AnyCancellable>()
    
    init(usingChars chars: FanCharacteristics) {
        motor = Motor(atAddr: chars.ipAddr)
        timer = FanTimer(atAddr: chars.ipAddr)
        startSubscribers()
        startKeepalive()
        print("init fan model \(chars.ipAddr)")
    }
    
    func setFan(toSpeed finalTarget: Int) async {
        motorContext = .adjusting
        print("start motor adjust")
        do {
            for try await char in motor.setSpeedAsync(to: finalTarget) {
                print( "In loop with speed \(char.speed)" )
                fanCharacteristics = char
            }
            motorContext = .standby
        } catch {
            motorContext = .fault
            print("error setting speed \(error)")
        }
    }
    
    func setFan(addHours hours: Int) async {
        guard let chars = fanCharacteristics, hours > 0 else { fanStatus.insert(.timerAdjustmentFailed)
            timerContext = .fault
            return
        }
        timerContext = .adjusting
        let current = chars.timer
        let target = min (current + hours * 60, 12 * 60) - 10
        print("timer target \(target)")
        do {
            for try await char in timer.setTimerAsync(to: target) {
                fanCharacteristics = char
            }
            timerContext = .standby
        } catch {
            timerContext = .fault
            print("Error setting timer \(error)")
        }
    }
    
    func refresh() {
        guard let ipAddr = fanCharacteristics?.ipAddr else { return }
        do {
            Task {
                let newChars = try await FanStatusLoader(addr: ipAddr).loadResultsAsync(action: .refresh)
                fanCharacteristics = newChars
            }
        }
    }
    
    private func startKeepalive () {
//        print ("Start keepalive, nil: \(updateTimer == nil), valid: \(updateTimer.map { $0.isValid } ?? false)")
        if case let .some (t) = updateTimer, t.isValid { return }
        updateTimer?.invalidate()
        updateTimer = nil
        updateTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            guard let self = self else { return }
//            print("Keepalive")
            Task {
                do {
                    guard let addr = self.fanCharacteristics?.ipAddr else { throw AdjustmentError.missingKeys }
                    self.fanCharacteristics = try await FanStatusLoader(addr: addr).loadResultsAsync(action: .refresh)
                } catch {
                    self.motorContext = .fault
                }
            }
        }
    }
    
    private func stopKeepalive () {
        print ("Stop keepalive, nil: \(updateTimer == nil), valid: \(updateTimer.map { $0.isValid } ?? false)")
        guard let t = updateTimer else { return }
        if t.isValid { t.invalidate() }
        self.updateTimer = nil
    }
}

extension FanModel {
    private func startSubscribers () {
//        $fanStatus
//            .filter { $0.contains(.fanNotResponsive) }
//            .sink(receiveValue: { _ in
//                print("Fan not responsive, removing from house.")
//                if let myFanFromHouse = self.house.fans.first(where: { chars in chars.ipAddr == self.ipAddr }) {
//                    self.house.fans.remove(myFanFromHouse)
//                }
//            })
//            .store(in: &bag)
        
        $fanCharacteristics
            .sink(receiveValue: { [weak self] optChars in
                guard let self = self else { return }
                var currentStatus = self.fanStatus.subtracting(FanStatus.updatedByFan)
                guard let chars = optChars else {
                    currentStatus.insert(.noFanCharacteristics)
                    self.fanStatus = currentStatus
                    return
                }
                if chars.speed == 0 {
                    currentStatus.insert(.fanOff)
                }
                
                if chars.timer > 0 {
                    currentStatus.insert(.nonZeroTimeRemaining)
                }
                
                if chars.interlock1 || chars.interlock2 {
                    currentStatus.insert(.interlockActive)
                }
                
                if chars.damper == .operating {
                    currentStatus.insert(.damperOperating)
                }
                self.fanStatus = currentStatus
            })
            .store(in: &bag)
    }
}

extension FanModel {
    convenience init () {
        print("Test fan model init")
        self.init(usingChars: FanCharacteristics())
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
            "Inside Temp" : insideTemp.map { "\($0)˚" } ?? "Not reported",
            "Attic Temp" : atticTemp.map { "\($0)˚" } ?? "Not reported",
            "Outside Temp" : outsideTemp.map { "\($0)˚" } ?? "Not reported",
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
        macAddr = try container.decode(String.self, forKey: .macaddr)
        airspaceFanModel = try container.decode(String.self, forKey: .model)
        do {
            ipAddr = try container.decode(String.self, forKey: .ipaddr)
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
        insideTemp = insideTempStr.map { Int($0) } ?? nil
        atticTemp = atticTempStr.map { Int($0) } ?? nil
        outsideTemp = outsideTempStr.map { Int($0) } ?? nil
        setpoint = setpointStr.map { Int($0) } ?? nil
    }
    
    init? (data: Data) {
        guard let tupleSource = String(data: data, encoding: .ascii) else { return nil }
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
        guard let chars = try? decoder.decode(FanCharacteristics.self, from: s.jsonData) else { return nil }
        self = chars
    }
    
    init () {
        speed = 0
        macAddr = UUID.init().uuidString.appending("BEEF")
        airspaceFanModel = "Whole House Fan"
        ipAddr = UUID.init().uuidString
    }
}

struct FanStatusLoader {
    typealias OutputPublisher = AnyPublisher<FanCharacteristics, ConnectionError>
    private var ip: String

    init (addr ip: String) {
        self.ip = ip
    }

    func loadResultsAsync (action: FanModel.Action) async throws -> FanCharacteristics {
        guard let url = URL(string: "http://\(ip)/fanspd.cgi?dir=\(action.rawValue)") else {
            throw ConnectionError.badUrl
        }
        let decoder = JSONDecoder()
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
        
        return try decoder.decode(FanCharacteristics.self, from:
            (String(data: data, encoding: .ascii) ?? "")
            .trimmingCharacters(in: .whitespaces)
            .split(separator: "<")
            .filter({ !$0.contains("/") && $0.contains(">") })
            .map ({ $0.split(separator: ">", maxSplits: 1) })
            .map ({ arr -> (String, String?) in
                let newTuple = (String(arr[0]), arr.count == 2 ? String(arr[1]) : nil)
                return newTuple
            })
            .jsonData
        )
    }
    
    func loadResultsPublished (action: FanModel.Action) throws -> AnyPublisher<FanCharacteristics, ConnectionError> {
        guard let url = URL(string: "http://\(ip)/fanspd.cgi?dir=\(action.rawValue)") else {
            throw ConnectionError.badUrl
        }
        let decoder = JSONDecoder()
        let config = URLSession.shared.configuration
        config.timeoutIntervalForRequest = 10
        let session = URLSession.init(configuration: config)
        return session
            .dataTaskPublisher(for: url)
            .tryMap { (data, response) -> FanCharacteristics in
                guard let r = (response as? HTTPURLResponse) else {
                    throw ConnectionError.serverError("Server error: could not interpret server response.")
                }
                guard (200..<300).contains(r.statusCode) else {
                    throw ConnectionError.serverError("Server error, code \(r.statusCode)")
                }
                return try decoder.decode(FanCharacteristics.self, from:
                                            (String(data: data, encoding: .ascii) ?? "")
                                            .trimmingCharacters(in: .whitespaces)
                                            .split(separator: "<")
                                            .filter({ !$0.contains("/") && $0.contains(">") })
                                            .map ({ $0.split(separator: ">", maxSplits: 1) })
                                            .map ({ arr -> (String, String?) in
                    let newTuple = (String(arr[0]), arr.count == 2 ? String(arr[1]) : nil)
                    return newTuple
                }).jsonData )
            }
            .mapError {
                ($0 as? ConnectionError) ?? ConnectionError.cast($0)
            }
            .eraseToAnyPublisher()
    }
}

final class Motor: MotorDelegate {
                        
                        enum Context { case adjusting, standby, fault }
    private var ipAddr: String
    private var context: Context = .standby
    
    required init (atAddr addr: String) {
        ipAddr = addr
    }

    func setSpeedAsync(to target: Int) -> AsyncThrowingStream<FanCharacteristics, Error> {
        context = .adjusting
        let getter = FanStatusLoader(addr: ipAddr)
        return AsyncThrowingStream<FanCharacteristics, Error> { continuation in
            Task {
                var chars: FanCharacteristics
                chars = try await getter.loadResultsAsync(action: .refresh) //get chars to start
                continuation.yield(chars) //send chars back to fan model
                guard chars.speed != target else { continuation.finish(); return } // preliminary check to see if we're already at target
                for _ in (0..<12) { //try 12 times to reach target
                    defer { context = .standby }
                    var preAdjustSpeed = chars.speed // take note of speed before adjustment
                    chars = try await getter.loadResultsAsync(action: target == 0 ? .off : target > chars.speed ? .faster : .slower) //make a speed adjustment
                    continuation.yield(chars) //send new chars to fan model
                    guard chars.speed != target else { continuation.finish(); return } //finish if we hit the target speed
                    for _ in (0..<3) { //loop to wait when fan is unresponsive. Will send .refresh at 3 second intervals and see if the fan speed changes. If it does, break out of the loop. If not, try again for up to 3 times.
                        guard preAdjustSpeed == chars.speed else { break } //check if fan is responsive. If so, break out of the unresponsive wait look
                        try await Task.sleep(nanoseconds: UInt64(3.0 * 1_000_000_000)) //wait for 3 seconds
                        preAdjustSpeed = chars.speed // take note of the speed before getting a refresh. Note we should have a pending adjustment at this point.
                        chars = try await getter.loadResultsAsync(action: .refresh) //check the chars
                        continuation.yield(chars) // send new chars to model
                    } //end unresponsive loop
                    try await Task.sleep(nanoseconds: UInt64(1.0 * 1_000_000_000)) //wait between adjustment attempts to avoid swamping the fan.
                } //end of adjust loop
                continuation.finish(throwing: AdjustmentError.fanNotResponsive) //if successful, function will exit out of the function. If not, we will hit this statement after 12 tries.
            }
        }
    }
    
}

final class FanTimer: TimerDelegate {
    enum Context { case adjusting, standby, fault }
    private var ipAddr: String
    private var context: Context = .standby

    required init (atAddr addr: String) {
        ipAddr = addr
    }
    
    func setTimerAsync (to target: Int) -> AsyncThrowingStream<FanCharacteristics, Error> {
        context = .adjusting
        let getter = FanStatusLoader(addr: ipAddr)
        return AsyncThrowingStream<FanCharacteristics, Error> { continuation in
            Task {
                var chars: FanCharacteristics
                chars = try await getter.loadResultsAsync(action: .refresh)
                continuation.yield(chars)
                guard chars.timer < target else { continuation.finish(); return }
                for _ in (0..<17) {
                    defer { context = .standby }
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
//    var refresh: AsyncThrowingStream<FanCharacteristics, Error> { get }
    func setSpeedAsync (to: Int) -> AsyncThrowingStream<FanCharacteristics, Error>
    init(atAddr: String)
}

protocol TimerDelegate {
    func setTimerAsync (to: Int) -> AsyncThrowingStream<FanCharacteristics, Error>
    init(atAddr: String)
}
