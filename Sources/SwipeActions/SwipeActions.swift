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

fileprivate struct SwipeActionModifier: ViewModifier {
    let swipeActions: [SwipeAction]
    @State private var offset = Offset()
    
    @GestureState private var dragOffset: CGSize = .zero
    
    func body(content: Content) -> some View {
        let fullWidth = offset.current.width + offset.stored.width
        content
            .contentShape(Rectangle())
            .offset(x: offset.current.width + offset.stored.width)
            .background {
                swipeActionButtons
                    .mask {
                        GeometryReader { geo in
//                            if fullWidth < 0 {
                            let maskWidth = fullWidth < 0 ? -fullWidth : 0
                            Rectangle()
                                .frame(width: maskWidth, height: geo.size.height, alignment: .trailing)
                                .position(x: geo.size.width - (maskWidth / 2), y: geo.size.height / 2)
//                            }
                        }
                    }
            }
            .animation(.default, value: offset)
            .gesture(
                DragGesture(minimumDistance: 10, coordinateSpace: .local)
                    .updating($dragOffset, body: { value, state, transaction in
                        state = value.translation
                    })
            )
            .onChange(of: dragOffset) { newValue in
                if newValue == .zero {
                    guard let firstAction = swipeActions.first else { return }
                    if self.offset.totalWidth < -totalWidth + -SwipeAction.bounceWidth {
                        commitSwipeAction(firstAction, byDrag: true)
                        guard case .stop = firstAction.continuationBehavior else { return }
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
                    if self.offset.current.width < 0 {
                        let fullSwipeActionWidth: CGFloat = swipeActions.reduce(0) { $0 + $1.width }
                        self.offset.stored.width = -fullSwipeActionWidth
//                        print("Open: \(self.offset.current)")
                    } else {
                        self.offset.stored.width = 0
//                        print("Close: \(self.offset.current)")
                    }
                } else {
                    let oldValue = self.offset
                    let totalTargetWidth = -totalWidth - SwipeAction.bounceWidth
                    self.offset.current = newValue
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
            let totalActionWidths = swipeActions.reduce(0) { $0 + $1.width }
            let currentRatio = self.offset.totalWidth / totalActionWidths
            ForEach(Array(swipeActions.indices).reversed(), id:\.self) { swipeActionIndex in
                let swipeAction = swipeActions[swipeActionIndex]
                let totalPriorActionWidths = swipeActions.prefix(swipeActionIndex).reduce(0) { $0 + $1.width }
                
                let isMainAction = swipeActionIndex == 0
                let shouldHideCurrentAction = isBeyondSwipeDistance && !isMainAction
                
                let currentWidth = abs(shouldHideCurrentAction ? 0 : (isBeyondSwipeDistance ? self.offset.totalWidth : swipeAction.width * currentRatio))
                let currentPriorWidths = abs(totalPriorActionWidths * currentRatio * (shouldHideCurrentAction ? 0 : 1))
                
                Text(swipeAction.name)
                    .foregroundStyle(.white)
                    .padding(.horizontal, SwipeAction.horizontalPadding)
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(width: currentWidth, alignment: isMainAction && isBeyondSwipeDistance ? .leading : .center)
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
        }
    }
    
    private var totalWidth: CGFloat {
        swipeActions.reduce(CGFloat()) { partialResult, action in
            partialResult + action.width
        }
    }
    
    private func commitSwipeAction(_ swipeAction: SwipeAction, byDrag: Bool) {
        switch swipeAction.continuationBehavior {
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
#warning("Applying multiple swipe actions only uses the first swipe action modifier used")
    
    func addSwipeAction(_ action: SwipeAction) -> some View {
        self.modifier(SwipeActionModifier(swipeActions: [action]))
    }
    
    func addSwipeActions(_ actions: [SwipeAction]) -> some View {
        self.modifier(SwipeActionModifier(swipeActions: actions))
    }
}

public enum SwipeContinuationBehavior {
    case stop
    case commit
    case delete
}

public struct SwipeActionGroup {
    public var actions: [SwipeAction]
    private(set) var continuationBehavior: SwipeContinuationBehavior = .stop
}

public struct SwipeAction: Identifiable {
    public let id = UUID()
    public var name: String
    public var action: () -> ()
    public var backgroundColor: Color
    private(set) var continuationBehavior: SwipeContinuationBehavior = .stop
    
    public static let bounceWidth: CGFloat = 50
    public static let commitWidth: CGFloat = 1000
    public static let horizontalPadding: CGFloat = 17
    
    public init(name: String, action: @escaping () -> (), backgroundColor: Color) {
        self.name = name
        self.action = action
        self.backgroundColor = backgroundColor
    }
    
    internal init(name: String, action: @escaping () -> (), backgroundColor: Color, continuationBehavior: SwipeContinuationBehavior = .stop) {
        self.name = name
        self.action = action
        self.backgroundColor = backgroundColor
        self.continuationBehavior = continuationBehavior
    }
    
    internal init(name: String, action: @escaping () -> (), backgroundColor: Color, bouncesBack: Bool = false) {
        self.init(name: name, action: action, backgroundColor: backgroundColor, continuationBehavior: .commit)
    }
    
    public static func DeleteAction(_ action: @escaping () -> ()) -> SwipeAction {
        SwipeAction(name: "Delete", action: action, backgroundColor: .red, bouncesBack: false)
    }
    
    public var width: CGFloat {
        name.renderedWidth + Self.horizontalPadding * 2
    }
}


#Preview {
    VStack(spacing: 0) {
        ForEach(0..<10, id: \.self) { index in
            Text("\(index)")
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .addSwipeActions([.init(name: "Test", action: { print("Test") }, backgroundColor: .blue/*, continuationBehavior: .commit*/), .init(name: "Test 2", action: { print ("Test 2") }, backgroundColor: .green/*, continuationBehavior: .commit*/)])
        }
    }
}
