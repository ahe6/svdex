# frozen_string_literal: true
module DiscourseSvdex
  module RetiredAboutPage
    def index
      raise Discourse::NotFound
    end
  end

  module RetiredGuidelinesPages
    def show
      raise Discourse::NotFound if %w[faq guidelines rules conduct].include?(params[:id].to_s)
      super
    end
  end
end
