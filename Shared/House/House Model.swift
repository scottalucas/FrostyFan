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
    @Published var fans = Set<FanCharacteristics>() //IP addresses
    @Published var scanning = false
    var runningFans: Bool {
        fans.filter { chars in chars.speed > 0}.count > 0 ? true : false
    }
    private var bag = Set<AnyCancellable>()
    
    init () {
//        scanForFans()
    }
    
    func scanForFans () {
        guard !scanning else { return }
        print("start scanning")
        scanning = true
        fans.removeAll()
        scanner
            .timeout(.seconds(15), scheduler: DispatchQueue.global())
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] comp in
                self?.scanning = false
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
            })
            .store(in: &bag)
    }
}

extension House {
    var scanner: AnyPublisher<(String, FanCharacteristics), ConnectionError> {
        typealias HostAddr = String
        return
            NetworkAddress.hosts.publisher
            .prepend("192.168.1.67:8080") //testing
            .setFailureType(to: ConnectionError.self)
            .flatMap ({ host -> AnyPublisher<(HostAddr, FanCharacteristics), ConnectionError> in
                guard let loader = FanStatusLoader(addr: host, action: .refresh) else { return Empty.init(completeImmediately: false).eraseToAnyPublisher() }
                return loader.loadResults
                    .catch({ _ in
                        Empty.init(completeImmediately: false)
                    })
                    .map { [host] chars in (host, chars) }
                    .eraseToAnyPublisher()
            })
            .eraseToAnyPublisher()
    }}
