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
          process_row(row)
        end
      end
    end

    # Process a single row
    # @param row [Row] the row to process
    # @return [void]
    sig { params(row: Row).void }
    def process_row(row)
      # Skip processing if row is marked to skip
      return if row.skip?

      # Check if the row is valid before attempting to save
      unless row.valid?
        add_row_to_report(row, :failure)
        raise ImportAborted if abort_when_invalid?
        return
      end

      if preview_mode
        # In preview mode, just mark as success for valid models
        add_row_to_report(row, :success)
      else
        # In normal mode, persist the models in the specified order
        save_models_for_row(row)
      end

      # Only run after_save hooks if not in preview mode
      return if preview_mode

      run_after_save_hooks(row)
    end

    # Save all models for a row in the specified order
    # @param row [Row] the row containing models to save
    # @return [void]
    sig { params(row: Row).void }
    def save_models_for_row(row)
      # Get the models to persist in the correct order
      models_list = get_models_to_persist(row)
      success = persist_models_in_order(row, models_list)

      # Report final status
      add_row_to_report(row, success ? :success : :failure)
    end

    # Get the list of models to persist in the correct order
    # @param row [Row] the row containing models
    # @return [Array<Array>] list of [model_key, model] pairs
    sig { params(row: Row).returns(T::Array[T::Array[T.untyped]]) }
    def get_models_to_persist(row)
      # Get the persist order, or use all model keys if empty
      persist_order = row.persist_order.dup
      if persist_order.empty?
        persist_order = row.models.keys.to_a
      end

      # Build list of models to persist
      models_list = []
      persist_order.each do |model_key|
        next unless row.built_models.key?(model_key)
        models_list << [model_key, row.built_models[model_key]]
      end

      models_list
    end

    # Persist models in the given order
    # @param row [Row] the row containing models
    # @param models_list [Array<Array>] list of [model_key, model] pairs
    # @return [Boolean] whether all models were saved successfully
    sig { params(row: Row, models_list: T::Array[T::Array[T.untyped]]).returns(T::Boolean) }
    def persist_models_in_order(row, models_list)
      # Use a method to process each model and return a boolean status
      process_all_models(row, models_list)
    end

    # Process all models and return success status
    # @param row [Row] the row containing models
    # @param models_list [Array<Array>] list of [model_key, model] pairs
    # @return [Boolean] whether all models were saved successfully
    sig { params(row: Row, models_list: T::Array[T::Array[T.untyped]]).returns(T::Boolean) }
    def process_all_models(row, models_list)
      # Process models in a separate method that returns true if all saved
      all_models_saved?(row, models_list)
    end

    # Check if all models saved successfully
    # @param row [Row] the row containing models
    # @param models_list [Array<Array>] list of [model_key, model] pairs
    # @return [Boolean] true if all models saved successfully
    sig { params(row: Row, models_list: T::Array[T::Array[T.untyped]]).returns(T::Boolean) }
    def all_models_saved?(row, models_list)
      # Check each model and return false at first failure
      models_list.each do |model_info|
        model_key, model = model_info

        # Skip if either key or model is nil
        next unless model_key && model

        # Skip if model doesn't respond to save
        next unless model.respond_to?(:save)

        # If any model fails to save, return false immediately
        unless process_single_model(row, model)
          return false
        end
      end

      # If we get here, all models saved successfully
      true
    end

    # Process a single model and handle any failures
    # @param row [Row] the row containing the model
    # @param model [Object] the model to save
    # @return [Boolean] whether the model was saved successfully
    sig { params(row: Row, model: T.untyped).returns(T::Boolean) }
    def process_single_model(row, model)
      # Try to save the model
      saved = model.save

      # If save failed, handle according to configuration
      if !saved && abort_when_invalid?
        add_row_to_report(row, :failure)
        raise ImportAborted
      end

      saved
    end

    # Add a row to the report based on its status
    # @param row [Row] the row to add to the report
    # @param status [Symbol] the status of the row (:success or :failure)
    # @return [void]
    sig { params(row: Row, status: Symbol).void }
    def add_row_to_report(row, status)
      # Get the model for the report (for backward compatibility use :_default or first model)
      first_model = row.built_models[:_default] || row.built_models.values.first

      # Determine if this is a create or update operation
      persisted = false
      if first_model
        persisted = first_model.persisted?
      end

      # Add the row to the appropriate bucket based on status and persistence
      if status == :success
        if persisted
          report.updated_rows << row
        else
          report.created_rows << row
        end
      elsif status == :failure
        if persisted
          report.failed_to_update_rows << row
        else
          report.failed_to_create_rows << row
        end
      else # skip
        if persisted
          report.update_skipped_rows << row
        else
          report.create_skipped_rows << row
        end
      end
    end

    # Run after_save hooks for all models in a row
    # @param row [Row] the row whose models to run after_save hooks for
    # @return [void]
    sig { params(row: Row).void }
    def run_after_save_hooks(row)
      after_save_blocks.each do |block|
        # For backward compatibility, support both old style (passing single model)
        # and new style (passing row)
        arity = block.arity

        if arity == 1
          # For backwards compatibility with single model
          block.call(row.model)
        elsif arity == 0
          # For new style with row
          block.call
        elsif arity == 2
          # Support legacy three-argument style (model, csv_attributes)
          block.call(row.model, row.csv_attributes)
        else
          # Just call with row if we can't determine the proper arity
          block.call(row)
        end
      end
    end

    # Run the code in a transaction using the model's class
    # @param block [Proc] the block to execute within the transaction
    # @return [Object] the result of the transaction
    # @raise [RuntimeError] if there are no rows to process
    sig { params(block: T.proc.void).returns(T.untyped) }
    def transaction(&block)
      raise "No rows to process" if rows.empty?

      # Use the first row's model class for the transaction
      first_row = T.must(rows.first)

      # Find a suitable model class to use for the transaction
      transaction_class = nil

      # First check persist_order for the preferred model
      if !first_row.persist_order.empty?
        persist_key = first_row.persist_order.first
        if persist_key && first_row.models.key?(persist_key)
          transaction_class = first_row.models[persist_key]
        end
      end

      # If we still don't have a class, try the models hash
      if transaction_class.nil? && !first_row.models.empty?
        # Use the :_default model if it exists (legacy single-model case)
        if first_row.models.key?(:_default)
          transaction_class = first_row.models[:_default]
        else
          # Otherwise use the first model in the hash
          first_key = first_row.models.keys.first
          if first_key
            transaction_class = first_row.models[first_key]
          end
        end
      end

      # If we found a class, use it for the transaction
      if transaction_class
        transaction_class.transaction(&block)
      else
        # Fallback to built_models if available
        if !first_row.built_models.empty?
          first_model = first_row.built_models.values.first
          if first_model && first_model.class.respond_to?(:transaction)
            first_model.class.transaction(&block)
          else
            # Last resort - just execute the block without a transaction
            yield
          end
        else
          # Last resort - just execute the block without a transaction
          yield
        end
      end
    end
  end
end
