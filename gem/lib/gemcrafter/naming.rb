# frozen_string_literal: true

module Gemcrafter
  module Naming
    MOD_ID = /\A[a-z][a-z0-9_]{1,63}\z/
    PATH = /\A[a-z0-9_]+\z/

    module_function

    def snake(name)
      name.gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
          .gsub(/([a-z\d])([A-Z])/, '\1_\2')
          .downcase
    end

    def title(name)
      snake(name).split("_").map(&:capitalize).join(" ")
    end

    def valid_mod_id?(id) = MOD_ID.match?(id)
    def valid_path?(path) = PATH.match?(path)

    def last_segment(mod)
      mod.name.to_s.split("::").last
    end
  end
end
