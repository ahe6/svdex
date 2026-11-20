# frozen_string_literal: true

require_relative "catalog_github"
require_relative "prototypes/public_catalog_document"

module DiscourseSvdex
  class CatalogProposals
    Document = Prototypes::CatalogDocument
    Schema = Prototypes::PublicCatalogDocument
    class Conflict < StandardError; end

    def self.publishing_ready?
      return false unless defined?(Prototypes::PublicCatalog) && Prototypes::PublicCatalog.ready?

      local = GlobalSetting.hostname == "localhost" && SiteSetting.port.to_s == "4080"
      local || SiteSetting.svdex_catalog_publishing_enabled
    end

    def self.enabled?
      SiteSetting.svdex_catalog_proposals_enabled && publishing_ready? && CatalogGithub.configured?
    end

    def initialize(kind, github: CatalogGithub.new)
      raise Document::Invalid, "Unknown directory" unless Schema::KINDS.include?(kind)
      @github = github
      @kind = kind
    end

    def draft(id)
      file = file_at(id, CatalogGithub::BASE)
      return unless file
      { document: decode(file), sha: file.fetch("sha") }
    end

    def submit(text, id: nil, sha: nil)
      document = Schema.parse(@kind, text)
      if @kind == "securities" && (topic_id = document.dig("facts", "topic_id")) &&
          !SecuritiesDirectory.eligible?(Topic.find_by(id: topic_id))
        raise Document::Invalid, "Choose an existing public security topic."
      end
      if id && (document.fetch("id") != id || !sha.is_a?(String) || !sha.match?(/\A[0-9a-f]{40}\z/))
        raise Document::Invalid, "Keep the existing file ID and use its current revision."
      end
      file_id = document.fetch("id")
      digest = Digest::SHA256.hexdigest("#{sha}:#{Document.revision(document)}")[0, 24]
      branch = "directory-proposals/#{@kind}/#{file_id}-#{digest}"
      DistributedMutex.synchronize("svdex:#{branch}", validity: 120) do
        pull_request = existing_pull_request(branch)
        next pull_request if pull_request

        base_sha = @github.get("/git/ref/heads/#{CatalogGithub::BASE}").fetch("object").fetch("sha")
        original = file_at(file_id, base_sha)
        if id
          raise Conflict, "This file changed. Close and reopen the editor for the latest version." unless original && original.fetch("sha") == sha
          raise Conflict, "Make a change before creating a pull request." if Schema.parse(@kind, decode(original)) == document
        elsif original
          raise Conflict, "That ID already exists. Propose a change from its existing file."
        end

        ref = "/git/ref/heads/#{branch}"
        @github.post("/git/refs", ref: "refs/heads/#{branch}", sha: base_sha) unless @github.get(ref, missing: true)
        update_proposal_file(file_id, document, branch, sha)
        title = "#{id ? 'Update' : 'Add'} #{@kind}/#{file_id}"
        pull = @github.post("/pulls", title: title, head: branch, base: CatalogGithub::BASE,
          body: "Submitted through SVDEX for review. The diff contains one public directory entry.", maintainer_can_modify: true)
        pull_request_result(pull)
      end
    end

    private

    def file_path(id)
      unless id.is_a?(String) && id.size <= 80 && id.match?(/\A[a-z0-9]+(?:-[a-z0-9]+)*\z/)
        raise Document::Invalid, "Use a stable lowercase ID with letters, numbers and hyphens."
      end
      "/contents/directory/#{@kind}/#{id}.json"
    end

    def file_at(id, ref)
      @github.get("#{file_path(id)}?#{URI.encode_www_form(ref: ref)}", missing: true)
    end

    def decode(file)
      raise CatalogGithub::Unavailable unless file["encoding"] == "base64" && file["content"].is_a?(String)
      Base64.decode64(file.fetch("content"))
    end

    def update_proposal_file(id, document, branch, sha)
      desired = "#{JSON.pretty_generate(document)}\n"
      current = file_at(id, branch)
      return if current && decode(current) == desired
      raise Conflict, "That proposal branch changed. Open the current file on GitHub." if current&.fetch("sha") != sha

      data = { branch: branch, content: Base64.strict_encode64(desired), message: "Propose #{@kind}/#{id}" }
      data[:sha] = sha if sha
      @github.put(file_path(id), data)
    end

    def existing_pull_request(branch)
      query = URI.encode_www_form(state: "all", head: "#{CatalogGithub::OWNER}:#{branch}", base: CatalogGithub::BASE)
      pull = @github.get("/pulls?#{query}").first
      pull_request_result(pull) if pull
    end

    def pull_request_result(pull)
      number = Integer(pull.fetch("number"))
      { url: "https://github.com/#{CatalogGithub::REPOSITORY}/pull/#{number}" }
    end
  end
end
