# typed: strong
# frozen_string_literal: true

module CSVImporter
  # The configuration of a CSVImporter
  class Config
    extend T::Sig

    # Model class or relation to which imported data will be mapped
    # Can be an ActiveRecord class, a scope, or an association
    # @!attribute [rw] model
    # @return [T.nilable(T.any(Class, Object))] the model to map to
    sig { returns(T.nilable(T.any(T::Class[T.anything], T.untyped))) }
    attr_accessor :model

    # The identifiers for the model, used to uniquely identify a record for finding or creating it
    # @!attribute [rw] identifiers
    # @return [T.nilable(T.any(T::Array[Symbol], Proc))] the identifiers for the model
    sig { returns(T.nilable(T.any(T::Array[Symbol], Proc))) }
    attr_accessor :identifiers

    # The action to take when a record is invalid
    # @!attribute [rw] when_invalid
    # @return [Symbol] the action to take when a record is invalid
    sig { returns(Symbol) }
    attr_accessor :when_invalid

    # Whether to run in preview mode (validate only, no persistence)
    # @!attribute [rw] preview_mode
    # @return [Boolean] whether to run in preview mode
    sig { returns(T::Boolean) }
    attr_accessor :preview_mode

    # The column definitions for the model
    # @!attribute [rw] column_definitions
    # @return [T::Array[ColumnDefinition]] the column definitions for the model
    sig { returns(T::Array[ColumnDefinition]) }
    attr_accessor :column_definitions

    # The blocks to perform before the import is run, i.e., before any rows are processed whatsoever
    # @!attribute [rw] before_import_blocks
    # @return [T::Array[Proc]] the blocks to perform before the import is run
    sig { returns(T::Array[Proc]) }
    attr_accessor :before_import_blocks

    # The blocks to run after a record is built
    # @!attribute [rw] after_build_blocks
    # @return [T::Array[Proc]] the blocks to run after a record is built
    sig { returns(T::Array[Proc]) }
    attr_accessor :after_build_blocks

    # The blocks to run after a record is saved
    # @!attribute [rw] after_save_blocks
    # @return [T::Array[Proc]] the blocks to run after a record is saved
    sig { returns(T::Array[Proc]) }
    attr_accessor :after_save_blocks

    # Initialize the config with default values
    sig { void }
    def initialize
      @column_definitions = T.let([], T::Array[ColumnDefinition])
      @before_import_blocks = T.let([], T::Array[Proc])
      @after_build_blocks = T.let([], T::Array[Proc])
      @after_save_blocks = T.let([], T::Array[Proc])
      @when_invalid = T.let(:skip, Symbol)
      @preview_mode = T.let(false, T::Boolean)
    end

    # Add a block to run before the import is run
    # @param block [Proc] the block to run before the import is run
    # @note the proc will be added to the config's before_import_blocks array
    sig { params(block: Proc).void }
    def before_import(block)
      @before_import_blocks << block
    end

    # Add a block to run after a record is built
    # @param block [Proc] the block to run after a record is built
    # @note the proc will be added to the config's after_build_blocks array
    sig { params(block: Proc).void }
    def after_build(block)
      @after_build_blocks << block
    end

    # Add a block to run after a record is saved
    # @param block [Proc] the block to run after a record is saved
    # @note the proc will be added to the config's after_save_blocks array
    sig { params(block: Proc).void }
    def after_save(block)
      @after_save_blocks << block
    end

    # Support for dup operations used in csv_importer.rb
    # @param orig [Config] the original config
    # @note the dup will be used to create a new config with the same values as the original config
    sig { params(orig: Config).void }
    def initialize_copy(orig)
      super
      @column_definitions = orig.column_definitions.dup
      @identifiers = orig.identifiers.dup if orig.identifiers
      @after_save_blocks = orig.after_save_blocks.dup
      @after_build_blocks = orig.after_build_blocks.dup
    end
  end
end
