#!/usr/bin/env ruby
# Adds the custom MPAboutWindowController source files and the LICENSE
# directory (as a folder reference) to MacDown.xcodeproj. Idempotent.

require 'xcodeproj'

PROJECT_PATH = File.expand_path('../../MacDown.xcodeproj', __FILE__)
project = Xcodeproj::Project.open(PROJECT_PATH)

target = project.targets.find { |t| t.name == 'MacDown' }
raise 'MacDown target missing' unless target

# Application group lives at MacDown > Application in the project (the
# on-disk path is Code/Application but the project group skips Code).
mac_group = project.main_group.children.find { |g| g.respond_to?(:display_name) && g.display_name == 'MacDown' } || raise('MacDown group missing')
app_group = mac_group.children.find { |g| g.respond_to?(:display_name) && g.display_name == 'Application' } || raise('Application group missing')

source_files = %w[MPAboutWindowController.h MPAboutWindowController.m]
source_files.each do |fname|
  existing = app_group.files.find { |f| f.display_name == fname }
  ref = existing || app_group.new_reference("Code/Application/#{fname}", :group)
  if fname.end_with?('.m')
    already = target.source_build_phase.files.any? { |bf| bf.file_ref == ref }
    target.add_file_references([ref]) unless already
  end
end

# Add LICENSE folder as a folder reference (blue folder) so the directory
# structure is preserved in the bundle and we can enumerate it at runtime.
existing_license = project.main_group.files.find { |f| f.path == 'LICENSE' && f.last_known_file_type == 'folder' }
license_ref = existing_license || project.main_group.new_reference('LICENSE')
license_ref.last_known_file_type = 'folder'
license_ref.set_path('LICENSE')

already_in_resources = target.resources_build_phase.files.any? { |bf| bf.file_ref == license_ref }
target.resources_build_phase.add_file_reference(license_ref) unless already_in_resources

project.save
puts 'added MPAboutWindowController.[hm] and LICENSE folder reference'
