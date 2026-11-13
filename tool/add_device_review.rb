require 'xcodeproj'
p=Xcodeproj::Project.open('ios/Runner.xcodeproj')
runner=p.targets.find{|t|t.name=='Runner'}
target=p.targets.find{|t|t.name=='HolyHimDeviceReview'} || p.new_target(:ui_test_bundle,'HolyHimDeviceReview',:ios,'16.0')
target.add_dependency(runner) unless target.dependencies.any?{|d|d.target==runner}
group=p.main_group.find_subpath('HolyHimDeviceReview',true)
group.set_source_tree('<group>');group.set_path('HolyHimDeviceReview')
file=group.files.find{|f|f.path=='DeviceReviewTests.swift'} || group.new_file('DeviceReviewTests.swift')
target.source_build_phase.add_file_reference(file) unless target.source_build_phase.files_references.include?(file)
target.build_configurations.each do |c|
 c.build_settings.merge!({'PRODUCT_NAME'=>'$(TARGET_NAME)','PRODUCT_BUNDLE_IDENTIFIER'=>'com.holyhim.app.devicereview','GENERATE_INFOPLIST_FILE'=>'YES','DEVELOPMENT_TEAM'=>'DU9D6TAM58','CODE_SIGN_STYLE'=>'Automatic','SWIFT_VERSION'=>'5.0','TEST_TARGET_NAME'=>'Runner','TARGETED_DEVICE_FAMILY'=>'1,2','SUPPORTED_PLATFORMS'=>'iphoneos'})
end
p.save
scheme=Xcodeproj::XCScheme.new
scheme.add_build_target(runner)
scheme.add_build_target(target)
scheme.add_test_target(target)
scheme.test_action.build_configuration='Profile'
scheme.save_as(p.path,'HolyHimDeviceReview',true)
puts 'Prepared read-only device review; no simulator target or runtime is used.'
