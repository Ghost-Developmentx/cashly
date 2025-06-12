# app/controllers/api/v1/documentation_controller.rb
module Api
  module V1
    class DocumentationController < ApplicationController
      skip_before_action :require_clerk_session!

      def index
        render json: {
          api_version: "v1",
          base_url: request.base_url,
          authentication: {
            method: "Clerk Session Token",
            header: "Authorization: Bearer <token>"
          },
          endpoints: {
            user: {
              profile: {
                get_profile: {
                  method: "GET",
                  path: "/me",
                  description: "Get current user profile"
                },
                update_profile: {
                  method: "PATCH",
                  path: "/me",
                  description: "Update user profile",
                  params: {
                    first_name: "string",
                    last_name: "string",
                    company_name: "string",
                    currency: "string",
                    timezone: "string"
                  }
                }
              }
            },
            banking: {
              accounts: {
                create_link_token: {
                  method: "POST",
                  path: "/fin/accounts/create_link_token",
                  description: "Create Plaid link token for connecting bank accounts"
                },
                connect_account: {
                  method: "POST",
                  path: "/fin/accounts/connect_account",
                  description: "Connect a bank account via Plaid",
                  params: {
                    public_token: "string (required)",
                    metadata: "object"
                  }
                },
                disconnect_account: {
                  method: "DELETE",
                  path: "/fin/accounts/disconnect_account",
                  description: "Disconnect a bank account",
                  params: {
                    account_id: "integer (required)"
                  }
                },
                sync_accounts: {
                  method: "POST",
                  path: "/fin/accounts/sync_accounts",
                  description: "Sync all connected bank accounts"
                },
                account_status: {
                  method: "GET",
                  path: "/fin/accounts/account_status",
                  description: "Get status of all connected accounts"
                }
              },
              transactions: {
                list: {
                  method: "GET",
                  path: "/fin/transactions",
                  description: "List transactions with filters",
                  params: {
                    account_id: "integer",
                    account_name: "string",
                    days: "integer (default: 30)",
                    start_date: "date",
                    end_date: "date",
                    category: "string",
                    min_amount: "number",
                    max_amount: "number",
                    type: "string (income|expense)",
                    limit: "integer (max: 100)"
                  }
                },
                get: {
                  method: "GET",
                  path: "/fin/transactions/:id",
                  description: "Get a specific transaction"
                },
                create: {
                  method: "POST",
                  path: "/fin/transactions",
                  description: "Create a manual transaction",
                  params: {
                    transaction: {
                      account_id: "integer (or account_name)",
                      account_name: "string (or account_id)",
                      amount: "number (required)",
                      description: "string (required)",
                      date: "date (default: today)",
                      category_name: "string",
                      recurring: "boolean"
                    }
                  }
                },
                update: {
                  method: "PATCH",
                  path: "/fin/transactions/:id",
                  description: "Update a transaction (manual only)",
                  params: {
                    transaction: {
                      amount: "number",
                      description: "string",
                      date: "date",
                      category: "string"
                    }
                  }
                },
                delete: {
                  method: "DELETE",
                  path: "/fin/transactions/:id",
                  description: "Delete a transaction (manual only)"
                },
                categorize_bulk: {
                  method: "POST",
                  path: "/fin/transactions/categorize_bulk",
                  description: "Bulk categorize transactions using AI",
                  params: {
                    transaction_ids: "array of integers (optional)"
                  }
                }
              }
            },
            billing: {
              invoices: {
                list: {
                  method: "GET",
                  path: "/fin/invoices",
                  description: "List invoices",
                  params: {
                    status: "string (draft|pending|paid|overdue)",
                    client_name: "string",
                    days: "integer",
                    limit: "integer"
                  }
                },
                get: {
                  method: "GET",
                  path: "/fin/invoices/:id",
                  description: "Get a specific invoice"
                },
                create: {
                  method: "POST",
                  path: "/fin/invoices",
                  description: "Create a new invoice",
                  params: {
                    invoice: {
                      client_name: "string (required)",
                      client_email: "email (required)",
                      amount: "number (required)",
                      description: "string (required)",
                      due_date: "date",
                      days_until_due: "integer (default: 30)",
                      currency: "string (default: USD)"
                    }
                  }
                },
                update: {
                  method: "PATCH",
                  path: "/fin/invoices/:id",
                  description: "Update an invoice (draft only)"
                },
                delete: {
                  method: "DELETE",
                  path: "/fin/invoices/:id",
                  description: "Delete an invoice (draft only)"
                },
                send_invoice: {
                  method: "POST",
                  path: "/fin/invoices/:id/send_invoice",
                  description: "Send invoice to client"
                },
                send_reminder: {
                  method: "POST",
                  path: "/fin/invoices/:id/send_reminder",
                  description: "Send payment reminder"
                },
                mark_paid: {
                  method: "PATCH",
                  path: "/fin/invoices/:id/mark_paid",
                  description: "Mark invoice as paid"
                }
              },
              stripe_connect: {
                status: {
                  method: "GET",
                  path: "/fin/stripe_connect/status",
                  description: "Get Stripe Connect account status"
                },
                setup: {
                  method: "POST",
                  path: "/fin/stripe_connect/setup",
                  description: "Create Stripe Connect account",
                  params: {
                    business_type: "string (individual|company)",
                    country: "string (US|CA|GB|AU)"
                  }
                },
                dashboard_link: {
                  method: "POST",
                  path: "/fin/stripe_connect/dashboard_link",
                  description: "Get Stripe dashboard link"
                },
                earnings: {
                  method: "GET",
                  path: "/fin/stripe_connect/earnings",
                  description: "Get earnings report",
                  params: {
                    period: "string (week|month|quarter|year)"
                  }
                }
              }
            },
            ai_assistant: {
              conversations: {
                list: {
                  method: "GET",
                  path: "/fin/conversations",
                  description: "Get current conversation"
                },
                get: {
                  method: "GET",
                  path: "/fin/conversations/:id",
                  description: "Get specific conversation"
                },
                query: {
                  method: "POST",
                  path: "/fin/conversations/query",
                  description: "Send query to Fin AI assistant",
                  params: {
                    query: "string (required)"
                  }
                },
                clear: {
                  method: "POST",
                  path: "/fin/conversations/clear",
                  description: "Start a new conversation"
                },
                history: {
                  method: "GET",
                  path: "/fin/conversations/history",
                  description: "Get conversation history"
                },
                feedback: {
                  method: "POST",
                  path: "/fin/conversations/feedback",
                  description: "Provide feedback on response",
                  params: {
                    message_id: "string (required)",
                    feedback: "string (helpful|not_helpful)",
                    rating: "integer (1-5)"
                  }
                }
              }
            },
            plaid: {
              create_link_token: {
                method: "POST",
                path: "/plaid/create_link_token",
                description: "Create Plaid link token"
              },
              exchange_public_token: {
                method: "POST",
                path: "/plaid/exchange_public_token",
                description: "Exchange Plaid public token",
                params: {
                  public_token: "string (required)"
                }
              },
              sync: {
                method: "POST",
                path: "/plaid/sync",
                description: "Manually sync Plaid data"
              }
            }
          },
          example_requests: {
            create_transaction: {
              description: "Create a new expense transaction",
              request: {
                method: "POST",
                path: "/fin/transactions",
                headers: {
                  'Authorization': "Bearer <your-clerk-token>",
                  'Content-Type': "application/json"
                },
                body: {
                  transaction: {
                    account_name: "Checking",
                    amount: -45.50,
                    description: "Lunch at restaurant",
                    date: "2024-01-15",
                    category_name: "Food & Dining"
                  }
                }
              }
            },
            query_ai: {
              description: "Ask Fin AI assistant a question",
              request: {
                method: "POST",
                path: "/fin/conversations/query",
                headers: {
                  'Authorization': "Bearer <your-clerk-token>",
                  'Content-Type': "application/json"
                },
                body: {
                  query: "What did I spend on food last month?"
                }
              }
            }
          },
          notes: {
            authentication: "All endpoints require Clerk authentication unless specified",
            rate_limiting: "API rate limits apply - 100 requests per minute",
            dates: "All dates should be in YYYY-MM-DD format",
            amounts: "All amounts are in base currency units (e.g., dollars, not cents)",
            plaid_transactions: "Transactions synced from Plaid cannot be edited or deleted"
          }
        }
      end
    end
  end
end
