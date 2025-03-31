# typed: strict
# frozen_string_literal: true

require "csv"

require "csv_importer/version"
require "csv_importer/csv_reader"
require "csv_importer/column_definition"
require "csv_importer/column"
require "csv_importer/config_interface"
require "csv_importer/header"
require "csv_importer/row"
require "csv_importer/report"
require "csv_importer/report_message"
require "csv_importer/runner"
require "csv_importer/config"
require "csv_importer/dsl"

# A class that includes CSVImporter inherit its DSL and methods. This allows it to define a model, column definitions,
# and configuration options.
#
# @example:
#   class ImportUserCSV
#     include CSVImporter
#
#     model User
#
#     column :email
#   end
#
#   report = ImportUserCSV.new(file: my_csv).run!
#   puts report.message
module CSVImporter
  extend T::Sig
  extend T::Helpers

  class Error < StandardError; end

  # Setup DSL and config object
  module ClassMethods
    extend T::Sig
    include ::CSVImporter::ConfigInterface
    include Dsl

    # Class level configuration, as defined by the `Config` class
    # @return [Config] - The class level configuration for the importer
    sig { override.returns(Config) }
    def config
      @config = T.let(@config, T.nilable(Config)) unless defined?(@config)
      @config ||= Config.new
    end
  end

  requires_ancestor { Object }
  mixes_in_class_methods(ClassMethods)

  # Instance level config will run against this configurator
  class Configurator
    extend T::Sig
    include ConfigInterface
    include Dsl

    sig { override.returns(Config) }
    attr_reader :config

    sig { params(config: Config).void }
    def initialize(config:)
      @config = config
    end
  end

  # Storage for data that can be accessed during the import process. This hash is populated with:
  # 1. Any initialization parameters that aren't used by CSVReader or Config
  # 2. Values set by `before_import` hooks
  # 3. Values used in `after_build` hooks
  #
  # @example Access constructor parameters in hooks
  #   # When initializing
  #   importer = MyImporter.new(file: csv_file, company_id: 123)
  #
  #   # In hooks
  #   before_import do
  #     # Access the company_id parameter
  #     company = Company.find(datastore[:company_id])
  #     # Store calculated values for later
  #     datastore[:employees] = company.employees.index_by(&:id)
  #   end
  #
  # @return [Hash<Symbol, Object>] A hash for storing and accessing data throughout the import
  sig { returns(T::Hash[Symbol, T.anything]) }
  attr_reader :datastore

  # Initialize a new importer
  # @param options [Hash] Options for the importer. Options are categorized as follows:
  #   - CSVReader options (content:, file:, path:, etc.) are passed to CSVReader
  #   - Config options that match the config object attributes are set on the config
  #   - Any other options are stored in the datastore and accessible in hooks
  # @yield [Configurator] A block to configure the importer
  # @return [void]
  sig { params(options: T::Hash[Symbol, T.anything], block: T.nilable(T.proc.params(arg0: T.untyped).returns(T.anything))).void }
  def initialize(options = {}, &block)
    csv_options = {}
    config_options = {}
    datastore_options = {}

    options.each do |key, value|
      if CSVReader::INITIALIZE_PARAMS.include?(key)
        csv_options[key] = value
      elsif T.unsafe(self).class.config.respond_to?(:"#{key}=")
        config_options[key] = value
      else
        datastore_options[key] = value
      end
    end

    @csv = T.let(CSVReader.new(**csv_options), CSVReader)
    @config = T.let(T.unsafe(self).class.config.dup, Config)
    @datastore = T.let(datastore_options, T::Hash[Symbol, T.anything])
    @report = T.let(Report.new, Report)
    @header = T.let(nil, T.nilable(Header))

    config_options.each { |k, v| @config.send(:"#{k}=", v) }

    Configurator.new(config: @config).instance_exec(&block) if block
  end

  # Class level configuration for the importer
  # @!attribute [r] config
  # @return [Config] - The class level configuration for the importer
  sig { returns(Config) }
  attr_reader :config

  # CSV reader to read the CSV file
  # @!attribute [r] csv
  # @return [CSVReader] - The CSV reader for the importer
  sig { returns(CSVReader) }
  attr_reader :csv

  # Report the result of the import
  # @!attribute [r] report
  # @return [Report] - The report for the import
  sig { returns(Report) }
  attr_reader :report

  # Initialize and return the `Header` for the current CSV file
  # @return [Header] - The header for the import
  sig { returns(Header) }
  def header
    @header ||= Header.new(column_definitions: config.column_definitions, column_names: csv.header)
  end

  # Initialize and return the `Row`s for the current CSV file
  # @return [T::Array[Row]] - The rows for the import
  sig { returns(T::Array[Row]) }
  def rows
    csv.rows.map.with_index(2) do |row_array, line_number|
      Row.new(header: header, line_number: line_number, row_array: row_array, model_klass: config.model,
        identifiers: config.identifiers, after_build_blocks: config.after_build_blocks, datastore: datastore)
    end
  end

  # Check if the header is valid
  # @return [T::Boolean] `true` if the header is valid, `false` otherwise
  sig { returns(T::Boolean) }
  def valid_header?
    if @report.pending?
      @report = if header.valid?
        Report.new(status: :pending, extra_columns: header.extra_columns)
      else
        Report.new(status: :invalid_header, missing_columns: header.missing_required_columns, extra_columns: header.extra_columns)
      end
    end

    header.valid?
  rescue CSV::MalformedCSVError => e
    @report = Report.new(status: :invalid_csv_file, parser_error: e.message)
    false
  end

  # Run the import. Return a Report.
  # @return [Report] the report for the import
  sig { returns(Report) }
  def run!
    # Always create a fresh report when starting an import run
    @report = Report.new

    if valid_header?
      config.before_import_blocks.each do |block|
        case block.arity
        when 0 then T.unsafe(self).instance_exec(&block)
        when 1 then T.unsafe(self).instance_exec(self, &block)
        end
      end

      @report = Runner.call(rows: rows, when_invalid: config.when_invalid,
        after_save_blocks: config.after_save_blocks, preview_mode: config.preview_mode, report: @report)
    else
      @report
    end
  rescue CSV::MalformedCSVError => e
    @report = Report.new(status: :invalid_csv_file, parser_error: e.message)
  end

  # Run the import in preview mode to validate data without persisting changes.
  # This processes all rows, runs validations, and reports errors, but does not save any records.
  # @return [Report] the report with validation results
  sig { returns(Report) }
  def preview!
    previous_mode = config.preview_mode
    config.preview_mode = true

    result = run!

    # Restore the previous mode in case the instance is reused
    config.preview_mode = previous_mode

    result
  end
end
