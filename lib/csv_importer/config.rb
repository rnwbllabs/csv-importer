module CSVImporter
  # The configuration of a CSVImporter
  class Config
    # attribute :model
    # attribute :column_definitions, Array[ColumnDefinition], default: proc { [] }
    # attribute :identifiers # Array[Symbol] or Proc
    # attribute :when_invalid, Symbol, default: proc { :skip }
    # attribute :after_build_blocks, Array[Proc], default: []
    # attribute :after_save_blocks, Array[Proc], default: []

    # def initialize_copy(orig)
    #   super
    #   self.column_definitions = orig.column_definitions.dup
    #   self.identifiers = orig.identifiers.dup
    #   self.after_save_blocks = orig.after_build_blocks.dup
    #   self.after_build_blocks = orig.after_save_blocks.dup
    # end

    # def after_build(block)
    #   after_build_blocks << block
    # end

    # def after_save(block)
    # after_save_blocks << block
    # end

    # Simple attributes with direct accessors
    attr_accessor :model, :identifiers, :when_invalid

    # Array attributes that need proper initialization
    attr_accessor :column_definitions, :after_build_blocks, :after_save_blocks

    def initialize
      @column_definitions = []
      @after_build_blocks = []
      @after_save_blocks = []
      @when_invalid = :skip
    end

    # Allow setting array attributes while maintaining type safety

    # DSL methods for adding blocks
    def after_build(block)
      @after_build_blocks << block
    end

    def after_save(block)
      @after_save_blocks << block
    end

    # Support for dup operations used in csv_importer.rb
    def initialize_copy(orig)
      super
      @column_definitions = orig.column_definitions.dup
      @identifiers = orig.identifiers.dup if orig.identifiers
      @after_save_blocks = orig.after_build_blocks.dup
      @after_build_blocks = orig.after_save_blocks.dup
    end
  end
end
