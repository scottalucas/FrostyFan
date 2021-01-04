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
//    @Published var chars : Dictionary<String, String?> = [:]
    @Published var fanCharacteristics = FanCharacteristics()
    private let timing = PassthroughSubject<FanConnectionTimers, Never>()
    private let action = PassthroughSubject<FanModel.Action, Never>()
    private var targetSpeed: Int?
    private var targetTimer: Int?
    private var lastReportedSpeed: Int?
    private var lastReportedTimer: Int?
    private var sharedFanLoader: AnyPublisher<FanCharacteristics, ConnectionError>
    private var bag = Set<AnyCancellable>()

    
    init(forAddress address: String) {
        ipAddr = address
//        let a =
            sharedFanLoader =
            action
            .setFailureType(to: ConnectionError.self)
                .flatMap({ action -> AnyPublisher<FanCharacteristics, ConnectionError> in
                    guard let loader = FanStatusLoader(addr: address, action: action) else { return Fail(error: .badUrl).eraseToAnyPublisher()}
                    return loader.loadResults
                        .eraseToAnyPublisher()
                })
                .share()
                .eraseToAnyPublisher()

        startFanTasks()

        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
            self.action.send(.refresh)
        }
        print("init fan model \(ipAddr)")
    }
    
    private func startFanTasks () {
        
        //char loader
        sharedFanLoader
            .sink(receiveCompletion: { [weak self] comp in
                if case .failure(let err) = comp {
                    self?.fanCommFailed(withError: err)
                }
                print("Unexpected completion in characteristics listener \(comp)")
            }, receiveValue: { [weak self] chars in
                self?.fanCharacteristics = chars
            })
            .store(in: &bag)
        
        //watchdog
        sharedFanLoader
            .map { _ in "query"}
            .merge(with: Timer.publish(every: 30, on: .main, in: .common)
                    .autoconnect()
                    .setFailureType(to: ConnectionError.self)
                    .map { _ in "watchdog"}
                    .eraseToAnyPublisher())
            .collect(.byTime(DispatchQueue.main, .seconds(30)))
            .filter({ !$0.contains("query") })
            .sink(receiveCompletion: {_ in}, receiveValue: { [weak self] _ in
                self?.action.send(.refresh)
            })
            .store(in: &bag)
        
        //speed setter
        sharedFanLoader
            .print("setter target: \(self.targetSpeed)")
            .filter { [targetSpeed] _ in targetSpeed != nil }
            .map { $0.speed }
            .map { [targetSpeed] spd -> (speed: Int, target: Int) in return (spd, targetSpeed!) }
            .filter { $0.speed != $0.target }
            .map { (speed, target) -> (speed: Int, action: FanModel.Action) in speed > target ? (speed, .slower) : (speed, .faster) }
            .flatMap { [lastReportedSpeed] (speed, action) -> AnyPublisher <FanModel.Action, Never> in
                let pause = lastReportedSpeed.map { $0 == speed } ?? false ? 5 : 0.8
                return Just(action)
                    .delay(for: .seconds(pause), scheduler: DispatchQueue.main)
                    .eraseToAnyPublisher()
            }
            .sink(receiveCompletion: { comp in
//                print("2 \(comp)")
            }, receiveValue: { [weak self] action in
                self?.action.send(action)
            })
            .store(in: &bag)
    }
    
    private func fanCommFailed(withError commErr: Error) {
        House.shared.lostFan(atIp: self.ipAddr)
    }
    
    func setFan(toSpeed finalTarget: Int? = nil) {
        self.targetSpeed = finalTarget
        action.send(.refresh)
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

struct FanCharacteristics: Decodable {
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
    }
    
    init () {
        speed = 0
        macAddr = "BEEF"
        airspaceFanModel = "Whole House Fan"
    }
}

struct FanStatusLoader {
    var urlSession = URLSession.shared
    let decoder = JSONDecoder()
    let loadResults: AnyPublisher<FanCharacteristics, ConnectionError>
    init? (addr ip: String, action: FanModel.Action) {
        guard let url = URL(string: "http://\(ip)/fanspd.cgi?dir=\(action.rawValue)") else { return nil }
        loadResults = urlSession.dataTaskPublisher(for: url)
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
            .map { $0.jsonData ?? Data() }
            .decode(type: FanCharacteristics.self, decoder: decoder)
            .print("loader")
            .mapError({ err in
                ConnectionError.cast(err)
            })
            .eraseToAnyPublisher()
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
        return timing
            .removeDuplicates()
//            .print("timing \(ipAddr)")
            .map { timerType in
                timerType.publisher
            }
            .switchToLatest()
            .combineLatest(action
                            .removeDuplicates()
//                            .print("action \(ipAddr)")
                            )
            .flatMap { [weak self] (_, action) -> AnyPublisher<Dictionary<String,String?>, AdjustmentError> in
                guard let self = self else {
                    return AdjustmentError.parentOutOfScope.publisher(valueType: Dictionary<String, String?>.self) }
                return self.adjustPhysicalFan(atNetworkAddr: self.ipAddr, withCommand: action)
                    .receive(on: DispatchQueue.main)
//                    .print("post adjust \(self.ipAddr) bag count \(self.bag.count)")
                    .eraseToAnyPublisher()
//                    .flatMap({ dict in Just(dict).setFailureType(to: AdjustmentError.self).eraseToAnyPublisher() })
            }
            .eraseToAnyPublisher()
//            .print("adjust post \(ipAddr)")
            .catch({ [weak self] err -> Just<Dictionary<String, String?>> in
                self?.fanCommFailed(withError: err)
                return Just ([:])
            })
            .filter { !$0.isEmpty }
            .share()
            .eraseToAnyPublisher()
    }
    
//    private func startCharUpdater (publisher: AnyPublisher<Dictionary<String, String?>, Never>) {
//        publisher
//            .print("updater")
//            .assign(to: &$chars)
//    }
    
    private func startKeepAlive (watchingPublisher publisher: CurrentValueSubject<FanModel.Action, Never>, timeout to: Int = 30) -> AnyCancellable {
        return publisher
            .map { _ in "update" }
            .merge(with: Timer.publish(every: Double(to/2), on: .main, in: .common)
                    .autoconnect()
                    .map { _ in "heartbeat" })
            .collect(.byTime(DispatchQueue.main, .seconds(to)))
            .map { $0.filter({ val in val != "heartbeat" }).count }
            .sink(receiveCompletion: { comp in
                print("received completion in keepalive")
            }, receiveValue: { [weak self] count in
                if count == 0 {
                    print("Updating keep alive bag \(self?.bag.count)")
                    self?.action.send(.refresh)
                    self?.timing.send(.now)
                }
            })
    }
    
    private func startSpeedManager (publisher: AnyPublisher<Dictionary<String, String?>, Never>) -> AnyCancellable {
        return publisher
            .map({ dict -> Int? in
                Int(FanModel.FanKey.getValue(forKey: .speed, fromTable: dict) ?? "")
            })
            .sink(receiveCompletion: { comp in
                print("received completion in speed manager")
            }, receiveValue: { [weak self] currentSpeed in
                guard let self = self else { return }
                guard
                    let currentSpeed = currentSpeed, //fan returned a valid current speed
                    let target = self.targetSpeed, //target speed is not nil
                    target != currentSpeed //adjustments still needed
                else {
                    self.targetSpeed = nil
                    self.lastReportedSpeed = nil
                    return
                }
                defer { self.lastReportedSpeed = currentSpeed }
                
                var nextAction: FanModel.Action
                switch (target, currentSpeed) {
                case (let t, _) where t == 0:
                    nextAction = .off
                case (let t, let c) where t > c:
                    nextAction = .faster
                case (let t, let c) where t < c:
                    nextAction = .slower
                default: //shouldn't hit this
                    self.targetSpeed = nil
                    self.lastReportedSpeed = nil
                    return
                }

                // we have a target speed, target speed != current speed
                if currentSpeed == 0 { //fan starting up
                    self.action.send(nextAction)
                    self.timing.send(.slow)
                } else if currentSpeed == self.lastReportedSpeed { //unresponsive fan
                    self.action.send(nextAction)
                    self.timing.send(.slow)
                } else {
                    self.action.send(nextAction)
                    self.timing.send(.fast)
                }
            })
    }
    
    private func startTimerManager (publisher: AnyPublisher<Dictionary<String, String?>, Never>) -> AnyCancellable {
        return publisher
            .map({ dict -> Int? in
                Int(FanModel.FanKey.getValue(forKey: .timer, fromTable: dict) ?? "")
            })
            .sink(receiveCompletion: { comp in
                print("received completion in timer manager")
            }, receiveValue: { [weak self] currentTimer in
                guard
                    let self = self
                else { return }
                
                guard
                    let target = self.targetTimer,
                    let currentTimer = currentTimer,
                    currentTimer < target
                else {
                    self.targetTimer = nil
                    self.lastReportedTimer = nil
                    return
                }
                defer { self.lastReportedTimer = currentTimer }
                if currentTimer == self.lastReportedTimer { //unresponsive fan
                    self.action.send(.timer)
                    self.timing.send(.slow)
                } else {
                    self.action.send(.timer)
                    self.timing.send(.fast)
                }
            })
    }
}

extension FanModel {
    func adjustPhysicalFan(atNetworkAddr ip: String, withCommand command: FanModel.Action, retry: Bool = false) -> AnyPublisher<Dictionary<String,String?>, AdjustmentError> {
        typealias Output = Dictionary<String, String?>
        typealias Failure = AdjustmentError
        
        guard let baseUrl = URL(string: "http://\(ip)"),
              let urlStr = baseUrl.appendingPathComponent("/fanspd.cgi?dir=\(command.rawValue)").absoluteString.removingPercentEncoding,
              let finalURL = URL(string: urlStr)
        else { return AdjustmentError.upstream(ConnectionError.badUrl).publisher(valueType: Output.self) }
        
        return URLSession.shared.dataTaskPublisher(for: finalURL)
            .tryMap { (data, resp) -> Output in
                guard let resp = resp as? HTTPURLResponse else {
                    throw Failure.upstream(ConnectionError.networkError("Bad response from fan."))
                }
                guard (200..<300).contains(resp.statusCode) else {
                    throw Failure.upstream(ConnectionError.networkError("Bad status code: \(resp.statusCode)"))
                }
                guard let decodedData = String(data: data, encoding: .ascii) else {
                    throw Failure.upstream(ConnectionError.decodeError("Failed to convert data to text, data length: \(data.count)"))
                }
                let tupleArray = decodedData
                    .filter({ !$0.isWhitespace })
                    .split(separator: "<")
                    .filter({ !$0.contains("/") && $0.contains(">") })
                    .map ({ $0.split(separator: ">", maxSplits: 1) })
                    .map ({ arr -> (String, String?) in
                        let newTuple = (String(arr[0]), arr.count == 2 ? String(arr[1]) : nil)
                        return newTuple
                    })
                
                let newDict = Dictionary(tupleArray, uniquingKeysWith: { (first, _) in first })
                
                guard FanModel.FanKey.requiredKeys.isSubset(of: Set( newDict.keys.map({ String($0) }) )) else {
                    throw Failure.missingKeys
                }
                
                return newDict
            }
            .retry(retry ? 3 : 0)
            .mapError { $0 as? Failure ?? Failure.cast($0) }
            .eraseToAnyPublisher()
    }
}
