# typed: strict
# frozen_string_literal: true

require 'csv'
require 'ostruct'

module CSVImporter
  # A Row from the CSV file.
  #
  # Using the header, the model_klass and the identifier it builds the model
  # to be persisted.
  # Individual row in the CSV file. Uses the
  class Row
    extend T::Sig

    # CustomError is used to track errors that are not tied to a specific column
    # It can be used to track errors that are tied to a model attribute or a general error
    # @!attribute [rw] message
    # @return [String] The error message
    # @!attribute [rw] column_name
    # @return [String, nil] The name of the column that the error is tied to
    # @!attribute [rw] attribute
    # @return [Symbol, nil] The name of the model attribute that the error is tied to
    # @!attribute [rw] model_key
    # @return [Symbol, nil] The key of the model the error is tied to
    class CustomError < T::Struct
      const :message, String
      const :column_name, T.nilable(String)
      const :attribute, T.nilable(Symbol)
      const :model_key, T.nilable(Symbol)
    end

    # @!attribute [rw] header
    # @return [Header, nil] the header of the row
    sig { returns(T.nilable(Header)) }
    attr_accessor :header

    # @!attribute [rw] line_number
    # @return [Integer] the line number of the row in the CSV file
    sig { returns(Integer) }
    attr_accessor :line_number

    # @!attribute [rw] row_array
    # @return [Array<String>] the array of values from the row
    sig { returns(T::Array[String]) }
    attr_accessor :row_array

    # @!attribute [rw] models
    # @return [Hash<Symbol, Class>] the model classes that will be instantiated
    sig { returns(T::Hash[Symbol, T.untyped]) }
    attr_accessor :models

    # @!attribute [rw] persist_order
    # @return [Array<Symbol>] the order in which models should be persisted
    sig { returns(T::Array[Symbol]) }
    attr_accessor :persist_order

    # @!attribute [rw] model_identifiers
    # @return [Hash<Symbol, T.any(Array<Symbol>, Proc)>] identifiers used to find existing records for each model
    sig { returns(T::Hash[Symbol, T.any(T::Array[Symbol], Proc)]) }
    attr_accessor :model_identifiers

    # @!attribute [rw] after_build_blocks
    # @return [Array<Proc>] blocks to run after building the model
    sig { returns(T::Array[Proc]) }
    attr_accessor :after_build_blocks

    # @!attribute [rw] skip
    # @return [Boolean] whether this row should be skipped
    sig { returns(T::Boolean) }
    attr_accessor :skip

    # @!attribute [r] datastore
    # @return [Hash<Symbol, T.anything>] Storage for data that can be accessed during the import process
    sig { returns(T::Hash[Symbol, T.anything]) }
    attr_reader :datastore

    # @!attribute [r] custom_errors
    # @return [Array<CustomError>] Array of custom errors
    sig { returns(T::Array[CustomError]) }
    attr_reader :custom_errors

    # @!attribute [r] valid
    # @return [Boolean, nil] Whether this row is valid (true if no model errors or custom errors)
    sig { returns(T.nilable(T::Boolean)) }
    attr_reader :valid

    # Initialize a new Row
    # @param line_number [Integer] The line number in the CSV file
    # @param header [Header, nil] The CSV header
    # @param row_array [Array<String>] The raw values from the CSV row
    # @param models [Hash<Symbol, Class>] The model classes to instantiate for this row
    # @param persist_order [Array<Symbol>] The order in which models should be persisted
    # @param model_identifiers [Hash<Symbol, T.any(Array<Symbol>, Proc)>] Identifiers to find existing records for each model
    # @param after_build_blocks [Array<Proc>] Blocks to run after building the model
    # @param skip [Boolean] Whether to skip this row
    # @param datastore [Hash<Symbol, T.anything>] Storage for data that can be accessed during the import process
    sig do
      params(
        line_number: Integer,
        header: T.nilable(Header),
        row_array: T::Array[String],
        models: T::Hash[Symbol, T.anything],
        persist_order: T::Array[Symbol],
        model_identifiers: T::Hash[Symbol, T.any(T::Array[Symbol], Proc)],
        after_build_blocks: T::Array[Proc],
        skip: T::Boolean,
        datastore: T::Hash[Symbol, T.anything]
      ).void
    end
    def initialize(line_number:, header: nil, row_array: [], models: {}, persist_order: [],
      model_identifiers: {}, after_build_blocks: [], skip: false, datastore: {})
      @header = T.let(header, T.nilable(Header))
      @line_number = T.let(line_number, Integer)
      @row_array = T.let(row_array, T::Array[String])
      @models = T.let(models, T::Hash[Symbol, T.anything])
      @persist_order = T.let(persist_order, T::Array[Symbol])
      @model_identifiers = T.let(model_identifiers, T::Hash[Symbol, T.any(T::Array[Symbol], Proc)])
      @after_build_blocks = T.let(after_build_blocks, T::Array[Proc])
      @skip = T.let(skip, T::Boolean)
      @built_models = T.let({}, T::Hash[Symbol, T.untyped])
      @csv_attributes = T.let(nil, T.nilable(T::Hash[T.any(String, Symbol), T.nilable(String)]))
      @datastore = T.let(datastore, T::Hash[Symbol, T.anything])
      @custom_errors = T.let([], T::Array[CustomError])
      @valid = T.let(nil, T.nilable(T::Boolean))
      @after_build_blocks_run = T.let(false, T::Boolean)
    end

    # Check if this row should be skipped
    # @return [Boolean] true if the row should be skipped
    sig { returns(T::Boolean) }
    def skip?
      skip
    end

    # Mark this row to be skipped
    # @return [void]
    sig { void }
    def skip!
      @skip = true
    end

    # The model to be persisted (for backward compatibility)
    # @return [Object] The built model instance with attributes set
    sig { returns(T.untyped) }
    def model
      # Ensure models are built
      built_models

      # Return the default model for backward compatibility
      @built_models[:_default] || @built_models.values.first
    end

    # All models to be persisted
    # @return [Hash<Symbol, Object>] Hash of built model instances with attributes set
    sig { returns(T::Hash[Symbol, T.untyped]) }
    def built_models
      if @built_models.empty?
        build_all_models
      end

      @built_models
    end

    # Build all models needed for this row
    # @return [void]
    sig { void }
    def build_all_models
      # Build each model in the models hash
      @models.each do |key, klass|
        next if @built_models.key?(key)

        model = find_or_build_model_for_key(key, klass)
        set_attributes_for_model(model, key)
        @built_models[key] = model
      end

      # Run after_build hooks only once
      run_after_build_hooks
    end

    # Run after_build blocks on the models
    # @return [void]
    sig { void }
    def run_after_build_hooks
      return if @after_build_blocks_run

      @after_build_blocks_run = true

      after_build_blocks.each do |block|
        if block.arity == 1
          T.unsafe(self).instance_exec(model, &block)
        else
          T.unsafe(self).instance_exec(&block)
        end
      end
    end

    # Get the CSV attributes from the header and row
    # @return [Hash] A hash of attribute name to attribute value from CSV
    sig { returns(T::Hash[T.any(String, Symbol), T.nilable(String)]) }
    def csv_attributes
      @csv_attributes ||= begin
        return {} unless header # Return empty hash if no header

        column_names = T.must(header).column_names
        column_names.zip(row_array).to_h
      end
    end

    # Find or build a model for the given key
    # @param key [Symbol] The key of the model to find or build
    # @param klass [Class] The class to instantiate for this model
    # @return [Object] The found or built model
    sig { params(key: Symbol, klass: T.untyped).returns(T.untyped) }
    def find_or_build_model_for_key(key, klass)
      find_model_for_key(key, klass) || build_model_for_key(key, klass)
    end

    # Set the attributes on the model from the CSV row for the given model key
    # @param model [Object] The model to set attributes on
    # @param model_key [Symbol] The key of the model to set attributes for
    # @return [Object] The model with attributes set
    sig { params(model: T.untyped, model_key: T.nilable(Symbol)).returns(T.untyped) }
    def set_attributes_for_model(model, model_key = nil)
      return model unless header

      # After the check, we know header exists
      header_obj = T.must(header)

      # Get the columns for this model
      header_obj.column_definitions.each do |definition|
        # Skip if this column is for a different model
        next if model_key && definition.model_key && definition.model_key != model_key

        # Ensure we have a column name that we can use to look up values
        column_name = definition.name
        next unless column_name

        # Get the column value from CSV attributes
        # We need to ensure column_name is used as the correct type
        safe_column_name = column_name.is_a?(Symbol) ? column_name : column_name.to_sym
        value = csv_attributes[safe_column_name]

        # Skip if the column is virtual
        next if definition.virtual?

        # Handle the attribute based on the 'to' definition
        if definition.to.is_a?(Proc)
          # Handle transformers (Procs)
          transformer = definition.to
          apply_transformer(transformer, value, model, safe_column_name)
        else
          # Standard attribute assignment - use the 'to' field or column name
          attribute = definition.to.is_a?(Symbol) ? definition.to : safe_column_name

          # Skip if model doesn't respond to this attribute
          next unless model.respond_to?(:"#{attribute}=")

          # Set the attribute
          begin
            model.send(:"#{attribute}=", value == "" ? nil : value)
          rescue StandardError => e
            add_error("#{e.class}: #{e.message}",
                     column_name: safe_column_name.to_s,
                     attribute: attribute)
          end
        end
      end

      model
    end

    # Apply a transformer (Proc) to a model attribute
    # @param transformer [Proc] The transformer to apply
    # @param value [String, nil] The value from the CSV
    # @param model [Object] The model to transform
    # @param column_name [Symbol, String] The name of the column
    # @return [void]
    sig do
      params(
        transformer: T.untyped,
        value: T.nilable(String),
        model: T.untyped,
        column_name: T.any(Symbol, String)
      ).void
    end
    def apply_transformer(transformer, value, model, column_name)
      begin
        arity = transformer.is_a?(Proc) ? transformer.arity : transformer.method(:call).arity

        case arity
        when 1 # to: ->(email) { email.downcase }
          # For single-argument transformers, call the transformer with the value
          # and assign the result to the attribute named by column_name
          model.public_send(:"#{column_name}=", T.unsafe(transformer).call(value))

        when 2 # to: ->(published, post) { post.published_at = Time.now if published == "true" }
          # For two-argument transformers, call the transformer with the value and model
          # The transformer itself is responsible for setting attributes on the model
          T.unsafe(transformer).call(value, model)

        when 3 # to: ->(field_value, post, column) { post.hash_field[column.name] = field_value }
          # For three-argument transformers, create a column-like object with needed properties
          # This replicates the behavior of passing a Column object in the original code
          column_obj = OpenStruct.new(
            name: column_name,    # The name of the column
            definition: OpenStruct.new(
              name: column_name,  # The column's definition name (often the same as column.name)
              to: transformer     # The transformer itself, for reference if needed
            )
          )
          T.unsafe(transformer).call(value, model, column_obj)

        else
          # Reject transformers with invalid arity
          raise ArgumentError, "arity: #{transformer.arity.inspect} - `to` can only have 1, 2 or 3 arguments"
        end
      rescue StandardError => e
        # Handle any errors that occur during transformation
        column_name_str = column_name.to_s
        add_error("#{e.class}: #{e.message}", column_name: column_name_str)
      end
    end

    # Check if the model has errors (either in the model's errors array or custom errors)
    # @return [Boolean] true if the model has errors
    sig { returns(T::Boolean) }
    def has_errors?
      return false if skip?

      check_errors
      !valid?
    end

    # Check if this row is valid (no errors)
    # @return [Boolean] true if the row is valid
    sig { returns(T::Boolean) }
    def valid?
      return true if skip?

      check_errors
      T.must(@valid)
    end

    # Find a model for the given key
    # @param key [Symbol] The key of the model to find
    # @param klass [Class] The class to look for
    # @return [Object, nil] The found model or nil if not found
    sig { params(key: Symbol, klass: T.untyped).returns(T.untyped) }
    def find_model_for_key(key, klass)
      identifiers = model_identifiers[key]
      return nil unless identifiers

      if identifiers.is_a?(Proc)
        # Execute the proc to get the identifier values
        identifier_result = T.unsafe(self).instance_exec(&identifiers)
        return nil unless identifier_result

        # Extract identifier values and build the query
        if identifier_result.is_a?(Hash)
          klass.find_by(identifier_result)
        else
          # Assume it's the actual record or nil
          identifier_result
        end
      else
        # Handle array of symbols
        identifier_array = identifiers

        # Make sure all identifier attributes are present
        attributes = identifier_array.map do |identifier|
          value = csv_attributes[identifier]
          return nil if value.nil?

          [identifier, value]
        end.to_h

        # Find the record with the identifier attributes
        klass.find_by(attributes)
      end
    end

    # Build a new instance of the model for the given key
    # @param key [Symbol] The key of the model to build
    # @param klass [Class] The class to instantiate
    # @return [Object] The newly built model instance
    sig { params(key: Symbol, klass: T.untyped).returns(T.untyped) }
    def build_model_for_key(key, klass)
      klass.new
    end

    # Add a custom error to this row
    # @param message [String] The error message
    # @param column_name [String, nil] The name of the column that the error is tied to
    # @param attribute [Symbol, nil] The name of the model attribute that the error is tied to
    # @param model_key [Symbol, nil] The key of the model the error is tied to
    # @return [void]
    sig do
      params(
        message: String,
        column_name: T.nilable(String),
        attribute: T.nilable(Symbol),
        model_key: T.nilable(Symbol)
      ).void
    end
    def add_error(message, column_name: nil, attribute: nil, model_key: nil)
      @valid = false
      custom_errors << CustomError.new(
        message: message,
        column_name: column_name,
        attribute: attribute,
        model_key: model_key
      )
    end

    # Get all errors for this row organized by column name
    # @return [Hash<String, String>] A hash of column name to error message
    sig { returns(T::Hash[String, String]) }
    def errors
      error_hash = {}

      # Add custom errors
      custom_errors.each do |error|
        error_hash[error.column_name || "_general"] = error.message
      end

      # Add model errors for the default model (for backward compatibility)
      if model.respond_to?(:errors) && model.errors.any?
        model.errors.each do |attribute, message|
          # Try to map the attribute back to a column name
          column_name = header&.column_name_for_model_attribute(attribute.to_sym) || attribute.to_s
          error_hash[column_name] = message
        end
      end

      error_hash
    end

    private

    # Check if any of the built models have errors
    # @return [void]
    sig { void }
    def check_errors
      return if @valid == false # already checked and found invalid

      # Build models if necessary
      built_models

      # Check for errors on all models
      model_errors = built_models.any? do |_key, model|
        # Check if the model responds to errors and if it has any
        model.respond_to?(:errors) && model.errors.any?
      end

      @valid = !custom_errors.any? && !model_errors
    end
  end
end
