# frozen_string_literal: true

# Loaded first: the parts required after it read these at load time.
module CrudComponents
  # The query params the gem owns (filters are top-level params named after the
  # field, so a field can't share these names). Declaring such an attribute
  # raises in the Builder rather than silently colliding with sort/pagination.
  RESERVED_PARAMS = %w[q sort dir page per cols].freeze

  # Sentinel filter value meaning "the column is NULL" (boolean/enum filters on
  # nullable columns offer it as a "not set" choice). Improbable as a real
  # value, so it never collides with a genuine enum key or boolean string.
  NULL_FILTER_VALUE = '__null__'

  # The two non-blank values of an attachment **presence** filter — its 3-state
  # control (any / present / absent) submits these, and the query turns them into
  # an EXISTS / NOT EXISTS (`where.associated` / `where.missing`) over the backing
  # attachment association rather than a value match. See {Fields::AttachmentField}.
  PRESENT_FILTER_VALUE = 'present'
  ABSENT_FILTER_VALUE = 'absent'
end
