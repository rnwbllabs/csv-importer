# typed: strong
# frozen_string_literal: true

module CSVImporter
  # Interface for objects that can provide a `Config`
  module ConfigInterface
    extend T::Sig
    extend T::Helpers

    interface!

    # Return the appropriate configuration for the relevant import
    # @return [Config] the configuration
    sig { abstract.returns(Config) }
    def config
    end
  end
end
