# typed: strict
# frozen_string_literal: true

module CSVImporter
  # CSV Header is a class that represents the header of a CSV file. It is ultimately used to map the columns of the CSV
  # file to the attributes of the model.
  class Header
    extend T::Sig

    # Associated column definitions for the importer
    # @!attribute [rw] column_definitions
    # @return [Array[ColumnDefinition]] the column definitions for the importer
    sig { returns(T::Array[ColumnDefinition]) }
    attr_accessor :column_definitions

    # Associated column names for the importer
    # @!attribute [rw] column_names
    # @return [Array[String, Symbol]] the column names for the importer
    sig { returns(T::Array[T.any(String, Symbol)]) }
    attr_accessor :column_names

    # Initialize the header with column definitions and names
    # @param column_definitions [Array[ColumnDefinition]] [Optional] the column definitions for the importer. Defaults
    # to an empty array.
    # @param column_names [Array[String]] [Optional] the column names for the importer. Defaults to an empty array.
    sig do
      params(column_definitions: T::Array[ColumnDefinition], column_names: T::Array[T.any(String, Symbol)]).void
    end
    def initialize(column_definitions: [], column_names: [])
      @column_definitions = T.let(column_definitions, T::Array[ColumnDefinition])

      @column_names = column_names
    end

    # Columns for the importer
    # @return [Array[Column]] the columns for the importer
    sig { returns(T::Array[Column]) }
    def columns
      column_names.map do |column_name|
        # ensure column name escapes invisible characters
        column_name = column_name.to_s.gsub(/[^[:print:]]/, "")

        Column.new(
          name: column_name,
          definition: find_column_definition(column_name)
        )
      end
    end

    # Get the CSV column name for a model attribute
    # @param attribute [Symbol] The model attribute
    # @return [String, nil] The CSV column name or nil if not found
    sig { params(attribute: Symbol).returns(T.nilable(String)) }
    def column_name_for_model_attribute(attribute)
      definition = column_definitions.find do |d|
        d.to == attribute || d.name == attribute
      end

      if definition
        # Find the column name and convert it to a string before and after
        found_name = column_names.find do |name|
          # Convert to string for matching
          definition.match?(name.to_s)
        end
        found_name ? found_name.to_s : nil
      else
        nil
      end
    end

    # Whether the header is valid, i.e., all required columns are present
    # @return [Boolean] true if the header is valid, false otherwise
    sig { returns(T::Boolean) }
    def valid?
      missing_required_columns.empty?
    end

    # Required columns for the importer
    # @return [Array[String]] the required columns, based on the column definitions
    sig { returns(T::Array[String]) }
    def required_columns
      column_definitions.select(&:required?).filter_map(&:name).map(&:to_s)
    end

    # Extra columns for the importer, i.e., columns that are not defined in the column definitions
    # @return [Array[String]] the extra columns, based on the column definitions
    sig { returns(T::Array[String]) }
    def extra_columns
      columns.reject(&:definition).filter_map(&:name).map(&:to_s)
    end

    # Missing columns for the importer, i.e., columns that are required but not present in the header
    # @return [Array[String]] the missing columns, based on the column definitions
    sig { returns(T::Array[String]) }
    def missing_required_columns
      (column_definitions.select(&:required?) - columns.map(&:definition)).filter_map(&:name).map(&:to_s)
    end

    # Columns for the importer that are defined in the column definitions but not present in the header
    # @return [Array[String]] the columns that are defined in the column definitions but not present in the header
    sig { returns(T::Array[String]) }
    def missing_columns
      (column_definitions - columns.map(&:definition)).filter_map(&:name).map(&:to_s)
    end

    private

    # Find a column definition by name
    # @param name [Symbol, String] the name of the column definition to find
    # @return [ColumnDefinition, nil] the column definition, or nil if the column definition is not found
    sig { params(name: T.any(Symbol, String)).returns(T.nilable(ColumnDefinition)) }
    def find_column_definition(name)
      column_definitions.find { |column_definition| column_definition.match?(name.to_s) }
    end

    # Column definition names for the importer
    # @return [Array[String]] the column definition names for the importer
    sig { returns(T::Array[String]) }
    def column_definition_names
      column_definitions.map(&:name).map(&:to_s)
    end
  end
end
