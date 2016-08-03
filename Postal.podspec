Pod::Spec.new do |s|
  s.name = 'Postal'
  s.version = '0.0.2'
  s.summary = 'A swift framework for working with emails.'
  s.description = 'A Swift framework for working with emails. Simple and quick to use. Built on top of libetpan.'
  s.homepage = 'https://github.com/snipsco/Postal'
  s.license = 'MIT'
  s.author = { 'Kevin Lefevre' => 'kevin.lefevre@snips.ai', 'Jeremie Girault' => 'jeremie.girault@gmail.com' }

  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.10'

  s.source = { :git => 'https://github.com/snipsco/Postal.git', :tag => s.version.to_s }
  
  s.default_subspec = 'Core'

  s.subspec 'Core' do |sp|
    sp.source_files  = 'Postal/*.{swift,h}'

    sp.pod_target_xcconfig = {
      'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) NO_MACROS=1'
    }
    sp.ios.pod_target_xcconfig = {
      'SWIFT_INCLUDE_PATHS' => '"$(SRCROOT)/Postal/dependencies" "$(SRCROOT)/Postal/dependencies/build/ios/include"',
      'LIBRARY_SEARCH_PATHS' => '"$(SRCROOT)/Postal/dependencies/build/ios/lib"',
      'HEADER_SEARCH_PATHS' => '"$(SRCROOT)/Postal/dependencies/build/ios/include"'
    }
    s.osx.pod_target_xcconfig = {
      'SWIFT_INCLUDE_PATHS' => '"$(SRCROOT)/Postal/dependencies" "$(SRCROOT)/Postal/dependencies/build/macos/include"',
      'LIBRARY_SEARCH_PATHS' => '"$(SRCROOT)/Postal/dependencies/build/macos/lib"',
      'HEADER_SEARCH_PATHS' => '"$(SRCROOT)/Postal/dependencies/build/macos/include"'
    }
    sp.preserve_paths = 'dependencies'

    sp.libraries = 'etpan', 'sasl2', 'z', 'iconv'
    sp.dependency 'Result', '~> 2.1.3'
  end

  s.subspec 'ReactiveCocoa' do |sp|
    sp.source_files = 'Postal/ReactiveCocoa/*.swift'
    sp.dependency "Postal/Core"
    sp.dependency 'ReactiveCocoa', '~> 4.2.1'
  end

end
