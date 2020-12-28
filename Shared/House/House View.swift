//
//  House View.swift
//  whf001
//
//  Created by Scott Lucas on 12/9/20.
//

import SwiftUI

struct HouseView: View {
    @ObservedObject var viewModel: HouseViewModel
    @State var currentTab: Int = 0
    @State var info: String = ""
    
    var body: some View {
        
//        VStack {
//
//                GeometryReader { geo in
//                    FanViewPageContainer(viewModel: viewModel)
//                    Text(info)
//                }
//                GeometryReader {geo in
                    TabView (selection: $currentTab)
                    {
                        VStack {
                            FanViewPageContainer(viewModel: viewModel)
//                                .frame(width: nil, height: nil, alignment: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/)
                            Spacer ()
                        }
                            .tabItem {
                                Image.fanIcon
                                Text("Fan")
                            }
                            .tag(1)
                        
                        Text("")
                            .tabItem {
                                Image.timer
                                Text("Timer")
                            }
                            .tag(2)
                        
                        Text("")
                            .tabItem {
                                Image.bell
                                Text("Alarms")
                            }
                            .tag(3)
                    }
//                    .onAppear(perform: {info = geo.frame(in: .global).debugDescription})
                    .accentColor(Color.main)
//                }
//                .frame(width: nil, height: nil, alignment: .bottom)

//        }
        
    }
    
    init (viewModel: HouseViewModel) {
        self.viewModel = viewModel
        //        viewModel.fanModels.forEach({ $0.update() })
    }
}

struct FanViewPageContainer: View {
    @ObservedObject var viewModel: HouseViewModel
    @State private var selectedFan: Int = 0
    
    var body: some View {
        if viewModel.fanModels.count == 0 {
            Text("No fans connected")
        } else {
            TabView (selection: $selectedFan) {
                ForEach (0..<viewModel.fanModels.count, id: \.self) { fanModelIndex in
                    viewModel.fanModels[fanModelIndex]
                        .getView()
//                        .padding([.bottom], viewModel.fanModels.count == 0 ? 0 : 75)
                        .tag(fanModelIndex)
                }
            }
            .tabViewStyle(PageTabViewStyle())
            .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
            .ignoresSafeArea(.container, edges: [.top])
        }
    }
}

struct HouseViewPreviews: PreviewProvider {
    static var previews: some View {
        //        FanViewPageContainer(viewModel: TestHouseViewModel(withHouse: TestHouse()))
        HouseView(viewModel: TestHouseViewModel())
    }
}
