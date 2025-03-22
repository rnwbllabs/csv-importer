# typed: true

module CSVImporter
  # The Report you get back from an import.
  #
  # * It has a status (pending, invalid_csv_file, invalid_header, in_progress, done, aborted)
  # * It lists out missing columns
  # * It reports parser_error
  # * It lists out (created / updated) * (success / failed) records
  # * It provides a human readable message
  #
  class Report
    extend T::Sig
    # sig { returns(Symbol) }
    attr_accessor :status

    # sig { returns(T::Array[String]) }
    attr_accessor :missing_columns

    # sig { returns(T::Array[String]) }
    attr_accessor :extra_columns

    # sig { returns(String) }
    attr_accessor :parser_error

    # sig { returns(T::Array[Row]) }
    attr_accessor :created_rows

    # sig { returns(T::Array[Row]) }
    attr_accessor :updated_rows

    # sig { returns(T::Array[Row]) }
    attr_accessor :failed_to_create_rows

    # sig { returns(T::Array[Row]) }
    attr_accessor :failed_to_update_rows

    # sig { returns(T::Array[Row]) }
    attr_accessor :create_skipped_rows

    # sig { returns(T::Array[Row]) }
    attr_accessor :update_skipped_rows

    # sig { returns(Class) }
    attr_accessor :message_generator

    def initialize(status: :pending, missing_columns: [], extra_columns: [], parser_error: nil, created_rows: [],
                   updated_rows: [], failed_to_create_rows: [], failed_to_update_rows: [], create_skipped_rows: [],
                   update_skipped_rows: [], message_generator: ReportMessage)
      @status = status
      @missing_columns = missing_columns
      @extra_columns = extra_columns
      @parser_error = parser_error
      @created_rows = created_rows
      @updated_rows = updated_rows
      @failed_to_create_rows = failed_to_create_rows
      @failed_to_update_rows = failed_to_update_rows
      @create_skipped_rows = create_skipped_rows
      @update_skipped_rows = update_skipped_rows
      @message_generator = message_generator
    end

    # attribute :status, Symbol, default: proc { :pending }

    # attribute :missing_columns, Array[String], default: proc { [] }
    # attribute :extra_columns, Array[String], default: proc { [] }

    # attribute :parser_error, String

    # attribute :created_rows, Array[Row], default: proc { [] }
    # attribute :updated_rows, Array[Row], default: proc { [] }
    # attribute :failed_to_create_rows, Array[Row], default: proc { [] }
    # attribute :failed_to_update_rows, Array[Row], default: proc { [] }
    # attribute :create_skipped_rows, Array[Row], default: proc { [] }
    # attribute :update_skipped_rows, Array[Row], default: proc { [] }

    # attribute :message_generator, Class, default: proc { ReportMessage }

    # TODO: kill this stupid thing
    def attributes
      {
        status: status,
        missing_columns: missing_columns,
        extra_columns: extra_columns,
        parser_error: parser_error,
        created_rows: created_rows,
        updated_rows: updated_rows,
        failed_to_create_rows: failed_to_create_rows,
        failed_to_update_rows: failed_to_update_rows,
        create_skipped_rows: create_skipped_rows,
        update_skipped_rows: update_skipped_rows,
        message_generator: message_generator
      }
    end

    def valid_rows
      created_rows + updated_rows
    end

    def invalid_rows
      failed_to_create_rows + failed_to_update_rows
    end

    def all_rows
      valid_rows + invalid_rows
    end

    def success?
      done? && invalid_rows.empty?
    end

    def pending?
      status == :pending
    end

    def in_progress?
      status == :in_progress
    end

    def done?
      status == :done
    end

    def aborted?
      status == :aborted
    end

    def invalid_header?
      status == :invalid_header
    end

    def invalid_csv_file?
      status == :invalid_csv_file
    end

    def pending!
      self.status = :pending
      self
    end

    def in_progress!
      self.status = :in_progress
      self
    end

    def done!
      self.status = :done
      self
    end

    def aborted!
      self.status = :aborted
      self
    end

    def invalid_header!
      self.status = :invalid_header
      self
    end

    def invalid_csv_file!
      self.status = :invalid_csv_file
      self
    end

    def message
      message_generator.call(self)
    end
  end
end
