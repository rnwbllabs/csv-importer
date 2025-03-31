# typed: strict
# frozen_string_literal: true

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
    class CustomError < T::Struct
      const :message, String
      const :column_name, T.nilable(String)
      const :attribute, T.nilable(Symbol)
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

    # @!attribute [rw] model_klass
    # @return [Class] the model class that will be instantiated
    sig { returns(T.untyped) }
    attr_accessor :model_klass

    # @!attribute [rw] identifiers
    # @return [Array<Symbol>, Proc, nil] identifiers used to find existing records
    sig { returns(T.nilable(T.any(T::Array[Symbol], Proc))) }
    attr_accessor :identifiers

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
    # @param model_klass [Class] The class to instantiate for this row
    # @param identifiers [Array<Symbol>, Proc, nil] Identifiers to find existing records
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
        after_build_blocks: T::Array[Proc],
        skip: T::Boolean,
        datastore: T::Hash[Symbol, T.anything]
      ).void
    end
    def initialize(line_number:, header: nil, row_array: [], model_klass: nil, identifiers: nil,
      after_build_blocks: [], skip: false, datastore: {})
      @header = T.let(header, T.nilable(Header))
      @line_number = T.let(line_number, Integer)
      @row_array = T.let(row_array, T::Array[String])
      @model_klass = T.let(model_klass, T.untyped)
      @identifiers = T.let(identifiers, T.nilable(T.any(T::Array[Symbol], Proc)))
      @after_build_blocks = T.let(after_build_blocks, T::Array[Proc])
      @skip = T.let(skip, T::Boolean)
      @model = T.let(nil, T.untyped)
      @csv_attributes = T.let(nil, T.nilable(T::Hash[T.any(String, Symbol), T.nilable(String)]))
      @datastore = T.let(datastore, T::Hash[Symbol, T.anything])
      @custom_errors = T.let([], T::Array[CustomError])
      @valid = T.let(nil, T.nilable(T::Boolean))
    end

    # Check if this row should be skipped
    # @return [Boolean] true if the row should be skipped
    sig { returns(T::Boolean) }
    def skip?
      skip
    end

    # The model to be persisted
    # @return [Object] The built model instance with attributes set
    sig { returns(T.untyped) }
    def model
      @model ||= begin
        model = find_or_build_model

        set_attributes(model)

        after_build_blocks.each do |block|
          # Use unsafe to handle blocks with unknown arity
          T.unsafe(self).instance_exec(model, &block)
        end
        model
      end
    end

    # A hash with this row's attributes
    # @return [Hash<String|Symbol, String|nil>] Mapping of column names to values
    sig { returns(T.nilable(T::Hash[T.any(String, Symbol), T.nilable(String)])) }
    def csv_attributes
      @csv_attributes ||= begin
        return nil if header.nil?

        # After the nil check, we know header is present
        column_names = T.must(header).column_names
        column_names.zip(row_array).to_h
      end
    end

    # Set attributes
    # @param model [Object] The model to set attributes on
    # @return [Object] The model with attributes set
    sig { params(model: T.untyped).returns(T.untyped) }
    def set_attributes(model)
      # Safely handle nil header
      return model if header.nil?

      T.must(header).columns.each do |column|
        name = T.cast(column.name, String)
        attrs = T.must(csv_attributes)
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

    # Set the attribute using the column_definition and the csv_value
    # @param model [Object] The model to set attributes on
    # @param column [Column] The column to set
    # @param csv_value [String, nil] The value from the CSV
    # @return [Object] The model with attribute set
    sig { params(model: T.untyped, column: T.untyped, csv_value: T.untyped).returns(T.untyped) }
    def set_attribute(model, column, csv_value)
      column_definition = column.definition
      transformer = column_definition.to
      if transformer.respond_to?(:call)
        arity = transformer.is_a?(Proc) ? transformer.arity : transformer.method(:call).arity

        case arity
        when 1 # to: ->(email) { email.downcase }
          model.public_send(:"#{column_definition.name}=", T.unsafe(transformer).call(csv_value))
        when 2 # to: ->(published, post) { post.published_at = Time.now if published == "true" }
          T.unsafe(transformer).call(csv_value, model)
        when 3 # to: ->(field_value, post, column) { post.hash_field[column.name] = field_value }
          T.unsafe(transformer).call(csv_value, model, column)
        else
          raise ArgumentError, "arity: #{transformer.arity.inspect} - `to` can only have 1, 2 or 3 arguments"
        end
      else
        attribute = column_definition.attribute
        model.public_send(:"#{attribute}=", csv_value)
      end

      model
    end

    # Add error for a specific CSV column
    # @param column_name [String, Symbol] Name of the CSV column
    # @param message [String] Error message
    # @return [self] Self for method chaining
    sig { params(column_name: T.any(String, Symbol), message: String).returns(T.self_type) }
    def add_error(column_name, message)
      @custom_errors << CustomError.new(
        message: message,
        column_name: column_name.to_s
      )
      skip!
      self
    end

    # Add error for a model attribute
    # @param attribute [Symbol] Model attribute name
    # @param message [String] Error message
    # @return [self] Self for method chaining
    sig { params(attribute: Symbol, message: String).returns(T.self_type) }
    def add_model_error(attribute, message)
      # Don't call model() here to avoid recursion - use @model if already built
      if @model
        @model.errors.add(attribute, message)
      else
        # Store it in custom errors if model isn't built yet
        @custom_errors << CustomError.new(message:, attribute:)
      end
      skip!
      self
    end

    # Add a general error not tied to any specific column
    # @param message [String] Error message
    # @return [self] Self for method chaining
    sig { params(message: String).returns(T.self_type) }
    def add_general_error(message)
      @custom_errors << CustomError.new(
        message: message
      )
      skip!
      self
    end

    # Check if this row is valid
    # @return [Boolean] true if the row is valid
    sig { returns(T::Boolean) }
    def valid?
      # Custom errors always make the row invalid
      return false if custom_errors.any?

      # Use cached validation result if available
      @valid = model.valid? if @valid.nil?
      @valid
    end

    # Error from the model mapped back to the CSV header if we can
    # @return [Hash] Errors mapped to CSV column names where possible
    # @note Includes custom errors if available
    sig { returns(T::Hash[T.any(String, Symbol), T.nilable(String)]) }
    def errors
      # Get model errors mapped to column names when possible
      model_errors = model.errors.to_hash.map do |attribute, errors|
        if header && (column_name = T.must(header).column_name_for_model_attribute(attribute))
          [column_name, errors.last]
        else
          [attribute, errors.last]
        end
      end.to_h

      custom_errors.each do |error|
        # If error has a column_name, use it directly
        key = if error.column_name
          error.column_name
        # If error has an attribute but no column_name, try to map it to CSV column
        elsif (attribute = error.attribute) && header
          T.must(header).column_name_for_model_attribute(attribute) || attribute
        # Otherwise use a general key
        else
          "_general"
        end

        model_errors[key] = error.message
      end

      model_errors
    end

    # Find an existing record or build a new one
    # @return [Object] Found or newly built model instance
    sig { returns(T.untyped) }
    def find_or_build_model
      find_model || build_model
    end

    # Find an existing model based on identifiers
    # @return [Object, nil] Found model instance or nil if not found
    sig { returns(T.untyped) }
    def find_model
      return nil if identifiers.nil?

      model = build_model
      set_attributes(model)

      ids = model_identifiers(model)
      return nil if ids.empty?

      query = ids.map { |identifier| [identifier, model.public_send(identifier)] }.to_h
      T.unsafe(model_klass).find_by(query)
    end

    # Build a new model instance
    # @return [Object] New model instance
    sig { returns(T.untyped) }
    def build_model
      model_klass.new
    end

    # Mark this row to be skipped
    # @return [self] Self for method chaining
    sig { returns(T.self_type) }
    def skip!
      self.skip = true
      self
    end

    private

    # Get the actual identifiers to use for the model
    # @param model [Object] The model to get identifiers for
    # @return [Array<Symbol>] The identifiers to use
    sig { params(model: T.untyped).returns(T::Array[Symbol]) }
    def model_identifiers(model)
      ids = @identifiers
      if ids.nil?
        []
      elsif ids.is_a?(Proc)
        # Use T.unsafe to handle the variable return type from the Proc
        [T.unsafe(ids).call(model)].flatten
      else
        ids
      end
    end
  end
end
