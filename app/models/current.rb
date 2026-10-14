class Current < ActiveSupport::CurrentAttributes
  attribute :session

  def account
    session&.account
  end

  alias_method :user, :account
end
