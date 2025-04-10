# CSVImporter

Importing a CSV file is easy to code until real users attempt to import
real data.

CSVImporter aims to handle validations, column mapping, import
and reporting.

[![CI Status](https://github.com/rnwbllabs/csv-importer/workflows/CI/badge.svg)](https://github.com/rnwbllabs/csv-importer/actions)
[![Gem Version](https://badge.fury.io/rb/csv-importer.svg)](http://badge.fury.io/rb/csv-importer)

## Rationale

Importing CSV files seems easy until you deal with *real* users uploading
their *real* CSV file. You then have to deal with ASCII-8BIT formats,
missing columns, empty rows, malformed headers, wild separators, etc.
Reporting progress and errors to the end-user is also key for a good
experience.

I went through this many times so I decided to build CSV Importer to
save us the trouble.

CSV Importer provides:

* a DSL to define the mapping between CSV columns and your model
* good reporting to the end user
* support for wild encodings and CSV formats.

It is compatible with ActiveRecord 4+ and any ORM that implements
the class methods `transaction` and `find_by` and the instance method `save`.

## Usage tldr;

Define your CSVImporter:

```ruby
class ImportUserCSV
  include CSVImporter

  model User # an active record like model

  column :email, to: ->(email) { email.downcase }, required: true
  column :first_name, as: [ /first.?name/i, /pr(é|e)nom/i ]
  column :last_name,  as: [ /last.?name/i, "nom" ]
  column :published,  to: ->(published, user) { user.published_at = published ? Time.now : nil }

  identifier :email # will update_or_create via :email

  when_invalid :skip # or :abort
end
```

Run the import:

```ruby
import = ImportUserCSV.new(file: my_file)

import.valid_header?  # => false
import.report.message # => "The following columns are required: email"

# Assuming the header was valid, let's run the import!

import.run!
import.report.success? # => true
import.report.message  # => "Import completed. 4 created, 2 updated, 1 failed to update"
```

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'csv-importer'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install csv-importer

## Usage

### Create an Importer

Create a class and include `CSVImporter`.

```ruby
class ImportUserCSV
  include CSVImporter
end
```

### Associate an active record model

The `model` is likely to be an active record model.

```ruby
class ImportUserCSV
  include CSVImporter

  model User
end
```

It can also be a relation which is handy to preset attributes:

```ruby
class User
  scope :pending, -> { where(status: 'pending') }
end

class ImportUserCSV
  include CSVImporter

  model User.pending
end
```

You can change the configuration at runtime to scope down to associated
records.

```ruby
class Team
  has_many :users
end

team = Team.find(1)

ImportUserCSV.new(path: "tmp/my_file.csv") do
  model team.users
end
```


### Define columns and their mapping

This is where the fun begins.

```ruby
class ImportUserCSV
  include CSVImporter

  model User

  column :email
end
```

This will map the column named email to the email attribute. By default,
we downcase and strip the columns so it will work with a column spelled " EMail ".

Now, email could also be spelled "e-mail", or "mail", or even "courriel"
(oh, canada). Let's give it a couple of aliases then:


```ruby
  column :email, as: [/e.?mail/i, "courriel"]
```

Nice, emails should be downcased though, so let's do this.

```ruby
  column :email, as: [/e.?mail/i, "courriel"], to: ->(email) { email.downcase }
```

If you need to do more advanced stuff, you've got access to the model:

```ruby
  column :email, as: [/e.?mail/i, "courriel"], to: ->(email, user) { user.email = email.downcase; model.super_user! if email[/@brewhouse.io\z/] }
```

Like very advanced stuff? We grant you access to the [`column`](https://github.com/pcreux/csv-importer/blob/master/lib/csv_importer/column.rb) object itself which contains the column name – quite handy if you want to support arbitrary columns.

```ruby
  column :extra, as: [/extra/], to: ->(value, user, column) do
    attribute = column.name.sub(/^extra /, '')
    user[attribute] = value
  end
```

Note that `to:` accepts anything that responds to call and take 1, 2 or
3 arguments.

```ruby
class ImportUserCSV
  include CSVImporter

  model User

  column :birth_date, to: DateTransformer
  column :renewal_date, to: DateTransformer
  column :next_renewal_at, to: ->(value) { Time.at(value.to_i) }
end

class DateTransformer
  def self.call(date)
    Date.strptime(date, '%m/%d/%y')
  end
end
```

#### Virtual Columns

You can define virtual columns that don't map directly to model attributes but are still processed during import:

```ruby
class ImportUserCSV
  include CSVImporter

  model User

  column :email, required: true
  column :full_name, virtual: true, to: ->(full_name, user) do
    first_name, last_name = full_name.split(' ', 2)
    user.first_name = first_name
    user.last_name = last_name
  end
end
```

Virtual columns are useful for:
- Processing combined fields (like full name into first and last name)
- Handling computed or temporary data that doesn't map directly to your model
- Validating data without storing it

#### Required Columns

Now, what if the user does not provide the email column? It's not worth
running the import, we should just reject the CSV file right away.
That's easy:

```ruby
class ImportUserCSV
  include CSVImporter

  model User

  column :email, required: true
end

import = ImportUserCSV.new(content: "name\nbob")
import.valid_header? # => false
import.report.status # => :invalid_header
import.report.message # => "The following columns are required: 'email'"
```

### Update or Create

You often want to find-and-update-or-create when importing a CSV file.
Just provide an identifier, and we'll do the hard work for you.

```ruby
class ImportUserCSV
  include CSVImporter

  model User

  column :email, to: ->(email) { email.downcase }

  identifier :email
end
```

And yes, we'll look for an existing record using the downcased email. :)

You can also define a composite identifier:

```ruby
  # Update records with matching company_id AND employee_id
  identifier :company_id, :employee_id
```

Or a Proc:

```ruby
  # Update records with email if email is present
  # Update records matching company_id AND employee_id if email is not present
  identifier ->(user) { user.email.empty? ? [:company_id, :employee_id] : :email }
```

### Skip or Abort on error

By default, we skip invalid records and report errors back to the user.
There are times where you want your import to be an all or nothing. The
`when_invalid` option is here for you.

```ruby
class ImportUserCSV
  include CSVImporter

  model User

  column :email, to: ->(email) { email.downcase }

  when_invalid :abort
end

import = ImportUserCSV.new(content: "email\nbob@example.com\nINVALID_EMAIL")
import.valid_header? # => true
import.run!
import.report.success? # => false
import.report.status # => :aborted
import.report.message # => "Import aborted"
```

You are now done defining your importer, let's run it!

### Import from a file, path or string

You can import from a file, path or just the CSV content. Please note
that we currently load the entire file in memory. Feel free to
contribute if you need to support CSV files with millions of lines! :)

```ruby
import = ImportUserCSV.new(file: my_file)
import = ImportUserCSV.new(path: "tmp/new_users.csv")
import = ImportUserCSV.new(content: "email,name\nbob@example.com,bob")
```

### Overwrite configuration at runtime

It is often needed to change the configuration at runtime, that's quite
easy:

```ruby
team = Team.find(1)
import = ImportUserCSV.new(file: my_file) do
  model team.users
end
```

### `after_build` and `after_save` callbacks

You can preset attributes (or perform any changes to the model) at
configuration or runtime using `after_build`

```ruby
class ImportUserCSV
  model User

  column :email

  after_build do |user|
    user.name = email.split('@').first
  end
end

# assuming `current_user` is available

import = ImportUserCSV.new(file: my_file) do
  after_build do |user|
    user.created_by_user = current_user
  end
end
```

The `after_save` callback is run after each call to the method `save` no
matter it fails or succeeds. It is quite handy to keep track of
progress.

```ruby
progress_bar = ProgressBar.new

UserImport.new(file: my_file) do
  after_save do |user|
    progress_bar.increment
  end
end
```

### `before_import` callback

The `before_import` callback runs once before the import process begins. It's useful for setup tasks, validation, or any processing needed before individual rows are handled.

```ruby
class ImportUserCSV
  include CSVImporter

  model User

  column :email

  before_import do
    # Perform setup operations
    Rails.logger.info "Starting import with #{rows.count} rows"

    # You can abort the import if needed
    abort!("Too many rows") if rows.count > 1000
  end
end
```

The callback provides access to all rows before processing and can be used to:
- Validate the overall dataset
- Prepare related records or dependencies
- Log import start information
- Abort the import based on dataset characteristics
- Set up shared data in the datastore for use in row processing

### Skip import

You can skip the import of a model by calling `skip!` in an
`after_build` block:

```ruby
UserImport.new(file: csv_file) do
  # Skip existing records
  after_build do |user|
    skip! if user.persisted?
  end
end
```


### Validate the header

On a web application, as soon as a CSV file is uploaded, you can check
if it has the required columns. This is handy to fail early and provide
the user with a meaningful error message right away.

```ruby
import = ImportUserCSV.new(file: params[:csv_file])
import.valid_header? # => false
import.report.message # => "The following columns are required: "email""
```

### Preview Mode

You can run the import in preview mode to validate data and show potential results without actually saving records:

```ruby
# Option 1: Using the preview! method
import = ImportUserCSV.new(file: params[:csv_file])
report = import.preview!

# Option 2: Setting preview_mode in the constructor
import = ImportUserCSV.new(file: params[:csv_file], preview_mode: true)
report = import.run!

# Check validation results without actual database changes
report.preview? # => true
report.valid_rows.map { |row| [row.model.email, row.model.valid?] }
```

Preview mode is useful for:
- Showing users validation results before committing to an import
- Testing column mappings and transformations
- Detecting potential errors early
- Providing row counts and statistics before actual import

### Custom Error Handling

You can add custom validation errors during the import process to provide more context or implement business logic:

```ruby
class ImportUserCSV
  include CSVImporter

  model User

  column :email, required: true
  column :age, virtual: true

  after_build do |user|
    # Add error for a specific CSV column
    if csv_attributes["age"] && csv_attributes["age"].to_i < 18
      add_error("age", "Must be 18 or older")
    end

    # Add error for a model attribute
    if user.email && user.email.end_with?("@example.com")
      add_model_error(:email, "Example.com addresses not accepted")
    end

    # Add a general error not tied to any specific column
    if user.first_name == "Admin" && user.last_name == "User"
      add_general_error("Admin users cannot be imported")
    end
  end
end
```

Custom error handling provides:
- Better context about validation failures
- Business logic validation beyond model validations
- User-friendly messages specific to the import process

### Run the import and provide feedback to the user

```ruby
import = ImportUserCSV.new(file: params[:csv_file])
import.run!
import.report.message  # => "Import completed. 4 created, 2 updated, 1 failed to update"
```

You can get your hands dirty and fetch the errored rows and the
associated error message:

```ruby
import.report.invalid_rows.map { |row| [row.line_number, row.model.email, row.errors] }
  # => [ [2, "INVALID_EMAIL", { "email" => "is invalid" } ] ]
```

We do our best to map the errors back to the original column name. So
with the following definition:

```ruby
  column :email, as: /e.?mail/i
```

and csv:

```csv
E-Mail,name
INVALID_EMAIL,bob
```

The error returned should be: `{ "E-Mail" => "is invalid" }`

### Custom quote char

You can handle exotic quote chars with the `quote_char` option.

```csv
email,name
bob@example.com,'bob "elvis" wilson'
```

```ruby
import = ImportUserCSV.new(content: csv_content)
import.run!
import.report.status
  # => :invalid_csv_file
import.report.messages
  # => CSV::MalformedCSVError: Illegal quoting in line 2.
```

Let's provide a valid quote char:

```ruby
import = ImportUserCSV.new(content: csv_content, quote_char: "'")
import.run!
  # => [ ["bob@example.com", "bob \"elvis\" wilson"] ]
```

### Custom encoding

You can handle exotic encodings with the `encoding` option.

```ruby
ImportUserCSV.new(content: "メール,氏名".encode('SJIS'), encoding: 'SJIS:UTF-8')
```

## Sorbet Integration

CSVImporter works with Sorbet for type checking. To use it in a Sorbet project, ensure your importer classes are properly typed:

```ruby
# typed: strict
class ImportUserCSV
  extend T::Sig
  include CSVImporter

  model User

  column :email, required: true
  column :first_name
  column :last_name

  sig { params(user: User).void }
  after_build do |user|
    user.username = user.email.split('@').first if user.email.present?
  end
end
```

Key benefits of using Sorbet with CSVImporter:
- Type safety for column transformers and callbacks
- Better IDE support and documentation
- Catch errors at development time rather than runtime

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release` to create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

1. Fork it ( https://github.com/pcreux/csv-importer/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
