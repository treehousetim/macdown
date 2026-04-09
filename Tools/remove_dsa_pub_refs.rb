#!/usr/bin/env ruby
# Removes the dsa_pub.pem file reference and its build phase entries
# from MacDown.xcodeproj. The file itself was deleted along with Sparkle.

require 'xcodeproj'

PROJECT_PATH = File.expand_path('../../MacDown.xcodeproj', __FILE__)

project = Xcodeproj::Project.open(PROJECT_PATH)

ref = project.files.find { |f| f.path == 'Resources/dsa_pub.pem' }
if ref.nil?
  puts 'no dsa_pub.pem reference found, nothing to do'
  exit 0
end

# Strip from any build phases that include it.
project.targets.each do |t|
  t.build_phases.each do |bp|
    next unless bp.respond_to?(:files_references)
    bp.files.each do |bf|
      if bf.file_ref == ref
        bp.remove_build_file(bf)
        puts "removed dsa_pub.pem from #{t.name}/#{bp.display_name}"
      end
    end
  end
end

ref.remove_from_project
puts 'removed file reference'
project.save
puts 'saved'
