# typed: strict
# frozen_string_literal: true

module CSVImporter
  # A Column from a CSV file with a `name` (from the csv file) and a matching
  # `ColumnDefinition` if any.
  class Column
    extend T::Sig

    # The name of the column in the CSV file
    # @!attribute [rw] name
    # @return [String, Symbol] the name of the column in the CSV file
    sig { returns(T.any(String, Symbol)) }
    attr_accessor :name

    # ColumnDefinition associated with the column
    # @!attribute [rw] definition
    # @return [ColumnDefinition, nil] the definition of the column
    sig { returns(T.nilable(ColumnDefinition)) }
    attr_accessor :definition

    # @param name [String, Symbol] the name of the column in the CSV file
    # @param definition [ColumnDefinition, nil] the definition of the column
    sig { params(name: T.any(String, Symbol), definition: T.nilable(ColumnDefinition)).void }
    def initialize(name:, definition:)
      @name = name
      @definition = definition
    end
  end
end
