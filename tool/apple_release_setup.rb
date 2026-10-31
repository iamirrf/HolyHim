#!/usr/bin/env ruby
# Grounded in installed fastlane 2.229.1's Spaceship/Deliver interfaces.
# https://docs.fastlane.tools/getting-started/ios/authentication/
# https://docs.fastlane.tools/actions/deliver/
# No App Store API-key creation endpoint is assumed or called.
require 'optparse'
require 'io/console'
require 'json'
require 'fileutils'
require 'tmpdir'
require 'time'
require 'uri'
require 'cgi'
require 'logger'
require 'digest'
require 'open3'
require 'stringio'
# Keep this credential-bearing process off SDK debug proxies and HTTP traces.
%w[DEBUG SPACESHIP_DEBUG SPACESHIP_PROXY SPACESHIP_PROXY_SSL_VERIFY_NONE].each { |name| ENV.delete(name) }
require 'spaceship'

# Compatibility shim from fastlane's current upstream fix for #30199/#30291.
# https://github.com/fastlane/fastlane/blob/master/spaceship/lib/spaceship/client.rb
# A fresh connection sends no cookies and does NOT follow the signout redirect.
# The removed Olympus config endpoint and its stale /tmp cache are never used.
module HolyHerAppleDiscovery
  def self.fetch
    return @result if @result
    connection = Faraday.new(url: 'https://appstoreconnect.apple.com') do |http|
      http.options.open_timeout = 15
      http.options.timeout = 20
      http.adapter(Faraday.default_adapter)
    end
    response = connection.head('/logout')
    location = URI.parse(response.headers['location'].to_s)
    key = CGI.parse(location.query.to_s).fetch('widgetKey', []).first.to_s
    unless [301, 302, 303, 307, 308].include?(response.status) && location.scheme == 'https' && location.host == 'idmsa.apple.com' && !key.empty?
      raise "Apple login discovery returned HTTP #{response.status} without the expected public widgetKey redirect."
    end
    @result = { key: key, status: response.status, redirect_host: location.host }
  end
end

module HolyHerSpaceshipCompatibility
  def itc_service_key
    @service_key ||= HolyHerAppleDiscovery.fetch.fetch(:key)
  end

  # Older fastlane logs every HTTP body. Keep credentials, cookies and SRP
  # exchanges out of persistent logs; normal SDK status output remains visible.
  def logger
    @holyher_safe_logger ||= Logger.new(File::NULL)
  end
end
Spaceship::Client.prepend(HolyHerSpaceshipCompatibility)

BUNDLE_ID = 'com.holyher.app'
DEVELOPER_TEAM = 'DU9D6TAM58'
TEAM_NAME = 'Codellion LLC'
VERSION = '1.0.0'
RELEASE_AT = Time.iso8601('2026-11-15T06:00:00-05:00').utc
ROOT = File.expand_path('..', __dir__)

# Session reuse is deliberately separate from Client#login: that SDK method
# reads Keychain credentials BEFORE checking a saved session. These interfaces
# are present in the installed fastlane 2.229.1 source (client.rb:673,728 and
# connect_api/client.rb:75); no password, placeholder password, or environment
# session is passed to the SDK when --reuse-session is selected.
class HolyHerSessionError < StandardError; end
class HolyHerReviewNotesError < StandardError; end

module HolyHerSessionOnlyClient
  def login(*)
    raise HolyHerSessionError, 'Saved-session mode never requests credentials. Run the owner Terminal login command again.'
  end

  private

  def do_login(*)
    raise HolyHerSessionError, 'The saved Apple session expired. Run the owner Terminal login command again.'
  end

  def send_shared_login_request(*)
    raise HolyHerSessionError, 'Saved-session mode does not start an Apple login.'
  end
end

class HolyHerSavedSession
  def initialize(email)
    @email = email
  end

  def load_cookie(client)
    client.user = @email
    path = client.persistent_cookie_path
    info = File.lstat(path)
    unless info.file? && !info.symlink? && info.uid == Process.uid && (info.mode & 0o077).zero? && info.size.between?(1, 1_048_576)
      raise HolyHerSessionError, 'The saved Apple cookie is not a private, owner-controlled file.'
    end
    # The old SDK prints parser exceptions. Suppress only the cookie loader's
    # output so malformed credential contents cannot enter a terminal/log.
    previous_out, previous_err = $stdout, $stderr
    begin
      $stdout, $stderr = StringIO.new, StringIO.new
      loaded = client.load_session_from_file
    ensure
      $stdout, $stderr = previous_out, previous_err
    end
    raise HolyHerSessionError, 'No usable saved Apple session exists. Run the owner Terminal login command once.' unless loaded
    client
  rescue Errno::ENOENT
    raise HolyHerSessionError, 'No saved Apple session exists. Run the owner Terminal login command once.'
  end

  def tunes
    return @tunes if @tunes
    client = load_cookie(Spaceship::TunesClient.new)
    raise HolyHerSessionError, 'The saved Apple session expired. Run the owner Terminal login command again.' unless client.fetch_olympus_session
    if !client.user_email.to_s.empty? && !client.user_email.casecmp(@email).zero?
      raise HolyHerSessionError, 'The saved cookie belongs to a different Apple account.'
    end
    teams = client.teams
    matches = teams.select { |team| team['publicProviderId'] == DEVELOPER_TEAM }
    matches = teams.select { |team| team['name'] == TEAM_NAME } if matches.empty?
    raise HolyHerSessionError, 'The saved session does not uniquely identify Codellion LLC.' unless matches.length == 1
    team = matches.first
    if !team['publicProviderId'].to_s.empty? && team['publicProviderId'] != DEVELOPER_TEAM
      raise HolyHerSessionError, 'The saved session belongs to a different developer team.'
    end
    expected_id = team.fetch('providerId').to_s
    client.select_team(team_id: expected_id)
    raise HolyHerSessionError, 'Apple did not select the expected App Store team.' unless client.team_id.to_s == expected_id
    Spaceship::Tunes.client = client
    @tunes = client
  end

  def portal
    return @portal if @portal
    client = load_cookie(Spaceship::PortalClient.new)
    unless client.teams.any? { |team| team['teamId'] == DEVELOPER_TEAM }
      raise HolyHerSessionError, 'The saved session does not include the HolyHer developer team.'
    end
    client.select_team(team_id: DEVELOPER_TEAM)
    raise HolyHerSessionError, 'Apple did not select the expected developer team.' unless client.team_id == DEVELOPER_TEAM
    Spaceship::Portal.client = client
    @portal = client
  end

  def client(user = nil, password = nil, use_portal: true, use_tunes: true,
             portal_team_id: nil, tunes_team_id: nil, team_name: nil, **)
    if (!user.to_s.empty? && !user.to_s.casecmp(@email).zero?) || !password.to_s.empty?
      raise HolyHerSessionError, 'Saved-session mode cannot switch account or accept a password.'
    end
    if (!portal_team_id.to_s.empty? && portal_team_id != DEVELOPER_TEAM) || (!team_name.to_s.empty? && team_name != TEAM_NAME)
      raise HolyHerSessionError, 'Saved-session mode cannot switch developer teams.'
    end
    tunes_client = use_tunes ? tunes : nil
    if !tunes_team_id.to_s.empty? && tunes_client&.team_id.to_s != tunes_team_id.to_s
      raise HolyHerSessionError, 'Saved-session mode cannot switch App Store teams.'
    end
    portal_client = use_portal ? portal : nil
    Spaceship::ConnectAPI.client = Spaceship::ConnectAPI::Client.new(tunes_client: tunes_client, portal_client: portal_client)
  rescue HolyHerSessionError
    raise
  rescue StandardError
    raise HolyHerSessionError, 'Apple could not validate the saved session. Run the owner Terminal login command again; no password fallback was attempted.'
  end
end

# Deliver and the privacy action call ConnectAPI.login themselves. In reuse
# mode intercept that adapter call and return only the verified cookie clients.
module HolyHerSessionOnlyConnectAPI
  attr_accessor :holyher_saved_session

  def login(*args, **kwargs)
    raise HolyHerSessionError, 'No saved-session factory is configured.' unless holyher_saved_session
    holyher_saved_session.client(*args, **kwargs)
  end
end

# Installed Deliver::UploadMetadata#review_information sets demo_account_required
# false when given notes alone. Keep the documented app_review_information option,
# but send a notes-only SDK update so existing review contact/credentials survive.
# Source: deliver/lib/deliver/upload_metadata.rb:654-685 and the installed
# AppStoreVersion / AppStoreReviewDetail models. Private fields stay in memory;
# they are never copied into Deliver options, a file, or a terminal message.
module HolyHerNotesOnlyReview
  PRESERVED_FIELDS = %i[contact_first_name contact_last_name contact_phone contact_email
                       demo_account_name demo_account_password demo_account_required].freeze

  private

  def holyher_review_details(version)
    # An included optional relationship distinguishes "no detail yet" from an
    # authorization/server failure without rescuing a 404-shaped error string.
    snapshot = Spaceship::ConnectAPI::AppStoreVersion.get(
      app_store_version_id: version.id, includes: 'appStoreReviewDetail')
    raise HolyHerReviewNotesError, 'Apple did not return the requested version for review notes.' unless snapshot&.id == version.id
    snapshot.app_store_review_detail
  end

  def review_information(version)
    info = options[:app_review_information]
    return if info.nil? || info.empty?
    unless info.is_a?(Hash) && info.keys.map(&:to_sym).sort == [:notes]
      raise HolyHerReviewNotesError, 'This helper accepts prepared review notes only; enter reviewer contact and credentials securely in App Store Connect.'
    end
    notes = (info[:notes] || info['notes']).to_s.strip
    raise HolyHerReviewNotesError, 'The prepared review narrative is empty.' if notes.empty?
    existing = holyher_review_details(version)
    preserved = existing && PRESERVED_FIELDS.to_h { |field| [field, existing.public_send(field)] }
    if existing
      existing.update(attributes: { notes: notes })
    else
      version.create_app_store_review_detail(attributes: { notes: notes })
    end
    readback = holyher_review_details(version)
    raise HolyHerReviewNotesError, 'Apple review-notes read-back did not match.' unless readback&.notes == notes
    if preserved && PRESERVED_FIELDS.any? { |field| readback.public_send(field) != preserved[field] }
      raise HolyHerReviewNotesError, 'Reviewer details changed during notes upload. No contact or credential values were sent or printed; inspect the current details securely in App Store Connect.'
    end
    puts 'Prepared review notes saved and verified. Existing reviewer contact, demo credentials, and demo requirement were preserved.'
  rescue HolyHerReviewNotesError
    raise
  rescue StandardError => error
    raise HolyHerReviewNotesError, "The notes-only review upload stopped (#{error.class}); no private reviewer values were printed or included in the update."
  end

  def review_attachment_file(version)
    # Old Deliver otherwise deletes every existing attachment when no new file
    # was specified. This helper does not request attachment replacement.
    return if options[:app_review_attachment_file].nil?
    super
  end
end

# Read-only gate inspection uses raw JSON from the installed authenticated SDK
# transport so newer Apple fields are not discarded by its older models. Paths,
# includes and field names were checked against Apple's OpenAPI 4.5.1 download:
# https://developer.apple.com/sample-code/app-store-connect/app-store-connect-openapi-specification.zip
# SHA256 7b826ae9ca3e45b0e7df2643cbb811c9930632640944db11a8af4586fab9db46
# No POST/PATCH/DELETE domain request or automatic questionnaire answer exists.
module HolyHerReleaseGates
  SPEC_VERSION = '4.5.1'
  SPEC_SHA256 = '7b826ae9ca3e45b0e7df2643cbb811c9930632640944db11a8af4586fab9db46'
  AGE_FIELDS = %w[advertising alcoholTobaccoOrDrugUseOrReferences contests gambling gamblingSimulated
    gunsOrOtherWeapons healthOrWellnessTopics kidsAgeBand lootBox medicalOrTreatmentInformation
    messagingAndChat parentalControls profanityOrCrudeHumor ageAssurance sexualContentGraphicAndNudity
    sexualContentOrNudity socialMedia socialMediaAgeRestricted horrorOrFearThemes matureOrSuggestiveThemes
    unrestrictedWebAccess userGeneratedContent violenceCartoonOrFantasy violenceRealisticProlongedGraphicOrSadistic
    violenceRealistic ageRatingOverride ageRatingOverrideV2 koreaAgeRatingOverride].freeze

  def self.one(path, params = {})
    body = Spaceship::ConnectAPI.client.tunes_request_client.get(path, params).body
    raise 'Unexpected Apple JSON document' unless body.is_a?(Hash)
    body
  end

  def self.many(path, params = {})
    response = Spaceship::ConnectAPI.client.tunes_request_client.get(path, { 'limit' => 200 }.merge(params))
    pages = response.next_pages(count: 9)
    { 'data' => pages.flat_map { |page| Array(page.body['data']) },
      'included' => pages.flat_map { |page| Array(page.body['included']) },
      'complete' => pages.last.next_url.nil? }
  end

  def self.related(resource, name)
    resource&.dig('relationships', name, 'data')
  end

  def self.included(body, relationship)
    return nil unless relationship.is_a?(Hash)
    Array(body['included']).find { |item| item['type'] == relationship['type'] && item['id'] == relationship['id'] }
  end

  def self.check
    yield.merge(inspected: true)
  rescue HolyHerSessionError
    raise
  rescue StandardError => error
    # Apple responses may contain reviewer details. Emit only the class, never
    # the response, exception message, private fields, or a Ruby backtrace.
    { inspected: false, error_type: error.class.name, result: 'Unavailable; no answer or mutation was attempted.' }
  end

  def self.price(app_id)
    schedule = one("v1/apps/#{app_id}/appPriceSchedule")['data']
    return { configured: false } unless schedule
    collections = %w[manualPrices automaticPrices].map do |kind|
      many("v1/appPriceSchedules/#{schedule.fetch('id')}/#{kind}", 'include' => 'appPricePoint,territory')
    end
    today = Time.now.utc.strftime('%Y-%m-%d')
    rows = collections.flat_map do |body|
      body['data'].filter_map do |resource|
        attributes = resource['attributes'] || {}
        next if attributes['startDate'] && attributes['startDate'] > today
        next if attributes['endDate'] && attributes['endDate'] <= today
        point = included(body, related(resource, 'appPricePoint'))
        { territory: related(resource, 'territory')&.fetch('id', nil),
          price: point&.dig('attributes', 'customerPrice') }
      end
    end
    prices = rows.filter_map { |row| row[:price] }.uniq.sort
    resolved = rows.all? { |row| row[:price].is_a?(String) }
    complete = collections.all? { |body| body['complete'] }
    { configured: true, base_territory: related(schedule, 'baseTerritory')&.fetch('id', nil),
      as_of_utc_date: today, current_price_records: rows.length,
      current_price_territories: rows.filter_map { |row| row[:territory] }.uniq.length,
      observed_customer_prices: prices, collection_complete: complete,
      all_observed_current_prices_are_free: complete && resolved && !prices.empty? && prices.all? { |value| value.match?(/\A0+(?:\.0+)?\z/) } }
  end

  def self.availability(app_id)
    availability = one("v1/apps/#{app_id}/appAvailabilityV2")['data']
    return { configured: false } unless availability
    rows = many("v2/appAvailabilities/#{availability.fetch('id')}/territoryAvailabilities", 'include' => 'territory')
    attributes = rows['data'].map { |row| row['attributes'] || {} }
    { configured: true, available_in_new_territories: availability.dig('attributes', 'availableInNewTerritories'),
      territory_records: attributes.length, available_territories: attributes.count { |row| row['available'] == true },
      preorder_territories: attributes.count { |row| row['preOrderEnabled'] == true },
      content_status_counts: attributes.flat_map { |row| row['contentStatuses'] || [] }.tally,
      collection_complete: rows['complete'] }
  end

  def self.ages(app_id)
    infos = many("v1/apps/#{app_id}/appInfos", 'include' => 'ageRatingDeclaration')
    { collection_complete: infos['complete'], app_infos: infos['data'].map do |info|
      declaration = included(infos, related(info, 'ageRatingDeclaration'))
      attributes = declaration&.fetch('attributes', {}) || {}
      { app_info_id: info['id'], state: info.dig('attributes', 'state') || info.dig('attributes', 'appStoreState'),
        calculated_rating: info.dig('attributes', 'appStoreAgeRating'), declaration_present: !declaration.nil?,
        answers: attributes.select { |key, _| AGE_FIELDS.include?(key) },
        unset_or_inapplicable_fields: AGE_FIELDS.reject { |key| attributes.key?(key) && !attributes[key].nil? },
        age_suitability_url_present: !attributes['developerAgeRatingInfoUrl'].to_s.empty?,
        korea_classification_number_present: !attributes['gracRatingClassificationNumber'].to_s.empty? }
    end }
  end

  def self.review(version_id)
    return { version_present: false } unless version_id
    body = one("v1/appStoreVersions/#{version_id}", 'include' => 'appStoreReviewDetail,build,appStoreVersionSubmission')
    version = body['data']
    detail = included(body, related(version, 'appStoreReviewDetail'))
    attrs = detail&.fetch('attributes', {}) || {}
    presence = %w[contactFirstName contactLastName contactPhone contactEmail demoAccountName demoAccountPassword notes].to_h do |field|
      ["#{field}_present", !attrs[field].to_s.empty?]
    end
    { version_present: true, review_detail_present: !detail.nil?,
      contact_complete: %w[contactFirstName contactLastName contactPhone contactEmail].all? { |key| presence["#{key}_present"] },
      demo_account_required: attrs['demoAccountRequired'], field_presence: presence,
      demo_password_may_be_redacted_by_apple: true,
      selected_build_present: !related(version, 'build').nil?,
      selected_build_id: related(version, 'build')&.fetch('id', nil),
      version_submission_present: !related(version, 'appStoreVersionSubmission').nil? }
  end

  def self.builds(app_id)
    rows = many('v1/builds', 'filter[app]' => app_id, 'include' => 'appEncryptionDeclaration,preReleaseVersion')
    { collection_complete: rows['complete'], count: rows['data'].length, builds: rows['data'].map do |build|
      declaration = included(rows, related(build, 'appEncryptionDeclaration'))
      attrs = declaration&.fetch('attributes', {}) || {}
      { id: build['id'], build_number: build.dig('attributes', 'version'),
        app_version: included(rows, related(build, 'preReleaseVersion'))&.dig('attributes', 'version'),
        processing_state: build.dig('attributes', 'processingState'), expired: build.dig('attributes', 'expired'),
        uses_non_exempt_encryption: build.dig('attributes', 'usesNonExemptEncryption'),
        encryption_declaration_present: !declaration.nil?,
        encryption: attrs.select { |key, _| %w[exempt containsProprietaryCryptography containsThirdPartyCryptography availableOnFrenchStore appEncryptionDeclarationState].include?(key) } }
    end }
  end

  def self.purchases(app_id, version_id)
    purchases = many("v1/apps/#{app_id}/inAppPurchasesV2", 'include' => 'appStoreReviewScreenshot,versions')
    lifetime = purchases['data'].find { |item| item.dig('attributes', 'productId') == 'holyher_lifetime' }
    expected_versions = Array(related(lifetime, 'versions')).map { |item| item['id'] }
    submissions = many("v1/apps/#{app_id}/reviewSubmissions", 'include' => 'appStoreVersionForReview')
    matches = version_id ? submissions['data'].select { |item| related(item, 'appStoreVersionForReview')&.fetch('id', nil) == version_id } : []
    checks = matches.map do |submission|
      items = many("v1/reviewSubmissions/#{submission.fetch('id')}/items", 'include' => 'appStoreVersion,inAppPurchaseVersion')
      { state: submission.dig('attributes', 'state'), items_complete: items['complete'],
        contains_current_app_version: items['data'].any? { |item| related(item, 'appStoreVersion')&.fetch('id', nil) == version_id },
        contains_lifetime_iap_version: items['data'].any? { |item| expected_versions.include?(related(item, 'inAppPurchaseVersion')&.fetch('id', nil)) } }
    end
    { lifetime_product_present: !lifetime.nil?, state: lifetime&.dig('attributes', 'state'),
      review_screenshot_present: !related(lifetime, 'appStoreReviewScreenshot').nil?,
      lifetime_version_ids_returned: expected_versions.length,
      matching_review_submissions: checks, collection_complete: purchases['complete'] && submissions['complete'],
      attachment_scope: 'Only association with a matching review submission is checked. Absence does not prove an unsent portal selection is missing.' }
  end

  def self.inspect(app, version)
    report = { app_id: app.id, bundle_id: BUNDLE_ID, version_id: version&.id,
      checked_at: Time.now.utc.iso8601, mode: 'read-only', openapi_version: SPEC_VERSION, openapi_sha256: SPEC_SHA256 }
    report[:content_rights] = check do
      attrs = one("v1/apps/#{app.id}", 'fields[apps]' => 'bundleId,contentRightsDeclaration')['data'].fetch('attributes')
      raise 'Unexpected app identity' unless attrs['bundleId'] == BUNDLE_ID
      { declaration: attrs['contentRightsDeclaration'] }
    end
    report[:download_pricing] = check { price(app.id) }
    report[:app_availability] = check { availability(app.id) }
    report[:age_rating] = check { ages(app.id) }
    report[:review_details] = check { review(version&.id) }
    report[:builds_and_encryption] = check { builds(app.id) }
    report[:in_app_purchase_submission] = check { purchases(app.id, version&.id) }
    report
  end
end

module HolyHerPrivacy
  CATEGORY_IDS = {
    'Name' => 'NAME', 'Email Address' => 'EMAIL_ADDRESS', 'Phone Number' => 'PHONE_NUMBER',
    'Coarse Location' => 'COARSE_LOCATION', 'Sensitive Info' => 'SENSITIVE_INFO',
    'User ID' => 'USER_ID', 'Device ID' => 'DEVICE_ID', 'Purchase History' => 'PURCHASE_HISTORY',
    'Product Interaction' => 'PRODUCT_INTERACTION', 'Other Usage Data' => 'OTHER_USAGE_DATA',
    'Customer Support' => 'CUSTOMER_SUPPORT', 'Other Data Types' => 'OTHER_DATA',
    'Other Diagnostic Data' => 'OTHER_DIAGNOSTIC_DATA'
  }.freeze
  PURPOSE_IDS = {
    'App Functionality' => 'APP_FUNCTIONALITY',
    'Product Personalization' => 'PRODUCT_PERSONALIZATION', 'Analytics' => 'ANALYTICS'
  }.freeze

  def self.reviewed_baseline(path)
    content = File.binread(path)
    baseline = JSON.parse(content)
    rows = baseline.fetch('dataTypes')
    raise 'Privacy baseline has no data types.' unless rows.is_a?(Array) && !rows.empty?
    converted = rows.map do |row|
      category = CATEGORY_IDS.fetch(row.fetch('type'))
      linked = row.fetch('linkedToUser')
      tracking = row.fetch('usedForTracking')
      raise 'Privacy protections must be explicit booleans.' unless [true, false].include?(linked) && [true, false].include?(tracking)
      purposes = row.fetch('purposes').map { |purpose| PURPOSE_IDS.fetch(purpose) }.uniq.sort
      raise 'Each collected category requires a purpose.' if purposes.empty?
      protections = [linked ? 'DATA_LINKED_TO_YOU' : 'DATA_NOT_LINKED_TO_YOU']
      protections << 'DATA_USED_TO_TRACK_YOU' if tracking
      { 'category' => category, 'purposes' => purposes, 'data_protections' => protections.sort }
    end.sort_by { |row| row.fetch('category') }
    raise 'Duplicate privacy categories.' unless converted.map { |row| row['category'] }.uniq.length == rows.length
    tracked = rows.any? { |row| row.fetch('usedForTracking') }
    raise 'Global tracking declaration does not match categories.' unless baseline.fetch('dataUsedForTracking') == tracked
    [converted, Digest::SHA256.hexdigest(content)]
  end

  def self.triples(usages)
    usages.flat_map do |row|
      row.fetch('purposes').product(row.fetch('data_protections')).map { |purpose, protection| [row.fetch('category'), purpose, protection] }
    end.uniq.sort
  end

  def self.remote_rows(app)
    Spaceship::ConnectAPI::AppDataUsage.all(app_id: app.id, includes: 'category,grouping,purpose,dataProtection', limit: 500).map do |usage|
      { id: usage.id, category: usage.category&.id, purpose: usage.purpose&.id, protection: usage.data_protection&.id }
    end
  end
end

def with_apple_password(password)
  return yield if password.nil?
  previous = ENV['FASTLANE_PASSWORD']
  ENV['FASTLANE_PASSWORD'] = password
  yield
ensure
  unless password.nil?
    previous ? ENV['FASTLANE_PASSWORD'] = previous : ENV.delete('FASTLANE_PASSWORD')
  end
end

def upload_archive(archive_path, state_dir)
  export_dir = Dir.mktmpdir('archive-upload-', state_dir)
  export_plist = File.join(export_dir, 'ExportOptions.plist')
  # These keys/options are documented by this Mac's installed xcodebuild -help.
  # Xcode creates/updates distribution signing resources using its own account.
  File.write(export_plist, <<~PLIST, mode: 'w', perm: 0o600)
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0"><dict>
      <key>method</key><string>app-store-connect</string>
      <key>destination</key><string>upload</string>
      <key>signingStyle</key><string>automatic</string>
      <key>teamID</key><string>DU9D6TAM58</string>
      <key>manageAppVersionAndBuildNumber</key><false/>
    </dict></plist>
  PLIST
  uploaded = system('/usr/bin/xcodebuild', '-exportArchive', '-archivePath', archive_path,
    '-exportOptionsPlist', export_plist, '-exportPath', export_dir, '-allowProvisioningUpdates')
  abort('Xcode did not confirm the archive upload. Inspect its signing/account status above.') unless uploaded
  puts 'Xcode completed archive export/upload. App Store processing and App Review are separate.'
end

options = {}
parser = OptionParser.new do |p|
  p.banner = 'Usage: bash tool/apple_release_setup.sh [options]'
  p.on('--check', 'Check installed SDK interfaces; no login or remote changes') { options[:check] = true }
  p.on('--check-auth-discovery', 'Verify the public cookie-free Apple login redirect; no account login') { options[:discovery] = true }
  p.on('--apple-id EMAIL', 'Apple ID; password is requested privately in Terminal') { |v| options[:email] = v }
  p.on('--reuse-session', 'Use only the private saved Apple cookie; never prompt, inspect Keychain, or fall back to login') { options[:reuse_session] = true }
  p.on('--inspect', 'Log in and read the existing HolyHer app/version') { options[:inspect] = true }
  p.on('--inspect-release-gates', 'Read pricing, availability, current age answers, review completeness, builds/encryption and IAP review association; never answer or mutate') { options[:release_gates] = true }
  p.on('--create-app', 'Create missing HolyHer bundle ID and App Store app record') { options[:create] = true }
  p.on('--upload-metadata', 'Upload prepared listing/screenshots; never upload a build or submit review') { options[:metadata] = true }
  p.on('--upload-archive PATH', 'Export/upload an existing xcarchive using the signed-in Xcode account') { |v| options[:archive] = v }
  p.on('--privacy-preview', 'Print the exact converted privacy baseline; no login or upload') { options[:privacy_preview] = true }
  p.on('--upload-privacy', 'Back up existing answers and replace the privacy draft; do not publish') { options[:privacy_upload] = true }
  p.on('--publish-privacy', 'Publish only when the remote draft exactly matches the reviewed baseline') { options[:privacy_publish] = true }
  p.on('--schedule-release', 'Set no-earlier-than Nov 15, 2026, 06:00 EST; never submit review') { options[:schedule] = true }
  p.on('-h', '--help', 'Show this help') { puts p; exit }
end
parser.parse!
abort('Unexpected positional arguments; use --help.') unless ARGV.empty?

if options[:check]
  checks = {
    login: Spaceship::ConnectAPI.respond_to?(:login),
    app_find: Spaceship::ConnectAPI::App.respond_to?(:find),
    app_create: Spaceship::ConnectAPI::App.respond_to?(:create),
    bundle_create: Spaceship::ConnectAPI::BundleId.respond_to?(:create),
    version_update: Spaceship::ConnectAPI::AppStoreVersion.instance_methods.include?(:update),
    certificate_create: Spaceship::ConnectAPI::Certificate.respond_to?(:create)
  }
  checks[:session_loader] = Spaceship::TunesClient.instance_methods.include?(:load_session_from_file)
  checks[:session_validator] = Spaceship::TunesClient.instance_methods.include?(:fetch_olympus_session)
  checks[:explicit_session_clients] = Spaceship::ConnectAPI.respond_to?(:client=) && Spaceship::Tunes.respond_to?(:client=) && Spaceship::Portal.respond_to?(:client=)
  require 'deliver'
  checks[:deliver_runner] = Deliver::Runner.instance_methods.include?(:run)
  checks[:deliver_review_notes] = Deliver::Options.available_options.any? { |option| option.key == :app_review_information } && Deliver::UploadMetadata.private_instance_methods.include?(:review_information)
  checks[:legacy_iphone_size] = Deliver::AppScreenshot.devices.values.any? { |sizes| sizes.include?([1179, 2556]) }
  checks[:legacy_ipad_size] = Deliver::AppScreenshot.devices.values.any? { |sizes| sizes.include?([2048, 2732]) }
  require 'fastlane'
  require 'fastlane/actions/upload_app_privacy_details_to_app_store'
  checks[:privacy_action] = Fastlane::Actions::UploadAppPrivacyDetailsToAppStoreAction.respond_to?(:run)
  privacy, = HolyHerPrivacy.reviewed_baseline(File.join(ROOT, 'store', 'metadata', 'privacy_labels.json'))
  checks[:privacy_baseline] = privacy.length == 13
  checks[:xcodebuild] = File.executable?('/usr/bin/xcodebuild')
  puts JSON.pretty_generate(checks.merge(release_utc: RELEASE_AT.iso8601, release_milliseconds: (RELEASE_AT.to_f * 1000).to_i))
  exit(checks.values.all? ? 0 : 1)
end

if options[:privacy_preview]
  privacy, digest = HolyHerPrivacy.reviewed_baseline(File.join(ROOT, 'store', 'metadata', 'privacy_labels.json'))
  puts JSON.pretty_generate(source: 'store/metadata/privacy_labels.json', source_sha256: digest, categories: privacy.length, entries: privacy)
  exit
end

if options[:discovery]
  result = HolyHerAppleDiscovery.fetch
  puts JSON.pretty_generate(status: result[:status], redirect_host: result[:redirect_host], widget_key_present: !result[:key].empty?, cookies_sent: false, redirects_followed: false)
  exit
end

unless options.values_at(:inspect, :release_gates, :create, :metadata, :schedule, :privacy_upload, :privacy_publish, :archive).any?
  puts parser
  exit
end
# Validate the archive before requesting credentials or making remote changes.
if options[:archive]
  archive_path = File.expand_path(options[:archive])
  apps = Dir.glob(File.join(archive_path, 'Products', 'Applications', '*.app'))
  abort('Provide a complete .xcarchive containing exactly one application.') unless archive_path.end_with?('.xcarchive') && apps.length == 1
  identifier, _, status = Open3.capture3('/usr/bin/plutil', '-extract', 'CFBundleIdentifier', 'raw', '-o', '-', File.join(apps.first, 'Info.plist'))
  abort('The archive does not contain com.holyher.app.') unless status.success? && identifier.strip == BUNDLE_ID
  options[:archive] = archive_path
end
# Archive-only uploads can use the existing Xcode account without asking for a
# second Apple ID password or opening a new Spaceship session.
if options[:archive] && !options.values_at(:inspect, :release_gates, :create, :metadata, :schedule, :privacy_upload, :privacy_publish).any?
  File.umask(0o077)
  standalone_state = File.join(Dir.home, 'Library', 'Application Support', 'HolyHer', 'apple-release')
  FileUtils.mkdir_p(standalone_state, mode: 0o700)
  File.chmod(0o700, standalone_state)
  upload_archive(options[:archive], standalone_state)
  exit
end
begin
File.umask(0o077)
state_dir = File.join(Dir.home, 'Library', 'Application Support', 'HolyHer', 'apple-release')
FileUtils.mkdir_p(state_dir, mode: 0o700)
File.chmod(0o700, state_dir)
# Spaceship will persist its own authenticated cookie here with restrictive umask.
ENV['SPACESHIP_COOKIE_PATH'] = state_dir
ENV['FASTLANE_TEAM_ID'] = DEVELOPER_TEAM
ENV['FASTLANE_ITC_TEAM_NAME'] = TEAM_NAME
account_path = File.join(state_dir, 'account.json')
email = options[:email].to_s.strip
password = nil
if options[:reuse_session]
  if email.empty?
    abort('No saved HolyHer Apple account exists. Run the owner Terminal login command once.') unless File.file?(account_path)
    email = JSON.parse(File.read(account_path)).fetch('apple_id')
  end
  abort('The saved Apple ID is invalid.') unless email.include?('@') && !email.match?(%r{[\\/\s]})
  Spaceship::Client.prepend(HolyHerSessionOnlyClient)
  Spaceship::ConnectAPI.singleton_class.prepend(HolyHerSessionOnlyConnectAPI)
  session = HolyHerSavedSession.new(email)
  Spaceship::ConnectAPI.holyher_saved_session = session
  session.client(email, use_portal: !!options[:create], use_tunes: true,
    portal_team_id: DEVELOPER_TEAM, team_name: TEAM_NAME)
  puts 'Using the verified private HolyHer Apple session. Password login and Keychain access are disabled.'
else
  # Fail before requesting credentials if public Apple discovery is unavailable.
  HolyHerAppleDiscovery.fetch
  abort('Run this helper directly in Terminal so credentials and 2FA stay private.') unless $stdin.tty? && $stdout.tty?
  if email.empty?
    print 'Apple ID: '
    email = $stdin.gets.to_s.strip
  end
  abort('Enter a valid Apple ID email.') unless email.include?('@') && !email.match?(%r{[\\/\s]})
  password = $stdin.getpass('Apple ID password (not saved by this helper): ')
  abort('A password is required.') if password.empty?
  # Supplying BOTH arguments avoids CredentialsManager's Keychain lookup.
  Spaceship::ConnectAPI.login(email, password,
    use_portal: !!options[:create], use_tunes: true,
    portal_team_id: DEVELOPER_TEAM, team_name: TEAM_NAME)
  # Tunes' name selection can otherwise fall back to a sole/default team.
  selected_team = Spaceship::ConnectAPI.client.tunes_teams.find do |team|
    team['providerId'].to_s == Spaceship::ConnectAPI.client.tunes_team_id.to_s
  end
  correct_team = selected_team && (selected_team['publicProviderId'].to_s.empty? ? selected_team['name'] == TEAM_NAME : selected_team['publicProviderId'] == DEVELOPER_TEAM)
  abort('Apple selected a different App Store team; no HolyHer records were changed.') unless correct_team
  if options[:create] && Spaceship::ConnectAPI.client.portal_team_id != DEVELOPER_TEAM
    abort('Apple selected a different developer team; no HolyHer records were changed.')
  end
  File.write(account_path, JSON.pretty_generate(apple_id: email, developer_team_id: DEVELOPER_TEAM) + "\n", mode: 'w', perm: 0o600)
end

if options[:create]
  bundle = Spaceship::ConnectAPI::BundleId.find(BUNDLE_ID)
  bundle ||= Spaceship::ConnectAPI::BundleId.create(name: 'HolyHer', identifier: BUNDLE_ID, platform: 'IOS')
  abort('Apple did not return the expected bundle identifier.') unless bundle&.identifier == BUNDLE_ID
end

app = Spaceship::ConnectAPI::App.find(BUNDLE_ID)
if app.nil? && options[:create]
  Spaceship::ConnectAPI::App.create(name: 'HolyHer', version_string: VERSION,
    sku: BUNDLE_ID, primary_locale: 'en-US', bundle_id: BUNDLE_ID, platforms: ['IOS'])
  6.times do
    app = Spaceship::ConnectAPI::App.find(BUNDLE_ID)
    break if app
    sleep 1
  end
end
abort('No HolyHer App Store record exists. Run again with --create-app.') unless app

if options[:metadata]
  require 'deliver'
  Deliver::UploadMetadata.prepend(HolyHerNotesOnlyReview)
  submission = JSON.parse(File.read(File.join(ROOT, 'store', 'metadata', 'submission.json')))
  abort('The prepared metadata belongs to a different bundle.') unless submission['bundleId'] == BUNDLE_ID
  stage = Dir.mktmpdir('metadata-stage-', state_dir)
  metadata = File.join(stage, 'metadata')
  localized = File.join(metadata, 'en-US')
  screenshots = File.join(stage, 'screenshots', 'en-US')
  FileUtils.mkdir_p([localized, screenshots])
  %w[name subtitle privacy_url description keywords release_notes support_url marketing_url promotional_text].each do |key|
    source = File.join(ROOT, 'store', 'metadata', 'en-US', "#{key}.txt")
    FileUtils.cp(source, File.join(localized, "#{key}.txt")) if File.file?(source)
  end
  copyright = File.join(ROOT, 'store', 'metadata', 'en-US', 'copyright.txt')
  FileUtils.cp(copyright, File.join(metadata, 'copyright.txt')) if File.file?(copyright)
  review_notes = File.read(File.join(ROOT, 'store', 'metadata', 'en-US', 'review_notes.txt')).strip
  abort('The prepared review narrative is empty; metadata was not uploaded.') if review_notes.empty?
  %w[iphone-1206x2622 ipad-2064x2752].each do |device|
    images = Dir.glob(File.join(ROOT, 'store', 'screenshots', 'app-store', device, '*.png')).sort
    abort("Expected five prepared screenshots for #{device}.") unless images.length == 5
    # fastlane 2.229.1 predates the new capture sizes. These slightly smaller
    # alternatives are also accepted by Apple's current screenshot specification.
    # Convert staged copies only; preserve the original reviewed upload artwork.
    width, height, prefix = device.start_with?('iphone') ? [1179, 2556, 'APP_IPHONE_61'] : [2048, 2732, 'IPAD_PRO_3GEN_129']
    images.each do |image|
      target = File.join(screenshots, "#{prefix}-#{File.basename(image)}")
      converted = system('/usr/bin/sips', '-z', height.to_s, width.to_s, image, '--out', target,
        out: File::NULL, err: File::NULL)
      abort('A staged screenshot could not be converted.') unless converted
      classified = Deliver::AppScreenshot.new(target, 'en-US')
      abort('The installed SDK does not recognize a staged screenshot.') unless classified.device_type
    end
  end
  values = {
    username: email, app_identifier: BUNDLE_ID, app_version: VERSION, platform: 'ios',
    metadata_path: metadata, screenshots_path: File.dirname(screenshots),
    app_review_information: { notes: review_notes },
    primary_category: submission['primaryCategory'], secondary_category: submission['secondaryCategory'],
    skip_binary_upload: true, submit_for_review: false, force: true,
    run_precheck_before_submit: false
  }
  config = FastlaneCore::Configuration.create(Deliver::Options.available_options, values)
  # Deliver reuses Spaceship cookies; the transient in-process password prevents
  # its login adapter from trying the Keychain. It is never a command argument.
  with_apple_password(password) do
    Deliver::Runner.new(config).run
  end
  puts 'Prepared metadata and screenshots uploaded. No build or review submission was sent.'
end

if options[:archive]
  upload_archive(options[:archive], state_dir)
end

if options[:privacy_upload] || options[:privacy_publish]
  require 'fastlane'
  require 'fastlane/actions/upload_app_privacy_details_to_app_store'
  privacy, privacy_digest = HolyHerPrivacy.reviewed_baseline(File.join(ROOT, 'store', 'metadata', 'privacy_labels.json'))
  # Check Apple's current vocabulary before invoking the built-in replacement.
  categories = Spaceship::ConnectAPI::AppDataUsageCategory.all.map(&:id)
  purposes = Spaceship::ConnectAPI::AppDataUsagePurpose.all.map(&:id)
  abort('Apple privacy categories or purposes no longer match the reviewed baseline.') unless privacy.all? { |row| categories.include?(row['category']) && (row['purposes'] - purposes).empty? }
  desired = HolyHerPrivacy.triples(privacy)
  if options[:privacy_upload]
    backup = File.join(state_dir, "privacy-before-#{Time.now.utc.strftime('%Y%m%dT%H%M%S')}.json")
    File.write(backup, JSON.pretty_generate(HolyHerPrivacy.remote_rows(app)) + "\n", mode: 'w', perm: 0o600)
    converted_path = File.join(state_dir, "privacy-reviewed-#{privacy_digest[0, 12]}.json")
    File.write(converted_path, JSON.pretty_generate(privacy) + "\n", mode: 'w', perm: 0o600)
    action = Fastlane::Actions::UploadAppPrivacyDetailsToAppStoreAction
    params = FastlaneCore::Configuration.create(action.available_options, {
      username: email, team_name: TEAM_NAME, app_identifier: BUNDLE_ID,
      json_path: converted_path, skip_publish: true
    })
    with_apple_password(password) { action.run(params) }
    puts "Privacy draft replaced from #{privacy_digest}; previous answers saved to #{backup}."
  end
  actual = []
  5.times do
    actual = HolyHerPrivacy.remote_rows(app).map { |row| [row[:category], row[:purpose], row[:protection]] }.uniq.sort
    break if actual == desired
    sleep 1
  end
  abort('Privacy draft read-back did not match; nothing was published. Inspect the saved backup and retry.') unless actual == desired
  if options[:privacy_publish]
    state = Spaceship::ConnectAPI::AppDataUsagesPublishState.get(app_id: app.id)
    state.publish! unless state.published
    readback = Spaceship::ConnectAPI::AppDataUsagesPublishState.get(app_id: app.id)
    abort('Apple did not confirm the privacy answers as published.') unless readback.published
    puts 'The matching reviewed privacy answers are published.'
  else
    puts 'Privacy read-back matches. Answers remain an unpublished draft for final archive review.'
  end
end

if options[:schedule]
  abort('The requested release date has passed; update the reviewed release configuration.') unless RELEASE_AT > Time.now
  app.ensure_version!(VERSION, platform: Spaceship::ConnectAPI::Platform::IOS)
  version = app.get_edit_app_store_version(platform: Spaceship::ConnectAPI::Platform::IOS)
  abort('The expected editable 1.0.0 version was not returned.') unless version&.version_string == VERSION
  version.update(attributes: { releaseType: Spaceship::ConnectAPI::AppStoreVersion::ReleaseType::SCHEDULED,
    earliestReleaseDate: RELEASE_AT.iso8601 })
  readback = Spaceship::ConnectAPI::AppStoreVersion.get(app_store_version_id: version.id)
  abort('Release policy read-back did not match.') unless readback.release_type == 'SCHEDULED' && Time.parse(readback.earliest_release_date) == RELEASE_AT
  puts "Saved: automatic release after approval, no earlier than #{RELEASE_AT.iso8601} (Nov 15, 06:00 EST)."
end

version = app.get_edit_app_store_version(platform: Spaceship::ConnectAPI::Platform::IOS)
if options[:release_gates]
  gates = HolyHerReleaseGates.inspect(app, version)
  gates_path = File.join(state_dir, 'release-gates.json')
  File.write(gates_path, JSON.pretty_generate(gates) + "\n", mode: 'w', perm: 0o600)
  puts JSON.pretty_generate(gates)
  puts "Sanitized release-gate inspection saved to #{gates_path}. No gate answers were changed."
end
public_config = {
  bundle_id: BUNDLE_ID, app_store_id: app.id,
  developer_team_id: DEVELOPER_TEAM,
  app_store_team_id: Spaceship::ConnectAPI.client.tunes_team_id,
  version: version&.version_string, release_type: version&.release_type,
  earliest_release_date: version&.earliest_release_date,
  checked_at: Time.now.utc.iso8601
}
config_path = File.join(state_dir, 'app.json')
File.write(config_path, JSON.pretty_generate(public_config) + "\n", mode: 'w', perm: 0o600)
puts JSON.pretty_generate(public_config)
puts "Non-secret app configuration saved to #{config_path}. Credentials were not written to the project."
rescue HolyHerSessionError, HolyHerReviewNotesError => error
  abort(error.message)
rescue StandardError => error
  if options[:reuse_session]
    abort("The saved-session operation stopped (#{error.class}). No password or login fallback was attempted. Check Apple account/session status in the owner's Terminal.")
  end
  raise
end
