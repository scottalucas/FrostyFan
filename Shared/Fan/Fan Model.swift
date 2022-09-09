//
//  Fan Model.swift
//  whf001
//
//  Created by Scott Lucas on 12/9/20.
//
/*
 Handles characteristics related to the fan. There are two controllable elements on the fan: the fan speed (controlled with the MotorDelegate) and the timer (controlled with the TimerDelegate).
 
 Communication with the fan takes place via the manufacturer's API, which does not conform to the JSON standard. The API returns all fan parameters at once. Later in this file there's a custom decoder that processes information returned by the API and creates a FanCharacteristics structure.
 
 Combine publishers handle updates from the fan since they are asynchronous. The fanCharacteristics publisher emits a new value whenever the fan responds with an update.
 
 If fan communication fails, the fan sets the invalidFan flag, which prevents any further adjustment attempts.
 
 motorContext and timerContext provide status for these two adjustable fan parameters. They're used by the view to communicate status to the user.
 */

import Foundation
import Combine
import SwiftUI

struct FanModel {
    var fanCharacteristics: AnyPublisher<FanCharacteristics, Never>
    var motorContext = CurrentValueSubject<Motor.Context, Never>(.standby)
    var timerContext = CurrentValueSubject<FanTimer.Context, Never>(.standby)
    private var motor: MotorDelegate!
    private var timer: TimerDelegate!
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var ipAddr: String
    private var _fanCharacteristics: CurrentValueSubject<FanCharacteristics, Never>
    private var invalidFan: Bool {
        _fanCharacteristics.value.ipAddr == "INVALID"
    }
    
    init(usingChars chars: FanCharacteristics) {
        motor = Motor(atAddr: chars.ipAddr)
        timer = FanTimer(atAddr: chars.ipAddr)
        ipAddr = chars.ipAddr
        _fanCharacteristics = CurrentValueSubject<FanCharacteristics, Never>.init(chars)
        fanCharacteristics = _fanCharacteristics.share().eraseToAnyPublisher()
        Log.fan(id).info("model init")
    }
    
    func setFan(toSpeed finalTarget: Int) async {
        guard !invalidFan else { return }
        Log.fan(id).info("\(_fanCharacteristics.value.macAddr) Set speed to \(finalTarget)")
        motorContext.send(.adjusting)
        do {
            for try await char in motor.setSpeedAsync(to: finalTarget) {
                guard !Task.isCancelled else { return }
                _fanCharacteristics.send(char)
            }
            Log.fan(id).info("Fan speed adjust successful")
            motorContext.send(.standby)
        } catch {
            motorContext.send(.fault)
            Log.fan(id).error("error setting speed \(error.localizedDescription)")
        }
    }
    
    func setFan(addHours hours: Int) async {
        guard !invalidFan else { return }
        Log.fan(id).info("Increase timer by \(hours)")
        guard hours > 0 else {
            timerContext.send(.fault)
            return
        }
        timerContext.send(.adjusting)
        let current = _fanCharacteristics.value.timer
        let target = min (current + hours * 60, 12 * 60) - 10
        do {
            for try await char in timer.setTimerAsync(to: target) {
                guard !Task.isCancelled else { return }
                _fanCharacteristics.send(char)
            }
            Log.fan(id).info("Fan timer adjust successful")
            timerContext.send(.standby)
        } catch {
            timerContext.send(.fault)
            Log.fan(id).error("error setting timer \(error.localizedDescription)")
        }
    }
    
    @discardableResult func refresh() async -> FanCharacteristics? {
        guard !invalidFan else { return nil }
        Log.fan(id).info("refresh")
        let newChars = try? await motor.refresh()
        guard !Task.isCancelled else { return nil }
        guard let chars = newChars else { return nil}
        _fanCharacteristics.send(chars)
        return chars
    }
}

extension FanModel {
    init () {
        self.init(usingChars: FanCharacteristics())
        Log.fan(id).info("Initialized generic FanModel")
    }
}

extension FanModel: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(_fanCharacteristics.value.macAddr)
    }
    
    static func ==(lhs: FanModel, rhs: FanModel) -> Bool {
        return lhs._fanCharacteristics.value.macAddr == rhs._fanCharacteristics.value.macAddr
    }
}

extension FanModel: Identifiable {
    var id: String {
        _fanCharacteristics.value.macAddr
    }
}

extension FanModel {
    enum Action: Int {
        case refresh = 0
        case faster = 1
        case timer = 2
        case slower = 3
        case off = 4
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
    var labelValueDictionary: [String: (value: String, alarm: Bool)] { //used by the Detail view.
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
            "Speed" : (String(speed), false),
            "Timer" : (String(timer), false),
            "Damper" : (damper == .operating ? "Opening" : "Not operating", damper == .operating),
            "Interlock 1" : (interlock1 ? "Active" : "Not active", interlock1),
            "Interlock 2" : (interlock2 ? "Active" : "Not active", interlock2),
            "MAC Address" : (macAddr, false),
            "Model" : (airspaceFanModel, false),
            "IP Address" : (ipAddr, false),
            "Airflow": (cubicFeetPerMinute.map { "\($0) cfm" } ?? "Not reported", false),
            "Software version" : (softwareVersion ?? "Not reported", false),
            "DNS" : (dns ?? "Not reported", false),
            "DIP Switch" : (dipSwitch ?? "Not reported", false),
            "Remote Switch" : (remoteSwitch ?? "Not reported", false),
            "Power" : (power.map { String($0) } ?? "Not reported", false),
            "Inside Temp" : (iT, false),
            "Attic Temp" : (aT, false),
            "Outside Temp" : (oT, false),
            "Setpoint" : (setpoint.map { String($0) } ?? "Not reported", false)
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
    
    init (data: Data?) throws { //since the API isn't JSON decodable, this initializer converts fan API data to JSON decodable data, then uses the custom decoder defined above.
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
        ipAddr = "INVALID"
    }
}

extension FanCharacteristics: Identifiable {
    var id: MACAddr { macAddr }
}

struct FanStatusLoader { //this is the structure used to make a network call to the fan.
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
}

/*
 This app adjusts the fan speed and a fan timer that will shut the fan off after a pre-set interval. Both the speed and timer are controlled by the fan. The API interface for these two parameters is crude and models physical keypresses. Users can increase/decrease the speed by one step at a time. The timer can be increased by an hour at a time, or reset to zero by turning the fan off. Possible API actions are reflected in the FanModel.Action structure.
 
 The app allows the user to select a target speed or time, and behind the scenes it performs the required "keypresses" to set the fan to the desired target. The motor and timer delegates handle the timing aspects of setting fan speed and timer values. Unfortunately, the fan API is quirky. The fan returns a status after each API call, but the reported status will lag the actual fan status. You might, for example, send a command to increase speed but the API does not reflect the new speed for several seconds. The speed and timer setting routines accomodate these issues with wait and refresh actions that ensure the fan's actual state is known before issuing additional speed up/slow down or timer increase commands.
 
 These routines use some advanced async constructs like AsyncThrowingStreams to both monitor fan status and report fan status back up to the fanCharacteristics publisher.
 */
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
                        guard preAdjustSpeed == chars.speed else { break } //check if fan is responsive. If so, break out of the unresponsive wait loop
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
    func setSpeedAsync (to: Int) -> AsyncThrowingStream<FanCharacteristics, Error>
    init(atAddr: IPAddr)
}

protocol TimerDelegate {
    func setTimerAsync (to: Int) -> AsyncThrowingStream<FanCharacteristics, Error>
    init(atAddr: IPAddr)
}
