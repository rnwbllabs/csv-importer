# typed: true
# frozen_string_literal: true

module CSVImporter
  # This Dsl extends a class that includes CSVImporter
  # It is a thin proxy to the Config object
  module Dsl
    extend T::Sig
    extend T::Helpers

    requires_ancestor { ConfigInterface }

    # Set the model to which imported data will be mapped
    # @param model_klass [Class] the model to which imported data will be mapped
    def model(model_klass)
      config.model = model_klass
      # For backward compatibility, also populate the models hash
      config.models[:_default] = model_klass
    end

    # Set multiple models for mapping CSV columns to different model types
    # @param models [Hash<Symbol, Class>] a hash mapping model keys to model classes
    # @example
    #   models user: User, time_card: TimeCard
    def models(models)
      config.models = models
    end

    # Set the order in which models should be persisted
    # @param order [Array<Symbol>] the order in which models should be persisted
    # @example
    #   persist_order [:user, :time_card]
    def persist_order(order)
      config.persist_order = order
    end

    # Define a column for the model
    # @param name [Symbol] the name of the column
    # @param to [Symbol, Proc, nil] the attribute on the model that will be set with the value of the column. If nil,
    #   the name of the column in the CSV file will be used.
    # @param as [Symbol, String, Regexp, Array, nil] more complex matching logic for the name of the column in the CSV file.
    #   If nil, the name of the column in the CSV file will be used.
    # @param required [Boolean] [Optional] whether the column is required, i.e., the importer will raise an error if
    #   the column is not present in the CSV file. Defaults to false.
    # @param virtual [Boolean] [Optional] whether the column is virtual, i.e., not present on the associated model and
    #   won't be set on the model at all. Defaults to false.
    # @param model [Symbol] [Optional] the key of the model this column belongs to. If not specified, the column
    #   will be mapped to the default model.
    # @param options [Hash] the options for the column
    sig do
      params(
        name: Symbol,
        to: CSVImporter::ColumnDefinition::ToType,
        as: CSVImporter::ColumnDefinition::AsType,
        required: T.nilable(T::Boolean),
        virtual: T.nilable(T::Boolean),
        model: T.nilable(Symbol)
      ).void
    end
    def column(name, to: nil, as: nil, required: false, virtual: false, model: nil)
      column_definition = ColumnDefinition.new(
        name:, to:, as:, required: required || false, virtual: virtual || false, model: model
      )
      config.column_definitions << column_definition
    end

    # Define the identifiers for the model, used to uniquely identify a record for finding or creating it
    # @param params [Symbol, Array, Proc] the identifiers for the model
    def identifier(*params)
      config.identifiers = params.first.is_a?(Proc) ? params.first : params
    end

    alias_method :identifiers, :identifier

    # Define the identifiers for a specific model, used to uniquely identify a record for finding or creating it
    # @param model_key [Symbol] the key of the model these identifiers are for
    # @param params [Symbol, Array, Proc] the identifiers for the model
    def model_identifier(model_key, *params)
      config.model_identifiers[model_key] = params.first.is_a?(Proc) ? params.first : params
    end

    alias_method :model_identifiers, :model_identifier

    # Action to take when a record is invalid
    # @param action [Symbol] the action to take when a record is invalid
    sig { params(action: Symbol).void }
    def when_invalid(action)
      config.when_invalid = action
    end

    # Define a block to run before the import process starts.
    # This runs before any rows are processed, making it ideal for:
    # - Preloading reference data needed for lookups
    # - Setting up context for the import
    # - Preparing data structures to optimize performance
    #
    # The block has access to the datastore, which contains any custom parameters
    # passed during initialization.
    #
    # @example Preload data for efficient lookups
    #   before_import do
    #     # Access constructor parameters
    #     company_id = datastore[:company_id]
    #
    #     # Preload data for lookups
    #     employees = Employee.where(company_id: company_id).all
    #     datastore[:employee_lookup] = employees.index_by(&:email)
    #   end
    #
    # @param block [Proc] A block to run before the import starts
    sig { params(block: Proc).void }
    def before_import(&block)
      config.before_import(block)
    end

    # Block to run after a record is built
    # @param block [Proc] the block to run after a record is built
    sig { params(block: Proc).void }
    def after_build(&block)
      config.after_build(block)
    end

    # Block to run after a record is saved
    # @param block [Proc] the block to run after a record is saved
    sig { params(block: Proc).void }
    def after_save(&block)
      config.after_save(block)
    end
  end
end
