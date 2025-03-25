# typed: strict
# frozen_string_literal: true

module CSVImporter
  # Define a column. Called from the DSL via `column.
  #
  # @example the csv column "email" will be assigned to the `email` attribute
  #
  #   column :email
  #
  # @example the csv column matching /email/i will be assigned to the `email` attribute
  #
  #   column :email, as: /email/i
  #
  # @example the csv column matching "First name" or "Prénom" will be assigned to the `first_name` attribute
  #
  #   column :first_name, as: [/first ?name/i, /pr(é|e)nom/i]
  #
  # @example the csv column "first_name" will be assigned to the `f_name` attribute
  #
  #   column :first_name, to: :f_name
  #
  # @example email will be downcased
  #
  #   column :email, to: ->(email) { email.downcase }
  #
  # @example transform `confirmed` to `confirmed_at`
  #
  #   column :confirmed, to: ->(confirmed, model) do
  #     model.confirmed_at = confirmed == "true" ? Time.new(2012) : nil
  #   end
  class ColumnDefinition
    extend T::Sig

    ToType = T.type_alias { T.nilable(T.any(Symbol, T.untyped)) }
    AsNonArrayType = T.type_alias { T.nilable(T.any(Symbol, String, Regexp)) }
    AsType = T.type_alias { T.nilable(T.any(AsNonArrayType, T::Array[AsNonArrayType])) }

    # @!attribute [rw] name
    # @return [String, Symbol, nil] the name of the column in the CSV file
    sig { returns(T.nilable(T.any(String, Symbol))) }
    attr_accessor :name

    # @!attribute [rw] to
    # @return [Symbol, T.untyped, nil] the attribute on the model that will be set with the value of the column.
    #  If nil, the name of the column in the CSV file will be used.
    sig { returns(ToType) }
    attr_accessor :to

    # @!attribute [rw] as
    # @return [Symbol, String, Regexp, Array<Symbol, String, Regexp>, nil] more complex matching logic for the name
    #   of the column in the CSV file. If nil, the name of the column in the CSV file will be used.
    sig { returns(AsType) }
    attr_accessor :as

    # @!attribute [rw] required
    # @return [Boolean] whether the column is required
    sig { returns(T::Boolean) }
    attr_accessor :required

    # Initialize a new column definition
    # @param name [Symbol, String, nil] the name of the column in the CSV file
    # @param to [Symbol, Proc, nil] the attribute on the model that will be set with the value of the column. If nil,
    #   the name of the column in the CSV file will be used.
    # @param as [Symbol, String, Regexp, Array, nil] more complex matching logic for the name of the column in the CSV file.
    #   If nil, the name of the column in the CSV file will be used.
    # @param required [Boolean] whether the column is required
    sig do
      params(
        name: T.nilable(T.any(String, Symbol)),
        to: ToType,
        as: AsType,
        required: T::Boolean
      ).void
    end
    def initialize(name: nil, to: nil, as: nil, required: false)
      @name = name
      @to = to
      @as = as
      @required = required
    end

    # Whether the column is required, i.e., the model will raise an error if the column is not present in the CSV file.
    # @return [Boolean] `true` if the column is required, `false` otherwise
    sig { returns(T::Boolean) }
    def required?
      required
    end

    # Attribute on the model that will be set with the value of the column
    # @return [Symbol, T.untyped] the model attribute that this column targets
    sig { returns(T.any(Symbol, T.untyped)) }
    def attribute
      if to.is_a?(Symbol)
        to
      else
        name
      end
    end

    # Return true if column definition matches the column name passed in.
    # @param column_name [String, nil] the name of the column in the CSV file
    # @param search_query [Symbol, String, Regexp, Array, nil] the name of the column in the CSV file
    # @return [Boolean] `true` if the column definition matches the column name, `false` otherwise
    # @raise [Error] if the `as` option is not a Symbol, String, Regexp or Array
    sig do
      params(
        column_name: T.nilable(String),
        search_query: AsType
      ).returns(T::Boolean)
    end
    def match?(column_name, search_query = nil)
      return false if column_name.nil?

      search_query ||= as || name

      downcased_column_name = column_name.downcase
      underscored_column_name = downcased_column_name.gsub(/\s+/, "_")

      case search_query
      when Symbol
        underscored_column_name == search_query.to_s
      when String
        downcased_column_name == search_query.downcase
      when Regexp
        !!(column_name =~ search_query)
      when Array
        search_query.any? { |query| match?(column_name, query) }
      else
        raise Error, "Invalid `as`. Should be a Symbol, String, Regexp or Array - was #{as.inspect}"
      end
    end
  end
end
