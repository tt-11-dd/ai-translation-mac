import SwiftUI
import AppKit

/// 全局统一纯实色设计系统 (无壁纸透光，确保纯粹一致的高级质感)
enum AppTheme {
    /// 窗口主背景色 (100% 实体纯色，绝不随桌面壁纸穿透)
    static let windowBg = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.086, green: 0.090, blue: 0.106, alpha: 1.0) // 深空炭黑 #16171B
            : NSColor(red: 0.957, green: 0.961, blue: 0.969, alpha: 1.0) // 洁净浅灰白 #F4F5F7
    }))

    /// 历史侧边栏实体底色
    static let sidebarBg = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.067, green: 0.071, blue: 0.082, alpha: 1.0) // #111215
            : NSColor(red: 0.925, green: 0.929, blue: 0.937, alpha: 1.0) // #ECEDEF
    }))

    /// 原文与译文卡片实体背景色
    static let cardBg = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.125, green: 0.133, blue: 0.153, alpha: 1.0) // #202227
            : NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)       // #FFFFFF
    }))

    /// 交互按钮/胶囊常规背景色
    static let controlBg = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.161, green: 0.169, blue: 0.192, alpha: 1.0) // #292B31
            : NSColor(red: 0.902, green: 0.910, blue: 0.922, alpha: 1.0) // #E6E8EB
    }))

    /// 交互按钮悬浮提亮背景色
    static let controlHoverBg = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.204, green: 0.212, blue: 0.239, alpha: 1.0) // #34363D
            : NSColor(red: 0.855, green: 0.867, blue: 0.882, alpha: 1.0) // #DCE0E3
    }))

    /// 精致细边框线
    static let border = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(white: 1.0, alpha: 0.08)
            : NSColor(white: 0.0, alpha: 0.08)
    }))

    /// 分割线颜色
    static let divider = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(white: 1.0, alpha: 0.06)
            : NSColor(white: 0.0, alpha: 0.06)
    }))

    /// 核心科技蓝强调色
    static let accent = Color(red: 0.29, green: 0.45, blue: 0.98)
    static let accentGradient = LinearGradient(
        colors: [Color(red: 0.32, green: 0.48, blue: 1.0), Color(red: 0.42, green: 0.36, blue: 0.96)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
