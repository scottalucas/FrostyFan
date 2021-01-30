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
    static let shared = House()
    @Published var fansAt = Set<FanModel>() //IP addresses
    @Published var runningFans = Set<FanModel>()
    @Published var scanning: Bool = false
    @Published var displayedAlarms = Alarm()
    private var bag = Set<AnyCancellable>()
    
    private init () {
        scanForFans()
    }
    
    func scanForFans () {
        guard !scanning else { return }
        print("start scanning")
        scanning = true
        fansAt.removeAll()
        scanner
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
                let newFan = FanModel.init(forAddress: ipAddr, usingChars: chars)
                self?.fansAt.update(with: newFan)
            })
            .store(in: &bag)
    }
    
    func getView (usingHouse house: House? = nil) -> some View {
        HouseViewModel().getView()
    }
    
    func lostFan(fanModel: FanModel) {
        fansAt.remove(fanModel)
    }
    
    func raiseAlarm(forCondition condition: Alarm) {
        guard !condition.isDisjoint(with: Storage.shared.configuredAlarms) else {
            clearAlarm(forCondition: condition)
            return
        }
        displayedAlarms.update(with: condition)
    }
    
    func clearAlarm(forCondition condition: Alarm? = nil) {
        if let cond = condition {
            displayedAlarms.remove(cond)
        } else {
            displayedAlarms = []
        }
    }
}

extension House {
    var scanner: AnyPublisher<(String, FanCharacteristics), ConnectionError> {
        return
            NetworkAddress.hosts.publisher
            .prepend("0.0.0.0:8181") //testing
            .setFailureType(to: ConnectionError.self)
                .flatMap ({ host -> AnyPublisher<(String, FanCharacteristics), ConnectionError> in
                guard let loader = FanStatusLoader(addr: host, action: .refresh) else { return Empty.init(completeImmediately: false).eraseToAnyPublisher() }
                return loader.loadResults
                    .catch({ _ in
                        Empty.init(completeImmediately: false)
                    })
                    .map { [host] chars in (host, chars) }
                    .timeout(.seconds(5), scheduler: DispatchQueue.main)
                    .eraseToAnyPublisher()
            })
//            .collect()
            .eraseToAnyPublisher()
    }}
