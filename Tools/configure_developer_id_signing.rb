#!/usr/bin/env ruby
# Configures Developer ID signing for the Release configuration of the
# MacDown and MacDownQuickLook targets, enabling hardened runtime and a
# secure timestamp so the resulting build can be notarized by Apple.
#
# Idempotent: re-running it just rewrites the same settings.

require 'xcodeproj'

PROJECT_PATH = File.expand_path('../../MacDown.xcodeproj', __FILE__)
TEAM_ID      = 'L2V57226NH'
IDENTITY     = 'Developer ID Application'
CONFIG_NAME  = 'Release'

TARGETS = {
  'MacDown'          => 'MacDown/MacDown.entitlements',
  'MacDownQuickLook' => 'MacDownQuickLook/MacDownQuickLook.entitlements',
}

project = Xcodeproj::Project.open(PROJECT_PATH)

TARGETS.each do |target_name, entitlements_path|
  target = project.targets.find { |t| t.name == target_name }
  raise "missing target: #{target_name}" unless target

  config = target.build_configurations.find { |c| c.name == CONFIG_NAME }
  raise "missing #{CONFIG_NAME} config on #{target_name}" unless config

  bs = config.build_settings
  bs['CODE_SIGN_STYLE']           = 'Manual'
  bs['DEVELOPMENT_TEAM']          = TEAM_ID
  bs['CODE_SIGN_IDENTITY']        = IDENTITY
  bs['CODE_SIGN_IDENTITY[sdk=macosx*]'] = IDENTITY
  bs['ENABLE_HARDENED_RUNTIME']   = 'YES'
  bs['OTHER_CODE_SIGN_FLAGS']     = '--timestamp'
  bs['CODE_SIGN_ENTITLEMENTS']    = entitlements_path
  puts "configured #{target_name} (#{CONFIG_NAME})"
end

project.save
puts 'project saved'
