# typed: false

module CSVImporter
  # This Dsl extends a class that includes CSVImporter
  # It is a thin proxy to the Config object
  module Dsl

    # Set the model to which imported data will be mapped
    # @param model_klass [Class] the model to which imported data will be mapped
    def model(model_klass)
      config.model = model_klass
    end

    # Define a column for the model
    # @param name [Symbol] the name of the column
    # @param options [Hash] the options for the column
    def column(name, options = {})
      config.column_definitions << options.merge(name: name)
    end

    # Define the identifiers for the model, used to uniquely identify a record for finding or creating it
    # @param params [Array] the identifiers for the model
    def identifier(*params)
      config.identifiers = params.first.is_a?(Proc) ? params.first : params
    end

    alias_method :identifiers, :identifier

    # Action to take when a record is invalid
    # @param action [Symbol] the action to take when a record is invalid
    def when_invalid(action)
      config.when_invalid = action
    end

    # Block to run after a record is built
    # @param block [Proc] the block to run after a record is built
    def after_build(&block)
      config.after_build(block)
    end

    # Block to run after a record is saved
    # @param block [Proc] the block to run after a record is saved
    def after_save(&block)
      config.after_save(block)
    end
  end
end
