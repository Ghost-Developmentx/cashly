# app/mailers/invoice_mailer.rb
class InvoiceMailer < ApplicationMailer
  default from: "invoices@cashly-app.com"

  def payment_reminder(invoice)
    @invoice = invoice
    @user = invoice.user

    mail(
      to: invoice.client_email,
      subject: "Payment Reminder: Invoice ##{invoice.generate_invoice_number}"
    )
  end

  def payment_confirmation(invoice)
    @invoice = invoice
    @user = invoice.user

    mail(
      to: invoice.client_email,
      subject: "Payment Received: Invoice ##{invoice.generate_invoice_number}"
    )
  end

  def payment_failed(invoice)
    @invoice = invoice
    @user = invoice.user

    mail(
      to: invoice.client_email,
      subject: "Payment Failed: Invoice ##{invoice.generate_invoice_number}"
    )
  end

  def invoice_created(invoice)
    @invoice = invoice
    @user = invoice.user

    mail(
      to: @user.email,
      subject: "New Invoice Created: ##{invoice.generate_invoice_number}"
    )
  end

  def invoice_sent(invoice)
    @invoice = invoice
    @user = invoice.user

    mail(
      to: @user.email,
      subject: "Invoice Sent: ##{invoice.generate_invoice_number}"
    )
  end
end
