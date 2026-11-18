# frozen_string_literal: true

module Collaboration
  class Conflict < StandardError
    attr_reader :code

    def initialize(code, message)
      @code = code
      super(message)
    end
  end
end
