require 'xcodeproj'
version = File.read('pubspec.yaml').match(/^version:\s*([^+\s]+)\+(\d+)/)
raise 'pubspec.yaml must declare version and build number' unless version
project = Xcodeproj::Project.open('ios/Runner.xcodeproj')
runner = project.targets.find { |t| t.name == 'Runner' }
widget = project.targets.find { |t| t.name == 'HolyHimWidget' }
raise 'Missing Runner or HolyHimWidget target' unless runner && widget
runner.add_dependency(widget) unless runner.dependencies.any? { |d| d.target == widget }
phase = runner.copy_files_build_phases.find { |p| p.name == 'Embed App Extensions' } || runner.new_copy_files_build_phase('Embed App Extensions')
phase.dst_subfolder_spec = '13'
phase.dst_path = ''
unless phase.files_references.include?(widget.product_reference)
 file = phase.add_file_reference(widget.product_reference)
 file.settings = {'ATTRIBUTES' => ['RemoveHeadersOnCopy']}
end
# Keep extension embedding before Flutter's final binary validation.
runner.build_phases.delete(phase)
thin = runner.build_phases.find { |p| p.respond_to?(:name) && p.name == 'Thin Binary' }
runner.build_phases.insert(thin ? runner.build_phases.index(thin) : runner.build_phases.length, phase)
group = project.main_group.find_subpath('HolyHimWidget', false) || project.main_group.groups.find { |g| g.path == 'HolyHimWidget' }
raise 'Missing widget source group' unless group
paths = ['WidgetVerses.json'] + Dir.glob('ios/HolyHimWidget/Art/*.jpg').map { |p| p.sub('ios/HolyHimWidget/', '') }
paths.each do |path|
 file = group.files.find { |f| f.path == path } || group.new_file(path)
 widget.resources_build_phase.add_file_reference(file) unless widget.resources_build_phase.files_references.include?(file)
end
widget.build_configurations.each do |config|
 config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
 config.build_settings['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
 config.build_settings['MARKETING_VERSION'] = version[1]
 config.build_settings['CURRENT_PROJECT_VERSION'] = version[2]
end
# Runner reads its build number from pubspec through Flutter's xcconfig.
runner.build_configurations.each { |config| config.build_settings['CURRENT_PROJECT_VERSION'] = '$(FLUTTER_BUILD_NUMBER)' }
project.save
puts "Runner embeds HolyHimWidget with its verified verse catalog and #{paths.length - 1} thumbnails."
