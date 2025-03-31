# typed: strict
# frozen_string_literal: true

module CSVImporter
  # Driver of the import, iterating through the rows' models and persisting the processed information. It returns a
  #  +Report+ object that summarizes the import results.
  class Runner
    extend T::Sig

    # Creates a new Runner instance and calls it to run the import.
    # @param kwargs [Hash] keyword arguments to be passed to the initializer
    # @return [Report] the report summarizing the import results
    sig { params(kwargs: T.untyped).returns(Report) }
    def self.call(**kwargs)
      new(**T.unsafe(kwargs)).call
    end

    # Array of rows to be imported
    # @!attribute [rw] rows
    # @return [Array<Row>] the rows to be imported
    sig { returns(T::Array[Row]) }
    attr_accessor :rows

    # Strategy to use when a row is invalid
    # @!attribute [rw] when_invalid
    # @return [Symbol] the strategy to use when a row is invalid
    sig { returns(Symbol) }
    attr_accessor :when_invalid

    # Whether to run in preview mode (validate only, no persistence)
    # @!attribute [rw] preview_mode
    # @return [Boolean] whether to run in preview mode
    sig { returns(T::Boolean) }
    attr_accessor :preview_mode

    # Blocks to be called after each row is saved
    # @!attribute [rw] after_save_blocks
    # @return [Array<Proc>] blocks to be called after each row is saved
    sig { returns(T::Array[Proc]) }
    attr_accessor :after_save_blocks

    # The report object that tracks the import progress and results
    # @!attribute [rw] report
    # @return [Report] the report summarizing the import results
    sig { returns(Report) }
    attr_accessor :report

    # Initialize a new Runner with the provided options.
    # @param rows [Array<Row>] the rows to be imported
    # @param when_invalid [Symbol] the strategy to use when a row is invalid
    # @param preview_mode [Boolean] whether to run in preview mode (validate only)
    # @param after_save_blocks [Array<Proc>] blocks to be called after each row is saved
    # @param report [Report] the report to update with import results
    # @return [void]
    sig do
      params(
        rows: T::Array[Row],
        when_invalid: Symbol,
        preview_mode: T::Boolean,
        after_save_blocks: T::Array[Proc],
        report: Report
      ).void
    end
    def initialize(rows:, when_invalid:, preview_mode: false, after_save_blocks: [], report: Report.new)
      @rows = rows
      @when_invalid = when_invalid
      @preview_mode = preview_mode
      @after_save_blocks = after_save_blocks
      @report = report
    end

    # Custom error class raised when the import is aborted
    ImportAborted = Class.new(StandardError)

    # Persist the rows' model and return a `Report`
    # @return [Report] the report summarizing the import results
    sig { returns(Report) }
    def call
      if rows.empty?
        report.done!
        return report
      end

      report.preview_mode = preview_mode

      report.in_progress!

      persist_rows!

      report.done!
      report
    rescue ImportAborted
      report.aborted!
      report
    end

    private

    # Determines if the import should be aborted when a row is invalid
    # @return [Boolean] true if the import should be aborted when a row is invalid
    sig { returns(T::Boolean) }
    def abort_when_invalid?
      when_invalid == :abort
    end

    # Persists all rows within a transaction
    # @return [void]
    sig { void }
    def persist_rows!
      transaction do
        rows.each do |row|
          tags = []

          # First tag: create or update based on whether the record exists
          tags << (row.model.persisted? ? :update : :create)

          # Second tag: determine success, failure, or skip status
          status_tag = determine_status_tag(row)
          tags << status_tag

          add_to_report(row, tags)

          # Only run after_save hooks if not in preview mode
          next if preview_mode

          run_after_save_hooks(row)
        end
      end
    end

    # Determine the status tag (:success, :failure, or :skip) for a row
    # @param row [Row] the row to determine the status for
    # @return [Symbol] the status tag
    sig { params(row: Row).returns(Symbol) }
    def determine_status_tag(row)
      return :skip if row.skip?

      # Validation check first - no need to attempt saving invalid models
      if !row.valid?
        return :failure
      end

      if preview_mode
        # In preview mode, just mark as success for valid models
        :success
      else
        # In normal mode, attempt to save and check result
        row.model.save ? :success : :failure
      end
    end

    # Run all after_save hooks for a row
    # @param row [Row] the row to run after_save hooks for
    # @return [void]
    sig { params(row: Row).void }
    def run_after_save_hooks(row)
      after_save_blocks.each do |block|
        case block.arity
        when 0 then block.call
        when 1 then block.call(row.model)
        when 2 then block.call(row.model, row.csv_attributes)
        else
          raise ArgumentError, "after_save block of arity #{block.arity} is not supported"
        end
      end
    end

    # Add a row to the appropriate report bucket based on its tags
    # @param row [Row] the row to add to the report
    # @param tags [Array<Symbol>] the tags associated with the row
    # @return [void]
    # @raise [ImportAborted] if the import should be aborted due to a failed row
    sig { params(row: Row, tags: T::Array[Symbol]).void }
    def add_to_report(row, tags)
      bucket = case tags
      when %i[create success]
        report.created_rows
      when %i[create failure]
        report.failed_to_create_rows
      when %i[update success]
        report.updated_rows
      when %i[update failure]
        report.failed_to_update_rows
      when %i[create skip]
        report.create_skipped_rows
      when %i[update skip]
        report.update_skipped_rows
      else
        raise "Invalid tags #{tags.inspect}"
      end

      bucket << row

      raise ImportAborted if abort_when_invalid? && tags[1] == :failure
    end

    # Run the code in a transaction using the model's class
    # @param block [Proc] the block to execute within the transaction
    # @return [Object] the result of the transaction
    # @raise [RuntimeError] if there are no rows to process
    sig { params(block: T.proc.void).returns(T.untyped) }
    def transaction(&block)
      raise "No rows to process" if rows.empty?

      T.must(rows.first).model_klass.transaction(&block)
    end
  end
end
