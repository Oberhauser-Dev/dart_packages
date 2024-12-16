require 'xcodeproj'

# Ensure the script is called with two arguments
if ARGV.length < 2
  puts "Usage: ruby get_bundle_id_product.rb <project_path> <bundle_id> <build_configuration>"
  exit 1
end

# Read arguments from the command line
project_path = ARGV[0]
bundle_id = ARGV[1]
build_configuration = ARGV[2]

# Open the Xcode project
project = Xcodeproj::Project.open(project_path)

# Find the target with the given bundle ID
matching_target = project.targets.find do |target|
  resolved_bundle_id = target.resolved_build_setting("PRODUCT_BUNDLE_IDENTIFIER")[build_configuration]
  resolved_bundle_id == bundle_id
end

if matching_target
  puts matching_target.name
end
