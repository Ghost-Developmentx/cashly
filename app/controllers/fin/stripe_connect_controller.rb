module Fin
  class StripeConnectController < ApplicationController
    def status
      # Get current Stripe Connect status through FinService
      status_data = FinService.check_stripe_connect_status(current_user.id)

      render json: {
        success: true,
        data: status_data
      }
    end

    def setup
      # Handle Stripe Connect setup through Fin
      business_type = params[:business_type] || "individual"
      country = params[:country] || "US"

      setup_result = FinService.execute_create_stripe_connect_account(
        current_user.id,
        {
          "business_type" => business_type,
          "country" => country
        }
      )

      if setup_result[:success]
        render json: {
          success: true,
          onboarding_url: setup_result[:onboarding_url],
          account_id: setup_result[:account_id],
          message: setup_result[:message]
        }
      else
        render json: {
          success: false,
          error: setup_result[:error]
        }, status: :unprocessable_entity
      end
    end

    def create_onboarding_link
      service = StripeConnectService.new(current_user)
      connect_account = current_user.stripe_connect_account

      unless connect_account
        render json: {
          success: false,
          error: "No Stripe Connect account found"
        }, status: :not_found
        return
      end

      begin
        onboarding_link = service.create_onboarding_link

        render json: {
          success: true,
          onboarding_url: onboarding_link.url,
          message: "Onboarding link created successfully"
        }
      rescue => e
        render json: {
          success: false,
          error: e.message
        }, status: :unprocessable_entity
      end
    end

    def dashboard_link
      # Create dashboard link through FinService
      dashboard_result = FinService.execute_create_dashboard_link(current_user.id)

      if dashboard_result[:success]
        render json: {
          success: true,
          dashboard_url: dashboard_result[:dashboard_url],
          message: dashboard_result[:message]
        }
      else
        render json: {
          success: false,
          error: dashboard_result[:error]
        }, status: :unprocessable_entity
      end
    end

    def earnings
      period = params[:period] || "month"
      connect_account = current_user.stripe_connect_account

      unless connect_account&.can_accept_payments?
        render json: {
          success: false,
          error: "Stripe Connect account not ready for earnings reporting"
        }, status: :unprocessable_entity
        return
      end

      # Get earnings data from Stripe
      earnings_data = fetch_stripe_connect_earnings(connect_account, period)

      render json: {
        success: true,
        earnings: earnings_data,
        period: period
      }
    end

    def disconnect
      connect_account = current_user.stripe_connect_account

      unless connect_account
        render json: {
          success: false,
          error: "No Stripe Connect account to disconnect"
        }, status: :not_found
        return
      end

      begin
        # Deauthorize through Stripe
        service = StripeConnectService.new(current_user)
        if service.disconnect_account
          render json: {
            success: true,
            message: "Stripe Connect account disconnected successfully"
          }
        else
          render json: {
            success: false,
            error: "Failed to disconnect Stripe Connect account"
          }, status: :unprocessable_entity
        end
      rescue => e
        Rails.logger.error "Error disconnecting Stripe Connect: #{e.message}"
        render json: {
          success: false,
          error: "Error disconnecting account"
        }, status: :unprocessable_entity
      end
    end

    def onboarding_refresh
      # User refreshed during onboarding - create new link
      service = StripeConnectService.new(current_user)
      onboarding_link = service.create_onboarding_link

      if onboarding_link
        redirect_to onboarding_link.url
      else
        redirect_to "#{ENV['FRONTEND_URL']}/dashboard", alert: "Unable to continue onboarding. Please try again."
      end
    end

    def onboarding_success
      connect_account = current_user.stripe_connect_account

      if connect_account
        # Sync latest status
        connect_account.sync_from_stripe!

        if connect_account.onboarding_complete?
          redirect_to "#{ENV['FRONTEND_URL']}/dashboard", notice: "Stripe Connect setup completed! You can now send invoices and accept payments."
        else
          redirect_to "#{ENV['FRONTEND_URL']}/dashboard", alert: "Onboarding needs to be completed. Please finish setting up your Stripe account."
        end
      else
        redirect_to "#{ENV['FRONTEND_URL']}/dashboard", alert: "Something went wrong with your Stripe setup. Please try again."
      end
    end

    def webhook
      payload = request.body.read
      sig_header = request.env["HTTP_STRIPE_SIGNATURE"]
      endpoint_secret = ENV["STRIPE_CONNECT_WEBHOOK_SECRET"]

      begin
        event = Stripe::Webhook.construct_event(
          payload, sig_header, endpoint_secret
        )
      rescue JSON::ParserError => e
        render json: { error: "Invalid payload" }, status: 400
        return
      rescue Stripe::SignatureVerificationError => e
        render json: { error: "Invalid signature" }, status: 400
        return
      end

      # Handle the event
      case event.type
      when "account.updated", "account.application.deauthorized"
        # Find user by account ID
        account_id = event.data.object.id
        connect_account = StripeConnectAccount.find_by(stripe_account_id: account_id)

        if connect_account
          service = StripeConnectService.new(connect_account.user)
          service.process_account_webhook(event)
        end

      when "invoice.payment_succeeded"
        # Handle successful payments and calculate platform fees
        handle_invoice_payment(event)

      else
        Rails.logger.info "Unhandled Stripe Connect webhook event: #{event.type}"
      end

      render json: { received: true }
    end

    private

    def handle_invoice_payment(event)
      invoice = event.data.object
      cashly_invoice_id = invoice.metadata&.dig("cashly_invoice_id")

      return unless cashly_invoice_id

      # Update the Cashly invoice status
      cashly_invoice = Invoice.find_by(id: cashly_invoice_id)
      if cashly_invoice
        cashly_invoice.mark_as_paid

        # Log platform fee earned
        platform_fee = invoice.application_fee_amount.to_f / 100
        Rails.logger.info "Platform fee earned: $#{platform_fee} from invoice #{cashly_invoice_id}"
      end
    end

    def fetch_stripe_connect_earnings(connect_account, period)
      # Calculate date range based on a period
      end_date = Date.current
      start_date = case period
      when "week"
                     1.week.ago.to_date
      when "month"
                     1.month.ago.to_date
      when "quarter"
                     3.months.ago.to_date
      when "year"
                     1.year.ago.to_date
      else
                     1.month.ago.to_date
      end

      begin
        # Get balance transactions from Stripe
        balance_transactions = Stripe::BalanceTransaction.list(
          {
            created: {
              gte: start_date.to_time.to_i,
              lte: end_date.to_time.to_i
            },
            limit: 100
          },
          { stripe_account: connect_account.stripe_account_id }
        )

        # Calculate earnings
        total_gross = 0
        total_fees = 0
        total_net = 0
        platform_fees_earned = 0
        transaction_count = 0

        balance_transactions.data.each do |txn|
          if txn.type == "charge"
            total_gross += txn.amount
            total_fees += txn.fee
            total_net += txn.net
            transaction_count += 1
          elsif txn.type == "application_fee"
            platform_fees_earned += txn.amount
          end
        end

        # Convert from cents to dollars
        {
          period: period,
          date_range: "#{start_date.strftime('%B %d, %Y')} - #{end_date.strftime('%B %d, %Y')}",
          total_gross: total_gross / 100.0,
          total_fees: total_fees / 100.0,
          total_net: total_net / 100.0,
          platform_fees_earned: platform_fees_earned / 100.0,
          transaction_count: transaction_count,
          platform_fee_percentage: connect_account.platform_fee_percentage
        }

      rescue Stripe::StripeError => e
        Rails.logger.error "Error fetching Stripe Connect earnings: #{e.message}"
        {
          error: "Unable to fetch earnings data",
          period: period
        }
      end
    end
  end
end