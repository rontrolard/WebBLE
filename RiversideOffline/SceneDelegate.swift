//
//  SceneDelegate.swift
//  RiversideOffline
//
//  Created by trolardr on 2/20/26.
//


import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let _ = (scene as? UIWindowScene) else { return }
    }
    var viewController: ViewController? {
        get {
            guard let nc = self.window?.rootViewController as? UINavigationController,
                let vc = nc.topViewController as? ViewController else {
                    return nil
            }
            return vc
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        print("Disconnecting");
        guard let vc = viewController else {
            NSLog("viewController unavailable!")
            return
        }
        vc.abortIfNeeded();
    }
    func sceneDidBecomeActive(_ scene: UIScene) {}
    func sceneWillResignActive(_ scene: UIScene) {}
    func sceneWillEnterForeground(_ scene: UIScene) {}
    func sceneDidEnterBackground(_ scene: UIScene) {
        print("Entering background");
        guard let vc = viewController else {
            NSLog("viewController unavailable!")
            return
        }
        vc.abortIfNeeded();

    }
}
