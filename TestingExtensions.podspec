
Pod::Spec.new do |s|
    s.name             = 'TestingExtensions'
    s.version          = '0.2.12'
    s.summary          = 'Testing helpers and extensions for SwiftRex and Combine'
  
    s.homepage         = 'https://github.com/SwiftRex/TestingExtensions'
    s.license          = { :type => 'Apache', :text => '© 2022 Luiz Barbosa' }
    s.author           = { 'Luiz Barbosa' => 'swiftrex@developercity.de' }
    s.source           = { :git => 'https://github.com/SwiftRex/TestingExtensions.git', :tag => s.version.to_s }
  
    s.ios.deployment_target       = '13.0'
    s.osx.deployment_target       = '10.15'
    s.swift_version               = '5.5'
  
    s.source_files = 'Sources/**/*.swift'
  
    s.frameworks = 'XCTest', 'SwiftUI'

    s.dependency 'SwiftRex', '~> 0.8.12'
    s.dependency 'CombineRex', '~> 0.8.12'
    s.dependency 'SnapshotTesting', '~> 1.8.2'
  end
