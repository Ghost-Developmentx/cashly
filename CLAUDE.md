# Cashly Development Guide

## Commands
- **Run server**: `bin/dev` (starts Rails server on port 3000)
- **Run tests**: `bin/rails test` (all tests)
- **Run single test**: `bin/rails test test/path/to/test_file.rb:line_number`
- **Run models tests**: `bin/rails test:models`
- **Run controllers tests**: `bin/rails test:controllers`
- **Linting**: `bin/rubocop` (using Rails Omakase style)
- **Security check**: `bin/brakeman`
- **Initialize accounting**: `bin/rails accounting:initialize`

## Codebase Style
- **Rails**: Follow Rails conventions (MVC architecture, RESTful controllers)
- **Ruby**: Uses Rubocop Rails Omakase style guide
- **Frontend**: Bootstrap 5 for styling, Stimulus.js for interactivity
- **Error handling**: Capture and report errors with appropriate logging
- **Naming**: Use snake_case for Ruby (files, variables, methods), camelCase for JS
- **Models**: Validate inputs, define relationships clearly
- **Controllers**: Keep thin, use services for complex operations
- **Views**: Use partials for reusable components

## Tech Stack
- Ruby 3.4.2, Rails 8.0
- Postgresql database
- Stimulus.js, Turbo, and Bootstrap 5
- Devise for authentication
- Plaid API for banking integration