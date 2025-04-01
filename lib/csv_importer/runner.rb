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
    ImportAborted = Class.new(StandardError) do
      extend T::Sig

      sig { returns(T.nilable(Row)) }
      attr_reader :row

      sig { params(message: String, row: T.nilable(Row)).void }
      def initialize(message, row = nil)
        @row = T.let(row, T.nilable(Row))
        super(message)
      end
    end

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

      begin
        persist_rows!
        report.done!
      rescue ImportAborted => e
        # The invalid row should already be added by process_row before the exception was raised
        report.aborted!
      end

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

    # Process a row and add it to the report
    # @param row [Row] The row to process
    # @return [void]
    sig { params(row: Row).void }
    def process_row(row)
      # Skip if the row is not valid (no model class or models)
      if (!row.legacy_mode? && row.built_models.empty?) || (row.legacy_mode? && row.model.nil?)
        report.add_invalid_row(row)
        return
      end

      # If the model has validation errors, add to invalid_rows
      if !row.valid?
        # Add to the invalid_rows collection
        report.add_invalid_row(row)

        # Determine if model was persisted before validation
        was_persisted = false
        if row.legacy_mode?
          model = row.model
          was_persisted = model.respond_to?(:persisted?) && model.persisted? if model
        else
          order = row.models_in_order
          if !order.empty? && row.built_models.key?(order.first)
            primary_model = row.built_models[order.first]
            was_persisted = primary_model.respond_to?(:persisted?) && primary_model.persisted?
          end
        end

        # Store this for proper reporting
        row.instance_variable_set(:@_was_persisted, was_persisted)

        # Add invalid row to the appropriate failed collection
        if was_persisted
          report.failed_to_update_rows << row
        else
          report.failed_to_create_rows << row
        end

        # For abort mode, raise ImportAborted exception after finding the first invalid row
        if abort_when_invalid?
          # This will abort the transaction and trigger the rescue handler
          raise ImportAborted.new("Import aborted due to invalid row", row)
        end

        # Skip invalid rows based on when_invalid setting, but only if
        # we aren't already adding it to failed_to_create/update
        if when_invalid == :skip && !row.skip?
          row.skip!
        end

        # Return early since we've handled this invalid row
        return
      end

      # Skip already invalid or marked-to-skip rows
      if row.skip?
        # Store whether the model was persisted for proper skip reporting
        primary_model_was_persisted = false

        if row.legacy_mode?
          model = row.model
          primary_model_was_persisted = model.respond_to?(:persisted?) && model.persisted? if model
        else
          order = row.models_in_order
          if !order.empty? && row.built_models.key?(order.first)
            primary_model = row.built_models[order.first]
            primary_model_was_persisted = primary_model.respond_to?(:persisted?) && primary_model.persisted?
          end
        end

        # Store this for the report
        row.instance_variable_set(:@_was_persisted, primary_model_was_persisted)

        add_row_to_report(row, :skip)
        return
      end

      # Update or create model(s)
      save_models_for_row(row)

      # Only run after_save hooks if not in preview mode and row was saved successfully
      unless preview_mode
        status = row.instance_variable_defined?(:@status) ? row.instance_variable_get(:@status) : nil
        if [:created, :updated].include?(status)
          run_after_save_hooks(row)
        end
      end

      # Add row to the report if not already added during save
      if preview_mode
        # In preview mode, just mark as success for valid models
        add_row_to_report(row, :success)
      end
    end

    # Save models for a row
    # @param row [Row] The row to save
    # @return [void]
    sig { params(row: Row).void }
    def save_models_for_row(row)
      return if row.skip?

      # Track primary model's persistence state before saving
      primary_model_was_persisted = false

      # Handle legacy mode (single model) and multi-model differently
      if row.legacy_mode?
        # Legacy mode - single model
        model = row.model
        if model.nil?
          add_row_to_report(row, :failure)
          return
        end

        # Store persistence state before saving
        primary_model_was_persisted = model.respond_to?(:persisted?) && model.persisted?
        # Store this for the report
        row.instance_variable_set(:@_was_persisted, primary_model_was_persisted)

        # Save and update status
        if !preview_mode && model.save
          add_row_to_report(row, :success)
          # Record status for after_save hooks
          row.instance_variable_set(:@status, primary_model_was_persisted ? :updated : :created)
        else
          # Check errors again after save failure
          row.check_errors(when_invalid == :skip)
          add_row_to_report(row, :failure)
          # Record status for after_save hooks
          row.instance_variable_set(:@status, :failed)
        end
      else
        # Multi-model mode - handle models in order
        order = row.persist_order.empty? ? row.models.keys.to_a : row.persist_order.dup

        if !row.built_models.key?(order.first)
          add_row_to_report(row, :failure)
          row.instance_variable_set(:@status, :failed)
          return
        end

        primary_model = row.built_models[order.first]

        # Store persistence state of primary model before saving
        primary_model_was_persisted = primary_model.respond_to?(:persisted?) && primary_model.persisted?
        # Store this for the report
        row.instance_variable_set(:@_was_persisted, primary_model_was_persisted)

        # Try to save all models in order (if not in preview mode)
        if !preview_mode
          success = order.all? do |key|
            next true unless row.built_models.key?(key)
            model = row.built_models[key]
            next true if model.nil?

            model.save
          end

          # Update row status based on save result
          if success
            add_row_to_report(row, :success)
            # Record status for after_save hooks
            row.instance_variable_set(:@status, primary_model_was_persisted ? :updated : :created)
          else
            # Check errors again after save failure
            row.check_errors(when_invalid == :skip)
            add_row_to_report(row, :failure)
            # Record status for after_save hooks
            row.instance_variable_set(:@status, :failed)
          end
        end
      end
    end

    # Add a row to the report based on its status
    # @param row [Row] the row to add to the report
    # @param status [Symbol] the status of the row (:success, :failure, or :skip)
    # @return [void]
    sig { params(row: Row, status: Symbol).void }
    def add_row_to_report(row, status)
      # Special case for skips - we may need to check already stored persistence state
      if status == :skip
        # Check if the row has persistence information stored
        was_persisted = false
        if row.instance_variable_defined?(:@_was_persisted)
          was_persisted = row.instance_variable_get(:@_was_persisted)
        else
          # Try to determine from the current state of the model
          if row.legacy_mode?
            model = row.model
            was_persisted = model.respond_to?(:persisted?) && model.persisted? if model
          else
            # For multi-model case, check the primary model
            order = row.models_in_order
            if !order.empty? && row.built_models.key?(order.first)
              primary_model = row.built_models[order.first]
              was_persisted = primary_model.respond_to?(:persisted?) && primary_model.persisted?
            end
          end
        end

        if was_persisted
          report.update_skipped_rows << row
        else
          report.create_skipped_rows << row
        end
        return
      end

      # Determine if model was persisted before save attempt
      # Check if we stored this information during save
      was_persisted = false
      if row.instance_variable_defined?(:@_was_persisted)
        was_persisted = row.instance_variable_get(:@_was_persisted)
      else
        # Fall back to current persisted state if we don't have historical information
        model = row.legacy_mode? ? row.model : (row.built_models[:_default] || (row.built_models.values.first if row.built_models.any?))
        was_persisted = model.respond_to?(:persisted?) && model.persisted? if model
      end

      # Add the row to the appropriate bucket based on status and persistence
      if status == :success
        if was_persisted
          report.updated_rows << row
        else
          report.created_rows << row
        end
      elsif status == :failure
        if was_persisted
          report.failed_to_update_rows << row
        else
          report.failed_to_create_rows << row
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
          # For legacy single model or provide the row
          if row.legacy_mode?
            block.call(row.model)
          else
            # For new style with row
            block.call(row)
          end
        elsif arity == 0
          # Zero args, just call the block
          block.call
        elsif arity == 2
          # Support legacy two-argument style (model, csv_attributes)
          if row.legacy_mode?
            block.call(row.model, row.csv_attributes)
          else
            # Best attempt for multi-model case
            primary_model = row.built_models.values.first
            block.call(primary_model, row.csv_attributes)
          end
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
