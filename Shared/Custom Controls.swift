import SwiftUI
import Combine



struct SizePreferenceKey: PreferenceKey {
    typealias Value = CGSize
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}
struct BackgroundGeometryReader: View {
    var body: some View {
        GeometryReader { geometry in
            return Color
                    .clear
                    .preference(key: SizePreferenceKey.self, value: geometry.size)
        }
    }
}
struct SizeAwareViewModifier: ViewModifier {

    @Binding private var viewSize: CGSize

    init(viewSize: Binding<CGSize>) {
        self._viewSize = viewSize
    }

    func body(content: Content) -> some View {
        content
            .background(BackgroundGeometryReader())
            .onPreferenceChange(SizePreferenceKey.self, perform: { if self.viewSize != $0 { self.viewSize = $0 }})
    }
}

struct SegmentedPicker: View {
    private static let ActiveSegmentColor: Color = Color.main
    private static let BackgroundColor: Color = Color(.lightGray)
    private static let ShadowColor: Color = Color.black.opacity(0.2)
    private static let TextColor: Color = Color.black
    private static let SelectedTextColor: Color = Color(.label)

    private static let TextFont: Font = .system(size: 24)
    
    private static let SegmentCornerRadius: CGFloat = 12
    private static let ShadowRadius: CGFloat = 4
    private static let SegmentXPadding: CGFloat = 16
    private static let SegmentYPadding: CGFloat = 8
    private static let PickerPadding: CGFloat = 4
    
    private static let AnimationDuration: Double = 0.1
    
    // Stores the size of a segment, used to create the active segment rect
    @State private var segmentSize: CGSize = .zero
    // Rounded rectangle to denote active segment
    private var activeSegmentView: AnyView {
        // Don't show the active segment until we have initialized the view
        // This is required for `.animation()` to display properly, otherwise the animation will fire on init
        let isInitialized: Bool = segmentSize != .zero
        if !isInitialized { return EmptyView().eraseToAnyView() }
        return
            RoundedRectangle(cornerRadius: SegmentedPicker.SegmentCornerRadius)
                .foregroundColor(SegmentedPicker.ActiveSegmentColor)
                .shadow(color: SegmentedPicker.ShadowColor, radius: SegmentedPicker.ShadowRadius)
                .frame(width: self.segmentSize.width, height: self.segmentSize.height)
                .offset(x: self.computeActiveSegmentHorizontalOffset(), y: 0)
                .animation(Animation.linear(duration: SegmentedPicker.AnimationDuration))
                .eraseToAnyView()
    }
    
    @Binding private var selection: Int
    private let items: [String]
    
    init(items: [String], selection: Binding<Int>) {
        self._selection = selection
        self.items = items
    }
    
    var body: some View {
        // Align the ZStack to the leading edge to make calculating offset on activeSegmentView easier
        ZStack(alignment: .leading) {
            // activeSegmentView indicates the current selection
            self.activeSegmentView
            HStack {
                ForEach(0..<self.items.count, id: \.self) { index in
                    self.getSegmentView(for: index)
                }
            }
        }
        .padding(SegmentedPicker.PickerPadding)
        .background(SegmentedPicker.BackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: SegmentedPicker.SegmentCornerRadius))
    }

    // Helper method to compute the offset based on the selected index
    private func computeActiveSegmentHorizontalOffset() -> CGFloat {
        CGFloat(self.selection) * (self.segmentSize.width + SegmentedPicker.SegmentXPadding / 2)
    }

    // Gets text view for the segment
    private func getSegmentView(for index: Int) -> some View {
        guard index < self.items.count else {
            return EmptyView().eraseToAnyView()
        }
        let isSelected = self.selection == index
        return
            Text(self.items[index])
            // Dark test for selected segment
            .font(SegmentedPicker.TextFont)
            .fixedSize()
            .foregroundColor(isSelected ? SegmentedPicker.SelectedTextColor: SegmentedPicker.TextColor)
            .lineLimit(1)
            .padding(.vertical, SegmentedPicker.SegmentYPadding)
            .padding(.horizontal, SegmentedPicker.SegmentXPadding)
            .frame(minWidth: 0, maxWidth: .infinity)
            // Watch for the size of the
            .modifier(SizeAwareViewModifier(viewSize: self.$segmentSize))
            .onTapGesture { self.onItemTap(index: index) }
            .eraseToAnyView()
    }

    // On tap to change the selection
    private func onItemTap(index: Int) {
        guard index < self.items.count else {
            return
        }
        self.selection = index
    }
    
}

class TestViewModel: ObservableObject {
    @Published var segmentState: Int = 0
    @Published var userSelection: Int?
    
    var userSelectedSpeed: Int?
    
    init () {
        Timer.scheduledTimer(withTimeInterval: 6.0, repeats: true) { _ in
            self.segmentState = 4
        }
    }
}

struct PreviewView: View {
    @ObservedObject private var viewModel: TestViewModel
    @State private var userSelected: Bool = true
    @State var selection: Int = 0
    @State private var pickerSelection: Int = 0
    @State private var countOf: Int = 6
    
    private var items: [String] {
        return (1...countOf + 1).map { idx -> String in
            switch idx {
            case 1:
                return "Off"
            case let a where a == countOf:
                return countOf == 2 ? "On" : "Full"
            default:
                return idx.description
            }
            //            $0 == 0 ? "Off" : $0.description }
            //        return Array.init(repeating: "2", count: 5)
        }
    }
//    private let items: [String] = ["M", "T", "W", "T", "F"]
    
    var body: some View {
        VStack {
            Picker (selection: $pickerSelection, label: Text("Picker")) {
                ForEach ( Range(1...countOf + 1) ) { item in
                    Text("\(item)")
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            .onChange(of: pickerSelection) { value in
                if userSelected {
                    viewModel.userSelection = value
                } else {
                    userSelected = true
                }
            }
            
            .onReceive(viewModel.$segmentState) { newSpd in
                userSelected = false
                pickerSelection = newSpd
            }
            
//            SegmentedPicker (items: items, selection: $selection)
////            .pickerStyle(SegmentedPickerStyle())
//            .padding()
//            .onChange(of: pickerSelection) { value in
//                print("\(value)")
//                if userSelected {
//                    viewModel.userSelection = value
//                } else {
//                    userSelected = true
//                }
//            }
//            .onReceive(viewModel.$segmentState) { newSpd in
//                userSelected = false
//                pickerSelection = newSpd
//            }
            Text("User selection \(viewModel.userSelection?.description ?? "Nil")")
        }
    }
    
    init(viewModel: TestViewModel) {
        self.viewModel = viewModel
//        speedController = UISegmentedControl()
        let app = UISegmentedControl.appearance()
        app.backgroundColor = .background
        app.selectedSegmentTintColor = .main
        app.setTitleTextAttributes([.foregroundColor: UIColor.main], for: .normal)
        app.setTitleTextAttributes([.foregroundColor: UIColor.background], for: .selected)
    }
}

struct Custom_Controls_Previews: PreviewProvider {
    static var previews: some View {
        PreviewView(viewModel: TestViewModel())
    }
}
