#!/usr/bin/env ruby
# Use only the owner's existing private Apple session. Never prompts for a
# password, reads Keychain passwords, revokes certificates, or deletes profiles.
source = File.read(File.join(__dir__, 'apple_release_setup.rb'))
eval(source.split(/^options = \{\}/).first, TOPLEVEL_BINDING, File.join(__dir__, 'apple_release_setup.rb'))
begin
  state_dir = File.join(Dir.home, 'Library', 'Application Support', 'HolyHim', 'apple-release')
  ENV['SPACESHIP_COOKIE_PATH'] = state_dir
  ENV['FASTLANE_TEAM_ID'] = DEVELOPER_TEAM
  account_path = File.join(state_dir, 'account.json')
  account = if File.file?(account_path)
    JSON.parse(File.read(account_path))
  else
    cookies = Dir.glob(File.join(state_dir, 'spaceship', '*', 'cookie'))
    raise HolyHimSessionError, 'No unique saved Apple session was found.' unless cookies.length == 1
    {'apple_id' => File.basename(File.dirname(cookies.first))}
  end
  Spaceship::Client.prepend(HolyHimSessionOnlyClient)
  session = HolyHimSavedSession.new(account.fetch('apple_id'))
  session.portal
  apps = ['com.holyhim.app', 'com.holyhim.app.widget'].map { |id| Spaceship::Portal.app.find(id) }
  groups = Spaceship::Portal.app_group.all.select { |g| g.group_id == 'group.com.holyhim.app' }
  puts JSON.pretty_generate(session: 'valid', expected_team: true,
    app_identifiers: apps.map { |a| a&.bundle_id }, holyhim_group_registered: !groups.empty?)
rescue HolyHimSessionError => error
  warn error.message
  exit 2
rescue StandardError => error
  warn "Widget signing inspection stopped (#{error.class}). No credential fallback or portal mutation was attempted."
  exit 2
end
