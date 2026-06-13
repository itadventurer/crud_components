# Polymorphic belongs_to — for reflection coverage (no playground UI).
class Comment < ApplicationRecord
  belongs_to :commentable, polymorphic: true
end
