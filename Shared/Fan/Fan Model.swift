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

    private var bag = Set<AnyCancellable>()
//    @Published var setpoint: Int?
    
    init(forAddress address: String) {
        connection = FanConnection(address: address)
        ipAddr = address
        update()
    }
    
    func testAdjustFan (action: Action? = nil) -> AnyPublisher<Dictionary<String, String?>, ConnectionError> {
        return Just(["fanspd":"4", "model":"3.5e"]).eraseToAnyPublisher().setFailureType(to: ConnectionError.self).eraseToAnyPublisher()
    }
    
    func adjustFan (action: Action? = nil) -> AnyPublisher<Dictionary<String, String?>, ConnectionError> {
        typealias Output = Dictionary<String, String?>
        typealias Error = ConnectionError
        
        guard var u = URL(string: "http://\(ipAddr)") else {
            return ConnectionError.badUrl.publisher(valueType: Output.self)
        }
        u.appendPathComponent(action == nil ? "/fanspd.cgi" : "/fanspd.cgi?dir=\(action!.rawValue)")
        guard let urlStr = u.absoluteString.removingPercentEncoding, let url = URL(string: urlStr) else { return ConnectionError.badUrl.publisher(valueType: Output.self) }
        
        return URLSession.shared
            .dataTaskPublisher(for: url)
//            .print("\(self.ipAddr)")
            .mapError { ConnectionError.networkError($0.localizedDescription) }
//            .flatMap { (data, resp) in
            .flatMap { (data, resp) -> AnyPublisher<Output, Error> in
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
                    return error.publisher(valueType: Output.self)
                } catch {
                    return ConnectionError.cast(error).publisher(valueType: Output.self)
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
    

}
