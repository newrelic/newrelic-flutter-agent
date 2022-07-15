#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint newrelic_mobile.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'newrelic_mobile'
  s.version          = '0.0.1'
  s.summary          = 'Flutter plugin for NewRelic Mobile.'
  s.description      = <<-DESC
Flutter plugin for NewRelic Mobile.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '9.0'

  s.dependency 'NewRelicAgent', '7.3.7'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
