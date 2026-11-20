# frozen_string_literal: true
module DiscourseSvdex
  # Core's helper authorizes a linked post, but otherwise permits any signed-in
  # visitor. A secure, not-yet-posted document must remain owner/staff-only.
  # Keep the native post-based authorization once it has an access-control post.
  module SecureDraftUploads
    private
    def check_secure_upload_permission(upload)
      if upload.secure? && upload.access_control_post_id.blank?
        unless current_user && (current_user.id == upload.user_id || guardian.is_staff?)
          raise Discourse::NotFound
        end
      end
      super
    end
  end
end
