class ApplicationRecord < ActiveRecord::Base
  include Timestampable

  primary_abstract_class
end
