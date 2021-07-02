//
//  AppDelegate.swift
//  ObjectDetectionSample
//
//  Created by Adarsh Manoharan on 26/06/3 R.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    

    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        self.setupRootController()
        return true
    }

}
// MARK: - Setup root view controller

// Pass the name for the model and label
extension AppDelegate {
    func setupRootController() {
        let rootViewController = CameraDetectionViewController(modelName: "model", labelName: "labels")
        self.window = UIWindow(frame: UIScreen.main.bounds)
        self.window?.rootViewController = UINavigationController(rootViewController: rootViewController)
        self.window?.makeKeyAndVisible()
    }

}
