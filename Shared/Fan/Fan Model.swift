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
    @Published var fanLamps = FanLamps()
    private var bag = Set<AnyCancellable>()

    init(forAddress address: String, usingChars chars: FanCharacteristics? = nil) {
        ipAddr = address
        motor = Motor(fan: self)
        chars.map { fanCharacteristics = $0 } ?? self.getFanStatus(sendingCommand: .refresh)
        print("init fan model \(ipAddr) chars \(chars == nil ? "not " : "")available")
    }
    
    func setFan(toSpeed finalTarget: Int) -> Future<(), AdjustmentError> {
        print("set speed to \(finalTarget)")
        guard let motor = motor else {
            return Future<(), AdjustmentError> { promise in promise(.failure(.parentOutOfScope))}
        }
        return motor.setSpeed(to: finalTarget)
    }
    
    func setFan(addHours hours: Int) -> Future<(), AdjustmentError> {
        guard let motor = motor else {
            return Future<(), AdjustmentError> { promise in promise(.failure(.parentOutOfScope)) }
        }
        let current = fanCharacteristics.map { $0.timer } ?? 0
        let target = min (current + hours * 60, 12 * 60) - 10
        print("timer target \(target)")
        return motor.setTimer(to: target)
    }
    
    func refreshFan () {
        getFanStatus(sendingCommand: .refresh)
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
            .subscribe(on: DispatchQueue.global())
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

class Motor {
    private var fan: FanModel
    private var lastSpeed: Int?
    private var lastTimer: Int?
//    private var setterSubscription: AnyCancellable?
    private var speedWatchdog = PassthroughSubject<Bool, AdjustmentError>()
    private var timerWatchdog = PassthroughSubject<Bool, AdjustmentError>()
    private var speedBag = Set<AnyCancellable>()
    private var timerBag = Set<AnyCancellable>()
    private var refreshTimer = AnyCancellable.init({})
    
    init (fan: FanModel) {
        self.fan = fan
        startRefreshMonitor()
    }
    
    private func startRefreshMonitor () {
        refreshTimer = Timer
            .publish(every: 300.0, on: .main, in: .common)
            .autoconnect()
            .sink(receiveValue: { [weak self] _ in
                self?.fan.getFanStatus(sendingCommand: .refresh)
            })
    }
    
    private func stopRefreshMonitor () {
        refreshTimer.cancel()
    }
    
    func setSpeed(to target: Int) -> Future<(), AdjustmentError> {
        return Future<(), AdjustmentError> { [weak self] promise in
            guard let self = self else { return }
            self.speedWatchdog = PassthroughSubject<Bool, AdjustmentError>()
            self.lastSpeed = nil
            self.stopRefreshMonitor()
            self.speedWatchdog
                .subscribe(on: DispatchQueue.global())
                .collect(.byTimeOrCount(DispatchQueue.global(), .seconds(7.5), 5))
                .timeout(.seconds(8), scheduler: DispatchQueue.global(), customError: { .notReady("Timed out") })
                .tryMap { changeTrackerArr in
                    guard changeTrackerArr.contains(false) else {
                        throw AdjustmentError.speedDidNotChange
                    }
                }
                .mapError { $0 as? AdjustmentError ?? AdjustmentError.cast($0) }
                .sink (receiveCompletion: { [weak self] comp in
                    self?.lastSpeed = nil
                    self?.speedBag.removeAll()
                    self?.startRefreshMonitor()
                    if case .failure (let err) = comp {
                        promise(.failure(err))
                    } else {
                        promise(.success(()))
                    }
                }, receiveValue: { _ in })
                .store(in: &self.speedBag)
            
            self.fan.$fanCharacteristics
                .subscribe(on: DispatchQueue.global())
                .compactMap { $0?.speed }
                .print("in speed adjust")
                .map { [weak self] currentSpeed -> AnyPublisher<FanModel.Action, Never> in
                    guard let self = self else {
                        return Empty.init(completeImmediately: true, outputType: FanModel.Action.self, failureType: Never.self).eraseToAnyPublisher()
                    }
                    defer { self.lastSpeed = currentSpeed }
                    self.speedWatchdog.send(self.lastSpeed.map { $0 == currentSpeed } ?? true)
                    switch () {
                    case _ where target == currentSpeed: //finished
                        self.speedWatchdog.send(completion: .finished)
                        return Empty.init(completeImmediately: true, outputType: FanModel.Action.self, failureType: Never.self).eraseToAnyPublisher()
                    case _ where target == 0: //turn off
                        return Just(FanModel.Action.off).eraseToAnyPublisher()
                    case _ where self.lastSpeed == nil && currentSpeed == 0: //startup
                        return Just(FanModel.Action.faster).eraseToAnyPublisher()
                    default: //adjust
                        return Just ( currentSpeed > target ? .slower : .faster).delay(for: .seconds(self.lastSpeed == currentSpeed ? 3.0 : 0.5), scheduler: DispatchQueue.global(qos: .utility)).eraseToAnyPublisher()
                    }
                }
                .switchToLatest()
                .sink (
                    receiveValue: { [weak self] action in
                        self?.fan.getFanStatus(sendingCommand: action)
                    })
                .store(in: &self.speedBag)
        }
    }

    func setTimer(to target: Int) -> Future<(), AdjustmentError> {
        return Future<(), AdjustmentError> { [weak self] promise in
            guard let self = self else { return }
            self.timerWatchdog = PassthroughSubject<Bool, AdjustmentError>()
            self.lastTimer = nil
            self.stopRefreshMonitor()
            
            self.timerWatchdog
                .subscribe(on: DispatchQueue.global())
                .collect(.byTimeOrCount(DispatchQueue.global(), .seconds(7.5), 5))
                .timeout(.seconds(8), scheduler: DispatchQueue.global(), customError: { .notReady("Timed out") })
                .tryMap { changeTrackerArr in
                    guard changeTrackerArr.contains(true) else {
                        throw AdjustmentError.timerDidNotChange
                    }
                }
                .mapError { $0 as? AdjustmentError ?? AdjustmentError.cast($0) }
                .sink (receiveCompletion: { [weak self] comp in
                    self?.lastTimer = nil
                    self?.timerBag.removeAll()
                    self?.startRefreshMonitor()
                    if case .failure (let err) = comp {
                        promise(.failure(err))
                    } else {
                        promise(.success(()))
                    }
                }, receiveValue: { _ in })
                .store(in: &self.timerBag)
            
            self.fan.$fanCharacteristics
                .subscribe(on: DispatchQueue.global())
                .compactMap { $0?.timer }
                .print("in timer adjust")
                .map { [weak self] currentTimer -> AnyPublisher<FanModel.Action, Never> in
                    guard let self = self else {
                        return Empty.init(completeImmediately: true, outputType: FanModel.Action.self, failureType: Never.self).eraseToAnyPublisher()
                    }
                    defer { self.lastTimer = currentTimer }
                    let timerDidChange = self.lastTimer.map { lastTime in
                        let timeRange = (lastTime - 2)...(lastTime + 2)
                        return !timeRange.contains(currentTimer) } ?? false
                    self.timerWatchdog.send(timerDidChange)
                    switch () {
                    case _ where target <= currentTimer: //finished
                        self.timerWatchdog.send(completion: .finished)
                        return Empty.init(completeImmediately: true, outputType: FanModel.Action.self, failureType: Never.self).eraseToAnyPublisher()
                    default: //adjust
                        return Just ( .timer ).delay(for: .seconds(!timerDidChange ? 3.0 : 1.0), scheduler: DispatchQueue.global()).eraseToAnyPublisher()
                    }
                }
                .switchToLatest()
                .sink (
                    receiveValue: { [weak self] action in
                        self?.fan.getFanStatus(sendingCommand: action)
                    })
                .store(in: &self.timerBag)
        }
    }
}

