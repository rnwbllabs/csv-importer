# typed: true

# DO NOT EDIT MANUALLY
# This is an autogenerated file for types exported from the `simplecov` gem.
# Please instead update this file by running `bin/tapioca gem simplecov`.


# Singleton that is responsible for caching, loading and merging
# SimpleCov::Results into a single result for coverage analysis based
# upon multiple test suites.
#
# source://simplecov//lib/simplecov.rb#19
module SimpleCov
  extend ::SimpleCov::Configuration

  class << self
    # Finds files that were to be tracked but were not loaded and initializes
    # their coverage to zero.
    #
    # source://simplecov//lib/simplecov.rb#60
    def add_not_loaded_files(result); end

    # Applies the configured filters to the given array of SimpleCov::SourceFile items
    #
    # source://simplecov//lib/simplecov.rb#110
    def filtered(files); end

    # Applies the configured groups to the given array of SimpleCov::SourceFile items
    #
    # source://simplecov//lib/simplecov.rb#121
    def grouped(files); end

    # source://simplecov//lib/simplecov.rb#141
    def load_adapter(name); end

    # Applies the profile of given name on SimpleCov configuration
    #
    # source://simplecov//lib/simplecov.rb#137
    def load_profile(name); end

    # Returns the value of attribute pid.
    #
    # source://simplecov//lib/simplecov.rb#22
    def pid; end

    # Sets the attribute pid
    #
    # @param value the value to set the attribute pid to.
    #
    # source://simplecov//lib/simplecov.rb#22
    def pid=(_arg0); end

    # Returns the result for the current coverage run, merging it across test suites
    # from cache using SimpleCov::ResultMerger if use_merging is activated (default)
    #
    # source://simplecov//lib/simplecov.rb#77
    def result; end

    # Returns nil if the result has not been computed
    # Otherwise, returns the result
    #
    # @return [Boolean]
    #
    # source://simplecov//lib/simplecov.rb#103
    def result?; end

    # Returns the value of attribute running.
    #
    # source://simplecov//lib/simplecov.rb#21
    def running; end

    # Sets the attribute running
    #
    # @param value the value to set the attribute running to.
    #
    # source://simplecov//lib/simplecov.rb#21
    def running=(_arg0); end

    # Sets up SimpleCov to run against your project.
    # You can optionally specify a profile to use as well as configuration with a block:
    #   SimpleCov.start
    #    OR
    #   SimpleCov.start 'rails' # using rails profile
    #    OR
    #   SimpleCov.start do
    #     add_filter 'test'
    #   end
    #     OR
    #   SimpleCov.start 'rails' do
    #     add_filter 'test'
    #   end
    #
    # Please check out the RDoc for SimpleCov::Configuration to find about available config options
    #
    # source://simplecov//lib/simplecov.rb#41
    def start(profile = T.unsafe(nil), &block); end

    # Checks whether we're on a proper version of Ruby (likely 1.9+) which
    # provides coverage support
    #
    # @return [Boolean]
    #
    # source://simplecov//lib/simplecov.rb#150
    def usable?; end
  end
end

# source://simplecov//lib/simplecov/filter.rb#45
class SimpleCov::ArrayFilter < ::SimpleCov::Filter
  # Returns true if any of the file paths passed in the given array matches the string
  # configured when initializing this Filter with StringFilter.new(['some/path', 'other/path'])
  #
  # @return [Boolean]
  #
  # source://simplecov//lib/simplecov/filter.rb#48
  def matches?(source_files_list); end
end

# source://simplecov//lib/simplecov/merge_helpers.rb#2
module SimpleCov::ArrayMergeHelper
  # Merges an array of coverage results with self
  #
  # source://simplecov//lib/simplecov/merge_helpers.rb#4
  def merge_resultset(array); end
end

# source://simplecov//lib/simplecov/filter.rb#37
class SimpleCov::BlockFilter < ::SimpleCov::Filter
  # Returns true if the block given when initializing this filter with BlockFilter.new {|src_file| ... }
  # returns true for the given source file.
  #
  # @return [Boolean]
  #
  # source://simplecov//lib/simplecov/filter.rb#40
  def matches?(source_file); end
end

# source://simplecov//lib/simplecov/command_guesser.rb#5
module SimpleCov::CommandGuesser
  class << self
    # source://simplecov//lib/simplecov/command_guesser.rb#14
    def guess; end

    # Storage for the original command line call that invoked the test suite.
    # This has got to be stored as early as possible because i.e. rake and test/unit 2
    # have a habit of tampering with ARGV, which makes i.e. the automatic distinction
    # between rails unit/functional/integration tests impossible without this cached
    # item.
    #
    # source://simplecov//lib/simplecov/command_guesser.rb#12
    def original_run_command; end

    # Storage for the original command line call that invoked the test suite.
    # This has got to be stored as early as possible because i.e. rake and test/unit 2
    # have a habit of tampering with ARGV, which makes i.e. the automatic distinction
    # between rails unit/functional/integration tests impossible without this cached
    # item.
    #
    # source://simplecov//lib/simplecov/command_guesser.rb#12
    def original_run_command=(_arg0); end

    private

    # source://simplecov//lib/simplecov/command_guesser.rb#28
    def from_command_line_options; end

    # source://simplecov//lib/simplecov/command_guesser.rb#43
    def from_defined_constants; end

    # source://simplecov//lib/simplecov/command_guesser.rb#20
    def from_env; end
  end
end

# source://simplecov//lib/simplecov/configuration.rb#10
module SimpleCov::Configuration
  # source://simplecov//lib/simplecov/configuration.rb#137
  def adapters; end

  # Add a filter to the processing chain.
  # There are three ways to define a filter:
  #
  # * as a String that will then be matched against all source files' file paths,
  #   SimpleCov.add_filter 'app/models' # will reject all your models
  # * as a block which will be passed the source file in question and should either
  #   return a true or false value, depending on whether the file should be removed
  #   SimpleCov.add_filter do |src_file|
  #     File.basename(src_file.filename) == 'environment.rb'
  #   end # Will exclude environment.rb files from the results
  # * as an instance of a subclass of SimpleCov::Filter. See the documentation there
  #   on how to define your own filter classes
  #
  # source://simplecov//lib/simplecov/configuration.rb#264
  def add_filter(filter_argument = T.unsafe(nil), &filter_proc); end

  # Define a group for files. Works similar to add_filter, only that the first
  # argument is the desired group name and files PASSING the filter end up in the group
  # (while filters exclude when the filter is applicable).
  #
  # source://simplecov//lib/simplecov/configuration.rb#273
  def add_group(group_name, filter_argument = T.unsafe(nil), &filter_proc); end

  # Gets or sets the behavior to process coverage results.
  #
  # By default, it will call SimpleCov.result.format!
  #
  # Configure with:
  #   SimpleCov.at_exit do
  #     puts "Coverage done"
  #     SimpleCov.result.format!
  #   end
  #
  # source://simplecov//lib/simplecov/configuration.rb#169
  def at_exit(&block); end

  # The name of the command (a.k.a. Test Suite) currently running. Used for result
  # merging and caching. It first tries to make a guess based upon the command line
  # arguments the current test suite is running on and should automatically detect
  # unit tests, functional tests, integration tests, rpsec and cucumber and label
  # them properly. If it fails to recognize the current command, the command name
  # is set to the shell command that the current suite is running on.
  #
  # You can specify it manually with SimpleCov.command_name("test:units") - please
  # also check out the corresponding section in README.rdoc
  #
  # source://simplecov//lib/simplecov/configuration.rb#74
  def command_name(name = T.unsafe(nil)); end

  # Allows you to configure simplecov in a block instead of prepending SimpleCov to all config methods
  # you're calling.
  #
  # SimpleCov.configure do
  #   add_filter 'foobar'
  # end
  #
  # This is equivalent to SimpleCov.add_filter 'foobar' and thus makes it easier to set a bunch of configure
  # options at once.
  #
  # source://simplecov//lib/simplecov/configuration.rb#153
  def configure(&block); end

  # The name of the output and cache directory. Defaults to 'coverage'
  #
  # Configure with SimpleCov.coverage_dir('cov')
  #
  # source://simplecov//lib/simplecov/configuration.rb#29
  def coverage_dir(dir = T.unsafe(nil)); end

  # Returns the full path to the output directory using SimpleCov.root
  # and SimpleCov.coverage_dir, so you can adjust this by configuring those
  # values. Will create the directory if it's missing
  #
  # source://simplecov//lib/simplecov/configuration.rb#40
  def coverage_path; end

  # Returns the list of configured filters. Add filters using SimpleCov.add_filter.
  #
  # source://simplecov//lib/simplecov/configuration.rb#61
  def filters; end

  # Sets the attribute filters
  #
  # @param value the value to set the attribute filters to.
  #
  # source://simplecov//lib/simplecov/configuration.rb#11
  def filters=(_arg0); end

  # Gets or sets the configured formatter.
  #
  # Configure with: SimpleCov.formatter(SimpleCov::Formatter::SimpleFormatter)
  #
  # source://simplecov//lib/simplecov/configuration.rb#85
  def formatter(formatter = T.unsafe(nil)); end

  # Sets the attribute formatter
  #
  # @param value the value to set the attribute formatter to.
  #
  # source://simplecov//lib/simplecov/configuration.rb#11
  def formatter=(_arg0); end

  # Gets the configured formatters.
  #
  # source://simplecov//lib/simplecov/configuration.rb#102
  def formatters; end

  # Sets the configured formatters.
  #
  # source://simplecov//lib/simplecov/configuration.rb#95
  def formatters=(formatters); end

  # Returns the configured groups. Add groups using SimpleCov.add_group
  #
  # source://simplecov//lib/simplecov/configuration.rb#126
  def groups; end

  # Sets the attribute groups
  #
  # @param value the value to set the attribute groups to.
  #
  # source://simplecov//lib/simplecov/configuration.rb#11
  def groups=(_arg0); end

  # Defines the maximum coverage drop at once allowed for the testsuite to pass.
  # SimpleCov will return non-zero if the coverage decreases by more than this threshold.
  #
  # Default is 100% (disabled)
  #
  # source://simplecov//lib/simplecov/configuration.rb#227
  def maximum_coverage_drop(coverage_drop = T.unsafe(nil)); end

  # Defines the maximum age (in seconds) of a resultset to still be included in merged results.
  # i.e. If you run cucumber features, then later rake test, if the stored cucumber resultset is
  # more seconds ago than specified here, it won't be taken into account when merging (and is also
  # purged from the resultset cache)
  #
  # Of course, this only applies when merging is active (e.g. SimpleCov.use_merging is not false!)
  #
  # Default is 600 seconds (10 minutes)
  #
  # Configure with SimpleCov.merge_timeout(3600) # 1hr
  #
  # source://simplecov//lib/simplecov/configuration.rb#206
  def merge_timeout(seconds = T.unsafe(nil)); end

  # Defines the minimum overall coverage required for the testsuite to pass.
  # SimpleCov will return non-zero if the current coverage is below this threshold.
  #
  # Default is 0% (disabled)
  #
  # source://simplecov//lib/simplecov/configuration.rb#217
  def minimum_coverage(coverage = T.unsafe(nil)); end

  # Defines the minimum coverage per file required for the testsuite to pass.
  # SimpleCov will return non-zero if the current coverage of the least covered file
  # is below this threshold.
  #
  # Default is 0% (disabled)
  #
  # source://simplecov//lib/simplecov/configuration.rb#238
  def minimum_coverage_by_file(coverage = T.unsafe(nil)); end

  # Certain code blocks (i.e. Ruby-implementation specific code) can be excluded from
  # the coverage metrics by wrapping it inside # :nocov: comment blocks. The nocov token
  # can be configured to be any other string using this.
  #
  # Configure with SimpleCov.nocov_token('skip') or it's alias SimpleCov.skip_token('skip')
  #
  # source://simplecov//lib/simplecov/configuration.rb#117
  def nocov_token(nocov_token = T.unsafe(nil)); end

  # Returns the hash of available profiles
  #
  # source://simplecov//lib/simplecov/configuration.rb#133
  def profiles; end

  # Returns the project name - currently assuming the last dirname in
  # the SimpleCov.root is this.
  #
  # source://simplecov//lib/simplecov/configuration.rb#179
  def project_name(new_name = T.unsafe(nil)); end

  # Refuses any coverage drop. That is, coverage is only allowed to increase.
  # SimpleCov will return non-zero if the coverage decreases.
  #
  # source://simplecov//lib/simplecov/configuration.rb#246
  def refuse_coverage_drop; end

  # The root for the project. This defaults to the
  # current working directory.
  #
  # Configure with SimpleCov.root('/my/project/path')
  #
  # source://simplecov//lib/simplecov/configuration.rb#19
  def root(root = T.unsafe(nil)); end

  # Certain code blocks (i.e. Ruby-implementation specific code) can be excluded from
  # the coverage metrics by wrapping it inside # :nocov: comment blocks. The nocov token
  # can be configured to be any other string using this.
  #
  # Configure with SimpleCov.nocov_token('skip') or it's alias SimpleCov.skip_token('skip')
  #
  # source://simplecov//lib/simplecov/configuration.rb#117
  def skip_token(nocov_token = T.unsafe(nil)); end

  # Coverage results will always include files matched by this glob, whether
  # or not they were explicitly required. Without this, un-required files
  # will not be present in the final report.
  #
  # source://simplecov//lib/simplecov/configuration.rb#53
  def track_files(glob = T.unsafe(nil)); end

  # Defines whether to use result merging so all your test suites (test:units, test:functionals, cucumber, ...)
  # are joined and combined into a single coverage report
  #
  # source://simplecov//lib/simplecov/configuration.rb#189
  def use_merging(use = T.unsafe(nil)); end

  private

  # The actal filter processor. Not meant for direct use
  #
  # source://simplecov//lib/simplecov/configuration.rb#282
  def parse_filter(filter_argument = T.unsafe(nil), &filter_proc); end
end

# source://simplecov//lib/simplecov/exit_codes.rb#2
module SimpleCov::ExitCodes; end

# source://simplecov//lib/simplecov/exit_codes.rb#4
SimpleCov::ExitCodes::EXCEPTION = T.let(T.unsafe(nil), Integer)

# source://simplecov//lib/simplecov/exit_codes.rb#6
SimpleCov::ExitCodes::MAXIMUM_COVERAGE_DROP = T.let(T.unsafe(nil), Integer)

# source://simplecov//lib/simplecov/exit_codes.rb#5
SimpleCov::ExitCodes::MINIMUM_COVERAGE = T.let(T.unsafe(nil), Integer)

# source://simplecov//lib/simplecov/exit_codes.rb#3
SimpleCov::ExitCodes::SUCCESS = T.let(T.unsafe(nil), Integer)

# source://simplecov//lib/simplecov/file_list.rb#4
class SimpleCov::FileList < ::Array
  # Returns the count of lines that have coverage
  #
  # source://simplecov//lib/simplecov/file_list.rb#6
  def covered_lines; end

  # Computes the coverage based upon lines covered and lines missed
  #
  # @return [Float]
  #
  # source://simplecov//lib/simplecov/file_list.rb#47
  def covered_percent; end

  # Computes the coverage based upon lines covered and lines missed for each file
  # Returns an array with all coverage percentages
  #
  # source://simplecov//lib/simplecov/file_list.rb#31
  def covered_percentages; end

  # Computes the strength (hits / line) based upon lines covered and lines missed
  #
  # @return [Float]
  #
  # source://simplecov//lib/simplecov/file_list.rb#54
  def covered_strength; end

  # Finds the least covered file and returns that file's name
  #
  # source://simplecov//lib/simplecov/file_list.rb#36
  def least_covered_file; end

  # Returns the overall amount of relevant lines of code across all files in this list
  #
  # source://simplecov//lib/simplecov/file_list.rb#41
  def lines_of_code; end

  # Returns the count of lines that have been missed
  #
  # source://simplecov//lib/simplecov/file_list.rb#12
  def missed_lines; end

  # Returns the count of lines that are not relevant for coverage
  #
  # source://simplecov//lib/simplecov/file_list.rb#18
  def never_lines; end

  # Returns the count of skipped lines
  #
  # source://simplecov//lib/simplecov/file_list.rb#24
  def skipped_lines; end
end

# Base filter class. Inherit from this to create custom filters,
# and overwrite the passes?(source_file) instance method
#
# # A sample class that rejects all source files.
# class StupidFilter < SimpleCov::Filter
#   def passes?(source_file)
#     false
#   end
# end
#
# source://simplecov//lib/simplecov/filter.rb#13
class SimpleCov::Filter
  # @return [Filter] a new instance of Filter
  #
  # source://simplecov//lib/simplecov/filter.rb#15
  def initialize(filter_argument); end

  # Returns the value of attribute filter_argument.
  #
  # source://simplecov//lib/simplecov/filter.rb#14
  def filter_argument; end

  # @return [Boolean]
  #
  # source://simplecov//lib/simplecov/filter.rb#19
  def matches?(_); end

  # @return [Boolean]
  #
  # source://simplecov//lib/simplecov/filter.rb#23
  def passes?(source_file); end
end

# TODO: Documentation on how to build your own formatters
#
# source://simplecov//lib/simplecov/formatter/multi_formatter.rb#2
module SimpleCov::Formatter; end

# source://simplecov//lib/simplecov/formatter/multi_formatter.rb#3
class SimpleCov::Formatter::MultiFormatter
  class << self
    # source://simplecov//lib/simplecov/formatter/multi_formatter.rb#26
    def [](*args); end

    # source://simplecov//lib/simplecov/formatter/multi_formatter.rb#17
    def new(formatters = T.unsafe(nil)); end
  end
end

# source://simplecov//lib/simplecov/formatter/multi_formatter.rb#4
module SimpleCov::Formatter::MultiFormatter::InstanceMethods
  # source://simplecov//lib/simplecov/formatter/multi_formatter.rb#5
  def format(result); end
end

# source://simplecov//lib/simplecov/formatter/simple_formatter.rb#6
class SimpleCov::Formatter::SimpleFormatter
  # Takes a SimpleCov::Result and generates a string out of it
  #
  # source://simplecov//lib/simplecov/formatter/simple_formatter.rb#8
  def format(result); end
end

# source://simplecov//lib/simplecov/merge_helpers.rb#20
module SimpleCov::HashMergeHelper
  # Merges the given Coverage.result hash with self
  #
  # source://simplecov//lib/simplecov/merge_helpers.rb#22
  def merge_resultset(hash); end
end

# source://simplecov//lib/simplecov/last_run.rb#4
module SimpleCov::LastRun
  class << self
    # source://simplecov//lib/simplecov/last_run.rb#6
    def last_run_path; end

    # source://simplecov//lib/simplecov/last_run.rb#10
    def read; end

    # source://simplecov//lib/simplecov/last_run.rb#15
    def write(json); end
  end
end

# source://simplecov//lib/simplecov/profiles.rb#9
class SimpleCov::Profiles < ::Hash
  # Define a SimpleCov profile:
  #   SimpleCov.profiles.define 'rails' do
  #     # Same as SimpleCov.configure do .. here
  #   end
  #
  # source://simplecov//lib/simplecov/profiles.rb#16
  def define(name, &blk); end

  # Applies the profile of given name on SimpleCov.configure
  #
  # source://simplecov//lib/simplecov/profiles.rb#25
  def load(name); end
end

# A simplecov code coverage result, initialized from the Hash Ruby 1.9's built-in coverage
# library generates (Coverage.result).
#
# source://simplecov//lib/simplecov/result.rb#9
class SimpleCov::Result
  extend ::Forwardable

  # Initialize a new SimpleCov::Result from given Coverage.result (a Hash of filenames each containing an array of
  # coverage data)
  #
  # @return [Result] a new instance of Result
  #
  # source://simplecov//lib/simplecov/result.rb#26
  def initialize(original_result); end

  # The command name that launched this result.
  # Delegated to SimpleCov.command_name if not set manually
  #
  # source://simplecov//lib/simplecov/result.rb#57
  def command_name; end

  # Explicitly set the command name that was used for this coverage result. Defaults to SimpleCov.command_name
  #
  # source://simplecov//lib/simplecov/result.rb#19
  def command_name=(_arg0); end

  # source://forwardable/1.3.3/forwardable.rb#231
  def covered_lines(*args, **_arg1, &block); end

  # source://forwardable/1.3.3/forwardable.rb#231
  def covered_percent(*args, **_arg1, &block); end

  # source://forwardable/1.3.3/forwardable.rb#231
  def covered_percentages(*args, **_arg1, &block); end

  # source://forwardable/1.3.3/forwardable.rb#231
  def covered_strength(*args, **_arg1, &block); end

  # Defines when this result has been created. Defaults to Time.now
  #
  # source://simplecov//lib/simplecov/result.rb#51
  def created_at; end

  # Explicitly set the Time this result has been created
  #
  # source://simplecov//lib/simplecov/result.rb#17
  def created_at=(_arg0); end

  # Returns all filenames for source files contained in this result
  #
  # source://simplecov//lib/simplecov/result.rb#36
  def filenames; end

  # Returns all files that are applicable to this result (sans filters!) as instances of SimpleCov::SourceFile. Aliased as :source_files
  #
  # source://simplecov//lib/simplecov/result.rb#14
  def files; end

  # Applies the configured SimpleCov.formatter on this result
  #
  # source://simplecov//lib/simplecov/result.rb#46
  def format!; end

  # Returns a Hash of groups for this result. Define groups using SimpleCov.add_group 'Models', 'app/models'
  #
  # source://simplecov//lib/simplecov/result.rb#41
  def groups; end

  # source://forwardable/1.3.3/forwardable.rb#231
  def least_covered_file(*args, **_arg1, &block); end

  # source://forwardable/1.3.3/forwardable.rb#231
  def missed_lines(*args, **_arg1, &block); end

  # Returns the original Coverage.result used for this instance of SimpleCov::Result
  #
  # source://simplecov//lib/simplecov/result.rb#12
  def original_result; end

  # Returns all files that are applicable to this result (sans filters!) as instances of SimpleCov::SourceFile. Aliased as :source_files
  #
  # source://simplecov//lib/simplecov/result.rb#14
  def source_files; end

  # Returns a hash representation of this Result that can be used for marshalling it into JSON
  #
  # source://simplecov//lib/simplecov/result.rb#62
  def to_hash; end

  # source://forwardable/1.3.3/forwardable.rb#231
  def total_lines(*args, **_arg1, &block); end

  private

  # source://simplecov//lib/simplecov/result.rb#77
  def coverage; end

  # Applies all configured SimpleCov filters on this result's source files
  #
  # source://simplecov//lib/simplecov/result.rb#83
  def filter!; end

  class << self
    # Loads a SimpleCov::Result#to_hash dump
    #
    # source://simplecov//lib/simplecov/result.rb#67
    def from_hash(hash); end
  end
end

# source://simplecov//lib/simplecov/result_merger.rb#9
module SimpleCov::ResultMerger
  class << self
    # Gets all SimpleCov::Results from cache, merges them and produces a new
    # SimpleCov::Result with merged coverage data and the command_name
    # for the result consisting of a join on all source result's names
    #
    # source://simplecov//lib/simplecov/result_merger.rb#62
    def merged_result; end

    # Gets the resultset hash and re-creates all included instances
    # of SimpleCov::Result from that.
    # All results that are above the SimpleCov.merge_timeout will be
    # dropped. Returns an array of SimpleCov::Result items.
    #
    # source://simplecov//lib/simplecov/result_merger.rb#45
    def results; end

    # Loads the cached resultset from JSON and returns it as a Hash
    #
    # source://simplecov//lib/simplecov/result_merger.rb#21
    def resultset; end

    # The path to the .resultset.json cache file
    #
    # source://simplecov//lib/simplecov/result_merger.rb#12
    def resultset_path; end

    # source://simplecov//lib/simplecov/result_merger.rb#16
    def resultset_writelock; end

    # Saves the given SimpleCov::Result in the resultset cache
    #
    # source://simplecov//lib/simplecov/result_merger.rb#74
    def store_result(result); end

    # Returns the contents of the resultset cache as a string or if the file is missing or empty nil
    #
    # source://simplecov//lib/simplecov/result_merger.rb#34
    def stored_data; end
  end
end

# Representation of a source file including it's coverage data, source code,
# source lines and featuring helpers to interpret that data.
#
# source://simplecov//lib/simplecov/source_file.rb#6
class SimpleCov::SourceFile
  # @return [SourceFile] a new instance of SourceFile
  #
  # source://simplecov//lib/simplecov/source_file.rb#78
  def initialize(filename, coverage); end

  # The array of coverage data received from the Coverage.result
  #
  # source://simplecov//lib/simplecov/source_file.rb#76
  def coverage; end

  # Returns all covered lines as SimpleCov::SourceFile::Line
  #
  # source://simplecov//lib/simplecov/source_file.rb#146
  def covered_lines; end

  # The coverage for this file in percent. 0 if the file has no relevant lines
  #
  # source://simplecov//lib/simplecov/source_file.rb#117
  def covered_percent; end

  # source://simplecov//lib/simplecov/source_file.rb#127
  def covered_strength; end

  # The full path to this source file (e.g. /User/colszowka/projects/simplecov/lib/simplecov/source_file.rb)
  #
  # source://simplecov//lib/simplecov/source_file.rb#74
  def filename; end

  # Access SimpleCov::SourceFile::Line source lines by line number
  #
  # source://simplecov//lib/simplecov/source_file.rb#112
  def line(number); end

  # Returns all source lines for this file as instances of SimpleCov::SourceFile::Line,
  # and thus including coverage data. Aliased as :source_lines
  #
  # source://simplecov//lib/simplecov/source_file.rb#93
  def lines; end

  # Returns the number of relevant lines (covered + missed)
  #
  # source://simplecov//lib/simplecov/source_file.rb#168
  def lines_of_code; end

  # Returns all lines that should have been, but were not covered
  # as instances of SimpleCov::SourceFile::Line
  #
  # source://simplecov//lib/simplecov/source_file.rb#152
  def missed_lines; end

  # Returns all lines that are not relevant for coverage as
  # SimpleCov::SourceFile::Line instances
  #
  # source://simplecov//lib/simplecov/source_file.rb#158
  def never_lines; end

  # Will go through all source files and mark lines that are wrapped within # :nocov: comment blocks
  # as skipped.
  #
  # source://simplecov//lib/simplecov/source_file.rb#174
  def process_skipped_lines!; end

  # Returns all lines that were skipped as SimpleCov::SourceFile::Line instances
  #
  # source://simplecov//lib/simplecov/source_file.rb#163
  def skipped_lines; end

  # The source code for this file. Aliased as :source
  #
  # source://simplecov//lib/simplecov/source_file.rb#84
  def source; end

  # Returns all source lines for this file as instances of SimpleCov::SourceFile::Line,
  # and thus including coverage data. Aliased as :source_lines
  #
  # source://simplecov//lib/simplecov/source_file.rb#93
  def source_lines; end

  # The source code for this file. Aliased as :source
  #
  # source://simplecov//lib/simplecov/source_file.rb#84
  def src; end

  private

  # ruby 1.9 could use Float#round(places) instead
  #
  # @return [Float]
  #
  # source://simplecov//lib/simplecov/source_file.rb#189
  def round_float(float, places); end
end

# Representation of a single line in a source file including
# this specific line's source code, line_number and code coverage,
# with the coverage being either nil (coverage not applicable, e.g. comment
# line), 0 (line not covered) or >1 (the amount of times the line was
# executed)
#
# source://simplecov//lib/simplecov/source_file.rb#12
class SimpleCov::SourceFile::Line
  # @raise [ArgumentError]
  # @return [Line] a new instance of Line
  #
  # source://simplecov//lib/simplecov/source_file.rb#27
  def initialize(src, line_number, coverage); end

  # The coverage data for this line: either nil (never), 0 (missed) or >=1 (times covered)
  #
  # source://simplecov//lib/simplecov/source_file.rb#18
  def coverage; end

  # Returns true if this is a line that has been covered
  #
  # @return [Boolean]
  #
  # source://simplecov//lib/simplecov/source_file.rb#43
  def covered?; end

  # The line number in the source file. Aliased as :line, :number
  #
  # source://simplecov//lib/simplecov/source_file.rb#16
  def line; end

  # The line number in the source file. Aliased as :line, :number
  #
  # source://simplecov//lib/simplecov/source_file.rb#16
  def line_number; end

  # Returns true if this is a line that should have been covered, but was not
  #
  # @return [Boolean]
  #
  # source://simplecov//lib/simplecov/source_file.rb#38
  def missed?; end

  # Returns true if this line is not relevant for coverage
  #
  # @return [Boolean]
  #
  # source://simplecov//lib/simplecov/source_file.rb#48
  def never?; end

  # The line number in the source file. Aliased as :line, :number
  #
  # source://simplecov//lib/simplecov/source_file.rb#16
  def number; end

  # Whether this line was skipped
  #
  # source://simplecov//lib/simplecov/source_file.rb#20
  def skipped; end

  # Flags this line as skipped
  #
  # source://simplecov//lib/simplecov/source_file.rb#53
  def skipped!; end

  # Returns true if this line was skipped, false otherwise. Lines are skipped if they are wrapped with
  # # :nocov: comment lines.
  #
  # @return [Boolean]
  #
  # source://simplecov//lib/simplecov/source_file.rb#59
  def skipped?; end

  # The source code for this line. Aliased as :source
  # Lets grab some fancy aliases, shall we?
  #
  # source://simplecov//lib/simplecov/source_file.rb#14
  def source; end

  # The source code for this line. Aliased as :source
  #
  # source://simplecov//lib/simplecov/source_file.rb#14
  def src; end

  # The status of this line - either covered, missed, skipped or never. Useful i.e. for direct use
  # as a css class in report generation
  #
  # source://simplecov//lib/simplecov/source_file.rb#65
  def status; end
end

# source://simplecov//lib/simplecov/filter.rb#29
class SimpleCov::StringFilter < ::SimpleCov::Filter
  # Returns true when the given source file's filename matches the
  # string configured when initializing this Filter with StringFilter.new('somestring)
  #
  # @return [Boolean]
  #
  # source://simplecov//lib/simplecov/filter.rb#32
  def matches?(source_file); end
end

# source://simplecov//lib/simplecov/version.rb#24
SimpleCov::VERSION = T.let(T.unsafe(nil), String)
