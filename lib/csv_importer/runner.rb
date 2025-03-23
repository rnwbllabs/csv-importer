# typed: true

module CSVImporter
  # Do the actual import.
  #
  # It iterates over the rows' models and persist them. It returns a `Report`.
  class Runner
    extend T::Sig
    def self.call(**kwargs)
      new(**kwargs).call
    end

    sig { returns(T::Array[Row]) }
    attr_accessor :rows

    sig { returns(Symbol) }
    attr_accessor :when_invalid

    sig { returns(T::Array[Proc]) }
    attr_accessor :after_save_blocks

    sig { returns(Report) }
    attr_accessor :report

    def initialize(rows:, when_invalid:, after_save_blocks: [], report: Report.new)
      @rows = rows
      @when_invalid = when_invalid
      @after_save_blocks = after_save_blocks
      @report = report
    end

    # attribute :rows, Array[Row]
    # attribute :when_invalid, Symbol
    # attribute :after_save_blocks, Array[Proc], default: []

    # attribute :report, Report, default: proc { Report.new }

    ImportAborted = Class.new(StandardError)

    # Persist the rows' model and return a `Report`
    def call
      if rows.empty?
        report.done!
        return report
      end

      report.in_progress!

      persist_rows!

      report.done!
      report
    rescue ImportAborted
      report.aborted!
      report
    end

    private

    def abort_when_invalid?
      when_invalid == :abort
    end

    def persist_rows!
      transaction do
        rows.each do |row|
          tags = []

          tags << if row.model.persisted?
            :update
          else
            :create
          end

          tags << if row.skip?
            :skip
          elsif row.model.save
            :success
          else
            :failure
          end

          add_to_report(row, tags)

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
      end
    end

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

    def transaction(&block)
      rows.first.model.class.transaction(&block)
    end
  end
end
