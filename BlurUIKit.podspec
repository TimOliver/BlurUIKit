Pod::Spec.new do |s|
  s.name     = 'BlurUIKit'
  s.version  = '1.2.1'
  s.license  =  { :type => 'MIT', :file => 'LICENSE' }
  s.summary  = 'An App Store safe framework for tapping into more of the dynamic blur capabilities of UIKit.'
  s.homepage = 'https://github.com/TimOliver/BlurUIKit'
  s.author   = 'Tim Oliver'
  s.source   = { :git => 'https://github.com/TimOliver/BlurUIKit.git', :tag => s.version }
  s.source_files = 'BlurUIKit/**/*.{swift}'
  s.requires_arc = true
  s.swift_version = '6.0'
  s.ios.deployment_target   = '14.0'
end
