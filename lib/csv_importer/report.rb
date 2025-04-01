# typed: strict
# frozen_string_literal: true

module CSVImporter
  # The Report class provides information about the results of a CSV import.
  #
  # It tracks:
  # * Import status (pending, in_progress, done, aborted, invalid_header, invalid_csv_file)
  # * Missing and extra columns
  # * CSV parsing errors
  # * Successfully created or updated records
  # * Failed import attempts
  # * Records skipped during import
  # * Preview mode flag (when validation only is performed)
  class Report
    extend T::Sig

    # Status types used throughout the import process
    STATUSES = T.let([:pending, :invalid_csv_file, :invalid_header, :in_progress, :done, :aborted].freeze, T::Array[Symbol])

    # @!attribute [r] status
    # @return [Symbol] Current status of the import process
    sig { returns(Symbol) }
    attr_accessor :status

    # @!attribute [r] missing_columns
    # @return [Array<String>] Column names required by the importer but missing from the CSV
    sig { returns(T::Array[String]) }
    attr_accessor :missing_columns

    # @!attribute [r] extra_columns
    # @return [Array<String>] Column names present in the CSV but not defined in the importer
    sig { returns(T::Array[String]) }
    attr_accessor :extra_columns

    # @!attribute [r] parser_error
    # @return [String, nil] Error message from the CSV parser if parsing failed
    sig { returns(T.nilable(String)) }
    attr_accessor :parser_error

    # @!attribute [r] preview_mode
    # @return [Boolean] Whether this report was generated in preview mode
    sig { returns(T::Boolean) }
    attr_accessor :preview_mode

    # @!attribute [r] created_rows
    # @return [Array<Row>] Rows that were successfully created in the database
    sig { returns(T::Array[Row]) }
    attr_accessor :created_rows

    # @!attribute [r] updated_rows
    # @return [Array<Row>] Rows that were successfully updated in the database
    sig { returns(T::Array[Row]) }
    attr_accessor :updated_rows

    # @!attribute [r] failed_to_create_rows
    # @return [Array<Row>] Rows that could not be created due to validation failures
    sig { returns(T::Array[Row]) }
    attr_accessor :failed_to_create_rows

    # @!attribute [r] failed_to_update_rows
    # @return [Array<Row>] Rows that could not be updated due to validation failures
    sig { returns(T::Array[Row]) }
    attr_accessor :failed_to_update_rows

    # @!attribute [r] create_skipped_rows
    # @return [Array<Row>] Rows that were skipped during creation (via skip!)
    sig { returns(T::Array[Row]) }
    attr_accessor :create_skipped_rows

    # @!attribute [r] update_skipped_rows
    # @return [Array<Row>] Rows that were skipped during update (via skip!)
    sig { returns(T::Array[Row]) }
    attr_accessor :update_skipped_rows

    # @!attribute [r] invalid_rows
    # @return [Array<Row>] Rows that were invalid (failed validation)
    sig { returns(T::Array[Row]) }
    attr_reader :invalid_rows

    # @!attribute [r] message_generator
    # @return [Class] The class responsible for generating human-readable messages
    sig { returns(T.class_of(ReportMessage)) }
    attr_accessor :message_generator

    # Initialize a new Report with default values
    # @param status [Symbol] Initial status of the import
    # @param missing_columns [Array<String>] Columns required but missing
    # @param extra_columns [Array<String>] Columns present but not used
    # @param parser_error [String, nil] Error message from CSV parser
    # @param preview_mode [Boolean] Whether this report was generated in preview mode
    # @param created_rows [Array<Row>] Rows successfully created
    # @param updated_rows [Array<Row>] Rows successfully updated
    # @param failed_to_create_rows [Array<Row>] Rows that failed to create
    # @param failed_to_update_rows [Array<Row>] Rows that failed to update
    # @param create_skipped_rows [Array<Row>] Rows skipped during creation
    # @param update_skipped_rows [Array<Row>] Rows skipped during update
    # @param invalid_rows [Array<Row>] Rows that were invalid (failed validation)
    # @param message_generator [Class] Class to generate user-friendly messages
    sig do
      params(
        status: Symbol,
        missing_columns: T::Array[String],
        extra_columns: T::Array[String],
        parser_error: T.nilable(String),
        preview_mode: T::Boolean,
        created_rows: T::Array[Row],
        updated_rows: T::Array[Row],
        failed_to_create_rows: T::Array[Row],
        failed_to_update_rows: T::Array[Row],
        create_skipped_rows: T::Array[Row],
        update_skipped_rows: T::Array[Row],
        invalid_rows: T::Array[Row],
        message_generator: T.class_of(ReportMessage)
      ).void
    end
    def initialize(status: :pending, missing_columns: [], extra_columns: [], parser_error: nil, preview_mode: false, created_rows: [],
      updated_rows: [], failed_to_create_rows: [], failed_to_update_rows: [], create_skipped_rows: [],
      update_skipped_rows: [], invalid_rows: [], message_generator: ReportMessage)
      @status = T.let(status, Symbol)
      @missing_columns = T.let(missing_columns, T::Array[String])
      @extra_columns = T.let(extra_columns, T::Array[String])
      @parser_error = T.let(parser_error, T.nilable(String))
      @preview_mode = T.let(preview_mode, T::Boolean)
      @created_rows = T.let(created_rows, T::Array[Row])
      @updated_rows = T.let(updated_rows, T::Array[Row])
      @failed_to_create_rows = T.let(failed_to_create_rows, T::Array[Row])
      @failed_to_update_rows = T.let(failed_to_update_rows, T::Array[Row])
      @create_skipped_rows = T.let(create_skipped_rows, T::Array[Row])
      @update_skipped_rows = T.let(update_skipped_rows, T::Array[Row])
      @invalid_rows = T.let(invalid_rows, T::Array[Row])
      @message_generator = T.let(message_generator, T.class_of(ReportMessage))
    end

    # Returns a hash of all attributes of the report
    # @return [Hash] All the attributes of the report
    sig { returns(T::Hash[Symbol, T.anything]) }
    def attributes
      {
        status: status,
        missing_columns: missing_columns,
        extra_columns: extra_columns,
        parser_error: parser_error,
        preview_mode: preview_mode,
        created_rows: created_rows,
        updated_rows: updated_rows,
        failed_to_create_rows: failed_to_create_rows,
        failed_to_update_rows: failed_to_update_rows,
        create_skipped_rows: create_skipped_rows,
        update_skipped_rows: update_skipped_rows,
        invalid_rows: invalid_rows,
        message_generator: message_generator
      }
    end

    # Returns all rows that were successfully imported
    # @return [Array<Row>] Array of valid rows (created or updated)
    sig { returns(T::Array[Row]) }
    def valid_rows
      created_rows + updated_rows
    end

    # Returns rows that specifically failed validation (not those that failed to save)
    # @return [Array<Row>] Array of rows that failed validation
    sig { returns(T::Array[Row]) }
    def validation_failed_rows
      @invalid_rows
    end

    # Returns all rows that failed during import
    # @return [Array<Row>] Array of invalid rows (failed to create or update + rows that failed validation)
    sig { returns(T::Array[Row]) }
    def all_invalid_rows
      # Include rows that failed to save and any rows in the validation-specific invalid_rows collection
      # that aren't already in failed_to_create_rows or failed_to_update_rows

      # Get line numbers from failed rows to avoid double-counting
      failed_line_numbers = (failed_to_create_rows + failed_to_update_rows).map(&:line_number)

      # Only include rows from @invalid_rows that aren't already in failed rows
      unique_invalid_rows = @invalid_rows.reject { |row| failed_line_numbers.include?(row.line_number) }

      failed_to_create_rows + failed_to_update_rows + unique_invalid_rows
    end

    # Returns all rows that were processed (valid and invalid)
    # @return [Array<Row>] Array of all processed rows
    sig { returns(T::Array[Row]) }
    def all_rows
      [
        all_invalid_rows, skipped_rows, created_rows, updated_rows,
        failed_to_create_rows, failed_to_update_rows,
        create_skipped_rows, update_skipped_rows
      ].flatten
    end

    # Indicates if the import was completely successful
    # @return [Boolean] true if status is :done and no rows failed
    sig { returns(T::Boolean) }
    def success?
      done? && all_invalid_rows.empty?
    end

    # Indicates if the import is in the pending state
    # @return [Boolean] true if status is :pending
    sig { returns(T::Boolean) }
    def pending?
      status == :pending
    end

    # Indicates if the import is currently in progress
    # @return [Boolean] true if status is :in_progress
    sig { returns(T::Boolean) }
    def in_progress?
      status == :in_progress
    end

    # Indicates if the import has completed
    # @return [Boolean] true if status is :done
    sig { returns(T::Boolean) }
    def done?
      status == :done
    end

    # Indicates if the import was aborted
    # @return [Boolean] true if status is :aborted
    sig { returns(T::Boolean) }
    def aborted?
      status == :aborted
    end

    # Indicates if the CSV had invalid headers
    # @return [Boolean] true if status is :invalid_header
    sig { returns(T::Boolean) }
    def invalid_header?
      status == :invalid_header
    end

    # Indicates if the CSV file itself was invalid
    # @return [Boolean] true if status is :invalid_csv_file
    sig { returns(T::Boolean) }
    def invalid_csv_file?
      status == :invalid_csv_file
    end

    # Sets the status to :pending and returns self
    # @return [self] The report instance
    sig { returns(T.self_type) }
    def pending!
      self.status = :pending
      self
    end

    # Sets the status to :in_progress and returns self
    # @return [self] The report instance
    sig { returns(T.self_type) }
    def in_progress!
      self.status = :in_progress
      self
    end

    # Sets the status to :done and returns self
    # @return [self] The report instance
    sig { returns(T.self_type) }
    def done!
      self.status = :done
      self
    end

    # Sets the status to :aborted and returns self
    # @return [self] The report instance
    sig { returns(T.self_type) }
    def aborted!
      self.status = :aborted
      self
    end

    # Sets the status to :invalid_header and returns self
    # @return [self] The report instance
    sig { returns(T.self_type) }
    def invalid_header!
      self.status = :invalid_header
      self
    end

    # Sets the status to :invalid_csv_file and returns self
    # @return [self] The report instance
    sig { returns(T.self_type) }
    def invalid_csv_file!
      self.status = :invalid_csv_file
      self
    end

    # Get a human-readable message describing the current status of the import
    # @return [String] Human-readable status message
    sig { returns(String) }
    def message
      message_generator.call(self)
    end

    # Indicates if the report was generated in preview mode
    # @return [Boolean] true if the report was generated in preview mode
    sig { returns(T::Boolean) }
    def preview?
      preview_mode
    end

    # All skipped rows (create and update)
    # @return [Array<Row>] all rows that were skipped
    sig { returns(T::Array[Row]) }
    def skipped_rows
      create_skipped_rows + update_skipped_rows
    end

    # Find a row by its line number
    # @param line_number [Integer] The line number of the row to find
    # @return [Row, nil] The row with the given line number, or nil if not found
    sig { params(line_number: Integer).returns(T.nilable(Row)) }
    def row_by_line_number(line_number)
      all_rows.find { |row| row.line_number == line_number }
    end

    # Get all rows that failed to be imported
    # @return [Array<Row>] All rows that failed to import
    sig { returns(T::Array[Row]) }
    def failed_rows
      failed_to_create_rows + failed_to_update_rows
    end

    # Add a row to the dedicated invalid_rows collection
    # @param row [Row] The row to add
    # @return [void]
    sig { params(row: Row).void }
    def add_invalid_row(row)
      @invalid_rows << row
    end
  end
end
