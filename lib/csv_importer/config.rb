# typed: strict
# frozen_string_literal: true

module CSVImporter
  # The configuration of a CSVImporter
  class Config
    extend T::Sig

    sig { returns(T.nilable(T.any(T::Class[T.anything], T.untyped))) }
    # Model class or relation to which imported data will be mapped
    # Can be an ActiveRecord class, a scope, or an association
    # @return [T.nilable(T.any(Class, Object))] the model to map to
    attr_accessor :model

    sig { returns(T.nilable(T.any(T::Array[Symbol], Proc)))}
    # The identifiers for the model, used to uniquely identify a record for finding or creating it
    # @return [T.nilable(T.any(T::Array[Symbol], Proc))] the identifiers for the model
    attr_accessor :identifiers

    sig { returns(Symbol) }
    # The action to take when a record is invalid
    # @return [Symbol] the action to take when a record is invalid
    attr_accessor :when_invalid

    sig { returns(T::Array[ColumnDefinition]) }
    # The column definitions for the model
    # @return [T::Array[ColumnDefinition]] the column definitions for the model
    attr_accessor :column_definitions

    sig { returns(T::Array[Proc]) }
    # The blocks to run after a record is built
    # @return [T::Array[Proc]] the blocks to run after a record is built
    attr_accessor :after_build_blocks

    sig { returns(T::Array[Proc]) }
    # The blocks to run after a record is saved
    # @return [T::Array[Proc]] the blocks to run after a record is saved
    attr_accessor :after_save_blocks

    sig { void }
    # Initialize the config with default values
    def initialize
      @column_definitions = T.let([], T::Array[ColumnDefinition])
      @after_build_blocks = T.let([], T::Array[Proc])
      @after_save_blocks = T.let([], T::Array[Proc])
      @when_invalid = T.let(:skip, Symbol)
    end

    sig { params(block: Proc).void }
    # Add a block to run after a record is built
    # @param block [Proc] the block to run after a record is built
    # @note the proc will be added to the config's after_build_blocks array
    def after_build(block)
      @after_build_blocks << block
    end

    sig { params(block: Proc).void }
    # Add a block to run after a record is saved
    # @param block [Proc] the block to run after a record is saved
    # @note the proc will be added to the config's after_save_blocks array
    def after_save(block)
      @after_save_blocks << block
    end

    sig { params(orig: Config).void }
    # Support for dup operations used in csv_importer.rb
    # @param orig [Config] the original config
    # @note the dup will be used to create a new config with the same values as the original config
    def initialize_copy(orig)
      super
      @column_definitions = orig.column_definitions.dup
      @identifiers = orig.identifiers.dup if orig.identifiers
      @after_save_blocks = orig.after_save_blocks.dup
      @after_build_blocks = orig.after_build_blocks.dup
    end
  end
end
