# Multi-Model Functionality for CSVImporter

This document describes the multi-model functionality added to CSVImporter that allows a single CSV row to create or update multiple related model instances.

## Overview

The multi-model functionality enables:

- Mapping CSV columns to different model types
- Specifying identifier strategies for each model
- Controlling the order in which models are persisted
- Maintaining associations between related models
- Validation across multiple models per row

## Example Use Case

A common example is importing time cards for employees:

- Each row contains both user data (name, email) and time card data (date, hours)
- You need to either find existing users or create new ones
- You need to create time card records associated with these users
- The user must be saved before the time card to establish foreign key relationships

## API Changes

### Configuration

```ruby
class ImportTimeCardCSV
  include CSVImporter

  # Define multiple models instead of a single model
  models user: User, time_card: TimeCard

  # Control persistence order (critical for foreign key relationships)
  persist_order [:user, :time_card]

  # Define identifiers for each model
  model_identifier :user, :email
  model_identifier :time_card, [:user_id, :date]

  # Assign columns to specific models
  column :email, required: true, model: :user
  column :first_name, model: :user
  column :date, required: true, model: :time_card
  column :hours_worked, model: :time_card

  # Associate related models
  after_build do
    time_card.user = user
  end
end
```

### Accessing Models

In callbacks, models can be accessed directly by their key name:

```ruby
after_build do
  # Both ways work:
  user.admin = false

  # For more complex logic, all models are available
  if user.email.end_with?("@admin.com")
    user.admin = true
  end
end
```

### Error Handling

Errors can be specific to a model:

```ruby
after_build do
  if time_card.hours_worked.to_f > 24
    add_error("hours_worked", "Hours worked cannot exceed 24 per day", model_key: :time_card)
  end
end
```

In error reports, model-specific errors are prefixed with the model key:

```
Row 3: time_card.hours_worked - Hours worked cannot exceed 24 per day
```

## Implementation Details

The implementation maintains backward compatibility with the existing single-model approach while adding the following components:

1. **Config Changes**:
   - Added `models` hash to store multiple model classes
   - Added `persist_order` to control the order of persistence
   - Added `model_identifiers` to store identifiers for each model

2. **ColumnDefinition Changes**:
   - Added `model_key` to specify which model a column belongs to

3. **Row Changes**:
   - Modified to build and manage multiple models per row
   - Added methods to access models by key
   - Updated validation to check all models
   - Enhanced error reporting to include model information

4. **Runner Changes**:
   - Modified to persist models in the specified order
   - Updated transaction handling for multiple models

## Backward Compatibility

The implementation preserves backward compatibility:

- Existing code using the single `model` directive continues to work
- Column definitions without a `model` key are assigned to the default model
- Error reporting maintains the same format for single-model imports

## Usage

See the `test/examples/time_card_import.rb` file for a complete example of using the multi-model functionality.
