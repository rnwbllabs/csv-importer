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

    sig { returns(T.nilable(Header)) }
    # @!attribute [r] header
    # @return [Header, nil] the header of the row
    attr_reader :header

    sig { params(value: T.nilable(Header)).void }
    # Sets the header for the row
    # @param value [Header, nil] the header to set
    def header=(value)
      @header = value
    end

    sig { returns(Integer) }
    # @!attribute [r] line_number
    # @return [Integer] the line number of the row in the CSV file
    attr_reader :line_number

    sig { params(value: Integer).void }
    # Sets the line number for the row
    # @param value [Integer] the line number to set
    def line_number=(value)
      @line_number = value
    end

    sig { returns(T::Array[String]) }
    # @!attribute [r] row_array
    # @return [Array<String>] the array of values from the row
    attr_reader :row_array

    sig { params(value: T::Array[String]).void }
    # Sets the row array values
    # @param value [Array<String>] the array of values to set
    def row_array=(value)
      @row_array = value
    end

    sig { returns(T.untyped) }
    # @!attribute [r] model_klass
    # @return [Class] the model class that will be instantiated
    attr_reader :model_klass

    sig { params(value: T.untyped).void }
    # Sets the model class
    # @param value [Class] the model class to set
    def model_klass=(value)
      @model_klass = value
    end

    sig { returns(T.nilable(T.any(T::Array[Symbol], Proc))) }
    # @!attribute [r] identifiers
    # @return [Array<Symbol>, Proc, nil] identifiers used to find existing records
    attr_reader :identifiers

    sig { params(value: T.nilable(T.any(T::Array[Symbol], Proc))).void }
    # Sets the identifiers for finding existing records
    # @param value [Array<Symbol>, Proc, nil] the identifiers to set
    def identifiers=(value)
      @identifiers = value
    end

    sig { returns(T::Array[Proc]) }
    # @!attribute [r] after_build_blocks
    # @return [Array<Proc>] blocks to run after building the model
    attr_reader :after_build_blocks

    sig { params(value: T::Array[Proc]).void }
    # Sets the after build blocks
    # @param value [Array<Proc>] the blocks to run after building
    def after_build_blocks=(value)
      @after_build_blocks = value
    end

    sig { returns(T::Boolean) }
    # @!attribute [r] skip
    # @return [Boolean] whether this row should be skipped
    attr_reader :skip

    sig { params(value: T::Boolean).void }
    # Sets whether this row should be skipped
    # @param value [Boolean] true if the row should be skipped
    def skip=(value)
      @skip = value
    end

    sig do
      params(
        line_number: Integer,
        header: T.nilable(Header),
        row_array: T::Array[String],
        model_klass: T.untyped,
        identifiers: T.nilable(T.any(T::Array[Symbol], Proc)),
        after_build_blocks: T::Array[Proc],
        skip: T::Boolean
      ).void
    end
    # Initialize a new Row
    # @param line_number [Integer] The line number in the CSV file
    # @param header [Header, nil] The CSV header
    # @param row_array [Array<String>] The raw values from the CSV row
    # @param model_klass [Class] The class to instantiate for this row
    # @param identifiers [Array<Symbol>, Proc, nil] Identifiers to find existing records
    # @param after_build_blocks [Array<Proc>] Blocks to run after building the model
    # @param skip [Boolean] Whether to skip this row
    def initialize(line_number:, header: nil, row_array: [], model_klass: nil, identifiers: nil,
      after_build_blocks: [], skip: false)
      @header = T.let(header, T.nilable(Header))
      @line_number = T.let(line_number, Integer)
      @row_array = T.let(row_array, T::Array[String])
      @model_klass = T.let(model_klass, T.untyped)
      @identifiers = T.let(identifiers, T.nilable(T.any(T::Array[Symbol], Proc)))
      @after_build_blocks = T.let(after_build_blocks, T::Array[Proc])
      @skip = T.let(skip, T::Boolean)
      @model = T.let(nil, T.untyped)
      @csv_attributes = T.let(nil, T.untyped)
    end

    sig { returns(T::Boolean) }
    # Check if this row should be skipped
    # @return [Boolean] true if the row should be skipped
    def skip?
      skip
    end

    sig { returns(T.untyped) }
    # The model to be persisted
    # @return [Object] The built model instance with attributes set
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

    sig { returns(T::Hash[String, String]) }
    # A hash with this row's attributes
    # @return [Hash<String, String>] Mapping of column names to values
    def csv_attributes
      @csv_attributes ||= begin
        # Safely handle nil header
        column_names = T.must(header).column_names
        T.cast([column_names.zip(row_array)].to_h, T::Hash[String, String])
      end
    end

    sig { params(model: T.untyped).returns(T.untyped) }
    # Set attributes on the associated model
    # @param model [Object] The model to set attributes on
    # @return [Object] The model with attributes set
    def set_attributes(model)
      # Safely handle nil header
      T.must(header).columns.each do |column|
        name = T.cast(column.name, String)
        value = csv_attributes[name]
        begin
          value = value.dup if value
        rescue TypeError
          # can't dup Symbols, Integer etc...
        end

        next if column.definition.nil?

        set_attribute(model, column, value)
      end

      model
    end

    sig { params(model: T.untyped, column: T.untyped, csv_value: T.untyped).returns(T.untyped) }
    # Set an attribute on the model using the column_definition and the csv_value
    # @param model [Object] The model to set attributes on
    # @param column [Column] The column to set
    # @param csv_value [String, nil] The value from the CSV
    # @return [Object] The model with attribute set
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

    sig { returns(T::Hash[T.any(String, Symbol), T.nilable(String)]) }
    # Errors from the model mapped back to the CSV header if we can
    # @return [Hash] Errors mapped to CSV column names where possible
    def errors
      Hash[
        model.errors.to_hash.map do |attribute, errors|
          if header && (column_name = T.must(header).column_name_for_model_attribute(attribute))
            [column_name, errors.last]
          else
            [attribute, errors.last]
          end
        end
      ]
    end

    sig { returns(T.untyped) }
    # Find an existing record or build a new one
    # @return [Object] Found or newly built model instance
    def find_or_build_model
      find_model || build_model
    end

    sig { returns(T.untyped) }
    # Find an existing model based on identifiers
    # @return [Object, nil] Found model instance or nil if not found
    def find_model
      return nil if identifiers.nil?

      model = build_model
      set_attributes(model)

      ids = model_identifiers(model)
      return nil if ids.empty?

      query = Hash[
        ids.map { |identifier| [identifier, model.public_send(identifier)] }
      ]
      T.unsafe(model_klass).find_by(query)
    end

    sig { returns(T.untyped) }
    # Build a new model instance
    # @return [Object] New model instance
    def build_model
      model_klass.new
    end

    sig { returns(T.self_type) }
    # Mark this row to be skipped
    # @return [self] Self for method chaining
    def skip!
      self.skip = true
      self
    end

    private

    sig { params(model: T.untyped).returns(T::Array[Symbol]) }
    # Get the actual identifiers to use for the model
    # @param model [Object] The model to get identifiers for
    # @return [Array<Symbol>] The identifiers to use
    def model_identifiers(model)
      ids = @identifiers
      if ids.nil?
        T.cast([], T::Array[Symbol])
      elsif ids.is_a?(Proc)
        # Use T.unsafe to handle the variable return type from the Proc
        T.cast([T.unsafe(ids).call(model)].flatten, T::Array[Symbol])
      else
        T.cast(ids, T::Array[Symbol])
      end
    end
  end
end
