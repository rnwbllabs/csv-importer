# typed: strict
# frozen_string_literal: true

require "csv"

require "csv_importer/version"
require "csv_importer/csv_reader"
require "csv_importer/column_definition"
require "csv_importer/column"
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
    include Dsl

    # Class level configuration, as defined by the `Config` class
    # @return [Config] - The class level configuration for the importer
    sig { returns(Config) }
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
    include Dsl

    sig { returns(Config) }
    attr_reader :config

    sig { params(config: Config).void }
    def initialize(config:)
      @config = config
    end
  end

  # Defines the path, file or content of the csv file.
  # Also allows you to overwrite the configuration at runtime.
  #
  # @param options [Hash] the options to pass to the CSVReader
  # @yield [Configurator] a block to configure the importer
  #
  # @example:
  #   .new(file: my_csv_file)
  #   .new(path: "subscribers.csv", model: newsletter.subscribers)
  #
  sig { params(options: T::Hash[Symbol, T.anything], block: T.nilable(T.proc.params(arg0: T.untyped).returns(T.anything))).void }
  def initialize(options = {}, &block)
    # Extract arguments for CSVReader using its defined parameter list
    csv_reader_args = options.slice(*CSVReader::INITIALIZE_PARAMS)

    @csv = T.let(T.unsafe(CSVReader).new(**csv_reader_args), CSVReader)

    # Duplicate class level configuration to allow instance level configuration
    @config = T.let(T.unsafe(self).class.config.dup, Config)

    config_options = T.unsafe(options).except(*csv_reader_args.keys)
    config_options.each do |key, value|
      @config.send(:"#{key}=", value) if @config.respond_to?(:"#{key}=")
    end

    @report = T.let(Report.new, Report)
    @header = T.let(nil, T.nilable(Header))

    Configurator.new(config: @config).instance_exec(&block) if block
  end

  # Class level configuration for the importer
  sig { returns(Config) }
  attr_reader :config

  # CSV reader to read the CSV file
  sig { returns(CSVReader) }
  attr_reader :csv

  # Report the result of the import
  sig { returns(Report) }
  attr_reader :report

  # Initialize and return the `Header` for the current CSV file
  sig { returns(Header) }
  def header
    @header ||= Header.new(column_definitions: config.column_definitions, column_names: csv.header)
  end

  # Initialize and return the `Row`s for the current CSV file
  sig { returns(T::Array[Row]) }
  def rows
    csv.rows.map.with_index(2) do |row_array, line_number|
      Row.new(header: header, line_number: line_number, row_array: row_array, model_klass: config.model,
        identifiers: config.identifiers, after_build_blocks: config.after_build_blocks)
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
    if valid_header?
      @report = Runner.call(rows: rows, when_invalid: config.when_invalid,
        after_save_blocks: config.after_save_blocks, report: @report)
    else
      @report
    end
  rescue CSV::MalformedCSVError => e
    @report = Report.new(status: :invalid_csv_file, parser_error: e.message)
  end
end
