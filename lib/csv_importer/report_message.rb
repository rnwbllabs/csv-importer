# typed: strict
# frozen_string_literal: true

module CSVImporter
  # Generate a human readable message for the given report.
  class ReportMessage
    extend T::Sig

    # Generate a human readable message for the given report.
    # @param report [Report] the report to generate a message for
    # @return [String] the human readable message
    sig { params(report: Report).returns(String) }
    def self.call(report)
      new(report).to_s
    end

    # Initialize the report message with the given report.
    # @param report [Report] the report to generate a message for
    sig { params(report: Report).void }
    def initialize(report)
      @report = report
    end

    # The report to generate a message for
    # @!attribute [rw] report
    # @return [Report] the report to generate a message for
    sig { returns(Report) }
    attr_accessor :report

    # Generate a human readable message for the given report.
    # @return [String] the human readable message
    sig { returns(String) }
    def to_s
      send(:"report_#{report.status}")
    end

    private

    # Pending report message
    # @return [String] the pending report message
    sig { returns(String) }
    def report_pending
      "Import hasn't started yet"
    end

    # In progress report message
    # @return [String] the in progress report message
    sig { returns(String) }
    def report_in_progress
      "Import in progress"
    end

    # Done report message
    # @return [String] the done report message
    sig { returns(String) }
    def report_done
      prefix = report.preview? ? "Preview completed" : "Import completed"
      "#{prefix}: #{import_details}"
    end

    # Invalid header report message
    # @return [String] the invalid header report message
    sig { returns(String) }
    def report_invalid_header
      "The following columns are required: #{report.missing_columns.join(", ")}"
    end

    # Invalid CSV file report message
    # @return [String] the invalid CSV file report message
    sig { returns(String) }
    def report_invalid_csv_file
      report.parser_error || "Invalid CSV file"
    end

    # Aborted report message
    # @return [String] the aborted report message
    sig { returns(String) }
    def report_aborted
      report.preview? ? "Preview aborted" : "Import aborted"
    end

    # Message for details of import
    # @return [String] the import details
    # @example "3 created. 4 updated. 1 failed to create. 2 failed to update."
    sig { returns(String) }
    def import_details
      # Create a consistent message format based on what's actually in the report
      # Get all buckets that contain rows
      buckets = report.attributes
        .select { |name, _| name.to_s.include?("_rows") }
        .select { |_, instances| !instances.empty? }
        .map { |bucket, instances| "#{instances.size} #{bucket.to_s.gsub("_rows", "").tr("_", " ")}" }
        .join(", ")

      # Return blank string if no buckets have rows
      buckets.empty? ? "" : buckets
    end
  end
end
