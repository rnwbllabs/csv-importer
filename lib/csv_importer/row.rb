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
    # @param model_klass [Class, nil] The legacy single model class (optional)
    # @param identifiers [Array<Symbol>, Proc, nil] Legacy identifiers for the single model
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
        model_klass: T.untyped,
        identifiers: T.nilable(T.any(T::Array[Symbol], Proc)),
        models: T::Hash[Symbol, T.anything],
        persist_order: T::Array[Symbol],
        model_identifiers: T::Hash[Symbol, T.any(T::Array[Symbol], Proc)],
        after_build_blocks: T::Array[Proc],
        skip: T::Boolean,
        datastore: T::Hash[Symbol, T.anything]
      ).void
    end
    def initialize(line_number:, header: nil, row_array: [], model_klass: nil, identifiers: nil,
      models: {}, persist_order: [], model_identifiers: {}, after_build_blocks: [], skip: false, datastore: {})
      @header = T.let(header, T.nilable(Header))
      @line_number = T.let(line_number, Integer)
      @row_array = T.let(row_array, T::Array[String])

      # Handle legacy single model or new multi-model approach
      @model_klass = T.let(model_klass, T.untyped)
      @identifiers = T.let(identifiers, T.nilable(T.any(T::Array[Symbol], Proc)))

      # Determine the mode: legacy single-model or multi-model
      @legacy_mode = T.let(model_klass != nil, T::Boolean)

      # If we have a legacy model_klass but no models hash, set up the models hash
      if model_klass && models.empty?
        models = { _default: model_klass }
      end

      # If we have legacy identifiers but no model_identifiers hash, set those up
      if identifiers && model_identifiers.empty?
        model_identifiers = { _default: identifiers }
      end

      @models = T.let(models, T::Hash[Symbol, T.anything])
      @persist_order = T.let(persist_order, T::Array[Symbol])
      @model_identifiers = T.let(model_identifiers, T::Hash[Symbol, T.any(T::Array[Symbol], Proc)])
      @after_build_blocks = T.let(after_build_blocks, T::Array[Proc])
      @skip = T.let(skip, T::Boolean)
      @built_models = T.let({}, T::Hash[Symbol, T.untyped])
      @model = T.let(nil, T.untyped) # Legacy @model field
      @csv_attributes = T.let(nil, T.nilable(T::Hash[T.any(String, Symbol), T.nilable(String)]))
      @datastore = T.let(datastore, T::Hash[Symbol, T.anything])
      @custom_errors = T.let([], T::Array[CustomError])
      @_was_persisted = T.let(false, T::Boolean)

      # Initialize @valid as true (assume valid until proven otherwise)
      @valid = T.let(true, T::Boolean)
      @validation_run = T.let(false, T::Boolean)

      @after_build_blocks_run = T.let(false, T::Boolean)
    end

    # Check if we're using the legacy single-model mode
    # @return [Boolean] true if using the legacy single-model mode
    sig { returns(T::Boolean) }
    def legacy_mode?
      @legacy_mode
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
      # When skipping, consider validation complete
      @validation_run = true
    end

    # The model to be persisted (for backward compatibility)
    # @return [Object] The built model instance with attributes set
    sig { returns(T.untyped) }
    def model
      # If we're using the legacy approach, use the original model code
      if legacy_mode?
        @model ||= begin
          model = find_or_build_model
          set_attributes(model)

          # Run after_build blocks only if not run yet
          run_after_build_hooks_legacy(model) unless @after_build_blocks_run

          model
        end
      else
        # Otherwise, use the multi-model approach and return the default model
        # Ensure built_models is called to build all models
        built_models
        built_models[:_default] || built_models.values.first
      end
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

    # Run after_build blocks on the models (legacy approach)
    # @param model [Object] The model to run blocks on
    # @return [void]
    sig { params(model: T.untyped).void }
    def run_after_build_hooks_legacy(model)
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

    # Run after_build blocks on the models
    # @return [void]
    sig { void }
    def run_after_build_hooks
      return if @after_build_blocks_run

      @after_build_blocks_run = true

      # Support both single-model and multi-model approaches
      if @model_klass
        # Single model approach - pass the legacy model
        after_build_blocks.each do |block|
          if block.arity == 1
            T.unsafe(self).instance_exec(model, &block)
          else
            T.unsafe(self).instance_exec(&block)
          end
        end
      else
        # Multi-model approach - pass the appropriate model or no model
        after_build_blocks.each do |block|
          if block.arity == 1
            # Try to find an appropriate model to pass - starting with _default
            model_to_pass = built_models[:_default] || built_models.values.first
            T.unsafe(self).instance_exec(model_to_pass, &block)
          else
            T.unsafe(self).instance_exec(&block)
          end
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
      header_obj.columns.each do |column|
        # Skip if this column is for a different model
        definition = column.definition
        next unless definition
        next if model_key && definition.model_key && definition.model_key != model_key

        # Get column name and value
        name = column.name
        value = csv_attributes[name]

        # Clone the value if possible to avoid modifying original
        begin
          value = value.dup if value
        rescue TypeError
          # can't dup Symbols, Integer etc...
        end

        # Skip if the column is virtual
        next if definition.virtual?

        # If the model doesn't respond to the attribute, skip it
        attribute = definition.to.is_a?(Symbol) ? definition.to : definition.name

        # Skip if transformer is a Proc (handle separately) or model doesn't respond to attribute
        if definition.to.is_a?(Proc)
          set_attribute(model, column, value)
        elsif respond_to_attribute?(model, attribute)
          set_attribute(model, column, value)
        end
      end

      model
    end

    # Check if a model responds to an attribute setter
    # @param model [Object] The model to check
    # @param attribute [T.any(String, Symbol)] The attribute to check for
    # @return [Boolean] true if the model responds to the attribute setter
    sig { params(model: T.untyped, attribute: T.any(String, Symbol)).returns(T::Boolean) }
    def respond_to_attribute?(model, attribute)
      model.respond_to?(:"#{attribute}=")
    end

    # Set the attribute using the column_definition and the csv_value
    # @param model [Object] The model to set attributes on
    # @param column [Column] The column to set
    # @param csv_value [String, nil] The value from the CSV
    # @return [Object] The model with attribute set
    sig { params(model: T.untyped, column: T.untyped, csv_value: T.untyped).returns(T.untyped) }
    def set_attribute(model, column, csv_value)
      column_definition = column.definition
      transformer = column_definition.to

      # Important: Do NOT normalize empty strings to nil
      # Leave empty strings as empty strings to maintain compatibility
      normalized_value = csv_value

      if transformer.respond_to?(:call)
        apply_transformer(model, column, normalized_value, transformer)
      else
        # Direct attribute assignment
        attribute = column_definition.to.is_a?(Symbol) ? column_definition.to : column_definition.name
        model.public_send(:"#{attribute}=", normalized_value)
      end

      model
    rescue StandardError => e
      # Add error handling that maintains compatibility with our error approach
      add_error("#{e.class}: #{e.message}",
               column_name: column.name.to_s,
               attribute: column_definition.to.is_a?(Symbol) ? column_definition.to : nil)
      model
    end

    # Apply a transformer to a model's attribute
    # @param model [Object] The model to set attributes on
    # @param column [Column] The column containing the definition
    # @param value [Object] The value to transform
    # @param transformer [Proc] The transformer to apply
    # @return [Object] The model with the transformer applied
    sig { params(model: T.untyped, column: T.untyped, value: T.untyped, transformer: T.untyped).returns(T.untyped) }
    def apply_transformer(model, column, value, transformer)
      column_definition = column.definition
      arity = transformer.is_a?(Proc) ? transformer.arity : transformer.method(:call).arity

      case arity
      when 1 # to: ->(email) { email.downcase }
        # Apply the transformer to the value and set the result
        result = T.unsafe(transformer).call(value)
        model.public_send(:"#{column_definition.name}=", result)
      when 2 # to: ->(published, post) { post.published_at = Time.now if published == "true" }
        # Pass both the value and the model to the transformer
        T.unsafe(transformer).call(value, model)
      when 3 # to: ->(field_value, post, column) { post.hash_field[column.name] = field_value }
        # Pass the value, model, and column to the transformer
        T.unsafe(transformer).call(value, model, column)
      else
        raise ArgumentError, "arity: #{transformer.arity.inspect} - `to` can only have 1, 2 or 3 arguments"
      end

      model
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

      # Only run validation once if not already done
      unless @validation_run
        check_errors
        @validation_run = true
      end

      @valid
    end

    # Collect error messages from all models for debugging
    # @return [String] error messages from all models
    sig { returns(String) }
    def collect_model_error_messages
      error_msg = []
      built_models.each do |key, model|
        next unless model.respond_to?(:errors) && model.errors.any?

        error_msg << "#{key}: #{model.errors.full_messages.join(', ')}"
      end
      error_msg.join("; ")
    end

    # Find a model for the given key
    # @param key [Symbol] The key of the model to find
    # @param klass [Class] The class to look for
    # @return [Object, nil] The found model or nil if not found
    sig { params(key: Symbol, klass: T.untyped).returns(T.untyped) }
    def find_model_for_key(key, klass)
      identifiers = model_identifiers[key]
      return nil unless identifiers

      # Create a temporary model to hold attributes for searching
      temp_model = build_model_for_key(key, klass)

      # Set attributes on the temp model
      set_attributes_for_model(temp_model, key)

      # Apply after_build hooks to ensure transformations are applied before searching
      if legacy_mode?
        run_after_build_hooks_legacy(temp_model) unless @after_build_blocks_run
      else
        # Store the current built_models so we can restore it
        original_built_models = @built_models.dup
        # Temporarily add the model to built_models for hooks
        @built_models[key] = temp_model
        run_after_build_hooks unless @after_build_blocks_run
        # Restore original built_models
        @built_models = original_built_models
      end

      # Use identifiers to find the existing record
      if identifiers.is_a?(Proc)
        find_model_with_proc(key, klass, temp_model, identifiers)
      else
        find_model_with_array(key, klass, temp_model, identifiers)
      end
    end

    # Find a model using a proc-based identifier
    # @param key [Symbol] The model key
    # @param klass [Class] The model class
    # @param temp_model [Object] A temp model with attributes set
    # @param identifiers_proc [Proc] The proc to use for finding
    # @return [Object, nil] The found model or nil
    sig { params(key: Symbol, klass: T.untyped, temp_model: T.untyped, identifiers_proc: Proc).returns(T.untyped) }
    def find_model_with_proc(key, klass, temp_model, identifiers_proc)
      # Execute the proc with or without model based on arity
      if identifiers_proc.arity == 1
        # Execute the proc with the model to get the identifier values
        identifier_result = T.unsafe(self).instance_exec(temp_model, &identifiers_proc)
      else
        # Execute the proc without arguments
        identifier_result = T.unsafe(self).instance_exec(&identifiers_proc)
      end

      return nil unless identifier_result

      # Handle different return types from the proc
      if identifier_result.is_a?(Hash)
        # Hash of attributes for find_by
        klass.find_by(identifier_result)
      elsif identifier_result.is_a?(Array) || identifier_result.is_a?(Symbol)
        # Array of symbols or single symbol - look up values in CSV attributes
        find_model_with_array(key, klass, temp_model, Array(identifier_result))
      else
        # Assume it's a model instance or nil
        identifier_result
      end
    end

    # Find a model using array-based identifiers
    # @param key [Symbol] The model key
    # @param klass [Class] The model class
    # @param temp_model [Object] A temp model with attributes set
    # @param identifiers_array [Array<Symbol>] The identifier attributes
    # @return [Object, nil] The found model or nil
    sig { params(key: Symbol, klass: T.untyped, temp_model: T.untyped, identifiers_array: T::Array[Symbol]).returns(T.untyped) }
    def find_model_with_array(key, klass, temp_model, identifiers_array)
      # Build a query hash for find_by
      query = {}

      # Add each identifier to the query
      identifiers_array.each do |identifier|
        # Try to get value from model
        value = temp_model.send(identifier) if temp_model.respond_to?(identifier)

        # If no value found, try CSV attributes
        if value.nil?
          value = csv_attributes[identifier]
          return nil if value.nil?
        end

        query[identifier] = value
      end

      # Return nil if no identifiers were found
      return nil if query.empty?

      # Find the record
      klass.find_by(query)
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
    # @param skip_row [Boolean] Whether to mark this row to be skipped
    # @return [void]
    sig do
      params(
        message: String,
        column_name: T.nilable(String),
        attribute: T.nilable(Symbol),
        model_key: T.nilable(Symbol),
        skip_row: T::Boolean
      ).void
    end
    def add_error(message, column_name: nil, attribute: nil, model_key: nil, skip_row: false)
      @valid = false
      @validation_run = true
      custom_errors << CustomError.new(
        message: message,
        column_name: column_name,
        attribute: attribute,
        model_key: model_key
      )

      # Optionally skip the row
      skip! if skip_row
    end

    # Convenience method to add a general error not tied to any column or attribute
    # @param message [String] The error message
    # @param skip_row [Boolean] Whether to mark this row to be skipped
    # @return [void]
    sig { params(message: String, skip_row: T::Boolean).void }
    def add_general_error(message, skip_row: false)
      add_error(message, column_name: "_general", skip_row: skip_row)
    end

    # Get all errors for this row organized by column name
    # @return [Hash<String, String>] A hash of column name to error message
    sig { returns(T::Hash[String, String]) }
    def errors
      # Force validation to run if not already done
      valid? unless @validation_run

      error_hash = {}

      # Add custom errors
      custom_errors.each do |error|
        column_name = error.column_name || "_general"
        error_hash[column_name] = error.message
      end

      # Add model errors for all models
      built_models.each do |model_key, model|
        next unless model.respond_to?(:errors) && model.errors.any?

        model.errors.each do |error|
          # Handle both ActiveModel style errors and other error types
          attribute = error.respond_to?(:attribute) ? error.attribute.to_sym : error.first.to_sym
          message = error.respond_to?(:message) ? error.message : error.last

          # Try to map the attribute back to a column name
          column_name = header&.column_name_for_model_attribute(attribute) || attribute.to_s

          # Prefix with model_key if not the default model
          if model_key != :_default
            column_name = "#{model_key}:#{column_name}"
          end

          error_hash[column_name] = message
        end
      end

      error_hash
    end

    # Check if we have models defined for this row
    # @return [Boolean] true if we have models defined
    sig { returns(T::Boolean) }
    def has_models?
      !models.empty?
    end

    # Mark this row as a success
    # @param was_persisted [Boolean] Whether the model was persisted before saving
    # @return [void]
    sig { params(was_persisted: T::Boolean).void }
    def mark_as_success(was_persisted)
      @_was_persisted = was_persisted
    end

    # Mark this row as a failure
    # @return [void]
    sig { void }
    def mark_as_failure
      # Nothing to do here for now
    end

    # Check if this row is empty (all values are empty strings or nil)
    # @return [Boolean] true if the row is empty
    sig { returns(T::Boolean) }
    def empty?
      row_array.all? { |v| v.nil? || v.to_s.strip.empty? }
    end

    # Get the order of models for persistence
    # @return [Array<Symbol>] The order in which models should be persisted
    sig { returns(T::Array[Symbol]) }
    def models_in_order
      if persist_order.empty?
        models.keys.to_a
      else
        persist_order
      end
    end

    # Check if any of the built models have errors
    # @param skip_on_error [Boolean] Whether to skip the row if errors are found
    # @return [void]
    sig { params(skip_on_error: T::Boolean).void }
    def check_errors(skip_on_error = false)
      # Nothing to do if already invalid or skipped
      return if !@valid || skip?

      # Build models if necessary
      built_models

      # Check for custom errors
      if custom_errors.any?
        @valid = false
        skip! if skip_on_error
        return
      end

      # Check for errors on all models
      built_models.each do |key, model|
        # Check if the model responds to errors and if it has any
        if model.respond_to?(:errors) && model.errors.any?
          @valid = false
          skip! if skip_on_error
          return
        end

        # For ActiveModel objects, trigger validations
        if model.respond_to?(:valid?)
          valid_result = model.valid?
          if !valid_result
            @valid = false
            skip! if skip_on_error
            return
          end
        end
      end

      # If we got here, everything is valid
      @valid = true
    end

    private

    # Find an existing record or build a new one (legacy method)
    # @return [Object] Found or newly built model instance
    sig { returns(T.untyped) }
    def find_or_build_model
      find_model || build_model
    end

    # Find an existing model based on identifiers (legacy method)
    # @return [Object, nil] Found model instance or nil if not found
    sig { returns(T.untyped) }
    def find_model
      return nil if @identifiers.nil?

      # Build a temporary model to extract identifier values
      temp_model = build_model
      set_attributes(temp_model)

      # Get the actual identifier values to search with
      ids = model_identifiers_legacy(temp_model)
      return nil if ids.empty?

      # Build the query from identifier values
      query = ids.map { |identifier| [identifier, temp_model.public_send(identifier)] }.to_h

      # Important: return the found model directly, not the temp model
      T.unsafe(@model_klass).find_by(query)
    end

    # Build a new model instance (legacy method)
    # @return [Object] New model instance
    sig { returns(T.untyped) }
    def build_model
      @model_klass.new
    end

    # Set attributes on a model (legacy method)
    # @param model [Object] The model to set attributes on
    # @return [Object] The model with attributes set
    sig { params(model: T.untyped).returns(T.untyped) }
    def set_attributes(model)
      # Safely handle nil header
      return model if header.nil?

      T.must(header).columns.each do |column|
        name = column.name
        attrs = csv_attributes
        value = attrs[name]
        begin
          value = value.dup if value
        rescue TypeError
          # can't dup Symbols, Integer etc...
        end

        definition = column.definition
        next unless definition
        next if definition.virtual?

        set_attribute(model, column, value)
      end

      model
    end

    # Get the actual identifiers to use for the model (legacy method)
    # @param model [Object] The model to get identifiers for
    # @return [Array<Symbol>] The identifiers to use
    sig { params(model: T.untyped).returns(T::Array[Symbol]) }
    def model_identifiers_legacy(model)
      ids = @identifiers
      if ids.nil?
        []
      elsif ids.is_a?(Proc)
        # Safely call the proc, handling nil values
        begin
          # Use T.unsafe to handle the variable return type from the Proc
          [T.unsafe(ids).call(model)].flatten
        rescue NoMethodError => e
          # If we get a NoMethodError (likely due to a nil value),
          # return a default identifier like :email
          add_error("Error in identifier proc: #{e.message}",
                   column_name: "_general",
                   skip_row: true)
          [:email] # Default to email as a last resort
        end
      else
        ids
      end
    end
  end
end
