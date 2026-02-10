Pod::Spec.new do |s|
  s.name     = 'BlurUIKit'
  s.version  = '1.3.0'
  s.license  =  { :type => 'MIT', :file => 'LICENSE' }
  s.summary  = 'An App Store safe framework for tapping into more of the dynamic blur capabilities of UIKit.'
  s.homepage = 'https://github.com/TimOliver/BlurUIKit'
  s.author   = 'Tim Oliver'
  s.source   = { :git => 'https://github.com/TimOliver/BlurUIKit.git', :tag => s.version }
  s.requires_arc = true
  s.swift_version = '6.0'
  s.ios.deployment_target   = '14.0'

  s.default_subspecs = 'UIKit'

  s.subspec 'UIKit' do |uikit|
    uikit.source_files = 'BlurUIKit/UIKit/**/*.{swift}', 'BlurUIKit/Internal/**/*.{swift}'
  end

  s.subspec 'SwiftUI' do |swiftui|
    swiftui.source_files = 'BlurUIKit/SwiftUI/**/*.{swift}'
    swiftui.dependency 'BlurUIKit/UIKit'
    swiftui.frameworks = 'SwiftUI'
  end
end
