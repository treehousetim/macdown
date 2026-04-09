#!/usr/bin/env ruby
# Removes the "Update Build Number" Run Script build phase from the
# MacDown target. The fork manages versions by editing MacDown-Info.plist
# directly and tagging, so the auto-versioning script is unnecessary and
# its execution order races with ProcessInfoPlistFile on clean builds.
# Idempotent.

require 'xcodeproj'

PROJECT_PATH = File.expand_path('../../MacDown.xcodeproj', __FILE__)
project = Xcodeproj::Project.open(PROJECT_PATH)

target = project.targets.find { |t| t.name == 'MacDown' }
raise 'MacDown target missing' unless target

removed = 0
target.build_phases.dup.each do |phase|
  next unless phase.is_a?(Xcodeproj::Project::Object::PBXShellScriptBuildPhase)
  if phase.name == 'Update Build Number'
    target.build_phases.delete(phase)
    removed += 1
  end
end

if removed.zero?
  puts 'no Update Build Number phase found, nothing to do'
else
  project.save
  puts "removed #{removed} Update Build Number phase(s)"
end
