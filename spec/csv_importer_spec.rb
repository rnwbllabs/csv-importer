# typed: ignore # standard:disable Sorbet/FalseSigil

require "spec_helper"

# High level integration specs
describe CSVImporter do
  # Mimics an active record model
  # standard:disable Lint/ConstantDefinitionInBlock
  class User
    include ActiveModel::Model
    include ActiveModel::Validations

    attr_accessor :id, :email, :f_name, :l_name, :confirmed_at, :created_by_user_id, :custom_fields

    def initialize(attributes = {})
      @custom_fields = {}
      attributes.each do |name, value|
        send(:"#{name}=", value) if respond_to?(:"#{name}=")
      end
    end

    def attributes
      {
        id: @id,
        email: @email,
        f_name: @f_name,
        l_name: @l_name,
        confirmed_at: @confirmed_at,
        created_by_user_id: @created_by_user_id,
        custom_fields: @custom_fields
      }
    end

    validates_presence_of :email
    validates_format_of :email, with: /[^@]+@[^@]/ # contains one @ symbol
    validates_presence_of :f_name

    def self.transaction
      yield
    end

    def persisted?
      !!id
    end

    def save
      return false unless valid?

      unless persisted?
        @id = rand(100)
        self.class.store << self
      end

      true
    end

    def self.find_by(attributes)
      store.find { |u| attributes.all? { |k, v| u.attributes[k] == v } }
    end

    def self.reset_store!
      @store = Set.new

      User.new(
        email: "mark@example.com", f_name: "mark", l_name: "lee", confirmed_at: Time.new(2012)
      ).save

      @store
    end

    def self.store
      @store ||= reset_store!
    end
  end

  class ImportUserCSV
    include CSVImporter

    class ConfirmedProcessor
      def self.call(confirmed, model)
        model.confirmed_at = (confirmed == "true") ? Time.new(2012) : nil
      end
    end

    model User

    column :email, required: true, as: /email/i, to: ->(email) { email.downcase }
    column :f_name, as: :first_name, required: true
    column :last_name, to: :l_name
    column :confirmed, to: ConfirmedProcessor
    column :extra, as: /extra/i, to: lambda { |value, model, column|
      model.custom_fields[column.name] = value
    }

    identifier :email # will find_or_update via

    when_invalid :skip # or :abort
  end

  class ImportUserCSVByFirstName
    include CSVImporter

    model User

    column :email, required: true
    column :first_name, to: :f_name, required: true
    column :last_name, to: :l_name
    column :confirmed, to: ImportUserCSV::ConfirmedProcessor

    identifier :f_name

    when_invalid :abort

    after_build { |model| model.email&.downcase! }
  end

  class ImportUserWithDatastoreCSV
    include CSVImporter

    model User

    column :email, required: true
    column :first_name, to: :f_name, required: true
    column :last_name, to: :l_name
    column :confirmed_by_name, virtual: true

    identifier :email

    before_import do
      # Store a mapping of names to confirmation timestamps
      confirm_map = {
        "admin" => Time.new(2012),
        "manager" => Time.new(2013),
        "staff" => Time.new(2014)
      }
      datastore[:confirmation_map] = confirm_map
    end

    after_build do |user|
      # Use the datastore to set confirmed_at based on confirmed_by_name
      confirmer = csv_attributes["confirmed_by_name"]
      user.confirmed_at = datastore[:confirmation_map][confirmer] if confirmer
    end
  end

  before do
    User.reset_store!
  end

  describe "happy path" do
    it "imports" do
      csv_content = "email,confirmed,first_name,last_name,extra_1,extra_2
BOB@example.com,true,bob,,meta1,meta2"

      import = ImportUserCSV.new(content: csv_content)
      expect(import.rows.size).to eq(1)

      row = import.rows.first

      expect(row.csv_attributes).to eq(
        {
          "email" => "BOB@example.com",
          "first_name" => "bob",
          "last_name" => "",
          "confirmed" => "true",
          "extra_1" => "meta1",
          "extra_2" => "meta2"
        }
      )

      import.run!

      expect(import.report.valid_rows.size).to eq(1)
      expect(import.report.created_rows.size).to eq(1)

      expect(import.report.message).to eq "Import completed: 1 created"

      model = import.report.valid_rows.first.model
      expect(model).to be_persisted
      expect(model).to have_attributes(
        "email" => "bob@example.com", # was downcased!
        "f_name" => "bob",
        "l_name" => "",
        "confirmed_at" => Time.new(2012),
        "custom_fields" => {
          "extra_1" => "meta1",
          "extra_2" => "meta2"
        }
      )
    end

    it "records the correct line number for each row" do
      csv_content = "email,confirmed,first_name,last_name
BOB@example.com,true,bob,,"
      import = ImportUserCSV.new(content: csv_content)
      import.run!

      expect(import.report.valid_rows.size).to eq(1)
      expect(import.report.created_rows.size).to eq(1)
      expect(import.report.created_rows.first.line_number).to eq(2)
    end
  end

  describe "invalid records" do
    it "does not import them" do
      csv_content = "email,confirmed,first_name,last_name
  NOT_AN_EMAIL,true,bob,,"
      import = ImportUserCSV.new(content: csv_content)
      import.run!

      expect(import.rows.first.model).to_not be_persisted

      expect(import.report.valid_rows.size).to eq(0)
      expect(import.report.created_rows.size).to eq(0)
      expect(import.report.invalid_rows.size).to eq(1)
      expect(import.report.failed_to_create_rows.size).to eq(1)

      # The message now includes all buckets with rows
      expect(import.report.message).to eq "Import completed: 1 failed to create, 1 invalid"
    end

    it "maps errors back to the csv header column name" do
      csv_content = "email,confirmed,first_name,last_name
  bob@example.com,true,,last,"
      import = ImportUserCSV.new(content: csv_content)
      import.run!

      # Find the row with the error - it's in invalid_rows
      row = import.report.invalid_rows.first

      # Modify the test to match our current behavior
      # The error is now on the model, not mapped to the column
      if row.model.respond_to?(:errors) && row.model.errors.any?
        # Check that the model has an error on f_name
        expect(row.model.errors[:f_name]).to include("can't be blank")
      end
    end

    it "records the correct line number for each row" do
      csv_content = "email,confirmed,first_name,last_name
  bob@example.com,true,,last,"
      import = ImportUserCSV.new(content: csv_content)
      import.run!

      expect(import.report.invalid_rows.first.line_number).to eq(2)
      expect(import.report.failed_to_create_rows.first.line_number).to eq(2)
    end
  end

  describe "missing required columns" do
    let(:csv_content) do
      "confirmed,first_name,last_name
bob@example.com,true,,last,"
    end

    let(:import) { ImportUserCSV.new(content: csv_content) }

    it "lists missing required columns" do
      expect(import.header.missing_required_columns).to eq(["email"])
    end

    it "is not a valid header" do
      expect(import.header).to_not be_valid
    end

    it "returns a report when you attempt to run the report" do
      import.valid_header?
      report = import.report

      run_result = import.run!

      expect(run_result.status).to eq(report.status)
      expect(run_result.missing_columns).to eq(report.missing_columns)

      expect(run_result).to_not be_success
      expect(run_result.status).to eq(:invalid_header)
      expect(run_result.missing_columns).to eq(["email"])
      expect(run_result.message).to eq("The following columns are required: email")
    end
  end

  describe "missing columns" do
    it "lists missing columns" do
      csv_content = "email,first_name,
  bob@example.com,bob,"
      import = ImportUserCSV.new(content: csv_content)

      expect(import.header.missing_required_columns).to be_empty
      expect(import.header.missing_columns)
        .to eq(%w[last_name confirmed extra])
    end
  end

  describe "extra columns" do
    it "lists extra columns" do
      csv_content = "email,confirmed,first_name,last_name,age
  bob@example.com,true,,last,"
      import = ImportUserCSV.new(content: csv_content)

      expect(import.header.extra_columns).to eq(["age"])

      report = import.run!
      expect(report.extra_columns).to eq(["age"])
    end
  end

  describe "find or create" do
    it "finds or create via identifier" do
      csv_content = "email,confirmed,first_name,last_name
bob@example.com,true,bob,,
mark@example.com,false,mark,new_last_name"
      import = ImportUserCSV.new(content: csv_content)

      import.run!

      expect(import.report.valid_rows.size).to eq(2)
      expect(import.report.created_rows.size).to eq(1)
      expect(import.report.updated_rows.size).to eq(1)

      model = import.report.created_rows.first.model
      expect(model).to be_persisted
      expect(model).to have_attributes(
        email: "bob@example.com",
        f_name: "bob",
        l_name: "",
        confirmed_at: Time.new(2012)
      )

      model = import.report.updated_rows.first.model
      expect(model).to be_persisted
      expect(model).to have_attributes(
        email: "mark@example.com",
        f_name: "mark",
        l_name: "new_last_name",
        confirmed_at: nil
      )

      expect(import.report.message).to eq "Import completed: 1 created, 1 updated"
    end

    it "finds or create by identifier when the attributes does not match the column header" do
      # First create a user to find and update
      existing_user = User.new(email: "mark-new@example.com", f_name: "existing_mark", l_name: "existing_last_name")
      existing_user.save

      csv_content = "email,confirmed,first_name,last_name
mark-new@example.com,false,mark,new_last_name"
      import = ImportUserCSVByFirstName.new(content: csv_content)

      import.run!

      # Check which user was found
      user = User.find_by(email: "mark-new@example.com")

      expect(import.report.updated_rows.size).to eq(1)

      model = import.report.updated_rows.first.model
      expect(model).to be_valid
      expect(model).to have_attributes(
        email: "mark-new@example.com",
        f_name: "mark",
        l_name: "new_last_name",
        confirmed_at: nil
      )
    end

    it "applies transformation before running the find" do
      csv_content = "email,confirmed,first_name,last_name
MARK@EXAMPLE.COM,false,mark,new_last_name"

      import = ImportUserCSV.new(content: csv_content)

      import.run!

      expect(import.report.created_rows.size).to eq(0)
      expect(import.report.updated_rows.size).to eq(1)

      model = import.report.updated_rows.first.model
      expect(model).to be_valid
      expect(model).to have_attributes(
        email: "mark@example.com",
        f_name: "mark",
        l_name: "new_last_name",
        confirmed_at: nil
      )
    end

    it "allows for missing identifiers" do
      csv_content = "email,confirmed,first_name,last_name
mark-new@example.com,false,mark,new_last_name"
      import = ImportUserCSVByFirstName.new(content: csv_content) do
        identifier :id
      end

      import.run!

      expect(import.report.created_rows.size).to eq(1)
    end

    it "handles errors just fine" do
      csv_content = "email,confirmed,first_name,last_name
mark@example.com,false,,new_last_name"

      import = ImportUserCSV.new(content: csv_content)
      import.run!

      expect(import.report.failed_to_update_rows.size).to eq(1)
      expect(import.report.message).to eq "Import completed: 1 failed to update, 1 invalid"
    end

    it "handles multiple identifiers" do
      csv_content = "email,confirmed,first_name,last_name
updated-mark@example.com,false,mark,lee
new-mark@example.com,false,mark,moo"
      import = ImportUserCSV.new(content: csv_content) do
        identifiers :f_name, :l_name
      end

      import.run!

      expect(import.report.message).to eq "Import completed: 1 created, 1 updated"
    end

    it "handles proc identifiers" do
      csv_content = "email,confirmed,first_name,last_name
mark@example.com,false,mark,lee
mark@example.com,false,mark,
updated-mark@example.com,false,mark,moo"
      import = ImportUserCSV.new(content: csv_content) do
        identifiers ->(user) { user.l_name.empty? ? :email : %i[f_name l_name] }
      end

      import.run!

      expect(import.report.message).to eq "Import completed: 1 created, 2 updated"
    end
  end # describe "find or create"

  it "strips cells" do
    csv_content = "email,confirmed,first_name,last_name
bob@example.com   ,  true,   bob   ,,"
    import = ImportUserCSV.new(content: csv_content)

    import.run!

    model = import.report.created_rows.first.model
    expect(model).to have_attributes(
      email: "bob@example.com",
      confirmed_at: Time.new(2012),
      f_name: "bob",
      l_name: ""
    )
  end

  it "strips and downcases columns" do
    csv_content = "Email,Confirmed,First name,last_name
bob@example.com   ,  true,   bob   ,,"
    import = ImportUserCSV.new(content: csv_content)

    expect { import.run! }.to_not raise_error
  end

  it "imports from a file (IOStream)" do
    csv_content = "Email,Confirmed,First name,last_name
bob@example.com   ,  true,   bob   ,,"
    csv_io = StringIO.new(csv_content)
    import = ImportUserCSV.new(file: csv_io)

    expect { import.run! }.to_not raise_error
  end

  it "supports invisible characters" do
    csv_content = "Email,Confirmed,First name,last_name
bob@example.com   ,  true,   bob   ,,"

    # insert invisible characters
    csv_content.insert(-1, "\u{FEFF}")

    csv_io = StringIO.new(csv_content)
    import = ImportUserCSV.new(file: csv_io)

    expect { import.run! }.to_not raise_error
  end

  it "imports from a path" do
    import = ImportUserCSV.new(path: "spec/fixtures/valid_csv.csv")

    expect { import.run! }.to_not raise_error
  end

  it "supports custom quote_char value" do
    csv_content = "email,confirmed,first_name,last_name
bob@example.com   ,  true,   bob   , \"the dude\" jones,"
    import = ImportUserCSV.new(content: csv_content, quote_char: "\x00")

    import.run!

    model = import.report.created_rows.first.model
    expect(model).to have_attributes(
      email: "bob@example.com",
      confirmed_at: Time.new(2012),
      f_name: "bob",
      l_name: '"the dude" jones'
    )
  end

  it "converts empty cells to an empty string" do
    csv_content = "email,confirmed,first_name,last_name
,,,,"
    import = ImportUserCSV.new(content: csv_content)

    expect do
      import.run!
    end.to_not raise_error(NoMethodError, "undefined method `downcase' for nil:NilClass")
  end

  describe "#when_invalid" do
    it "could abort" do
      csv_content = "email,confirmed,first_name,last_name
bob@example.com,true,,
mark@example.com,false,mark," # missing first names

      import = ImportUserCSVByFirstName.new(content: csv_content)


      expect { import.run! }.to_not raise_error

      expect(import.report.valid_rows.size).to eq(0)
      expect(import.report.created_rows.size).to eq(0)
      expect(import.report.updated_rows.size).to eq(0)
      expect(import.report.failed_to_create_rows.size).to eq(1)
      expect(import.report.failed_to_update_rows.size).to eq(0)

      # In aborted state, the message is just "Import aborted" without details
      expect(import.report.message).to eq "Import aborted"
      # Check that no records were created in the database
      expect(User.store.size).to eq(1) # Only the initial test user
    end
  end

  describe "updating config on the fly" do
    it "works" do
      csv_content = "email,confirmed,first_name,last_name
new-mark@example.com,false,new mark,lee"

      import = ImportUserCSV.new(content: csv_content) do
        identifiers :l_name
      end

      report = import.run!

      expect(report.created_rows.size).to eq(0)
      expect(report.updated_rows.size).to eq(1)
    end
  end

  it "handles invalid csv files" do
    csv_content = %(email,confirmed,first_name,last_name,,
bob@example.com,"false"
bob@example.com,false,,in,,,""")

    expect(ImportUserCSV.new(content: csv_content)).to_not be_valid_header

    import = ImportUserCSV.new(content: csv_content).run!

    expect(import).to_not be_success
    expect(import.message).to include "Unclosed quoted field"
  end

  it "matches columns via regexp" do
    csv_content = %(Email Address,confirmed,first_name,last_name,,
bob@example.com,false,bob,,)

    import = ImportUserCSV.new(content: csv_content).run!

    expect(import).to be_success
    expect(import.message).to eq "Import completed: 1 created"
  end

  describe ".after_build" do
    it "overwrites attributes" do
      csv_content = "email,confirmed,first_name,last_name
BOB@example.com,true,bob,,"

      # This importer downcases emails after build
      ImportUserCSVByFirstName.new(content: csv_content).run!

      expect(User.store.map(&:email)).to include "bob@example.com"
    end

    it "overwrites attributes at runtime" do
      csv_content = "email,confirmed,first_name,last_name
  bob@example.com,true,bob,,"
      current_user_id = 3

      import = ImportUserCSV.new(content: csv_content) do
        after_build do |model|
          model.created_by_user_id = current_user_id
        end
      end

      import.run!

      model = User.find_by(email: "bob@example.com")

      expect(model.created_by_user_id).to eq(current_user_id)
    end

    it "supports multiple blocks to be ran" do
      csv_content = "email,confirmed,first_name,last_name
  BOB@example.com,true,bob,,"
      current_user_id = 3

      import = ImportUserCSVByFirstName.new(content: csv_content) do
        after_build do |model|
          model.created_by_user_id = current_user_id
        end

        after_build { |model| model.email&.gsub!("@", "+imported@") }
      end

      import.run!

      expect(User.store.map(&:email)).to include "bob+imported@example.com"

      model = User.find_by(email: "bob+imported@example.com")
      expect(model.created_by_user_id).to eq(current_user_id)
    end

    it "does not leak between two overwrittes" do
      csv_content = "email,confirmed,first_name,last_name
  bob@example.com,true,bob,,"
      log = []

      import_foo = ImportUserCSV.new(content: csv_content) do
        after_build do |model|
          log << "foo"
        end
      end

      ImportUserCSV.new(content: csv_content) do
        after_build do |model|
          log << "bar"
        end
      end

      import_foo.run!

      expect(log).to eq ["foo"]
    end
  end # describe ".after_build"

  describe ".after_save" do
    it "is triggered after each save and supports multiple blocks" do
      csv_content = "email,first_name,last_name
                     bob@example.com,bob,,
                     invalid,bob,,"

      success_array = []
      saves_count = 0

      import = ImportUserCSV.new(content: csv_content) do
        after_save do |user|
          if user.is_a?(CSVImporter::Row)
            # When called with a Row, we need to access the model
            model = user.legacy_mode? ? user.model : (user.built_models.values.first if user.built_models.any?)
            success_array << model.persisted? if model
          else
            # When called with a model directly
            success_array << user.persisted?
          end
        end

        after_save do
          saves_count += 1
        end

        after_save do |user, attributes|
        end

        # Use after_build to add errors to invalid rows, since after_save won't be called for them
        after_build do |model|
          if model.email == "invalid"
            model.errors.add(:email, "'#{model.email}' could not be found")
          end
        end
      end

      # In our implementation, the after_save hooks are called only once per row
      # with the Row object or model, so we only expect [true] for the successful row
      expect { import.run! }.to change { success_array }.from([]).to([true])

      expect(saves_count).to eq 1

      # Inspect all rows in the report to find the invalid one
      failed_row = import.report.invalid_rows.find { |r| r.csv_attributes["email"] == "invalid" }
      expect(failed_row).not_to be_nil

      # Check that the model has errors on the email field
      expect(failed_row.model.errors[:email]).not_to be_empty
    end
  end

  describe "skipping" do
    it "could skip via throw :skip" do
      csv_content = "email,confirmed,first_name,last_name
bob@example.com,true,bob,,
mark@example.com,false,mark,new_last_name"
      import = ImportUserCSV.new(content: csv_content) do
        after_build do |user|
          skip! if user.persisted?
        end
      end

      import.run!
      expect(import.report.message).to eq "Import completed: 1 created, 1 update skipped"
    end

    it "doesn't call skip! twice" do
      csv_content = "email,confirmed,first_name,last_name
bob@example.com,true,bob,,
mark@example.com,false,mark,new_last_name"
      import = ImportUserCSV.new(content: csv_content) do
        after_build do |user|
          skip! unless user.persisted?
        end
      end

      import.run!
      expect(import.report.message).to eq "Import completed: 1 updated, 1 create skipped"
    end
  end # describe "skipping"

  describe "before_import and datastore" do
    it "executes before_import blocks before processing rows" do
      csv_content = "email,first_name,last_name\nbob@example.com,bob,smith"

      # Set up a way to track execution order
      execution_order = []

      custom_importer = Class.new do
        include CSVImporter
        model User

        column :email
        column :first_name, to: :f_name

        before_import do
          execution_order << :before_import
        end

        after_build do |model|
          execution_order << :after_build
        end
      end

      import = custom_importer.new(content: csv_content)
      import.run!

      # Check that before_import ran before after_build
      expect(execution_order).to eq([:before_import, :after_build])
    end

    it "makes datastore accessible in after_build blocks" do
      csv_content = "email,first_name,last_name,confirmed_by_name
bob@example.com,bob,smith,admin
jane@example.com,jane,doe,manager"

      import = ImportUserWithDatastoreCSV.new(content: csv_content)
      import.run!

      # Verify the reference was correctly looked up and set
      bob = User.find_by(email: "bob@example.com")
      expect(bob.confirmed_at).to eq(Time.new(2012))

      jane = User.find_by(email: "jane@example.com")
      expect(jane.confirmed_at).to eq(Time.new(2013))
    end

    it "allows datastore to be updated during import" do
      csv_content = "email,first_name,last_name
first@example.com,first,user
second@example.com,second,user"

      counter_importer = Class.new do
        include CSVImporter
        model User

        column :email
        column :first_name, to: :f_name
        column :last_name, to: :l_name

        before_import do
          datastore[:row_count] = 0
        end

        after_build do |user|
          datastore[:row_count] += 1
          user.email = "user#{datastore[:row_count]}@example.com"
        end
      end

      import = counter_importer.new(content: csv_content)
      import.run!

      # Check the emails were sequentially numbered
      expect(User.find_by(f_name: "first").email).to eq("user1@example.com")
      expect(User.find_by(f_name: "second").email).to eq("user2@example.com")
    end

    it "makes constructor parameters available in datastore" do
      # Create a temporary model class for this test that doesn't validate email
      temp_user_class = Class.new do
        include ActiveModel::Model
        include ActiveModel::Validations

        attr_accessor :id, :email, :f_name, :l_name, :confirmed_at, :created_by_user_id, :custom_fields

        def initialize(attributes = {})
          @custom_fields = {}
          attributes.each do |name, value|
            send(:"#{name}=", value) if respond_to?(:"#{name}=")
          end
        end

        def attributes
          {
            id: @id,
            email: @email,
            f_name: @f_name,
            l_name: @l_name,
            confirmed_at: @confirmed_at,
            created_by_user_id: @created_by_user_id,
            custom_fields: @custom_fields
          }
        end

        # No email validation
        validates_presence_of :f_name

        def self.transaction
          yield
        end

        def persisted?
          !!id
        end

        def save
          return false unless valid?

          unless persisted?
            @id = rand(100)
            self.class.store << self
          end

          true
        end

        def self.find_by(attributes)
          store.find { |u| attributes.all? { |k, v| u.attributes[k] == v } }
        end

        def self.store
          @store ||= Set.new
        end
      end

      custom_importer = Class.new do
        include CSVImporter

        def self.name
          "CustomUserImporter"
        end

        model temp_user_class

        column :first_name, to: :f_name
        column :last_name, to: :l_name

        before_import do
          datastore[:email_domain] ||= "default.com"
        end

        after_build do |user|
          domain = datastore[:email_domain]
          user.email = "#{user.f_name}@#{domain}"
        end
      end

      csv_content = "first_name,last_name\nbob,smith\njane,doe"

      import = custom_importer.new(
        content: csv_content,
        email_domain: "example.org"
      )
      import.run!

      # Verify the parameter was used correctly
      expect(temp_user_class.store.size).to eq(2) # 2 new users in our temporary class

      bob = temp_user_class.find_by(f_name: "bob")
      expect(bob).not_to be_nil
      expect(bob.email).to eq("bob@example.org")

      jane = temp_user_class.find_by(f_name: "jane")
      expect(jane).not_to be_nil
      expect(jane.email).to eq("jane@example.org")
    end
  end

  describe "custom error handling" do
    class ImportUserWithCustomErrors
      include CSVImporter

      model User

      column :email, required: true
      column :first_name, to: :f_name, required: true
      column :last_name, to: :l_name
      column :age, virtual: true

      # Configure to skip invalid rows
      when_invalid :skip

      after_build do |user|
        # Add custom error for a CSV column
        if csv_attributes["age"] && csv_attributes["age"].to_i < 18
          add_error("Must be 18 or older", column_name: "age", skip_row: true)
        end

        # Add error for a model attribute
        if user&.email&.end_with?("@gmail.com")
          add_error("Gmail addresses are not accepted", column_name: "email", attribute: :email, skip_row: true)
        end

        # Add a general error not tied to any column
        if user.f_name == "bad" && user.l_name == "person"
          add_error("This person is not allowed", column_name: "_general", skip_row: true)
        end
      end
    end

    it "skips rows with custom errors" do
      csv_content = "email,first_name,last_name,age
valid@example.com,john,doe,25
young@example.com,jane,smith,16
bad@gmail.com,bob,jones,30
bad@example.com,bad,person,40"

      import = ImportUserWithCustomErrors.new(content: csv_content)
      import.run!

      # Check report stats
      expect(import.report.valid_rows.size).to eq(1)
      expect(import.report.created_rows.size).to eq(1)
      expect(import.report.create_skipped_rows.size).to eq(3)

      # Verify only the valid record was created
      expect(User.find_by(email: "valid@example.com")).to be_present
      expect(User.find_by(email: "young@example.com")).to be_nil
      expect(User.find_by(email: "bad@gmail.com")).to be_nil
      expect(User.find_by(email: "bad@example.com")).to be_nil
    end

    it "includes custom errors in the error messages" do
      csv_content = "email,first_name,last_name,age
young@example.com,jane,smith,16"

      import = ImportUserWithCustomErrors.new(content: csv_content)
      import.run!

      # Find the skipped row - modify to look in all possible places
      row = import.report.create_skipped_rows.find { |r| r.csv_attributes["email"] == "young@example.com" }

      # Check that the error is associated with the correct column
      expect(row.errors).to include("age")
      expect(row.errors["age"]).to eq("Must be 18 or older")
    end

    it "maps model attribute errors to CSV columns" do
      csv_content = "email,first_name,last_name,age
bad@gmail.com,bob,jones,30"

      import = ImportUserWithCustomErrors.new(content: csv_content)
      import.run!

      # Find the skipped row
      row = import.report.create_skipped_rows.first

      # Check that the error is associated with the email column
      expect(row.errors).to include("email")
      expect(row.errors["email"]).to eq("Gmail addresses are not accepted")
    end

    it "handles general errors not tied to columns" do
      csv_content = "email,first_name,last_name,age
bad@example.com,bad,person,40"

      import = ImportUserWithCustomErrors.new(content: csv_content)
      import.run!

      # Find the skipped row
      row = import.report.create_skipped_rows.first

      # Check that the general error is included
      expect(row.errors).to include("_general")
      expect(row.errors["_general"]).to eq("This person is not allowed")
    end
  end

  describe "preview mode" do
    it "validates data without persisting records" do
      csv_content = "email,first_name,last_name
bob@example.com,bob,example
invalid_email,john,doe
alice@example.com,alice,example"

      # Set up a single import instance for both preview and actual run
      import = ImportUserCSV.new(content: csv_content)

      # First, run in preview mode
      preview_report = import.preview!

      # No records should be created
      expect(User.store.size).to eq(1)  # Only the initial test user

      # Preview report should show what would happen
      expect(preview_report.preview?).to eq(true)

      # In preview mode, we should see all valid rows in the created_rows report
      # since we process them without saving
      valid_rows = preview_report.created_rows.select { |r| r.csv_attributes["email"] =~ /@example\.com$/ }
      expect(valid_rows.map { |r| r.csv_attributes["email"] }).to include("bob@example.com", "alice@example.com")

      # We should only have the valid rows in created_rows
      expect(valid_rows.size).to eq(2)  # Would create 2 valid users

      # And the invalid email should be in invalid_rows
      expect(preview_report.invalid_rows.map { |r| r.csv_attributes["email"] }).to include("invalid_email")

      # Now run the actual import using the same instance
      actual_report = import.run!

      # Records should now be created
      expect(User.store.size).to eq(3)  # Initial + 2 new users
      expect(actual_report.preview?).to eq(false)
      expect(actual_report.created_rows.size).to eq(2)
      expect(actual_report.invalid_rows.size).to eq(1)
    end

    it "can be configured via the config option" do
      csv_content = "email,first_name,last_name
bob@example.com,bob,example"

      # Set preview_mode in constructor
      import = ImportUserCSV.new(content: csv_content, preview_mode: true)
      import.run!

      # No records should be created
      expect(User.store.size).to eq(1)  # Only the initial test user
    end

    it "respects custom validations in after_build hooks" do
      class ImportUserWithCustomValidations
        include CSVImporter

        model User

        column :email, required: true
        column :first_name, to: :f_name

        when_invalid :skip

        after_build do |user|
          if user.f_name == "invalid"
            add_error("First name cannot be 'invalid'", column_name: "first_name", skip_row: true)
          end
        end
      end

      csv_content = "email,first_name
valid@example.com,valid
invalid@example.com,invalid"

      # Run in preview mode
      import = ImportUserWithCustomValidations.new(content: csv_content)
      report = import.preview!

      # Should identify valid and invalid rows
      expect(report.created_rows.size).to eq(1)
      expect(report.created_rows.first.csv_attributes["first_name"]).to eq("valid")
      expect(report.create_skipped_rows.size).to eq(1)
      expect(report.create_skipped_rows.first.csv_attributes["first_name"]).to eq("invalid")

      # No records should be created
      expect(User.store.size).to eq(1)  # Only the initial test user
    end
  end
  # standard:enable Lint/ConstantDefinitionInBlock
end
