# Multi-Model Import Guide

This guide shows how to use CSVImporter's multi-model functionality to import data that maps to multiple related models.

## Basic Concepts

In many real-world scenarios, a single row in a CSV file contains data that should be distributed across multiple related database tables. For example:

- User data alongside subscription data
- Employee data alongside time card records
- Product data alongside inventory location data

The multi-model functionality allows you to:

1. Define multiple models for your import
2. Map CSV columns to specific models
3. Control the order in which models are persisted
4. Define identifiers for finding existing records for each model
5. Build relationships between models

## Step-by-Step Guide

### 1. Define Models

Instead of using the `model` directive, use `models` to specify multiple models:

```ruby
class ImportTimeCardCSV
  include CSVImporter

  models user: User, time_card: TimeCard
end
```

### 2. Define Persistence Order

For related models with foreign key relationships, order matters:

```ruby
persist_order [:user, :time_card]
```

This ensures users are saved before their related time cards.

### 3. Define Identifiers for Each Model

Specify how existing records should be found for each model:

```ruby
# Find users by email
model_identifier :user, :email

# Find time cards by user_id and date combination
model_identifier :time_card, [:user_id, :date]
```

You can also use dynamic identifiers:

```ruby
model_identifier :user, ->(user) { user.email.present? ? :email : [:first_name, :last_name] }
```

### 4. Map Columns to Models

When defining columns, specify which model each belongs to:

```ruby
# User columns
column :email, required: true, model: :user
column :first_name, model: :user
column :last_name, model: :user

# TimeCard columns
column :date, required: true, model: :time_card
column :hours_worked, model: :time_card
column :project_code, model: :time_card
```

Columns without a `model` key are assigned to the default model if only one model is defined.

### 5. Connect Related Models

Use the `after_build` callback to establish relationships between models:

```ruby
after_build do
  # Both the user and time_card are accessible by their model key names
  time_card.user = user

  # You can also access all models as a hash
  # built_models[:time_card].user = built_models[:user]
end
```

### 6. Add Custom Validation

You can add validation specific to each model:

```ruby
after_build do
  if time_card.hours_worked.to_f > 24
    add_error("hours_worked", "Hours worked cannot exceed 24 per day", model_key: :time_card)
  end

  if user.email.present? && !user.email.include?('@')
    add_model_error(:email, "Invalid email format", model_key: :user)
  end
end
```

## Complete Example

Here's a complete example that imports user time cards:

```ruby
class ImportTimeCardCSV
  include CSVImporter

  # Define models and persistence order
  models user: User, time_card: TimeCard
  persist_order [:user, :time_card]

  # Define identifiers for each model
  model_identifier :user, :email
  model_identifier :time_card, [:user_id, :date]

  # Skip invalid rows
  when_invalid :skip

  # Define columns with their respective models
  column :email, required: true, model: :user
  column :first_name, model: :user
  column :last_name, model: :user

  column :date, required: true, model: :time_card
  column :hours_worked, model: :time_card, to: ->(value) { value.to_f }
  column :project_code, model: :time_card

  # Set up relationships
  after_build do
    # Link time card to user
    time_card.user = user

    # Set additional calculated fields
    time_card.week = Date.parse(time_card.date).strftime("%U").to_i if time_card.date.present?
  end

  # Add custom validation
  after_build do
    if time_card.hours_worked && time_card.hours_worked > 24
      add_error("hours_worked", "Cannot exceed 24 hours per day", model_key: :time_card)
    end
  end
end
```

## Usage

Use the importer just like you would a single-model importer:

```ruby
csv_content = <<~CSV
email,first_name,last_name,date,hours_worked,project_code
john@example.com,John,Doe,2023-05-01,8,PROJECT-123
jane@example.com,Jane,Smith,2023-05-01,7.5,PROJECT-456
CSV

importer = ImportTimeCardCSV.new(content: csv_content)

if importer.valid_header?
  report = importer.run!
  puts report.message # "Import completed. 2 created, 0 updated, 0 failed to create"
else
  puts importer.report.message
end
```

## Error Handling

Errors in the report will include the model key as a prefix:

```
Row 3: time_card.hours_worked - Hours worked cannot exceed 24 per day
Row 4: user.email - is invalid
```

## Preview Mode

You can use preview mode to validate without saving:

```ruby
report = importer.preview!
if report.success?
  puts "Data is valid, proceed with import"
else
  puts "Validation errors found:"
  report.invalid_rows.each do |row|
    puts "Row #{row.line_number}: #{row.errors.inspect}"
  end
end
```

## Tips and Best Practices

1. **Start simple**: Begin with a minimal implementation and add complexity as needed
2. **Order matters**: Always set the persistence order when models have foreign key relationships
3. **Use callbacks wisely**: Keep `after_build` blocks focused on a single responsibility
4. **Test thoroughly**: Create tests with various CSV inputs to ensure correct behavior
5. **Handle associations**: Always establish relationships between models in `after_build`
6. **Validate early**: Use preview mode to catch issues before attempting to save records
