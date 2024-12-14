//
//  SwipeActions.swift
//
//
//  Created by Kristian Kiraly on 2/7/24.
//

import SwiftUI

fileprivate extension CGSize {
    static func +(lhs: CGSize, rhs: CGSize) -> CGSize {
        return CGSize(width: lhs.width + rhs.width, height: lhs.height + rhs.height)
    }
}

fileprivate struct Offset: Equatable {
    var current: CGSize
    var stored: CGSize
    
    init() {
        current = .zero
        stored = .zero
    }
    
    var totalWidth: CGFloat {
        current.width + stored.width
    }
}

fileprivate extension String {
    var renderedWidth: CGFloat {
        let font = UIFont.systemFont(ofSize: 17)
        
        let attributes: [NSAttributedString.Key : Any] = [.font : font]
        
        let nsString = self as NSString
        
        return nsString.size(withAttributes: attributes).width
    }
}

fileprivate struct DragGestureStorage: Equatable {
    var dragOffset: CGSize
    var predictedDragEnd: CGSize
}

fileprivate struct SwipeActionModifier: ViewModifier {
    let swipeActions: SwipeActionGroup
    @State private var offset = Offset()
    
    @GestureState private var gestureState: DragGestureStorage = .init(dragOffset: .zero, predictedDragEnd: .zero)
    
    func body(content: Content) -> some View {
        let fullWidth = offset.current.width + offset.stored.width
        content
            .contentShape(Rectangle())
            .offset(x: offset.current.width + offset.stored.width)
            .background {
                swipeActionButtons
                    .mask {
                        GeometryReader { geo in
                            let maskWidth = fullWidth < 0 ? -fullWidth : 0
                            Rectangle()
                                .frame(width: maskWidth, height: geo.size.height, alignment: .trailing)
                                .position(x: geo.size.width - (maskWidth / 2), y: geo.size.height / 2)
                        }
                    }
            }
            .animation(.default, value: offset)
            .gesture(
                DragGesture(minimumDistance: 10, coordinateSpace: .local)
                    .updating($gestureState, body: { value, state, transaction in
                        state = .init(dragOffset: value.translation, predictedDragEnd: value.predictedEndTranslation)
                    })
            )
            .onChange(of: gestureState) { [oldValue=gestureState] newValue in
                if newValue.dragOffset == .zero {
                    if self.offset.totalWidth < -totalWidth + -SwipeAction.bounceWidth {
                        guard case .stop = swipeActions.continuationBehavior else {
                            commitSwipeAction(swipeActions.mainAction, byDrag: true)
                            return
                        }
                    }
                    defer {
                        self.offset.current.width = 0
                    }
                    if self.offset.totalWidth >= 0 {
                        self.offset.stored.width = 0
                        return
                    }
                    //Code to bounce to individual actions
//                    var currentPosition: CGFloat = 0
//                    for swipeAction in swipeActions {
//                        if self.offset.totalWidth > -(swipeAction.width / 2) - currentPosition {
//                            self.offset.stored.width = -currentPosition
//                            return
//                        }
//                        currentPosition += swipeAction.width
//                    }
//                    self.offset.stored.width = -currentPosition
                    let rightDrag = oldValue.predictedDragEnd.width > oldValue.dragOffset.width
                    if !rightDrag {
                        let fullSwipeActionWidth: CGFloat = swipeActions.allActions.reduce(0) { $0 + $1.width }
                        self.offset.stored.width = -fullSwipeActionWidth
                    } else {
                        self.offset.stored.width = 0
                    }
                } else {
                    let oldValue = self.offset
                    let totalTargetWidth = -totalWidth - SwipeAction.bounceWidth
                    self.offset.current = newValue.dragOffset
                    if self.offset.totalWidth > SwipeAction.bounceWidth { //if the width is too far off the right side of the screen, stop it and bounce back
                        self.offset.current.width = SwipeAction.bounceWidth - self.offset.stored.width //set the current width to the bounce distance minus the stored width to get the totalWidth to be the bounceWidth
                        //If the user drags past the end of the buttons (If the total offset width is past the end of the width of the button options and the previous value was at or before that width)
                        //OR
                        //If the user drags back to the other side of the buttons (If the total offset width is before the end of the width of the button options and the previous value was at or past that width)
                        //                    } else if self.offset.totalWidth < -totalWidth && oldValue.totalWidth >= -totalWidth
                        //                                ||
                        //                                self.offset.totalWidth > -totalWidth && oldValue.totalWidth <= -totalWidth
                        //                    {
                        //                        let selectionGenerator = UISelectionFeedbackGenerator()
                        //                        selectionGenerator.prepare()
                        //                        selectionGenerator.selectionChanged()
                        
                        //If the user drags past the end of the buttons (If the total offset width is past the end of the width of the button options and the previous value was at or before that width)
                    } else if self.offset.totalWidth < totalTargetWidth && oldValue.totalWidth >= totalTargetWidth {
                        let impactGenerator = UIImpactFeedbackGenerator()
                        impactGenerator.prepare()
                        impactGenerator.impactOccurred()
                    }
                }
            }
    }
    
    @ViewBuilder
    private var swipeActionButtons: some View {
        let isBeyondSwipeDistance = self.offset.totalWidth < -totalWidth - SwipeAction.bounceWidth
        GeometryReader { geo in
            let totalActionWidths = swipeActions.allActions.reduce(0) { $0 + $1.width }
            let currentRatio = self.offset.totalWidth / totalActionWidths
            
            /*
             if we want to get the distance between -1000 and the end of the screen, we need to figure out how far past the end of the screen the gesture is
             the gesture is past the end of the screen if the total width is greater than the screen size
             to get the remainder of the gesture width past the screen size, subtract the width of the screen from the width of the gesture
             */
            let distanceBeyondEnd = abs(self.offset.totalWidth) - geo.size.width
            let adjustedEnd = SwipeAction.commitWidth - geo.size.width //Need to offset end since we're subtracting the width from the distance
            let percentBeyondDistance = distanceBeyondEnd / adjustedEnd
            ForEach(Array(swipeActions.allActions.indices).reversed(), id:\.self) { swipeActionIndex in
                let swipeAction = swipeActions.allActions[swipeActionIndex]
                let totalPriorActionWidths = swipeActions.allActions.prefix(swipeActionIndex).reduce(0) { $0 + $1.width }
                
                let isMainAction = swipeActionIndex == 0
                let shouldHideCurrentAction = isBeyondSwipeDistance && !isMainAction
                
                let currentWidth = abs(shouldHideCurrentAction ? 0 : (isBeyondSwipeDistance ? self.offset.totalWidth : swipeAction.width * currentRatio))
                let currentPriorWidths = abs(totalPriorActionWidths * currentRatio * (shouldHideCurrentAction ? 0 : 1))
                
                swipeAction.label
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(width: currentWidth, alignment: .leading)
                    .frame(maxHeight: .infinity, alignment: .center)
                    .background {
                        Rectangle()
                            .fill(swipeAction.backgroundColor)
                            .frame(width: currentWidth)
                    }
                    .clipped()
                    .position(x: geo.size.width - currentPriorWidths - currentWidth / 2, y: geo.size.height / 2)
                    .onTapGesture {
                        commitSwipeAction(swipeAction, byDrag: false)
                    }
            }
            .opacity(percentBeyondDistance > 0 ? 1 - percentBeyondDistance : 1)
        }
    }
    
    private var totalWidth: CGFloat {
        swipeActions.allActions.reduce(CGFloat()) { partialResult, action in
            partialResult + action.width
        }
    }
    
    private func commitSwipeAction(_ swipeAction: SwipeAction, byDrag: Bool) {
        switch swipeActions.continuationBehavior {
        case .commit:
            performSwipeAction(swipeAction)
        case .stop:
            guard !byDrag else { return }
            performSwipeAction(swipeAction)
        case .delete:
            self.offset.stored.width = -SwipeAction.commitWidth
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                swipeAction.action()
            }
        }
    }
    
    private func performSwipeAction(_ swipeAction: SwipeAction) {
        self.offset.current = .zero
        self.offset.stored.width = 0
        swipeAction.action()
    }
}

public extension View {
#warning("Applying multiple swipe actions in separate modifiers only uses the first swipe action modifier used")
    
    func addSwipeAction(_ action: SwipeAction, continuationBehavior: SwipeContinuationBehavior = .commit) -> some View {
        self.modifier(SwipeActionModifier(swipeActions: .init(mainAction: action, continuationBehavior: continuationBehavior)))
    }
    
    @ViewBuilder
    func addSwipeActions(_ actions: [SwipeAction], continuationBehavior: SwipeContinuationBehavior = .commit) -> some View {
        if let firstAction = actions.first {
            let remainingActions = Array(actions.suffix(from: 1))
            self.modifier(SwipeActionModifier(swipeActions: .init(mainAction: firstAction, otherActions: remainingActions, continuationBehavior: continuationBehavior)))
        } else {
            self
        }
    }
    
    func addSwipeActions(mainAction: SwipeAction, otherActions: [SwipeAction] = [], continuationBehavior: SwipeContinuationBehavior = .commit) -> some View {
        self.modifier(SwipeActionModifier(swipeActions: .init(mainAction: mainAction, otherActions: otherActions, continuationBehavior: continuationBehavior)))
    }
    
    func addSwipeActions(deleteAction: SwipeAction, otherActions: [SwipeAction] = []) -> some View {
        self.modifier(SwipeActionModifier(swipeActions: .init(deleteAction: deleteAction, otherActions: otherActions)))
    }
}

public enum SwipeContinuationBehavior {
    case stop
    case commit
    case delete
}

public struct SwipeActionGroup {
    public let mainAction: SwipeAction
    public let allActions: [SwipeAction]
    public let continuationBehavior: SwipeContinuationBehavior
    
    init(mainAction: SwipeAction, otherActions: [SwipeAction] = [], continuationBehavior: SwipeContinuationBehavior = .stop) {
        self.mainAction = mainAction
        self.allActions = [mainAction] + otherActions.reversed()
        self.continuationBehavior = continuationBehavior
    }
    
    init(deleteAction: SwipeAction, otherActions: [SwipeAction] = []) {
        self.init(mainAction: deleteAction, otherActions: otherActions, continuationBehavior: .delete)
    }
}

public struct SwipeAction: Identifiable {
    public let id = UUID()
    public let name: String
    public let symbol: Image?
    public let action: () -> ()
    public let backgroundColor: Color
    
    public static let bounceWidth: CGFloat = 50
    public static let commitWidth: CGFloat = 1000
    public static let horizontalPadding: CGFloat = 17
    
    public init(name: String, symbol: Image? = nil, backgroundColor: Color, action: @escaping () -> ()) {
        self.name = name
        self.action = action
        self.backgroundColor = backgroundColor
        self.symbol = symbol
    }
    
    public static func DeleteAction(_ action: @escaping () -> ()) -> SwipeAction {
        SwipeAction(name: "Delete", symbol: .init(systemName: "trash"), backgroundColor: .red, action: action)
    }
    
    public var width: CGFloat {
        name.renderedWidth + Self.horizontalPadding * 2
    }
    
    @ViewBuilder
    internal var label: some View {
        Group {
            if #available(iOS 16.0, *) {
                ViewThatFits {
                    symbolStack
                    nameLabel
                }
            } else {
                symbolStack
            }
        }
        .padding(.horizontal, SwipeAction.horizontalPadding)
    }
    
    private var nameLabel: some View {
        Text(name)
            .foregroundStyle(.white)
    }
    
    private var symbolStack: some View {
        VStack {
            if let symbol {
                symbol
            }
            nameLabel
        }
    }
}


#Preview {
    VStack(spacing: 0) {
        ForEach(0..<10, id: \.self) { index in
            Text("\(index)")
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
//                .addSwipeActions([.init(name: "Test", symbol: .init(systemName: "plus"), backgroundColor: .blue, action: { print("Test") }), .init(name: "Test 2", symbol: .init(systemName: "square.fill"), backgroundColor: .green, action: { print ("Test 2") })])
                .addSwipeActions(deleteAction: .DeleteAction { print("Delete") })
        }
    }
}
