# frozen_string_literal: true

# Preload that simulates a host with the ruby-vips gem but without the native
# libvips: every dlopen of a vips library fails the way FFI fails without it.
require 'ffi'

class << FFI::DynamicLibrary
  alias open_with_libvips open

  def open(name, flags)
    if name.to_s.include?('vips')
      raise LoadError, "Could not open library '#{name}': #{name}: " \
                       'cannot open shared object file: No such file or directory'
    end

    open_with_libvips(name, flags)
  end
end
