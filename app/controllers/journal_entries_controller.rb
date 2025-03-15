class JournalEntriesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_journal_entry, only: [ :show, :edit, :update, :destroy, :post, :reverse ]

  def index
    @journal_entries = current_user.journal_entries.order(date: :desc, created_at: :desc)
                                   .includes(:journal_lines)
                                   .page(params[:page])
                                   .per(20)
  end

  def show
    @journal_lines = @journal_entry.journal_lines.includes(:ledger_account)
  end

  def new
    @journal_entry = current_user.journal_entries.new(date: Date.today)
    @journal_entry.journal_lines.build
  end

  def create
    @journal_entry = current_user.journal_entries.new(journal_entry_params)

    if @journal_entry.save
      if @journal_entry.balanced? && params[:post] == "true"
        @journal_entry.post
      end
      redirect_to @journal_entry, notice: "Journal entry was successfully created."
    else
      render :new
    end
  end

  def edit
    # Only allow editing draft journal entries
    unless @journal_entry.status == JournalEntry::DRAFT
      redirect_to @journal_entry, alert: "Only draft journal entries can be edited."
      return
    end
  end

  def update
    # Only allow updating draft journal entries
    unless @journal_entry.status == JournalEntry::DRAFT
      redirect_to @journal_entry, alert: "Only draft journal entries can be updated."
      return
    end

    if @journal_entry.update(journal_entry_params)
      if params[:post] == "true" && @journal_entry.balanced?
        @journal_entry.post
      end
      redirect_to @journal_entry, notice: "Journal entry was successfully updated."
    else
      render :edit
    end
  end

  def destroy
    # Only allow deleting draft journal entries
    unless @journal_entry.status == JournalEntry::DRAFT
      redirect_to @journal_entry, alert: "Only draft journal entries can be deleted."
      return
    end

    @journal_entry.destroy
    redirect_to journal_entries_path, notice: "Journal entry was successfully deleted."
  end

  def post
    # Only allow posting balanced draft journal entries
    unless @journal_entry.status == JournalEntry::DRAFT
      redirect_to @journal_entry, alert: "Only draft journal entries can be posted."
      return
    end

    unless @journal_entry.balanced?
      redirect_to @journal_entry, alert: "Journal entry must be balanced before posting."
      return
    end

    if @journal_entry.post
      redirect_to @journal_entry, notice: "Journal entry was successfully posted."
    else
      redirect_to @journal_entry, alert: "Failed to post journal entry."
    end
  end

  def reverse
    # Only allow reversing posted journal entries
    unless @journal_entry.status == JournalEntry::POSTED
      redirect_to @journal_entry, alert: "Only posted journal entries can be reversed."
      return
    end

    reversal = @journal_entry.reverse
    if reversal
      redirect_to reversal, notice: "Journal entry was successfully reversed. New reversal entry created."
    else
      redirect_to @journal_entry, alert: "Failed to reverse journal entry."
    end
  end

  private

  def set_journal_entry
    @journal_entry = current_user.journal_entries.find(params[:id])
  end

  def journal_entry_params
    params.expect(journal_entry:
                    [ :date, :reference, :description, :status,
                      journal_lines_attributes:
                        [ [ :id, :ledger_account_id, :debit_amount, :credit_amount, :description, :_destroy ] ]
                    ])
  end
end
