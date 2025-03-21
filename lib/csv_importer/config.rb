require 'virtus'

module CSVImporter
  # The configuration of a CSVImporter
  class Config
    include ActiveModel::Attributes
    include Virtus.model

    # attr_accessor :model

    # attr_accessor :column_definitions

    # attr_accessor :identifiers

    # attr_accessor :when_invalid

    # attr_accessor :after_build_blocks

    # attr_accessor :after_save_blocks

    # def initialize(model:, column_definitions:, identifiers:, when_invalid: :skip, after_build_blocks: [], after_save_blocks: [])
      # @model = model
      # @column_definitions = column_definitions
      # @identifiers = identifiers
      # @when_invalid = when_invalid
      # @after_build_blocks = after_build_blocks
      # @after_save_blocks = after_save_blocks
    # end

    # attribute :model
    # attribute :column_definitions, array: true, default: []
    # attribute :identifiers, array: true
    # attribute :when_invalid, array: true, default: :skip
    # attribute :after_build_blocks, array: true, default: []
    # attribute :after_save_blocks, array: true, default: []

    attribute :model
    attribute :column_definitions, Array[ColumnDefinition], default: proc { [] }
    attribute :identifiers # Array[Symbol] or Proc
    attribute :when_invalid, Symbol, default: proc { :skip }
    attribute :after_build_blocks, Array[Proc], default: []
    attribute :after_save_blocks, Array[Proc], default: []

    def initialize_copy(orig)
      super
      self.column_definitions = orig.column_definitions.dup
      self.identifiers = orig.identifiers.dup
      self.after_save_blocks = orig.after_save_blocks.dup
      self.after_build_blocks = orig.after_build_blocks.dup
    end

    def after_build(block)
      self.after_build_blocks << block
    end

    def after_save(block)
      self.after_save_blocks << block
    end
  end
end
