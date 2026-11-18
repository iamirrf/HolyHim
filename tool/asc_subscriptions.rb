# frozen_string_literal: true

# Creates HolyHim's membership in App Store Connect with the App Store Connect
# API key: the subscription group "HolyHim Membership" and its two yearly
# subscriptions, each 1.99 USD in the United States with prices equalized
# for every other storefront except China mainland, the free week on
# holyhim_annual_trial, the en-US names, review notes and the review
# screenshot (store/iap-review/offer.png). Safe to re-run: whatever already
# exists is kept, and nothing is submitted.
#
#   source ~/.config/holyhim/asc.env && bash tool/asc_subscriptions.sh
#
# The key comes from ASC_KEY_ID, ASC_ISSUER_ID and ASC_KEY_PATH; the key file
# is read only to sign requests, never printed or copied.

require 'json'
require 'net/http'
require 'uri'
require 'digest'
require 'spaceship'

ROOT = File.expand_path('..', __dir__)
BUNDLE_ID = 'com.holyhim.app'
GROUP = 'HolyHim Membership'
US_PRICE = '1.99'
LEFT_OUT = %w[CHN].freeze # China mainland needs a licence HolyHim does not hold
SCREENSHOT = File.join(ROOT, 'store', 'iap-review', 'offer.png')
DISPLAY = { name: 'HolyHim Membership', description: 'Every lesson, every morning, all year.' }.freeze
REVIEW_NOTE = 'Yearly HolyHim membership; it opens every lesson. The offer appears after the welcome. ' \
              'Its free-trial switch chooses holyhim_annual_trial (one-week free trial for new subscribers) ' \
              'or holyhim_annual (no trial). Restore purchases is on the offer and in Profile.'
PRODUCTS = [
  { id: 'holyhim_annual_trial', reference: 'HolyHim Membership, free week', trial: true },
  { id: 'holyhim_annual', reference: 'HolyHim Membership', trial: false }
].freeze

def bearer
  if @token.nil? || Time.now - @made > 400 # fastlane tokens last 500 s by default
    @token = Spaceship::ConnectAPI::Token.create(key_id: ENV.fetch('ASC_KEY_ID'),
                                                 issuer_id: ENV.fetch('ASC_ISSUER_ID'),
                                                 filepath: ENV.fetch('ASC_KEY_PATH'))
    @made = Time.now
  end
  @token.text
end

def api(method, path, body = nil, params = nil)
  uri = path.start_with?('http') ? URI(path) : URI("https://api.appstoreconnect.apple.com/#{path}")
  uri.query = URI.encode_www_form(params) if params
  request = Net::HTTP.const_get(method.to_s.capitalize).new(uri)
  request['Authorization'] = "Bearer #{bearer}"
  request['Content-Type'] = 'application/json'
  request.body = JSON.generate(body) if body
  response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 90) { |http| http.request(request) }
  data = response.body.to_s.strip.empty? ? {} : JSON.parse(response.body)
  unless response.code.to_i.between?(200, 299)
    detail = (data['errors'] || []).map { |e| e['detail'] || e['title'] }.join('; ')
    raise "#{method.to_s.upcase} #{uri.path} -> #{response.code}: #{detail[0, 400]}"
  end
  data
end

def all_pages(path, params = {})
  page = api(:get, path, nil, params)
  items = page['data'] || []
  included = page['included'] || []
  while (following = page.dig('links', 'next'))
    page = api(:get, following)
    items += page['data'] || []
    included += page['included'] || []
  end
  [items, included]
end

def ref(type, id)
  { data: { type: type, id: id } }
end

app = api(:get, 'v1/apps', nil, { 'filter[bundleId]' => BUNDLE_ID })['data'].first
abort('No HolyHim App Store record exists. Create it in App Store Connect first.') unless app

groups, = all_pages("v1/apps/#{app['id']}/subscriptionGroups", { 'limit' => 50 })
group = groups.find { |g| g.dig('attributes', 'referenceName') == GROUP }
group ||= api(:post, 'v1/subscriptionGroups',
              { data: { type: 'subscriptionGroups', attributes: { referenceName: GROUP },
                        relationships: { app: ref('apps', app['id']) } } })['data']
puts "Group: #{GROUP} (#{group['id']})"

group_locales, = all_pages("v1/subscriptionGroups/#{group['id']}/subscriptionGroupLocalizations")
unless group_locales.any? { |l| l.dig('attributes', 'locale') == 'en-US' }
  api(:post, 'v1/subscriptionGroupLocalizations',
      { data: { type: 'subscriptionGroupLocalizations', attributes: { name: GROUP, locale: 'en-US' },
                relationships: { subscriptionGroup: ref('subscriptionGroups', group['id']) } } })
end

everywhere = all_pages('v1/territories', { 'limit' => 200 }).first.map { |t| t['id'] }
territories = everywhere - LEFT_OUT
existing, = all_pages("v1/subscriptionGroups/#{group['id']}/subscriptions", { 'limit' => 50 })

PRODUCTS.each do |product|
  sub = existing.find { |s| s.dig('attributes', 'productId') == product[:id] }
  sub ||= api(:post, 'v1/subscriptions',
              { data: { type: 'subscriptions',
                        attributes: { name: product[:reference], productId: product[:id],
                                      subscriptionPeriod: 'ONE_YEAR', familySharable: false,
                                      reviewNote: REVIEW_NOTE },
                        relationships: { group: ref('subscriptionGroups', group['id']) } } })['data']
  id = sub['id']
  subscription = ref('subscriptions', id)

  locales, = all_pages("v1/subscriptions/#{id}/subscriptionLocalizations")
  unless locales.any? { |l| l.dig('attributes', 'locale') == 'en-US' }
    api(:post, 'v1/subscriptionLocalizations',
        { data: { type: 'subscriptionLocalizations',
                  attributes: { locale: 'en-US', name: DISPLAY[:name], description: DISPLAY[:description] },
                  relationships: { subscription: subscription } } })
  end

  available = begin
    api(:get, "v1/subscriptions/#{id}/subscriptionAvailability")['data']
  rescue StandardError
    nil
  end
  unless available
    api(:post, 'v1/subscriptionAvailabilities',
        { data: { type: 'subscriptionAvailabilities', attributes: { availableInNewTerritories: true },
                  relationships: { subscription: subscription,
                                   availableTerritories: { data: territories.map { |t| { type: 'territories', id: t } } } } } })
  end

  # One price per storefront: 1.99 USD in the United States and Apple's
  # equalized price point everywhere else. App Review requires a price in
  # every storefront, including the ones left out of availability (China
  # mainland); availability alone decides where it is sold.
  points, = all_pages("v1/subscriptions/#{id}/pricePoints", { 'filter[territory]' => 'USA', 'limit' => 200 })
  us = points.find { |p| p.dig('attributes', 'customerPrice') == US_PRICE } or abort("No #{US_PRICE} USD price point.")
  _, price_territories = all_pages("v1/subscriptions/#{id}/prices", { 'include' => 'territory', 'limit' => 200 })
  priced = price_territories.select { |i| i['type'] == 'territories' }.map { |t| t['id'] }
  equal, = all_pages("v1/subscriptionPricePoints/#{us['id']}/equalizations",
                     { 'include' => 'territory', 'limit' => 200 })
  wanted = [[us['id'], 'USA']] + equal.map { |p| [p['id'], p.dig('relationships', 'territory', 'data', 'id')] }
  added = 0
  wanted.each do |point, territory|
    next if priced.include?(territory) || !everywhere.include?(territory)

    api(:post, 'v1/subscriptionPrices',
        { data: { type: 'subscriptionPrices', attributes: { preserveCurrentPrice: false },
                  relationships: { subscription: subscription,
                                   subscriptionPricePoint: ref('subscriptionPricePoints', point) } } })
    added += 1
  end

  offers = 0
  if product[:trial]
    current, = all_pages("v1/subscriptions/#{id}/introductoryOffers", { 'limit' => 200 })
    if current.empty?
      attributes = { duration: 'ONE_WEEK', offerMode: 'FREE_TRIAL', numberOfPeriods: 1 }
      territories.each do |territory|
        api(:post, 'v1/subscriptionIntroductoryOffers',
            { data: { type: 'subscriptionIntroductoryOffers', attributes: attributes,
                      relationships: { subscription: subscription, territory: ref('territories', territory) } } })
        offers += 1
      rescue StandardError => e
        # A storefront without a price takes no offer; report the rest.
        raise unless e.message.include?('409') || e.message.include?('territory')
      end
    end
  end

  shot = begin
    api(:get, "v1/subscriptions/#{id}/appStoreReviewScreenshot")['data']
  rescue StandardError
    nil
  end
  unless shot
    bytes = File.binread(SCREENSHOT)
    made = api(:post, 'v1/subscriptionAppStoreReviewScreenshots',
               { data: { type: 'subscriptionAppStoreReviewScreenshots',
                         attributes: { fileName: 'offer.png', fileSize: bytes.bytesize },
                         relationships: { subscription: subscription } } })['data']
    made.dig('attributes', 'uploadOperations').each do |op|
      uri = URI(op['url'])
      put = Net::HTTP.const_get(op['method'].capitalize).new(uri)
      (op['requestHeaders'] || []).each { |h| put[h['name']] = h['value'] }
      put.body = bytes.byteslice(op['offset'], op['length'])
      done = Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 120) { |http| http.request(put) }
      raise "Screenshot upload -> #{done.code}" unless done.code.to_i.between?(200, 299)
    end
    api(:patch, "v1/subscriptionAppStoreReviewScreenshots/#{made['id']}",
        { data: { type: 'subscriptionAppStoreReviewScreenshots', id: made['id'],
                  attributes: { uploaded: true, sourceFileChecksum: Digest::MD5.hexdigest(bytes) } } })
  end

  state = api(:get, "v1/subscriptions/#{id}")['data'].dig('attributes', 'state')
  puts "#{product[:id]}: #{state}; #{added} prices added (#{priced.length + added} storefronts priced)" \
       "#{product[:trial] ? ", free week in #{offers} storefronts this run" : ''}"
end
puts 'Nothing was submitted.'
