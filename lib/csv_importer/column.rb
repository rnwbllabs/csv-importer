module CSVImporter
  # A Column from a CSV file with a `name` (from the csv file) and a matching
  # `ColumnDefinition` if any.
  class Column
    extend T::Sig
    # include Virtus.model

    # attribute :name, String
    # attribute :definition, ColumnDefinition

    sig { returns(Symbol) }
    attr_accessor :name

    sig { returns(ColumnDefinition) }
    attr_accessor :definition
  end
end
