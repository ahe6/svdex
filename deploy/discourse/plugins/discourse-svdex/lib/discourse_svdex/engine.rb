# frozen_string_literal: true
module DiscourseSvdex
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace DiscourseSvdex
  end
end
