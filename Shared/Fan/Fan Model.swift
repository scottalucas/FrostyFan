//
//  Fan Model.swift
//  whf001
//
//  Created by Scott Lucas on 12/9/20.
//

import Foundation
import Combine
import SwiftUI

enum FanValue : String {
    case speed = "fanspd", model = "model", swVersion = "softver", damper = "doorinprocess", timer = "timeremaining", macAddr = "macaddr", interlock1 = "interlock1", interlock2 = "interlock2", cfm = "cfm", power = "power", houseTemp = "house_temp", atticTemp = "attic_temp", DIPSwitch = "DIPS", remoteSwitch = "switch2"
    
    static func getValue(forKey key: FanValue, fromTable table: [String : String?]) -> String? {
        return table[key.rawValue] ?? nil
    }
    
    static var requiredKeys: Set<String> = ["fanspd", "doorinprocess", "timeremaining", "macaddr", "ipaddr", "model", "softver", "interlock1", "interlock2", "cfm", "power" , "house_temp", "attic_temp", "DIPS", "switch2"]
}


class FanModel: ObservableObject {
    @ObservedObject var connection = FanConnection()
//    private var characteristics = Dictionary<String, String>()
    var ipAddr: String
    @Published var chars : Dictionary<String, String?> = [:]
//    @Published var speed: Int?
//    @Published var model: String?
//    @Published var swVersion: String?
//    @Published var availableLevels: Int?
//    @Published var opening: Bool?
//    @Published var timerRemaining: Int?
//    @Published var macAddr: String?
//    @Published var interlock1: Bool?
//    @Published var interlock2: Bool?
//    @Published var cfm: Int?
//    @Published var power: Int?
//    @Published var houseTemp: Int?
//    @Published var atticTemp: Int?
//    @Published var serverResponse: String?
//    @Published var dipSwitches: String?
//    @Published var remoteSwitch: String?
//    var speedAdjustPublisher = PassthroughSubject<Int, FanConnection.ConnectionError>()
//    private var characteristicsRetriever: Future<Dictionary<String,String?>, FanConnection.ConnectionError>
//    private var characteristicsPublisher = CurrentValueSubject<Dictionary<String, String?>, Never>([:])
    private var bag = Set<AnyCancellable>()
//    @Published var setpoint: Int?
    
    init(forAddress address: String) {
        connection = FanConnection(address: address)
        ipAddr = address
//        characteristicsRetriever = FanConnection.updateFuture(ipAddr: address)
//        startSubscribers()
        update()
    }
    
    func adjustFan (action: Action? = nil) -> AnyPublisher<Dictionary<String, String?>, ConnectionError> {
        func fail(withError: Error) -> AnyPublisher<Dictionary<String, String?>, ConnectionError> {
            let err: ConnectionError = withError as? ConnectionError ?? .unknown(withError.localizedDescription)
            return Fail<Dictionary<String, String?>, ConnectionError>.init(error: err).eraseToAnyPublisher()
        }
        
        guard var u = URL(string: "http://\(ipAddr)") else {
            return fail(withError: ConnectionError.badUrl)
        }
        u.appendPathComponent(action == nil ? "/fanspd.cgi" : "/fanspd.cgi?dir=\(action!.rawValue)")
        guard let urlStr = u.absoluteString.removingPercentEncoding, let url = URL(string: urlStr) else { return fail(withError: ConnectionError.badUrl) }
        
        return URLSession.shared
            .dataTaskPublisher(for: url)
//            .print("\(self.ipAddr)")
            .mapError { ConnectionError.networkError($0.localizedDescription) }
//            .flatMap { (data, resp) in
            .flatMap { (data, resp) -> AnyPublisher<Dictionary<String, String?>, FanModel.ConnectionError> in
                do {
                    guard let resp = resp as? HTTPURLResponse else {
                        throw ConnectionError.networkError("Unknown error")
                    }
                    guard (200..<300).contains(resp.statusCode) else {
                        throw ConnectionError.networkError("Bad status code: \(resp.statusCode)")
                    }
                    guard let decodedData = String(data: data, encoding: .ascii) else {
                        throw ConnectionError.decodeError("Failed to convert data to text, data length: \(data.count)")
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
                    
                    guard FanConnection.requiredKeys.isSubset(of: Set( newDict.keys.map({ String($0) }) )) else {
                            throw ConnectionError.decodeError("Missing required fan parameters")
                            }
                    
                    return Just(newDict)
                        .setFailureType(to: ConnectionError.self)
                        .eraseToAnyPublisher()
                    
                } catch let error as ConnectionError {
                    return Fail (outputType: Dictionary<String, String?>.self, failure: error).eraseToAnyPublisher()
                } catch {
                    return Fail (outputType: Dictionary<String, String?>.self, failure: ConnectionError.unknown(error.localizedDescription)).eraseToAnyPublisher()
                }
            }
            .eraseToAnyPublisher()
    }
    
    func update(_ msg: Action? = nil) {
        adjustFan()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: {[weak self] dict in
                self?.chars = dict
            })
            .store(in: &bag)
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
    enum ConnectionError: Error {
        case badUrl
        case networkError (String)
        case serverError (Int)
        case decodeError (String)
        case unknown (String)
    }
}

extension FanModel {
//    func startSubscribers () {
//        characteristicsPublisher
//            .map({ [weak self] dict in
//                guard let s = dict["fanspd"], let s2 = s, let spd = Int(s2) else { return nil }
////                self?.speedAdjustPublisher.send(spd)
//                return spd
//            })
//            .receive(on: DispatchQueue.main)
//            .assign(to: &$speed)
//
//        characteristicsPublisher
//            .map({ dict in
//                guard let optStringRemaining = dict["timeremaining"], let stringRemaining = optStringRemaining, let remaining = Int(stringRemaining) else { return nil }
//                return remaining
//            })
//            .receive(on: DispatchQueue.main)
//            .assign(to: &$timerRemaining)
//
//        characteristicsPublisher
//            .map({ dict in
//                dict["macaddr"] ?? nil
//            })
//            .receive(on: DispatchQueue.main)
//            .assign(to: &$macAddr)
//
//        characteristicsPublisher
//            .map({ dict in
//                guard let inProcess = dict["doorinprocess"] else { return nil }
//                return inProcess == "1" ? true : false
//            })
//            .receive(on: DispatchQueue.main)
//            .assign(to: &$opening)
//
//        characteristicsPublisher
//            .map({ dict in
//                dict["model"] ?? nil
//            })
//            .receive(on: DispatchQueue.main)
//            .assign(to: &$model)
//
//        characteristicsPublisher
//            .map({ dict in
//                dict["softver"] ?? nil
//            })
//            .receive(on: DispatchQueue.main)
//            .assign(to: &$swVersion)
//
//        characteristicsPublisher
//            .map({ dict in
//                guard let interlock1Str = dict["interlock1"] else { return nil }
//                return interlock1Str == "0" ? false : true
//            })
//            .receive(on: DispatchQueue.main)
//            .assign(to: &$interlock1)
//
//        characteristicsPublisher
//            .map({ dict in
//                guard let interlock2Str = dict["interlock2"] else { return nil }
//                return interlock2Str == "0" ? false : true
//            })
//            .receive(on: DispatchQueue.main)
//            .assign(to: &$interlock2)
//
//        characteristicsPublisher
//            .map({ dict in
//                guard let s = dict["cfm"], let s2 = s, let cfm = Int(s2) else { return nil }
//                return cfm
//            })
//            .receive(on: DispatchQueue.main)
//            .assign(to: &$cfm)
//
//        characteristicsPublisher
//            .map({ dict in
//                guard let s = dict["power"], let s2 = s, let power = Int(s2) else { return nil }
//                return power
//            })
//            .receive(on: DispatchQueue.main)
//            .assign(to: &$power)
//
//        characteristicsPublisher
//            .map({ dict in
//                guard let s = dict["house_temp"], let s2 = s, let hTemp = Int(s2) else { return nil }
//                return hTemp
//            })
//            .receive(on: DispatchQueue.main)
//            .assign(to: &$houseTemp)
//
//
//        characteristicsPublisher
//            .map({ dict in
//                guard let s = dict["attic_temp"], let s2 = s, let aTemp = Int(s2) else { return nil }
//                return aTemp
//            })
//            .receive(on: DispatchQueue.main)
//            .assign(to: &$atticTemp)
//
//        characteristicsPublisher
//            .map({ dict in
//                dict["DIPS"] ?? nil
//            })
//            .receive(on: DispatchQueue.main)
//            .assign(to: &$dipSwitches)
//
//        characteristicsPublisher
//            .map({ dict in
//                dict["switch2"] ?? nil
//            })
//            .receive(on: DispatchQueue.main)
//            .assign(to: &$remoteSwitch)
//    }
}
