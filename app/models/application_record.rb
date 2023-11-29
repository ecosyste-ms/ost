class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class
  ActiveRecord::Base.record_timestamps = false
end
