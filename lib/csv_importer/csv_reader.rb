# typed: strict
# frozen_string_literal: true

module CSVImporter
  # Reads, sanitizes and parses a CSV file from various sources.
  #
  # This class handles:
  # - Reading CSV content from a string, file object, or file path
  # - Sanitizing content to handle encoding issues and line separators
  # - Auto-detecting the CSV delimiter (comma, semicolon, or tab)
  # - Parsing the CSV content into rows of cells
  # - Providing access to header and data rows
  class CSVReader
    extend T::Sig

    # List of parameters accepted by the initialize method.
    # This is used by CSVImporter to filter options.
    INITIALIZE_PARAMS = [:content, :file, :path, :quote_char, :encoding].freeze

    # Supported CSV delimiter characters
    SEPARATORS = [",", ";", "\t"].freeze

    # The raw CSV content string
    # @!attribute [rw] content
    # @return [String, nil] the raw CSV content
    sig { returns(T.nilable(String)) }
    attr_accessor :content

    # The file object containing CSV data
    # @!attribute [rw] file
    # @return [IO, StringIO, nil] the file object containing CSV data
    sig { returns(T.nilable(T.any(IO, StringIO))) }
    attr_accessor :file

    # The path to the CSV file
    # @!attribute [rw] path
    # @return [String, nil] the path to the CSV file
    sig { returns(T.nilable(String)) }
    attr_accessor :path

    # The character used to quote CSV fields
    # @!attribute [rw] quote_char
    # @return [String] the quote character, defaults to double quote (")
    sig { returns(String) }
    attr_accessor :quote_char

    # The encoding specification (source:target format)
    # @!attribute [rw] encoding
    # @return [String] the encoding specification, defaults to UTF-8:UTF-8
    sig { returns(String) }
    attr_accessor :encoding

    # Initialize a new CSVReader with the provided options.
    # @param content [String, nil] the raw CSV content
    # @param file [IO, StringIO, nil] the file object containing CSV data
    # @param path [String, nil] the path to the CSV file
    # @param quote_char [String] the character used to quote CSV fields
    # @param encoding [String] the encoding specification (source:target format)
    # @return [void]
    sig do
      params(
        content: T.nilable(String),
        file: T.nilable(T.any(IO, StringIO)),
        path: T.nilable(String),
        quote_char: String,
        encoding: String
      ).void
    end
    def initialize(content: nil, file: nil, path: nil, quote_char: '"', encoding: "UTF-8:UTF-8")
      @content = content
      @file = file
      @path = path
      @quote_char = quote_char
      @encoding = encoding
      @csv_rows = T.let(nil, T.nilable(T::Array[T::Array[String]]))
      @header = T.let(nil, T.nilable(T::Array[String]))
      @rows = T.let(nil, T.nilable(T::Array[T::Array[String]]))
    end

    # Parse the CSV content and return rows of cells.
    # @return [Array<Array<String>>] the parsed CSV rows
    sig { returns(T::Array[T::Array[String]]) }
    def csv_rows
      @csv_rows ||= begin
        sane_content = sanitize_content(read_content)
        separator = detect_separator(sane_content)
        cells = CSV.parse(
          sane_content,
          col_sep: separator, quote_char: quote_char, skip_blanks: true,
          external_encoding: source_encoding
        ).to_a # Convert CSV::Table to Array explicitly
        sanitize_cells(encode_cells(cells))
      end
    end

    # Returns the header row (first row) of the CSV.
    # @return [Array<String>] the header row
    sig { returns(T::Array[String]) }
    def header
      @header ||= csv_rows.first || []
    end

    # Returns the data rows (all rows except the header) of the CSV.
    # @return [Array<Array<String>>] the data rows
    sig { returns(T::Array[T::Array[String]]) }
    def rows
      @rows ||= csv_rows[1..] || []
    end

    private

    # Read content from the provided source (content string, file, or path).
    #    # @return [String] the raw CSV content
    # @raise [Error] if no content source is provided
    sig { returns(String) }
    def read_content
      if content
        content.to_s
      elsif file
        T.must(file).read.to_s
      elsif path
        File.read(T.must(path).to_s).to_s
      else
        raise Error, "Please provide content, file, or path"
      end
    end

    # Sanitize the CSV content by handling encoding issues and line separators.
    # @param csv_content [String] the raw CSV content
    # @return [String] the sanitized CSV content
    sig { params(csv_content: String).returns(String) }
    def sanitize_content(csv_content)
      csv_content
        .encode(Encoding.find(source_encoding), invalid: :replace, undef: :replace, replace: "") # Remove invalid byte sequences
        .gsub(/\r\r?\n?/, "\n") # Replaces windows line separators with "\n"
    end

    # Detect the most likely delimiter character used in the CSV.
    # Assume a correct CSV file has the same count of separators in each line. We calculate deviations from the base
    # number, counting points of inconsistencies in each line. Correct/valid CSV will have a score of 0. We take the
    # separator with the least score.
    #
    # @param csv_content [String] the sanitized CSV content
    # @return [String] the detected delimiter character
    # @example with 3 commas in header, 2 in one line and 5 in another - then score for comma would be 3
    #   ( abs(3-2) + abs(3-5) = 1 + 2 = 3 ).
    sig { params(csv_content: String).returns(String) }
    def detect_separator(csv_content)
      all_lines = csv_content.lines
      return "," if all_lines.empty?

      # Header or first line of the CSV
      first_line = all_lines.first || ""

      # Find the separator with the most consistent occurrence across lines
      best_separator = SEPARATORS.min_by do |separator|
        base_number = first_line.count(separator)

        if base_number.zero?
          Float::MAX
        else
          all_lines.map { |line| line.count(separator) - base_number }.map(&:abs).inject(0) { |sum, i| sum + i }
        end
      end

      T.must(best_separator)
    end

    # Remove trailing white spaces from cells and ensure all cells are strings.
    # @param rows [Array<Array>] the parsed CSV rows
    # @return [Array<Array<String>>] the sanitized rows
    sig { params(rows: T::Array[T::Array[T.untyped]]).returns(T::Array[T::Array[String]]) }
    def sanitize_cells(rows)
      rows.map do |cells|
        cells.map do |cell|
          cell ? cell.strip : ""
        end
      end
    end

    # Encode all cells to the target encoding.
    # @param rows [Array<Array>] the parsed CSV rows
    # @return [Array<Array>] the encoded rows
    sig { params(rows: T::Array[T::Array[T.untyped]]).returns(T::Array[T::Array[T.untyped]]) }
    def encode_cells(rows)
      rows.map do |cells|
        cells.map do |cell|
          cell ? cell.encode(target_encoding) : ""
        end
      end
    end

    # Extract the source encoding from the encoding specification.
    # @return [String] the source encoding
    sig { returns(String) }
    def source_encoding
      encoding.split(":").first || "UTF-8"
    end

    # Extract the target encoding from the encoding specification.
    # @return [String] the target encoding
    sig { returns(String) }
    def target_encoding
      encoding.split(":").last || "UTF-8"
    end
  end
end
