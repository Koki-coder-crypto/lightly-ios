#!/usr/bin/env ruby
# Creates the App ID, App Store Connect record, and a short-lived App Store profile for CI.
require "base64"
require "json"
require "net/http"
require "openssl"
require "uri"

def b64url(value)
  Base64.urlsafe_encode64(value, padding: false)
end

def token
  header = b64url(JSON.generate({ alg: "ES256", kid: ENV.fetch("APPSTORE_KEY_ID") }))
  payload = b64url(JSON.generate({ iss: ENV.fetch("APPSTORE_ISSUER_ID"), iat: Time.now.to_i, exp: Time.now.to_i + 1_100, aud: "appstoreconnect-v1" }))
  key = OpenSSL::PKey.read(File.read(ENV.fetch("APPSTORE_KEY_PATH")))
  der = key.dsa_sign_asn1(OpenSSL::Digest::SHA256.digest("#{header}.#{payload}"))
  sequence = OpenSSL::ASN1.decode(der)
  raw = sequence.value.map { |number| number.value.to_s(2).rjust(32, "\0") }.join
  "#{header}.#{payload}.#{b64url(raw)}"
end

def request(method, path, body = nil)
  uri = URI("https://api.appstoreconnect.apple.com#{path}")
  request = Net::HTTP.const_get(method.capitalize).new(uri)
  request["Authorization"] = "Bearer #{token}"
  request["Content-Type"] = "application/json"
  request.body = JSON.generate(body) if body
  response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(request) }
  return JSON.parse(response.body) if response.code.to_i.between?(200, 299)
  message = JSON.parse(response.body).fetch("errors", []).map { |error| error["detail"] || error["title"] }.join("; ") rescue response.body
  abort("Apple Developer API #{method.upcase} #{path} failed (#{response.code}): #{message}")
end

bundle_id = ENV.fetch("BUNDLE_ID")
app_name = ENV.fetch("APP_NAME")
sku = ENV.fetch("APP_SKU")
certificate_serial = ENV.fetch("CERTIFICATE_SERIAL").delete(":").upcase

bundle = request("get", "/v1/bundleIds?filter%5Bidentifier%5D=#{bundle_id}&limit=1").fetch("data").first
unless bundle
  bundle = request("post", "/v1/bundleIds", { data: { type: "bundleIds", attributes: { identifier: bundle_id, name: app_name, platform: "IOS" } } }).fetch("data")
end

apps = request("get", "/v1/apps?filter%5BbundleId%5D=#{bundle_id}&limit=1").fetch("data")
if apps.empty?
  request("post", "/v1/apps", { data: { type: "apps", attributes: { bundleId: bundle_id, name: app_name, primaryLocale: "en-US", sku: sku } } })
  sleep 10
end

certificates = request("get", "/v1/certificates?filter%5BcertificateType%5D=DISTRIBUTION&limit=200").fetch("data")
certificate = certificates.find { |item| item.dig("attributes", "serialNumber").to_s.delete(":").upcase == certificate_serial }
abort("The imported Apple Distribution certificate is not available through the Apple Developer API.") unless certificate

profile_name = "#{app_name} AppStore CI #{ENV.fetch("GITHUB_RUN_ID")}".slice(0, 100)
profile = request("post", "/v1/profiles", {
  data: {
    type: "profiles",
    attributes: { name: profile_name, profileType: "IOS_APP_STORE" },
    relationships: {
      bundleId: { data: { type: "bundleIds", id: bundle.fetch("id") } },
      certificates: { data: [{ type: "certificates", id: certificate.fetch("id") }] }
    }
  }
}).fetch("data")
content = profile.dig("attributes", "profileContent")
abort("Apple Developer API returned no provisioning profile content.") if content.to_s.empty?
File.binwrite("profile.mobileprovision", Base64.decode64(content))
File.open(ENV.fetch("GITHUB_ENV"), "a") { |file| file.puts("PROFILE_NAME=#{profile_name}") }
