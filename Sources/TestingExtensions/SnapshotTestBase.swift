//
//  SnapshotTestBase.swift
//  TestingExtensions
//
//  Created by Luiz Barbosa on 08.01.20.
//  Copyright © 2020 Lautsprecher Teufel GmbH. All rights reserved.
//

#if canImport(UIKit) && canImport(XCTest)
import Foundation
import SnapshotTesting
import SwiftUI
import XCTest
import AccessibilitySnapshot

extension SnapshotTestBase {
    public typealias DeviceConfiguration = (name: String, device: ViewImageConfig)
}

extension SnapshotTestBase {
    /// Configuration of Accessibility snapshots.
    public enum A11ySnapshotConfiguration {
        case disabled
        case enabled
        case enabledWithDevices([DeviceConfiguration])
    }
}

open class SnapshotTestBase: XCTestCase {
    public var allowAnimations: Bool = false

    override open func setUp() {
        super.setUp()
        UIView.setAnimationsEnabled(allowAnimations)
    }

    open var defaultDevices: [DeviceConfiguration] {
        [
            ("iPhone8", .iPhone8),
            ("iPhone13proMax", .iPhone13ProMax),
            ("iPadMini", .iPadMini(.portrait) ),
            ("iPadPro", .iPadPro12_9(.portrait))
        ]
    }
    
    open var a11yDefaultDevices: [DeviceConfiguration] {
        [
            ("iPhone13pro", .iPhone13)
        ]
    }
    
    /// Asserts snapshots on the given devices (or default) respecting it's parameters.
    /// - Parameters:
    ///   - view: The view to be snapshotted
    ///   - devices: Specified devices, if not given it'll take default devices
    ///   - a11ySnapshotConfiguration: Accessibility snapshot configuration, if enabled it adds a accessibility snapshot
    ///   - style: `UIUserInterfaceStyle` to be applied
    ///   - imageDiffPrecision: Precision of the compared images, 1 means it matches 100%, range is between 0 and 1.
    ///   - file: The file this was executed from, it will be taken as the snapshot's file name.
    ///   - testName: The test name taken as a part of the snapshot's file name.
    ///   - line: The line number on which failure occurred. Defaults to the line number on which this
    ///     function was called.
    open func assertSnapshotDevices<V: View>(
        _ view: V,
        devices: [DeviceConfiguration]? = nil,
        a11ySnapshotConfiguration: A11ySnapshotConfiguration = .disabled,
        style:  [UIUserInterfaceStyle] = [.unspecified],
        imageDiffPrecision: Float = 1.0,
        file: StaticString = #file,
        testName: String = #function,
        line: UInt = #line
    ) {
        (devices ?? defaultDevices).forEach { config in
            style.forEach { uiStyle in
                let vc = UIHostingController(rootView: view)
                vc.overrideUserInterfaceStyle = uiStyle

                let suffix: String = {
                    switch uiStyle {
                    case .unspecified:
                        return ""
                    case .light:
                        return "-light"
                    case .dark:
                        return "-dark"
                    @unknown default:
                        fatalError("Unhandled UIUserInterfaceStyle \(uiStyle)")
                    }
                }()
                
                assertSnapshot(
                    of: vc,
                    as: .image(on: config.device, precision: imageDiffPrecision),
                    file: file,
                    testName: "\(testName)-\(config.name)\(suffix)",
                    line: line
                )
            }
        }
        
        let a11ySnapshotDevices: [DeviceConfiguration]? = {
            switch a11ySnapshotConfiguration {
            case .disabled:
                return nil
            case .enabled:
                return a11yDefaultDevices
            case .enabledWithDevices(let specifiedDevices):
                return specifiedDevices
            }
        }()
        
        guard let a11ySnapshotDevices else { return }
        
        guard UIApplication.shared != nil else {
            XCTFail("Accessibility snapshots must be run from a hosting application!")
        }
        
        a11ySnapshotDevices.forEach { config in
            assertSnapshot(
                of: view,
                as: .accessibilityImage(showActivationPoints: .always, drawHierarchyInKeyWindow: true),
                file: file,
                testName: "\(testName)-\(config.name)-accessibility",
                line: line
            )
        }
    }
}
#endif
