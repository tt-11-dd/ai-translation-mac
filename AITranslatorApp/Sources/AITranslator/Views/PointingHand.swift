import SwiftUI
import AppKit

/// 让视图在鼠标悬停时显示手型指针
struct PointingHand: ViewModifier {
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                if hovering {
                    if !isHovering {
                        NSCursor.pointingHand.push()
                    }
                } else {
                    if isHovering {
                        NSCursor.pop()
                    }
                }
                isHovering = hovering
            }
            .onDisappear {
                // 视图被移除时兜底 pop，避免污染全局光标栈
                if isHovering {
                    NSCursor.pop()
                    isHovering = false
                }
            }
    }
}

extension View {
    /// 悬停显示手型指针
    func pointingHand() -> some View {
        modifier(PointingHand())
    }
}
