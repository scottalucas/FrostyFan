//
//  House Model.swift
//  whf001
//
//  Created by Scott Lucas on 12/9/20.
//

import Foundation
import SwiftUI
import Combine

class House: ObservableObject {
    typealias IPAddr = String
    static let shared = House()
    @Published var fans = Set<FanCharacteristics>() //IP addresses
    @Published var status = HouseStatus()
//    @Published var scanning = false
//    var runningFans: Bool {
//        fans.filter { chars in chars.speed > 0}.count > 0 ? true : false
//    }
    private var bag = Set<AnyCancellable>()
    
    private init () {
//        scanForFans()
    }
    
    func scanForFans () {
        guard !status.contains(.scanning) else { return }
        print("start scanning")
        status.insert(.scanning)
        status.insert(.noFansAvailable)
        fans.removeAll()
        scanner
            .timeout(.seconds(15), scheduler: DispatchQueue.global())
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] comp in
                guard let self = self else { return }
                self.status.remove(.scanning)
                if case .finished = comp {
                    print ("scan complete")
                }
                if case .failure (let err) = comp {
                    print ("error: \(err)")
                }
            }, receiveValue: { [weak self] (ipAddr, chars) in
                print ("Found fan addr: \(ipAddr)")
                var modChars = chars
                modChars.ipAddr = ipAddr
                self?.fans.update(with: modChars)
                self?.status.remove(.noFansAvailable)
            })
            .store(in: &bag)
    }
}

extension House {
    var scanner: AnyPublisher<(String, FanCharacteristics), ConnectionError> {
        return
            NetworkAddress.hosts.publisher
            .prepend("192.168.1.67:8080") //testing
            .setFailureType(to: ConnectionError.self)
            .flatMap ({ addr -> AnyPublisher<(IPAddr, FanCharacteristics), ConnectionError> in
                return FanStatusLoader(addr: addr).loadResults(action: .refresh)
                    .catch({ _ in
                        Empty.init(completeImmediately: false)
                    })
                    .map { [addr] chars in (addr, chars) }
                    .eraseToAnyPublisher()
            })
            .eraseToAnyPublisher()
    }}
