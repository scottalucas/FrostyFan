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
    static let shared = House.init()
    @Published var fansAt = Set<String>() //IP addresses
    @Published var scanning: Bool = false
    private var bag = Set<AnyCancellable>()
    
    private init () {
        scanForFans()
    }
    
    func scanForFans () {
        guard !scanning else { return }
        print("start scanning")
        scanning = true
        fansAt.removeAll()
//        TestItems.fans.forEach ({ fansAt.update(with: $0) })
        scanner
            .sink(receiveCompletion: { [weak self] comp in
                self?.scanning = false
                if case .finished = comp {
                    print ("scan complete")
                }
                if case .failure (let err) = comp {
                    print ("error: \(err)")
                }
            }, receiveValue: { [weak self] ipAddr in
                print ("Got fan addr: \(ipAddr)")
                self?.fansAt.update(with: ipAddr)
            })
            .store(in: &bag)
    }
    
    func getView (usingHouse house: House? = nil) -> some View {
        HouseViewModel().getView()
    }
    
    func lostFan(atIp ip: String) {
        fansAt.remove(ip)
    }
}

extension House {
//    var scanner: AnyPublisher<String, Never> {
//        return
//            NetworkAddress.hosts.publisher
//            .flatMap ({ host -> AnyPublisher<String, Never> in
//                return Just (FanModel.Action.refresh)
//                    .adjustPhysicalFan(atNetworkAddr: host, retry: false)
//                    .tryMap { dict in
//                        let addr = FanModel.FanKey.getValue(forKey: .ipAddress, fromTable: dict)
//                        guard let a = addr else { throw AdjustmentError.notFound }
//                        return a }
//                    .replaceError(with: "Not found")
//                    .filter({ $0 != "Not found" })
//                    .timeout(.seconds(2), scheduler: DispatchQueue.main)
//                    .eraseToAnyPublisher()
//            })
//            .eraseToAnyPublisher()
//    }
    var scanner: AnyPublisher<String, ConnectionError> {
        return
            NetworkAddress.hosts.publisher
            .setFailureType(to: ConnectionError.self)
            .flatMap ({ host -> AnyPublisher<String, ConnectionError> in
                guard let loader = FanStatusLoader(addr: host, action: .refresh) else { return Empty.init(completeImmediately: false, outputType: String.self, failureType: ConnectionError.self).eraseToAnyPublisher() }
                return loader.loadResults
                    .map { [host] _ in host }
                    .timeout(.seconds(2), scheduler: DispatchQueue.main)
                    .eraseToAnyPublisher()
            })
            .eraseToAnyPublisher()
    }}
