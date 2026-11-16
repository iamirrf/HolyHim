# frozen_string_literal: true

# App Store Connect steps for a HolyHim release, signed with an App Store
# Connect API key instead of an Apple ID session. The key file is read by
# fastlane from its path; it is never printed, copied or logged.
#
#   bash tool/asc_release.sh inspect        # read-only: version, build, review, subscriptions
#   bash tool/asc_release.sh metadata       # listing text, screenshots, review notes; no submission
#   bash tool/asc_release.sh attach-build   # select this release's build for the version
#   bash tool/asc_release.sh submit         # send the version to App Review
#
# The key comes from ASC_KEY_ID, ASC_ISSUER_ID and ASC_KEY_PATH.

require 'json'
require 'fileutils'
require 'tmpdir'
require 'spaceship'

ROOT = File.expand_path('..', __dir__)
BUNDLE_ID = 'com.holyhim.app'
RELEASE = JSON.parse(File.read(File.join(ROOT, 'config', 'release.json')))
VERSION = RELEASE.fetch('version')
BUILD = RELEASE.fetch('buildNumber').to_s

command = ARGV.first.to_s
abort('Usage: asc_release.rb inspect|metadata|attach-build|submit') unless %w[inspect metadata attach-build submit].include?(command)

API_KEY = {
  key_id: ENV.fetch('ASC_KEY_ID'),
  issuer_id: ENV.fetch('ASC_ISSUER_ID'),
  filepath: ENV.fetch('ASC_KEY_PATH')
}.freeze
abort('The App Store Connect key file is missing.') unless File.file?(API_KEY[:filepath])
Spaceship::ConnectAPI.token = Spaceship::ConnectAPI::Token.create(**API_KEY)

app = Spaceship::ConnectAPI::App.find(BUNDLE_ID)
abort('No HolyHim App Store record exists.') unless app

def api_get(path, params = {})
  Spaceship::ConnectAPI.client.tunes_request_client.get(path, params).body
rescue StandardError => e
  { 'error' => e.message.to_s[0, 300] }
end

def version_for(app)
  app.get_app_store_versions(filter: { versionString: VERSION, platform: 'IOS' }).first
end

def build_for(app)
  Spaceship::ConnectAPI::Build.all(app_id: app.id, version: VERSION, build_number: BUILD).first
end

case command
when 'inspect'
  versions = app.get_app_store_versions.map do |v|
    { version: v.version_string, state: v.app_store_state, release_type: v.release_type }
  end
  build = build_for(app)
  version = version_for(app)
  review = version&.fetch_app_store_review_detail rescue nil
  groups = api_get("v1/apps/#{app.id}/subscriptionGroups", { include: 'subscriptions,subscriptionGroupLocalizations' })
  groups = api_get("apps/#{app.id}/subscriptionGroups", { include: 'subscriptions,subscriptionGroupLocalizations' }) if groups['error']
  subs = (groups['included'] || []).select { |i| i['type'] == 'subscriptions' }.map do |s|
    a = s['attributes'] || {}
    { product: a['productId'], name: a['name'], state: a['state'], period: a['subscriptionPeriod'] }
  end
  group_locs = (groups['included'] || []).select { |i| i['type'] == 'subscriptionGroupLocalizations' }.map do |l|
    { locale: l.dig('attributes', 'locale'), name: l.dig('attributes', 'name'), state: l.dig('attributes', 'state') }
  end
  puts JSON.pretty_generate(
    app: { id: app.id, name: app.name, bundle_id: app.bundle_id },
    versions: versions,
    release_version: version && { id: version.id, state: version.app_store_state, build: version.build&.version },
    build: build && { id: build.id, version: build.version, processing: build.processing_state, expired: build.expired },
    review_detail: review && {
      contact_set: !review.contact_first_name.to_s.empty? && !review.contact_email.to_s.empty?,
      demo_required: review.demo_account_required,
      demo_user_set: !review.demo_account_name.to_s.empty?,
      notes_set: !review.notes.to_s.empty?
    },
    subscription_groups: (groups['data'] || []).map { |g| g.dig('attributes', 'referenceName') },
    subscription_group_localizations: group_locs,
    subscriptions: subs,
    errors: groups['error']
  )
when 'metadata'
  require 'deliver'
  submission = JSON.parse(File.read(File.join(ROOT, 'store', 'metadata', 'submission.json')))
  stage = Dir.mktmpdir('holyhim-metadata-')
  metadata = File.join(stage, 'metadata')
  localized = File.join(metadata, 'en-US')
  screenshots = File.join(stage, 'screenshots', 'en-US')
  FileUtils.mkdir_p([localized, screenshots])
  # The name stays as it was set in App Store Connect. A first release has
  # no "What's New", so release notes wait for the next version.
  %w[subtitle privacy_url description keywords support_url marketing_url promotional_text].each do |key|
    source = File.join(ROOT, 'store', 'metadata', 'en-US', "#{key}.txt")
    FileUtils.cp(source, File.join(localized, "#{key}.txt")) if File.file?(source)
  end
  copyright = File.join(ROOT, 'store', 'metadata', 'en-US', 'copyright.txt')
  FileUtils.cp(copyright, File.join(metadata, 'copyright.txt')) if File.file?(copyright)
  notes = File.read(File.join(ROOT, 'store', 'metadata', 'en-US', 'review_notes.txt')).strip
  abort('The review notes are empty; nothing was uploaded.') if notes.empty?
  images = Dir.glob(File.join(ROOT, 'store', 'screenshots', 'app-store', 'iphone-1290x2796', '0*.png')).sort
  abort("Expected 8 iPhone screenshots; found #{images.length}.") unless images.length == 8
  images.each { |image| FileUtils.cp(image, File.join(screenshots, File.basename(image))) }
  values = {
    api_key: API_KEY, app_identifier: BUNDLE_ID, app_version: VERSION, platform: 'ios',
    metadata_path: metadata, screenshots_path: File.dirname(screenshots),
    primary_category: submission['primaryCategory'], secondary_category: submission['secondaryCategory'],
    skip_binary_upload: true, submit_for_review: false, force: true,
    overwrite_screenshots: true, run_precheck_before_submit: false, skip_app_version_update: false
  }
  # Review notes only, set before fastlane runs: it expects the review detail
  # to exist. The reviewer contact and demo account stay as entered in App
  # Store Connect.
  version = version_for(app) || app.get_edit_app_store_version(platform: 'IOS')
  abort('No editable App Store version exists.') unless version
  detail = begin
    version.fetch_app_store_review_detail
  rescue StandardError
    nil
  end
  if detail
    detail.update(attributes: { notes: notes })
  else
    version.create_app_store_review_detail(attributes: { notes: notes })
  end
  config = FastlaneCore::Configuration.create(Deliver::Options.available_options, values)
  Deliver::Runner.new(config).run
  FileUtils.remove_entry(stage)
  puts "Listing, screenshots and review notes uploaded for #{VERSION}. Nothing was submitted."
when 'attach-build'
  version = version_for(app) or abort("No #{VERSION} version exists yet; run metadata first.")
  build = build_for(app) or abort("Build #{BUILD} is not in App Store Connect yet.")
  abort("Build #{BUILD} is still #{build.processing_state}.") unless build.processing_state == 'VALID'
  version.select_build(build_id: build.id)
  puts "Build #{VERSION} (#{BUILD}) is selected for the #{VERSION} version."
when 'submit'
  version = version_for(app) or abort("No #{VERSION} version exists.")
  abort("Select build #{BUILD} first.") unless version.build&.version == BUILD
  submission = app.get_ready_review_submission(platform: 'IOS') || app.create_review_submission(platform: 'IOS')
  submission.add_app_store_version_to_review_items(app_store_version_id: version.id)
  submission.submit_for_review
  puts "#{VERSION} (#{BUILD}) is submitted to App Review."
end
