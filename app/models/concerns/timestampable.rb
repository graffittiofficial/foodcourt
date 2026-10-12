module Timestampable
  extend ActiveSupport::Concern

  included do
    before_validation :ensure_timestamps, on: :create
  end

  private

  def ensure_timestamps
    self.created_at = Time.current if has_attribute?("created_at") && created_at.nil?
    self.updated_at = Time.current if has_attribute?("updated_at") && updated_at.nil?
  end
end
