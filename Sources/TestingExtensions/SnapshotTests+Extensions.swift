//
//  SnapshotTests+Extensions.swift
//  TestingExtensions
//
//  Created by Luiz Barbosa on 15.04.20.
//  Copyright © 2020 Lautsprecher Teufel GmbH. All rights reserved.
//

import Foundation
import SnapshotTesting
import SwiftUI
#if canImport(UIKit)
import UIKit

extension Snapshotting where Value: UIViewController, Format == UIImage {
    public static var windowedImage: Snapshotting {
        Snapshotting<UIImage, UIImage>.image.asyncPullback { vc in
            Async<UIImage> { callback in
                UIView.setAnimationsEnabled(false)
                let window = UIApplication.shared.windows.first!
                window.rootViewController = vc
                DispatchQueue.main.async {
                    let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                        window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                    }
                    callback(image)
                    UIView.setAnimationsEnabled(true)
                }
            }
        }
    }
}

extension Snapshotting where Value: View, Format == UIImage {
    public static var image: Snapshotting {
        Snapshotting<UIViewController, UIImage>.image.asyncPullback { view in
            Async<UIViewController> { callback in
                UIView.setAnimationsEnabled(false)
                let vc = UIHostingController(rootView: view)
                vc.view.frame = UIScreen.main.bounds
                DispatchQueue.main.async {
                    callback(vc)
                    UIView.setAnimationsEnabled(true)
                }
            }
        }
    }
}
#endif
