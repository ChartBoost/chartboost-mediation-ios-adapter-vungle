Pod::Spec.new do |spec|
  spec.name        = 'ChartboostMediationAdapterVungle'
  spec.version     = '5.7.4.0.0'
  spec.license     = { :type => 'MIT', :file => 'LICENSE.md' }
  spec.homepage    = 'https://github.com/ChartBoost/chartboost-mediation-ios-adapter-vungle'
  spec.authors     = { 'Chartboost' => 'https://www.chartboost.com/' }
  spec.summary     = 'Chartboost Mediation iOS SDK Vungle adapter.'
  spec.description = 'Vungle Adapters for mediating through Chartboost Mediation. Supported ad formats: Banner, Interstitial, and Rewarded.'

  # Source
  spec.module_name  = 'ChartboostMediationAdapterVungle'
  spec.source       = { :git => 'https://github.com/ChartBoost/chartboost-mediation-ios-adapter-vungle.git', :tag => spec.version }
  spec.source_files = 'Source/**/*.{swift}'
  spec.resource_bundles = { 'ChartboostMediationAdapterVungle' => ['PrivacyInfo.xcprivacy'] }

  # Minimum supported versions
  spec.swift_version         = '5.0'
  spec.ios.deployment_target = '13.0'

  # System frameworks used
  spec.ios.frameworks = ['Foundation', 'UIKit']
  
  # This adapter is compatible with all Chartboost Mediation 5.X versions of the SDK.
  spec.dependency 'ChartboostMediationSDK', '~> 5.0'

  # Partner network SDK and version that this adapter is certified to work with.
  spec.dependency 'VungleAds', '~> 7.4.0'

  # The partner network SDK is a static framework which requires the static_framework option.
  spec.static_framework = true
end
