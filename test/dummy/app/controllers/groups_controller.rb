class GroupsController < ApplicationController
  # Grouping is a render-time arrangement, like the layout (`as:`). You hand
  # crud_collection a scope as usual and add `group_by:`; the gem orders by the
  # group key, splits the rows into collapsible groups, and keeps the open ones
  # in `?open=` so the view is copy-pasteable.
  def index = @books = Book.all
end
