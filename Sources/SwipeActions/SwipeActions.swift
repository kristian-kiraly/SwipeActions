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
    
    var isDragging: Bool {
        dragOffset != .zero && predictedDragEnd != .zero
    }
}

fileprivate enum SwipeDirection {
    case left
    case right
    
    init(oldGestureStorage: DragGestureStorage, newGestureStorage: DragGestureStorage) {
        //-35 - -25 = -10 > right
        //35 - 45 = -10 > right
        //35 - 25 = 10 < left
        //-35 - -45 = 10 < left
        if oldGestureStorage.dragOffset.width - newGestureStorage.dragOffset.width < 0 {
            self = .right
        } else {
            self = .left
        }
    }
}

fileprivate struct SwipeActionModifier: ViewModifier {
    var rightSwipeActions: SwipeActionGroup? = nil
    var leftSwipeActions: SwipeActionGroup? = nil
    @State private var swipeDirection: SwipeDirection? = nil
    @State private var offset = Offset()
    
    @GestureState private var gestureState: DragGestureStorage = .init(dragOffset: .zero, predictedDragEnd: .zero)
    
    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .offset(x: offset.totalWidth)
            .background {
                swipeActionButtons
            }
            .animation(.default, value: offset)
            .gesture(
                DragGesture(minimumDistance: 10, coordinateSpace: .local)
                    .updating($gestureState, body: { value, state, transaction in
                        state = .init(dragOffset: value.translation, predictedDragEnd: value.predictedEndTranslation)
                    })
            )
            .onChange(of: gestureState) { [oldValue=gestureState] newValue in
                if swipeDirection == nil {
                    swipeDirection = .init(oldGestureStorage: oldValue, newGestureStorage: newValue)
                }
//                if case .right = swipeDirection {
//                    print("Right")
//                } else {
//                    print("Left")
//                }
                guard let swipeDirection else { return }
                if newValue.dragOffset == .zero { //Drag stopped
                    defer {
                        self.offset.current.width = 0
                        if self.offset.totalWidth == 0 {
                            self.swipeDirection = nil
                        }
                    }
                    switch swipeDirection {
                    case .left:
                        //Right actions
                        if let rightSwipeActions {
                            if self.offset.totalWidth < -totalRightActionsWidth + -SwipeAction.bounceWidth {
                                guard case .stop = rightSwipeActions.continuationBehavior else {
                                    commitRightSwipeAction(rightSwipeActions.mainAction, byDrag: true)
                                    return
                                }
                            }
                            if self.offset.totalWidth >= 0 {
                                self.offset.stored.width = 0
                                return
                            }
                            //Code to bounce to individual actions
//                          var currentPosition: CGFloat = 0
//                          for swipeAction in swipeActions {
//                              if self.offset.totalWidth > -(swipeAction.width / 2) - currentPosition {
//                                  self.offset.stored.width = -currentPosition
//                                  return
//                              }
//                              currentPosition += swipeAction.width
//                          }
//                          self.offset.stored.width = -currentPosition
                            let rightDrag = oldValue.predictedDragEnd.width > oldValue.dragOffset.width
                            if !rightDrag {
                                self.offset.stored.width = -totalRightActionsWidth
                            } else {
                                self.offset.stored.width = 0
                            }
                        } else {
                            self.offset.stored.width = 0
                        }
                    case .right:
                        if let leftSwipeActions {
                            if self.offset.totalWidth > totalLeftActionsWidth + SwipeAction.bounceWidth {
                                guard case .stop = leftSwipeActions.continuationBehavior else {
                                    commitLeftSwipeAction(leftSwipeActions.mainAction, byDrag: true)
                                    return
                                }
                            }
                            if self.offset.totalWidth <= 0 {
                                self.offset.stored.width = 0
                                return
                            }
                            let leftDrag = oldValue.predictedDragEnd.width < oldValue.dragOffset.width
                            if !leftDrag {
                                self.offset.stored.width = totalLeftActionsWidth
                            } else {
                                self.offset.stored.width = 0
                            }
                        } else {
                            self.offset.stored.width = 0
                        }
                    }
                } else {
                    let oldValue = self.offset
                    self.offset.current = newValue.dragOffset
                    switch swipeDirection {
                    case .left:
                        if let _ = rightSwipeActions {
                            let totalTargetWidth = -totalRightActionsWidth - SwipeAction.bounceWidth
                            if self.offset.totalWidth > SwipeAction.bounceWidth { //if the width is too far off the right side of the screen, stop it and bounce back
                                self.offset.current.width = SwipeAction.bounceWidth - self.offset.stored.width //set the current width to the bounce distance minus the stored width to get the totalWidth to be the bounceWidth
                                //If the user drags past the end of the buttons (If the total offset width is past the end of the width of the button options and the previous value was at or before that width)
                                //OR
                                //If the user drags back to the other side of the buttons (If the total offset width is before the end of the width of the button options and the previous value was at or past that width)
//                          } else if self.offset.totalWidth < -totalWidth && oldValue.totalWidth >= -totalWidth
//                                      ||
//                                      self.offset.totalWidth > -totalWidth && oldValue.totalWidth <= -totalWidth
//                          {
//                              let selectionGenerator = UISelectionFeedbackGenerator()
//                              selectionGenerator.prepare()
//                              selectionGenerator.selectionChanged()
                                
                                //If the user drags past the end of the buttons (If the total offset width is past the end of the width of the button options and the previous value was at or before that width)
                            } else if abs(self.offset.totalWidth) > abs(totalTargetWidth) && abs(oldValue.totalWidth) <= abs(totalTargetWidth) {
                                let impactGenerator = UIImpactFeedbackGenerator()
                                impactGenerator.prepare()
                                impactGenerator.impactOccurred()
//                                print("impact")
                            }
                        } else {
                            bounceBackToLimit()
                        }
                    case .right:
                        if let _ = leftSwipeActions {
                            let totalTargetWidth = totalLeftActionsWidth + SwipeAction.bounceWidth
                            if self.offset.totalWidth < -SwipeAction.bounceWidth {
                                self.offset.current.width = -SwipeAction.bounceWidth + self.offset.stored.width
                            } else if abs(self.offset.totalWidth) > abs(totalTargetWidth) && abs(oldValue.totalWidth) <= abs(totalTargetWidth) {
                                let impactGenerator = UIImpactFeedbackGenerator()
                                impactGenerator.prepare()
                                impactGenerator.impactOccurred()
//                                print("impact")
                            }
                        } else {
                            bounceBackToLimit()
                        }
                    }
                }
            }
    }
    
    private func bounceBackToLimit() {
        if self.offset.totalWidth > SwipeAction.bounceWidth {
            self.offset.current.width = SwipeAction.bounceWidth - self.offset.stored.width
        } else if self.offset.totalWidth < -SwipeAction.bounceWidth {
            self.offset.current.width = -SwipeAction.bounceWidth + self.offset.stored.width
        }
    }
    
    @ViewBuilder
    private var swipeActionButtons: some View {
        GeometryReader { geo in
            if let rightSwipeActions {
                let isBeyondSwipeDistance = abs(self.offset.totalWidth) > abs(totalRightActionsWidth) + abs(SwipeAction.bounceWidth)
                let currentRatio = self.offset.totalWidth / totalRightActionsWidth
                
                /*
                 if we want to get the distance between -1000 and the end of the screen, we need to figure out how far past the end of the screen the gesture is
                 the gesture is past the end of the screen if the total width is greater than the screen size
                 to get the remainder of the gesture width past the screen size, subtract the width of the screen from the width of the gesture
                 */
                let distanceBeyondEnd = abs(self.offset.totalWidth) - geo.size.width
                let adjustedEnd = SwipeAction.commitWidth - geo.size.width //Need to offset end since we're subtracting the width from the distance
                let percentBeyondDistance = distanceBeyondEnd / adjustedEnd
                ForEach(Array(rightSwipeActions.allActions.indices).reversed(), id:\.self) { swipeActionIndex in
                    let swipeAction = rightSwipeActions.allActions[swipeActionIndex]
                    let totalPriorActionWidths = rightSwipeActions.allActions.prefix(swipeActionIndex).reduce(0) { $0 + $1.width }
                    
                    let isMainAction = swipeActionIndex == 0
                    let shouldSnapMainAction = rightSwipeActions.continuationBehavior != .stop
                    let shouldHideCurrentAction = (isBeyondSwipeDistance && !isMainAction && shouldSnapMainAction) || swipeDirection == .right
                    
                    let currentWidth = abs(shouldHideCurrentAction ? 0 : (isBeyondSwipeDistance && shouldSnapMainAction ? self.offset.totalWidth : swipeAction.width * currentRatio))
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
                            commitRightSwipeAction(swipeAction, byDrag: false)
                        }
                }
                .opacity(percentBeyondDistance > 0 && !gestureState.isDragging ? 1 - percentBeyondDistance : 1)
            }
            if let leftSwipeActions {
//                let isBeyondSwipeDistance = self.offset.totalWidth < -totalRightActionsWidth - SwipeAction.bounceWidth
                let isBeyondSwipeDistance = abs(self.offset.totalWidth) > abs(totalRightActionsWidth) + abs(SwipeAction.bounceWidth)
                let currentRatio = self.offset.totalWidth / totalLeftActionsWidth
                
                /*
                 if we want to get the distance between -1000 and the end of the screen, we need to figure out how far past the end of the screen the gesture is
                 the gesture is past the end of the screen if the total width is greater than the screen size
                 to get the remainder of the gesture width past the screen size, subtract the width of the screen from the width of the gesture
                 */
                let distanceBeyondEnd = abs(self.offset.totalWidth) - geo.size.width
                let adjustedEnd = SwipeAction.commitWidth - geo.size.width
                let percentBeyondDistance = distanceBeyondEnd / adjustedEnd
                ForEach(Array(leftSwipeActions.allActions.indices), id:\.self) { swipeActionIndex in
                    let swipeAction = leftSwipeActions.allActions[swipeActionIndex]
                    let totalPriorActionWidths = leftSwipeActions.allActions.prefix(swipeActionIndex).reduce(0) { $0 + $1.width }
                    
                    let isMainAction = swipeActionIndex == 0
                    let shouldSnapMainAction = leftSwipeActions.continuationBehavior != .stop
                    let shouldHideCurrentAction = (isBeyondSwipeDistance && !isMainAction && shouldSnapMainAction) || swipeDirection == .left
                    
                    let currentWidth = abs(shouldHideCurrentAction ? 0 : (isBeyondSwipeDistance && shouldSnapMainAction ? self.offset.totalWidth : swipeAction.width * currentRatio))
                    let currentPriorWidths = abs(totalPriorActionWidths * currentRatio * (shouldHideCurrentAction ? 0 : 1))
                    
                    swipeAction.label
                        .fixedSize(horizontal: true, vertical: false)
                        .frame(width: currentWidth, alignment: .trailing)
                        .frame(maxHeight: .infinity, alignment: .center)
                        .background {
                            Rectangle()
                                .fill(swipeAction.backgroundColor)
                                .frame(width: currentWidth)
                        }
                        .clipped()
                        .position(x: currentPriorWidths + currentWidth / 2, y: geo.size.height / 2)
                        .onTapGesture {
                            commitRightSwipeAction(swipeAction, byDrag: false)
                        }
                }
                .opacity(percentBeyondDistance > 0 && !gestureState.isDragging ? 1 - percentBeyondDistance : 1)
            }
        }
    }
    
    private var totalRightActionsWidth: CGFloat {
        rightSwipeActions?.allActions.reduce(CGFloat()) { $0 + $1.width } ?? 0
    }
    
    private var totalLeftActionsWidth: CGFloat {
        leftSwipeActions?.allActions.reduce(CGFloat()) { $0 + $1.width } ?? 0
    }
    
    private func commitLeftSwipeAction(_ swipeAction: SwipeAction, byDrag: Bool) {
        switch leftSwipeActions?.continuationBehavior {
        case .stop:
            guard !byDrag else { return }
            performSwipeAction(swipeAction)
        case .commit:
            performSwipeAction(swipeAction)
        case .delete:
            self.offset.stored.width = SwipeAction.commitWidth
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                swipeAction.action()
            }
        case nil:
            break
        }
    }
    
    private func commitRightSwipeAction(_ swipeAction: SwipeAction, byDrag: Bool) {
        switch rightSwipeActions?.continuationBehavior {
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
        case nil:
            break
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
        self.modifier(SwipeActionModifier(rightSwipeActions: .init(mainAction: action, continuationBehavior: continuationBehavior)))
    }
    
    @ViewBuilder
    func addSwipeActions(_ actions: [SwipeAction], continuationBehavior: SwipeContinuationBehavior = .commit) -> some View {
        if let firstAction = actions.first {
            let remainingActions = Array(actions.suffix(from: 1))
            self.modifier(SwipeActionModifier(rightSwipeActions: .init(mainAction: firstAction, otherActions: remainingActions, continuationBehavior: continuationBehavior)))
        } else {
            self
        }
    }
    
    func addSwipeActions(mainAction: SwipeAction, otherActions: [SwipeAction] = [], continuationBehavior: SwipeContinuationBehavior = .commit) -> some View {
        self.modifier(SwipeActionModifier(rightSwipeActions: .init(mainAction: mainAction, otherActions: otherActions, continuationBehavior: continuationBehavior)))
    }
    
    func addSwipeActions(deleteAction: SwipeAction, otherActions: [SwipeAction] = []) -> some View {
        self.modifier(SwipeActionModifier(rightSwipeActions: .init(deleteAction: deleteAction, otherActions: otherActions)))
    }
    
    func addSwipeActions(leftActions: SwipeActionGroup? = nil, rightActions: SwipeActionGroup? = nil) -> some View {
//        if let rightActions {
//            let rightActions = SwipeActionGroup(mainAction: rightActions.mainAction, otherActions: rightActions.allActions.suffix(from: 1).reversed(), continuationBehavior: rightActions.continuationBehavior)
//            return self.modifier(SwipeActionModifier(rightSwipeActions: rightActions, leftSwipeActions: leftActions))
//        } else {
            return self.modifier(SwipeActionModifier(rightSwipeActions: rightActions, leftSwipeActions: leftActions))
//        }
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
        self.allActions = [mainAction] + otherActions
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
        .foregroundStyle(.white)
    }
    
    private var nameLabel: some View {
        Text(name)
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
//                .addSwipeActions(deleteAction: .DeleteAction { print("Delete") })
                .addSwipeActions(leftActions: .init(deleteAction: .DeleteAction { }) /*.init(mainAction: .init(name: "Test Left", symbol: .init(systemName: "plus"), backgroundColor: .blue, action: {}), continuationBehavior: .commit)*/, rightActions: .init(mainAction: .DeleteAction { }/*.init(name: "Test Right", symbol: .init(systemName: "clock"), backgroundColor: .green, action: {})*/, otherActions: [/*.init(name: "Test Right 2", symbol: .init(systemName: "square.fill"), backgroundColor: .red, action: {}),*/ .init(name: "Right 3", symbol: .init(systemName: "circle"), backgroundColor: .purple, action: {})], continuationBehavior: .delete))
        }
    }
}
