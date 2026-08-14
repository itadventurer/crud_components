require_relative 'test_helper'

# Who may in at all. What a visitor may see and do once inside is the app's
# ordinary ability, asked per model and per action — not this.
class AdminAuthTest < ActiveSupport::TestCase
  # A can?-shaped ability answering from a list of granted [action, subject]
  # pairs — the gem asks nothing else of one.
  class Grants
    def initialize(*pairs) = @pairs = pairs

    def can?(action, subject) = @pairs.include?([action, subject])
  end

  def config
    CrudComponents::Admin::Configuration.new.tap { |c| yield c if block_given? }
  end

  def gate(ability, conf = config)
    CrudComponents::Admin::Gate.new(conf, ability)
  end

  test 'the default asks the ability for access to the admin' do
    conf = config

    assert conf.cancan_gate?
    assert_equal :crud_admin, conf.auth_subject
  end

  test 'can :access, :crud_admin opens the gate' do
    assert_equal :allowed, gate(Grants.new(%i[access crud_admin])).verdict
  end

  test 'an ability without it is turned away' do
    assert_equal :forbidden, gate(Grants.new(%i[index all])).verdict
  end

  test 'a grant on the models is not a way in' do
    assert_equal :forbidden, gate(Grants.new([:access, Book], %i[manage all])).verdict
  end

  test 'nothing that answers can? is unauthorized, not forbidden' do
    gate = gate(nil)

    assert_equal :unauthorized, gate.verdict
    assert_match(/nothing here answers `can\?`/, gate.unauthorized_message)
    assert_match(/can :access, :crud_admin/, gate.unauthorized_message)
  end

  test 'auth_with :none opens the gate without an ability' do
    assert_equal :open, gate(nil, config { |c| c.auth_with :none }).verdict
  end

  test 'auth_with a block defers to the block' do
    assert_equal :block, gate(nil, config { |c| c.auth_with { nil } }).verdict
  end

  test 'auth_with takes the subject to ask about' do
    conf = config { |c| c.auth_with :cancan, subject: :backend }

    assert_equal :backend, conf.auth_subject
    assert_equal :allowed, gate(Grants.new(%i[access backend]), conf).verdict
    assert_equal :forbidden, gate(Grants.new(%i[access crud_admin]), conf).verdict
  end

  test 'auth_with rejects an unknown mode, and a mode with a block' do
    assert_raises(ArgumentError) { config { |c| c.auth_with :devise } }
    assert_raises(ArgumentError) { config { |c| c.auth_with(:cancan) { nil } } }
  end
end
