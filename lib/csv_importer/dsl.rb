# typed: true
# frozen_string_literal: true

module CSVImporter
  # This Dsl extends a class that includes CSVImporter
  # It is a thin proxy to the Config object
  module Dsl
    extend T::Sig
    extend T::Helpers

    requires_ancestor { ConfigInterface }

    # Definition of the model class to use for this import
    # @note For multi-model imports, use the `models` method instead
    # @param model_klass [Class] The model class to use
    # @return [Class] The model class
    sig { params(model_klass: T.untyped).returns(T.untyped) }
    def model(model_klass)
      config.model = model_klass
      # For backward compatibility, also populate the models hash
      config.models[:_default] = model_klass
    end

    # Definition of multiple model classes to use for this import
    # @example Define multiple models for a time card import
    #   models user: User, time_card: TimeCard
    # @param models [Hash<Symbol, Class>] A hash mapping model keys to model classes
    # @return [Hash<Symbol, Class>] The models hash
    sig { params(models: T::Hash[Symbol, T.untyped]).returns(T::Hash[Symbol, T.untyped]) }
    def models(models)
      config.models = models
    end

    # Define the order in which models should be persisted
    # This is crucial for maintaining proper foreign key relationships
    # @example Set persistence order for time cards requiring users to exist first
    #   persist_order [:user, :time_card]
    # @param order [Array<Symbol>] The order of model keys for persistence
    # @return [Array<Symbol>] The persistence order
    sig { params(order: T::Array[Symbol]).returns(T::Array[Symbol]) }
    def persist_order(order)
      config.persist_order = order
    end

    # Define a column mapping for the import
    # @param name [Symbol] the name of the attribute into which the CSV column value will be stored
    # @param to [Symbol, Proc, Class] (optional) the name of the model attribute to set or a transformer
    # @param as [Symbol, String, Regexp, Array] (optional) a matcher for the column header
    # @param required [Boolean] (optional) whether the column is required (default: false)
    # @param virtual [Boolean] (optional) whether the column should be ignored (default: false)
    # @param model [Symbol] (optional) the model key this column belongs to (for multi-model imports)
    # @return [ColumnDefinition] the column definition
    # @example Map a CSV column to a model attribute
    #   column :email
    # @example Map a CSV column to a different model attribute
    #   column :email, to: :login
    # @example Transform the value before setting it
    #   column :email, to: ->(value) { value.downcase }
    # @example Map a CSV column to a specific model in multi-model import
    #   column :email, model: :user
    #   column :hours_worked, model: :time_card
    sig do
      params(
        name: Symbol,
        to: T.nilable(T.any(Symbol, T.untyped)),
        as: T.nilable(T.any(Regexp, String, Symbol, T::Array[T.nilable(T.any(String, Symbol))])),
        required: T::Boolean,
        virtual: T::Boolean,
        model: T.nilable(Symbol)
      ).returns(ColumnDefinition)
    end
    def column(name, to: nil, as: nil, required: false, virtual: false, model: nil)
      column_definition = ColumnDefinition.new(
        name: name,
        to: to || name,
        as: as,
        required: required,
        virtual: virtual,
        model: model
      )
      config.column_definitions << column_definition
      column_definition
    end

    # Define identifiers for the model for find_or_create behavior
    # @note For multi-model imports, use `model_identifier` method instead
    # @param params [Array<Symbol>, Proc] Either array of attributes or proc returning identifier(s)
    # @return [T.any(Array<Symbol>, Proc)] The identifiers
    sig { params(params: T.untyped).returns(T.untyped) }
    def identifier(*params)
      config.identifiers = params.first.is_a?(Proc) ? params.first : params
    end

    alias_method :identifiers, :identifier

    # Define identifiers for a specific model in multi-model imports
    # @example Define email as identifier for users
    #   model_identifier :user, :email
    # @example Define compound identifiers for time cards
    #   model_identifier :time_card, :user_id, :date
    # @example Define dynamic identifiers with a proc
    #   model_identifier :user, ->(user) { user.email.present? ? :email : [:first_name, :last_name] }
    # @param model_key [Symbol] The key of the model to set identifiers for
    # @param params [Array<Symbol>, Proc] Either array of attributes or proc returning identifier(s)
    # @return [T.any(Array<Symbol>, Proc)] The identifiers for the specified model
    sig { params(model_key: Symbol, params: T.untyped).returns(T.untyped) }
    def model_identifier(model_key, *params)
      config.model_identifiers[model_key] = params.first.is_a?(Proc) ? params.first : params
    end

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
