Pod::Spec.new do |spec|
  spec.name        = 'ChartboostHeliumAdapterVungle'
  spec.version     = '4.6.12.1.0'
  spec.license     = { :type => 'MIT', :file => 'LICENSE.md' }
  spec.homepage    = 'https://github.com/ChartBoost/helium-ios-adapter-vungle'
  spec.authors     = { 'Chartboost' => 'https://www.chartboost.com/' }
  spec.summary     = 'Helium iOS SDK Vungle adapter.'
  spec.description = 'Vungle Adapters for mediating through Helium. Supported ad formats: Banner, Interstitial, and Rewarded.'

  # Source
  spec.module_name  = 'HeliumAdapterVungle'
  spec.source       = { :git => 'https://github.com/ChartBoost/helium-ios-adapter-vungle.git', :tag => '#{spec.version}' }
  spec.source_files = 'Source/**/*.{swift}'

  # Minimum supported versions
  spec.swift_version         = '5.0'
  spec.ios.deployment_target = '10.0'

  # System frameworks used
  spec.ios.frameworks = ['Foundation', 'UIKit']
  
  # This adapter is compatible with all Helium 4.X versions of the SDK.
  spec.dependency 'ChartboostHelium', '~> 4.0'

  # Partner network SDK and version that this adapter is certified to work with.
  spec.dependency 'VungleSDK-iOS', '6.12.1'

  # The partner network SDK is a static framework which requires the static_framework option.
  spec.static_framework = true
end
