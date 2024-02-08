# SwipeActions

Adding swipe actions to any SwiftUI view without the need for it to be in a List view to work

Usage:

```swift
struct ContentView: View {
    @State var testList = [...]
    
    var body: some View {
        ForEach(testList) { item in
            Text(item.name)
                .addSwipeAction(SwipeAction(name: "Edit", action: {
                    beginEditing(item))
                }, backgroundColor: .blue)
        }
    }
```
