//
//  House View Model.swift
//  whf001
//
//  Created by Scott Lucas on 12/9/20.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class HouseViewModel: ObservableObject {
    private var dataSource: House
    @Published var fanViews = Set<FanView>()
    @Published var indicators = HouseLamps()
    init (dataSource: House = House(), initialFans: Set<FanCharacteristics> = []) {
        fanViews = Set(initialFans.map { FanView(initialCharacteristics: $0) })
        self.dataSource = dataSource
    }

    func scan () async throws {
        fanViews.removeAll()
        for try await item in dataSource.scan() {
            fanViews.update(with: FanView(initialCharacteristics: item))
        }
    }
}
