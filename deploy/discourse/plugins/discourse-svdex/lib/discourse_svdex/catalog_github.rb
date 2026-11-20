# frozen_string_literal: true

require "base64"
require "json"
require "jwt"
require "net/http"

module DiscourseSvdex
  class CatalogGithub
    REPOSITORY = "ahe6/svdex"
    OWNER, REPO = REPOSITORY.split("/")
    BASE = "main"
    API_VERSION = "2022-11-28"

    class Unavailable < StandardError; end

    def self.configured?
      %w[SVDEX_CATALOG_GITHUB_APP_ID SVDEX_CATALOG_GITHUB_INSTALLATION_ID].all? do |variable|
        ENV[variable].to_s.match?(/\A[1-9][0-9]*\z/)
      end && File.file?(ENV["SVDEX_CATALOG_GITHUB_PRIVATE_KEY_PATH"].to_s)
    end

    def get(path, missing: false)
      request(Net::HTTP::Get, "/repos/#{REPOSITORY}#{path}", token, nil, missing: missing)
    end

    def post(path, data)
      request(Net::HTTP::Post, "/repos/#{REPOSITORY}#{path}", token, data)
    end

    def put(path, data)
      request(Net::HTTP::Put, "/repos/#{REPOSITORY}#{path}", token, data)
    end

    private

    def token
      @token ||= begin
        key = OpenSSL::PKey::RSA.new(File.read(ENV.fetch("SVDEX_CATALOG_GITHUB_PRIVATE_KEY_PATH")))
        now = Time.now.to_i
        jwt = JWT.encode({ iss: ENV.fetch("SVDEX_CATALOG_GITHUB_APP_ID"), iat: now - 60, exp: now + 540 }, key, "RS256")
        installation = ENV.fetch("SVDEX_CATALOG_GITHUB_INSTALLATION_ID")
        data = { repositories: [REPO], permissions: { contents: "write", pull_requests: "write" } }
        request(Net::HTTP::Post, "/app/installations/#{installation}/access_tokens", jwt, data).fetch("token")
      rescue SystemCallError, OpenSSL::PKey::PKeyError, JWT::EncodeError, KeyError
        raise Unavailable
      end
    end

    def request(method, path, credential, data, missing: false)
      headers = { "Accept" => "application/vnd.github+json", "Authorization" => "Bearer #{credential}",
                  "X-GitHub-Api-Version" => API_VERSION, "Content-Type" => "application/json", "User-Agent" => "SVDEX-directory" }
      http_request = method.new(path, headers)
      http_request.body = JSON.generate(data) if data
      response = Net::HTTP.start("api.github.com", 443, use_ssl: true, open_timeout: 3, read_timeout: 5, write_timeout: 5, max_retries: 0) do |http|
        http.request(http_request)
      end
      return nil if missing && response.code == "404"
      raise Unavailable unless response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)
    rescue IOError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError, JSON::ParserError
      raise Unavailable
    end
  end
end
