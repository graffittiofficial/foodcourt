class Current < ActiveSupport::CurrentAttributes
  attribute :session, :organization, :restaurant

  def account
    session&.account
  end

  alias_method :user, :account
end
