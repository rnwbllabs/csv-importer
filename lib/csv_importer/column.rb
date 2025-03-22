# typed: true

module CSVImporter
  # A Column from a CSV file with a `name` (from the csv file) and a matching
  # `ColumnDefinition` if any.
  class Column
    extend T::Sig
    # attribute :name, String
    # attribute :definition, ColumnDefinition

    sig { returns(T.any(String, Symbol)) }
    attr_accessor :name

    sig { returns(T.nilable(ColumnDefinition)) }
    attr_accessor :definition

    def initialize(name:, definition:)
      @name = name
      @definition = definition
    end
  end
end
