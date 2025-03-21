# typed: true

# DO NOT EDIT MANUALLY
# This is an autogenerated file for types exported from the `simplecov-html` gem.
# Please instead update this file by running `bin/tapioca gem simplecov-html`.


# source://simplecov-html//lib/simplecov-html.rb#14
module SimpleCov
  class << self
    # source://simplecov/0.13.0/lib/simplecov.rb#60
    def add_not_loaded_files(result); end

    # source://simplecov/0.13.0/lib/simplecov.rb#110
    def filtered(files); end

    # source://simplecov/0.13.0/lib/simplecov.rb#121
    def grouped(files); end

    # source://simplecov/0.13.0/lib/simplecov.rb#141
    def load_adapter(name); end

    # source://simplecov/0.13.0/lib/simplecov.rb#137
    def load_profile(name); end

    # source://simplecov/0.13.0/lib/simplecov.rb#22
    def pid; end

    # source://simplecov/0.13.0/lib/simplecov.rb#22
    def pid=(_arg0); end

    # source://simplecov/0.13.0/lib/simplecov.rb#77
    def result; end

    # source://simplecov/0.13.0/lib/simplecov.rb#103
    def result?; end

    # source://simplecov/0.13.0/lib/simplecov.rb#21
    def running; end

    # source://simplecov/0.13.0/lib/simplecov.rb#21
    def running=(_arg0); end

    # source://simplecov/0.13.0/lib/simplecov.rb#41
    def start(profile = T.unsafe(nil), &block); end

    # source://simplecov/0.13.0/lib/simplecov.rb#150
    def usable?; end
  end
end

# source://simplecov-html//lib/simplecov-html.rb#15
module SimpleCov::Formatter; end

# source://simplecov-html//lib/simplecov-html.rb#16
class SimpleCov::Formatter::HTMLFormatter
  # source://simplecov-html//lib/simplecov-html.rb#17
  def format(result); end

  # source://simplecov-html//lib/simplecov-html.rb#28
  def output_message(result); end

  private

  # source://simplecov-html//lib/simplecov-html.rb#43
  def asset_output_path; end

  # source://simplecov-html//lib/simplecov-html.rb#50
  def assets_path(name); end

  # source://simplecov-html//lib/simplecov-html.rb#69
  def coverage_css_class(covered_percent); end

  # Returns a table containing the given source files
  #
  # source://simplecov-html//lib/simplecov-html.rb#60
  def formatted_file_list(title, source_files); end

  # Returns the html for the given source_file
  #
  # source://simplecov-html//lib/simplecov-html.rb#55
  def formatted_source_file(source_file); end

  # Return a (kind of) unique id for the source file given. Uses SHA1 on path for the id
  #
  # source://simplecov-html//lib/simplecov-html.rb#90
  def id(source_file); end

  # source://simplecov-html//lib/simplecov-html.rb#102
  def link_to_source_file(source_file); end

  # source://simplecov-html//lib/simplecov-html.rb#39
  def output_path; end

  # source://simplecov-html//lib/simplecov-html.rb#98
  def shortened_filename(source_file); end

  # source://simplecov-html//lib/simplecov-html.rb#79
  def strength_css_class(covered_strength); end

  # Returns the an erb instance for the template of given name
  #
  # source://simplecov-html//lib/simplecov-html.rb#35
  def template(name); end

  # source://simplecov-html//lib/simplecov-html.rb#94
  def timeago(time); end
end

# source://simplecov-html//lib/simplecov-html/version.rb#4
SimpleCov::Formatter::HTMLFormatter::VERSION = T.let(T.unsafe(nil), String)
