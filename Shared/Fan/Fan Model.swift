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
    @EnvironmentObject var house: House
    @Published var motor: Motor?
    @Published var fanCharacteristics: FanCharacteristics?
    @Published var commError: ConnectionError?
    @Published var fanLamps = FanLamps()
    private var bag = Set<AnyCancellable>()
    
    init(forAddress address: String, usingChars chars: FanCharacteristics? = nil) {
        ipAddr = address
        motor = Motor(fan: self)
        if let c = chars {
            fanCharacteristics = c
        } else {
            getFanStatus(sendingCommand: .refresh)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { [weak self] comp in
                    if case .failure(let err) = comp {
                        print("Error \(err), removing fan from house.")
                        if let myFanFromHouse = self?.house.fans.first(where: { chars in chars.ipAddr == self!.ipAddr }) {
                            self!.house.fans.remove(myFanFromHouse)
                        }
                    }
                }, receiveValue: { [weak self] chars in
                    self?.fanCharacteristics = chars
                })
                .store(in: &bag)
        }
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
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] chars in
                self?.fanCharacteristics = chars
            })
            .store(in: &bag)
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
    fileprivate func getFanStatus(sendingCommand command: FanModel.Action) -> Future<FanCharacteristics, ConnectionError> {
        return Future<FanCharacteristics, ConnectionError> { promise in
            FanStatusLoader(addr: self.ipAddr)
                .loadResults(action: command)
                .sink(receiveCompletion: { comp in
                    if case .failure (let err) = comp {
                        promise(.failure(err))
                    }
                }, receiveValue: { chars in
                    promise(.success(chars))
                })
                .store(in: &self.bag)
        }
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
    typealias OutputPublisher = AnyPublisher<FanCharacteristics, ConnectionError>
    private var ip: String

    init (addr ip: String) {
        self.ip = ip
    }

    func loadResults (action: FanModel.Action) -> OutputPublisher {
        guard let url = URL(string: "http://\(ip)/fanspd.cgi?dir=\(action.rawValue)") else { return Fail.init(error: .badUrl).eraseToAnyPublisher() }
        let decoder = JSONDecoder()
        let session = URLSession.shared
        return session.dataTaskPublisher(for: url)
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
    enum Context { case adjust, standby }
    private var fan: FanModel
    private var context: Context {
        didSet {
            switch context {
                case .standby:
                    adjusterBag.forEach { $0.cancel() }
                    adjusterBag.removeAll()
                    watchdogTimer.cancel()
                    refreshTimer = Timer
                        .publish(every: 300.0, on: .main, in: .common)
                        .autoconnect()
                        .sink(receiveValue: { [weak self] _ in
                            self?.fan.refreshFan()
                        })
                case .adjust:
                    refreshTimer.cancel()
            }
        }
    }
    private var lastSpeed: Int?
    private var lastTimer: Int?
    private var adjusterBag = Set<AnyCancellable>()
    private var refreshTimer = AnyCancellable({ })
    private var watchdogTimer = AnyCancellable({ })
    private var loaderEmitter = PassthroughSubject<FanStatusLoader.OutputPublisher, Never>()
    private var fanLoader: FanStatusLoader
    
    init (fan: FanModel) {
        self.fan = fan
        fanLoader = FanStatusLoader(addr: fan.ipAddr)
        context = .standby
    }

    func setSpeed(to target: Int) -> Future<(), AdjustmentError> {
        context = .adjust
        let initialSpeed = fan.fanCharacteristics?.speed
        return Future<(), AdjustmentError> { [fanLoader, initialSpeed] promise in
            guard let initialSpeed = initialSpeed else {
                promise(.failure(.notReady("No initial fan speed")))
                return
            }

            self.watchdogTimer =
            Timer.publish(every: 120, on: .main, in: .common)
                .sink(receiveValue: { [weak self] _ in
                    self?.context = .standby
                    promise(.failure(.fanNotResponsive))
                })
            
            var maxRefreshTries = 6 {
                didSet {
                    if maxRefreshTries == 0 {
                        self.context = .standby
                        promise(.failure(AdjustmentError.speedDidNotChange))
                    }
                }
            }

            func getDirection(forSpeed spd: Int) -> FanModel.Action {
                if target == 0 { return .off }
                switch target - spd {
                    case let result where result > 0:
                        return .faster
                    case let result where result < 0:
                        return .slower
                    default:
                        return .refresh
                }
            }

            self.loaderEmitter
                .flatMap { $0 }
                .mapError({ AdjustmentError.cast($0) })
                .timeout(3.5, scheduler: DispatchQueue.global(), customError: { .notAtTarget })
                .sink(receiveCompletion: { [weak self] comp in
                    self?.context = .standby
                    if case .failure(let err) = comp {
                        print ("Adjust failed \(err)")
                        promise(.failure(err))
                    } else {
                        print("Adjustment complete")
                    }
                }, receiveValue: { [weak self] chars in
                    guard let self = self else { return }
                    self.fan.fanCharacteristics = chars
                    defer { self.lastSpeed = chars.speed }
                    if chars.speed == target { // finished
                        print("speed eq target")
                        promise(.success(()))
                        self.context = .standby
                        return
                    }
                    let responsive = chars.speed != self.lastSpeed
                    let delay = responsive ? 0.5 : 2.0
                    if !responsive { maxRefreshTries -= 1 }
                    let dir:FanModel.Action = responsive ? getDirection(forSpeed: chars.speed) : .refresh
                    self.loaderEmitter.send(
                        Just((delay, dir))
                            .flatMap( { (delay, dir) in
                                Just(dir)
                                    .delay(for: .seconds(delay), scheduler: DispatchQueue.global())
                            } )
                            .flatMap { dir in
                                fanLoader.loadResults(action: dir)
                            }
                            .eraseToAnyPublisher()
                    )
                })
                .store(in: &self.adjusterBag)
            
            self.loaderEmitter.send(fanLoader.loadResults(action: getDirection(forSpeed: initialSpeed)).eraseToAnyPublisher())
        }
    }
    
    func setTimer(to target: Int) -> Future<(), AdjustmentError> {
        context = .adjust
        return Future<(), AdjustmentError> { [fanLoader] promise in
            
            self.watchdogTimer =
            Timer.publish(every: 120, on: .main, in: .common)
                .sink(receiveValue: { [weak self] _ in
                    self?.context = .standby
                    promise(.failure(.fanNotResponsive))
                })
            
            var maxRefreshTries = 6 {
                didSet {
                    if maxRefreshTries == 0 {
                        self.context = .standby
                        promise(.failure(AdjustmentError.timerDidNotChange))
                    }
                }
            }
            
            self.loaderEmitter
                .flatMap { $0 }
                .mapError({ AdjustmentError.cast($0) })
                .timeout(3.5, scheduler: DispatchQueue.global(), customError: { .notAtTarget })
                .sink(receiveCompletion: { [weak self] comp in
                    self?.context = .standby
                    if case .failure(let err) = comp {
                        print ("Adjust failed \(err)")
                        promise(.failure(err))
                    } else {
                        print("Adjustment complete")
                    }
                }, receiveValue: { [weak self] chars in
                    guard let self = self else { return }
                    self.fan.fanCharacteristics = chars
                    defer { self.lastTimer = chars.timer }
                    if chars.timer >= target { // finished
                        print("speed eq target")
                        promise(.success(()))
                        self.context = .standby
                        return
                    }
                    let responsive = self.lastTimer.map { !(($0 - 2)...($0 + 2)).contains(chars.timer) } ?? true
                    if !responsive { maxRefreshTries -= 1 }
                    let delay = responsive ? 0.5 : 2.0
                    let dir:FanModel.Action = responsive ? .timer : .refresh
                    self.loaderEmitter.send(
                        Just((delay, dir))
                            .flatMap( { (delay, dir) in
                                Just(dir)
                                    .delay(for: .seconds(delay), scheduler: DispatchQueue.global())
                            } )
                            .flatMap { dir in
                                fanLoader.loadResults(action: dir)
                            }
                            .eraseToAnyPublisher()
                    )
                })
                .store(in: &self.adjusterBag)
            
            self.loaderEmitter.send(fanLoader.loadResults(action: .timer).eraseToAnyPublisher())
        }
//            self.timerWatchdog
//                .subscribe(on: DispatchQueue.global())
//                .collect(.byTimeOrCount(DispatchQueue.global(), .seconds(7.5), 5))
//                .timeout(.seconds(8), scheduler: DispatchQueue.global(), customError: { .notReady("Timed out") })
//                .tryMap { changeTrackerArr in
//                    guard changeTrackerArr.contains(true) else {
//                        throw AdjustmentError.timerDidNotChange
//                    }
//                }
//                .mapError { $0 as? AdjustmentError ?? AdjustmentError.cast($0) }
//                .sink (receiveCompletion: { [weak self] comp in
//                    self?.lastTimer = nil
//                    self?.adjusterBag.removeAll()
//                    self?.startRefresher()
//                    if case .failure (let err) = comp {
//                        promise(.failure(err))
//                    } else {
//                        promise(.success(()))
//                    }
//                }, receiveValue: { _ in })
//                .store(in: &self.adjusterBag)
//
//            self.fan.$fanCharacteristics
//                .subscribe(on: DispatchQueue.global())
//                .compactMap { $0?.timer }
//                .print("in timer adjust")
//                .map { [weak self] currentTimer -> AnyPublisher<FanModel.Action, Never> in
//                    guard let self = self else {
//                        return Empty.init(completeImmediately: true, outputType: FanModel.Action.self, failureType: Never.self).eraseToAnyPublisher()
//                    }
//                    defer { self.lastTimer = currentTimer }
//                    let timerDidChange = self.lastTimer.map { lastTime in
//                        let timeRange = (lastTime - 2)...(lastTime + 2)
//                        return !timeRange.contains(currentTimer) } ?? false
//
//                    self.timerWatchdog.send(timerDidChange)
//
//                    switch () {
//                        case _ where target <= currentTimer: //finished
//                            self.timerWatchdog.send(completion: .finished)
//                            return Empty.init(completeImmediately: true, outputType: FanModel.Action.self, failureType: Never.self).eraseToAnyPublisher()
//                        default: //adjust
//                            return Just ( .timer ).delay(for: .seconds(!timerDidChange ? 3.0 : 1.0), scheduler: DispatchQueue.global()).eraseToAnyPublisher()
//                    }
//                }
//                .switchToLatest()
//                .sink (
//                    receiveValue: { [weak self] action in
//                        self?.fan.getFanStatus(sendingCommand: action)
//                    })
//                .store(in: &self.adjusterBag)
//        }
    }
}

