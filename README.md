# Cashly - Intelligent Cash Flow Management

Cashly is a modern personal finance management application that helps users track expenses, manage budgets, and gain AI-powered insights into their financial habits.

## Features

### 💰 Account Management
- Track multiple financial accounts (checking, savings, credit cards, investments)
- Real-time sync with your financial institutions via Plaid
- Manual account management options

### 📊 Transaction Tracking
- Automatic transaction import from connected bank accounts
- Manual transaction entry
- CSV import for bulk transaction uploads
- Smart categorization using AI

### 📈 Budget Management
- Create and track budgets by category
- Visual progress indicators for budget usage
- AI-recommended budget allocations based on spending patterns

### 🧠 AI-Powered Insights
- Spending pattern analysis
- Cash flow forecasting
- Personalized financial recommendations
- Automatic transaction categorization

### 📝 Invoice Management
- Create and track invoices
- Monitor payment status
- Track due dates and overdue payments

## Technology Stack

- **Backend**: Ruby on Rails 8.0
- **Database**: PostgreSQL
- **Frontend**: Bootstrap 5, Stimulus.js
- **Authentication**: Devise
- **Banking Integration**: Plaid API
- **AI Services**: Custom AI service for financial insights
- **Deployment**: Docker, Kamal

## Prerequisites

- Ruby 3.4.2
- PostgreSQL
- Node.js & Yarn
- Docker (for production deployment)

## Getting Started

### Local Development Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/cashly.git
   cd cashly
   ```

2. Install dependencies:
   ```bash
   bundle install
   ```

3. Set up the database:
   ```bash
   bin/rails db:create db:migrate db:seed
   ```

4. Set up environment variables:
   ```bash
   # Create a .env file in the root directory with the following variables:
   PLAID_CLIENT_ID=your_plaid_client_id
   PLAID_SECRET=your_plaid_secret
   PLAID_PUBLIC_KEY=your_plaid_public_key
   AI_SERVICE_URL=your_ai_service_url
   ENCRYPTION_KEY=your_encryption_key_for_attr_encrypted
   ```

5. Start the development server:
   ```bash
   bin/dev
   ```

6. Visit `http://localhost:3000` in your browser.

### Docker Setup

The project includes Docker configuration for containerized deployment:

1. Build the Docker image:
   ```bash
   docker build -t cashly .
   ```

2. Run the container:
   ```bash
   docker run -d -p 80:80 -e RAILS_MASTER_KEY=<value from config/master.key> --name cashly cashly
   ```

### Production Deployment with Kamal

Cashly is configured for deployment with Kamal:

1. Update your deployment configuration in `config/deploy.yml`

2. Deploy to production:
   ```bash
   bin/kamal setup
   bin/kamal deploy
   ```

## Environment Configuration

### Required Environment Variables

- `RAILS_MASTER_KEY`: Master key for Rails credentials
- `PLAID_CLIENT_ID`: Plaid API client ID
- `PLAID_SECRET`: Plaid API secret
- `PLAID_PUBLIC_KEY`: Plaid API public key
- `AI_SERVICE_URL`: URL to the AI service for financial insights
- `ENCRYPTION_KEY`: Key for encrypting sensitive data with attr_encrypted

## External Services

### Plaid Integration

Cashly uses Plaid for connecting to users' bank accounts. You'll need to:

1. Sign up for a Plaid developer account at [plaid.com](https://plaid.com)
2. Obtain API credentials
3. Configure the credentials in your environment variables

### AI Service

The application uses an external AI service for:
- Transaction categorization
- Budget recommendations
- Financial trend analysis
- Cash flow forecasting

You'll need to set up this service separately or modify the code to work with a different service.

## Database Schema

The application includes the following key models:

- `User`: Account information and authentication
- `Account`: Financial accounts (bank accounts, credit cards, etc.)
- `Transaction`: Individual financial transactions
- `Category`: Transaction categories
- `Budget`: Budget allocations by category
- `Invoice`: Invoice tracking for freelancers/small businesses
- `PlaidToken`: Secure storage of Plaid API tokens

## Testing

Run the test suite:

```bash
bin/rails test
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

[MIT License](LICENSE)

## Contact

Your Name - your.email@example.com

Project Link: [https://github.com/yourusername/cashly](https://github.com/yourusername/cashly)
