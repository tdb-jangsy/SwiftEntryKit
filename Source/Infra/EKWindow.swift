//
//  EKWindow.swift
//  SwiftEntryKit
//
//  Created by Daniel Huri on 4/19/18.
//  Copyright (c) 2018 huri000@gmail.com. All rights reserved.
//

import UIKit

class EKWindow: UIWindow {
    
    var isAbleToReceiveTouches = false
    
    init(with rootVC: UIViewController, level: UIWindow.Level) {
        if #available(iOS 13.0, *) {
            // Fork: Attach to the app's window scene even when it isn't foreground-active. A window created with
            // `init(frame:)` in a scene-based app belongs to no scene and is never shown, so an entry displayed while
            // the app was inactive (returning from the background, Control Center, a system alert) or in the background
            // stayed "displayed" invisibly forever and held every enqueued entry after it until the app was relaunched.
            if let scene = EKWindow.preferredWindowScene {
                super.init(windowScene: scene)
            } else {
                super.init(frame: UIScreen.main.bounds)
            }
        } else {
            super.init(frame: UIScreen.main.bounds)
        }
        windowLevel = level
        backgroundColor = .clear
        rootViewController = rootVC
        accessibilityViewIsModal = true

        if #available(iOS 13.0, *) {
            // Fork: See `sceneWillShow(_:)`. Selector-based observers are removed automatically when the window deallocates.
            NotificationCenter.default.addObserver(self, selector: #selector(sceneWillShow(_:)), name: UIScene.willEnterForegroundNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(sceneWillShow(_:)), name: UIScene.didActivateNotification, object: nil)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// Fork: The window scene to attach an entry window to. Prefers the app's own (application-role) scenes over others such
    /// as an external display, then the most active one: foreground-active, foreground-inactive, background, and finally
    /// any connected window scene.
    @available(iOS 13.0, *)
    static var preferredWindowScene: UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let applicationScenes = scenes.filter { $0.session.role == .windowApplication }
        let candidates = applicationScenes.isEmpty ? scenes : applicationScenes
        let states: [UIScene.ActivationState] = [.foregroundActive, .foregroundInactive, .background]
        for state in states {
            if let scene = candidates.first(where: { $0.activationState == state }) {
                return scene
            }
        }
        return candidates.first
    }

    /// Fork: Attaches the window to the preferred window scene when it has none (or only a disconnected one), e.g. it was
    /// created while no window scene was connected. Does nothing when it is already attached to a connected scene.
    func attachToSceneIfNeeded() {
        guard #available(iOS 13.0, *) else {
            return
        }
        if let windowScene = windowScene, windowScene.activationState != .unattached {
            return
        }
        guard let scene = EKWindow.preferredWindowScene, scene !== windowScene else {
            return
        }
        windowScene = scene
    }

    /// Fork: An entry window created while no window scene was connected (e.g. a background launch) has no scene and stays
    /// invisible, holding the entry queue. Attach it once a scene comes to the foreground. A window its provider has already
    /// let go of (rolled back, scene cleared on purpose) is left alone.
    @available(iOS 13.0, *)
    @objc private func sceneWillShow(_ notification: Notification) {
        guard EKWindowProvider.isEntryWindowInUse(self) else {
            return
        }
        attachToSceneIfNeeded()
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if isAbleToReceiveTouches {
            return super.hitTest(point, with: event)
        }
        
        guard let rootVC = EKWindowProvider.provider(for: windowLevel).rootVC else {
            return nil
        }
        
        if let view = rootVC.view.hitTest(point, with: event) {
            return view
        }
        
        return nil
    }
}
