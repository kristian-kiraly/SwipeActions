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
        content
            .contentShape(Rectangle())
            .background {
                GeometryReader { geo in
                    Color(UIColor.systemBackground)
                        .frame(width: geo.size.width, height: geo.size.height)
                }
            }
            .offset(x: offset.current.width + offset.stored.width)
            .background {
                swipeActionButtons
            }
            .gesture(
                DragGesture(minimumDistance: 10, coordinateSpace: .local)
                    .updating($dragOffset, body: { value, state, transaction in
                        state = value.translation
                    })
            )
            .animation(.default, value: offset)
            .onChange(of: dragOffset) { newValue in
                if newValue == .zero {
                    guard let lastAction = swipeActions.last else { return }
                    if self.offset.totalWidth < -totalWidth + -SwipeAction.bounceWidth {
                        commitSwipeAction(lastAction)
                        return
                    }
                    defer {
                        self.offset.current.width = 0
                    }
                    if self.offset.totalWidth >= 0 {
                        self.offset.stored.width = 0
                        return
                    }
                    var currentPosition: CGFloat = 0
                    for swipeAction in swipeActions {
                        if self.offset.totalWidth > -(swipeAction.width / 2) - currentPosition {
                            self.offset.stored.width = -currentPosition
                            return
                        }
                        currentPosition += swipeAction.width
                    }
                    self.offset.stored.width = -currentPosition
                } else {
                    let oldValue = self.offset
                    self.offset.current = newValue
                    if self.offset.totalWidth > SwipeAction.bounceWidth { //if the width is too far off the right side of the screen, stop it and bounce back
                        self.offset.current.width = SwipeAction.bounceWidth - self.offset.stored.width //set the current width to the bounce distance minus the stored width to get the totalWidth to be the bounceWidth
                    //If the user drags past the end of the buttons (If the total offset width is past the end of the width of the button options and the previous value was at or before that width)
                    //OR
                    //If the user drags back to the other side of the buttons (If the total offset width is before the end of the width of the button options and the previous value was at or past that width)
                    } else if self.offset.totalWidth < -totalWidth && oldValue.totalWidth >= -totalWidth
                                ||
                                self.offset.totalWidth > -totalWidth && oldValue.totalWidth <= -totalWidth
                    {
                        let selectionGenerator = UISelectionFeedbackGenerator()
                        selectionGenerator.prepare()
                        selectionGenerator.selectionChanged()
                    }
                }
            }
    }
    
    @ViewBuilder
    private var swipeActionButtons: some View {
        if self.offset.totalWidth < 0 {
            HStack(spacing: 0) {
                Spacer()
                ForEach(Array(swipeActions.indices).reversed(), id:\.self) { swipeActionIndex in
                    let swipeAction = swipeActions[swipeActionIndex]
                    Text(swipeAction.name)
                        .foregroundStyle(.white)
                        .padding(.horizontal, SwipeAction.horizontalPadding)
                        .frame(maxHeight: .infinity, alignment: .center)
                        .background {
                            swipeAction.backgroundColor
                        }
                        .onTapGesture {
                            commitSwipeAction(swipeAction)
                        }
                }
            }
            .background {
                if let swipeAction = swipeActions.last {
                    GeometryReader { geo in
                        HStack(spacing: 0) {
                            Spacer()
                            swipeAction.backgroundColor
                                .frame(width: geo.size.width / (self.offset.current.width + self.offset.stored.width < -swipeAction.width - SwipeAction.bounceWidth ? 1 : 2), height: geo.size.height)
                        }
                    }
                }
            }
            .opacity(self.offset.stored.width < -totalWidth - SwipeAction.bounceWidth ? 0 : 1)
        }
    }
    
    private var totalWidth: CGFloat {
        swipeActions.reduce(CGFloat()) { partialResult, action in
            partialResult + action.width
        }
    }
    
    private func commitSwipeAction(_ swipeAction: SwipeAction) {
        let impactGenerator = UIImpactFeedbackGenerator()
        impactGenerator.prepare()
        impactGenerator.impactOccurred()
        if swipeAction.bouncesBack {
            self.offset.stored.width = 0
            swipeAction.action()
        } else {
            self.offset.stored.width = -SwipeAction.commitWidth
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                swipeAction.action()
            }
        }
    }
}

public extension View {
    func addSwipeAction(_ action: SwipeAction) -> some View {
        self.modifier(SwipeActionModifier(swipeActions: [action]))
    }
    
    func addSwipeActions(_ actions: [SwipeAction]) -> some View {
        self.modifier(SwipeActionModifier(swipeActions: actions))
    }
}

public struct SwipeAction: Identifiable {
    public let id = UUID()
    public var name: String
    public var action: () -> ()
    public var backgroundColor: Color
    private(set) var bouncesBack = true
    
    public static let bounceWidth: CGFloat = 50
    public static let commitWidth: CGFloat = 1000
    public static let horizontalPadding: CGFloat = 17
    
    public init(name: String, action: @escaping () -> (), backgroundColor: Color) {
        self.name = name
        self.action = action
        self.backgroundColor = backgroundColor
    }
    
    internal init(name: String, action: @escaping () -> (), backgroundColor: Color, bouncesBack: Bool = true) {
        self.name = name
        self.action = action
        self.backgroundColor = backgroundColor
        self.bouncesBack = bouncesBack
    }
    
    public static func DeleteAction(_ action: @escaping () -> ()) -> SwipeAction {
        SwipeAction(name: "Delete", action: action, backgroundColor: .red, bouncesBack: false)
    }
    
    public var width: CGFloat {
        name.renderedWidth + Self.horizontalPadding * 2
    }
}
