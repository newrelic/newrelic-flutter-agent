#
#   Copyright (c) 2022-present New Relic Corporation. All rights reserved.
#   SPDX-License-Identifier: Apache-2.0
#

#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint newrelic_mobile.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'newrelic_mobile'
  s.version          = '1.1.12'
  s.summary          = 'Flutter plugin for NewRelic Mobile.'
  s.description      = <<-DESC
Flutter plugin for NewRelic Mobile.
                       DESC
  s.homepage         = '"https://docs.newrelic.com/docs/mobile-monitoring/new-relic-mobile/get-started/introduction-mobile-monitoring/"'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'New Relic' => 'mobile-agents@newrelic.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '9.0'

  s.dependency 'NewRelicAgent', '~>7.5.8'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end