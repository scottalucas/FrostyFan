//
//  Network resources.swift
//  whf001
//
//  Created by Scott Lucas on 12/9/20.
//

import Foundation
import Combine

class FanConnection: ObservableObject {
    private var ipAddress: String
    private var characteristics = CurrentValueSubject<Dictionary<String, String?>, Never>([:])
    @Published var characteristicsPublisher: AnyPublisher<Dictionary<String, String?>, Never>
    var lastConnectionError: ConnectionError?
    private var bag = Set<AnyCancellable>()
    static var requiredKeys: Set<String> = ["fanspd", "doorinprocess", "timeremaining", "macaddr", "ipaddr", "model", "softver", "interlock1", "interlock2", "cfm", "power" , "house_temp", "attic_temp", "DIPS", "switch2"]
    
    enum ConnectionError: Error {
        case badUrl
        case networkError (String)
        case serverError (Int)
        case decodeError (String)
        case unknown (String)
    }
    
    init (address ipAddress: String = "192.168.1.122") {
        self.ipAddress = ipAddress
        characteristicsPublisher = characteristics.eraseToAnyPublisher()
    }
    
    func update(action: Int? = nil) {
        print("connecting for update to \(ipAddress)")
        let actionStr = action == nil ? "" : "?dir=\(action!)"
        guard let url = URL(string: "http://\(ipAddress)/fanspd.cgi\(actionStr)") else {
            lastConnectionError = .badUrl
            characteristics.send([:])
            return
        }
        
        URLSession.shared
            .dataTaskPublisher(for: url)
            .sink(
                receiveCompletion: { [weak self] comp in
                    if case .failure(let err) = comp {
                        self?.lastConnectionError = .networkError(err.localizedDescription)
                        self?.characteristics.send([:])
                    }
                },
                receiveValue:
                    { [weak self] data, resp in
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
                            self?.characteristics.send(newDict)
                            self?.lastConnectionError = nil
                        } catch let error as ConnectionError {
                            self?.lastConnectionError = error
                            self?.characteristics.send([:])
                        } catch {
                            self?.lastConnectionError = .unknown(error.localizedDescription)
                            self?.characteristics.send([:])
                        }
                    }
            )
            .store(in: &bag)
    }
}
