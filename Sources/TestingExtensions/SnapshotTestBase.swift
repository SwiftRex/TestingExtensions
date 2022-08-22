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

open class SnapshotTestBase: XCTestCase {
    public var allowAnimations: Bool = false

    override open func setUp() {
        super.setUp()
        UIView.setAnimationsEnabled(allowAnimations)
    }

    open var defaultDevices: [(name: String, device: ViewImageConfig)] {
        [
            ("SE", .iPhoneSe),
            ("X", .iPhoneX),
            ("iPadMini", .iPadMini(.portrait) ),
            ("iPadPro", .iPadPro12_9(.portrait))
        ]
    }

    open func assertSnapshotDevices<V: View>(
        _ view: V,
        devices: [(name: String, device: ViewImageConfig)]? = nil,
        style:  [UIUserInterfaceStyle] = [.unspecified],
        imageDiffPrecision: Float = 1.0,
        subpixelThreshold: UInt8 = 0, // only available with https://github.com/pimms/swift-snapshot-testing
        file: StaticString = #file,
        testName: String = #function,
        line: UInt = #line
    ) {
        (devices ?? defaultDevices).forEach { config in
            style.forEach { uiStyle in
                let vc = UIHostingController(rootView: view)
                vc.overrideUserInterfaceStyle = uiStyle

                let suffix: String
                switch uiStyle {
                case .unspecified:
                    suffix = ""
                case .light:
                    suffix = "-light"
                case .dark:
                    suffix = "-dark"
                @unknown default:
                    fatalError("Unhandled UIUserInterfaceStyle \(uiStyle)")
                }

                assertSnapshot(
                    matching: vc,
                    as: .image(on: config.device, precision: imageDiffPrecision, subpixelThreshold: subpixelThreshold),
                    file: file,
                    testName: "\(testName)-\(config.name)\(suffix)",
                    line: line
                )
            }
        }
    }

    /// Asserts that a given value matches a reference on disk. Adopted from
    /// https://github.com/pointfreeco/swift-snapshot-testing/discussions/553#discussioncomment-1862560
    /// to make testing on Xcode-cloud possible. Depending on the CI / CI_PRIMARY_REPOSITORY_PATH environment
    /// variables, we point snapshot test to a different snapshotDirectoryUrl.
    ///
    /// - Parameters:
    ///   - value: A value to compare against a reference.
    ///   - snapshotting: A strategy for serializing, deserializing, and comparing values.
    ///   - name: An optional description of the snapshot.
    ///   - recording: Whether or not to record a new reference.
    ///   - timeout: The amount of time a snapshot must be generated in.
    ///   - file: The file in which failure occurred. Defaults to the file name of the test case in which this function was called.
    ///   - testName: The name of the test in which failure occurred. Defaults to the function name of the test case in which this function was called.
    ///   - line: The line number on which failure occurred. Defaults to the line number on which this function was called.
    public func assertSnapshot<Value, Format>(
      matching value: @autoclosure () throws -> Value,
      as snapshotting: Snapshotting<Value, Format>,
      named name: String? = nil,
      record recording: Bool = false,
      timeout: TimeInterval = 5,
      file: StaticString = #file,
      testName: String = #function,
      line: UInt = #line
      ) {
          let isCI = ProcessInfo.processInfo.environment["CI"] == "TRUE"
          guard let srcRoot: String = ProcessInfo.processInfo.environment["CI_PRIMARY_REPOSITORY_PATH"] else {
              let failure = verifySnapshot(
                  matching: try value(),
                  as: snapshotting,
                  named: name,
                  record: recording,
                  timeout: timeout,
                  file: file,
                  testName: testName
              )
              guard let message = failure else { return }
              XCTFail(message, file: file, line: line)
              return
          }

          let sourceRoot = URL(fileURLWithPath: srcRoot, isDirectory: true)
          let fileUrl = URL(fileURLWithPath: "\(file)", isDirectory: false)
          let fileName = fileUrl.deletingPathExtension().lastPathComponent

          let absoluteSourceTestPath = fileUrl
              .deletingLastPathComponent()
              .appendingPathComponent("__Snapshots__")
              .appendingPathComponent(fileName)
          var components = absoluteSourceTestPath.pathComponents
          let sourceRootComponents = sourceRoot.pathComponents
          for component in sourceRootComponents {
              if components.first == component {
                  components = Array(components.dropFirst())
              } else {
                  XCTFail("Test file does not share a prefix path with CI_PRIMARY_REPOSITORY_PATH")
                  return
              }
          }
          var snapshotDirectoryUrl = sourceRoot
          if isCI {
              snapshotDirectoryUrl = snapshotDirectoryUrl.appendingPathComponent("ci_scripts")
              snapshotDirectoryUrl = snapshotDirectoryUrl.appendingPathComponent("Artifacts")
          }
          for component in components {
              snapshotDirectoryUrl = snapshotDirectoryUrl.appendingPathComponent(component)
          }

          let failure = verifySnapshot(
              matching: try value(),
              as: snapshotting,
              named: name,
              record: recording,
              snapshotDirectory: snapshotDirectoryUrl.path,
              timeout: timeout,
              file: file,
              testName: testName
          )
          guard let message = failure else { return }
          XCTFail("\(message) snap: \(snapshotDirectoryUrl)", file: file, line: line)
    }
}

#endif
