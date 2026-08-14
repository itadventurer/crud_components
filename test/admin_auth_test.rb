require_relative 'test_helper'

# Who may in: the gate's verdict, and the ability the admin asks behind it.
class AdminAuthTest < ActiveSupport::TestCase
  # A can?-shaped ability answering from a list of granted [action, subject]
  # pairs — the gem asks nothing else of one.
  class Grants
    def initialize(*pairs) = @pairs = pairs

    def can?(action, subject)
      @pairs.any? do |granted_action, granted_subject|
        granted_action == action && (granted_subject == :all || granted_subject == subject_class(subject))
      end
    end

    def sees_records = 'delegated'

    private

    def subject_class(subject) = subject.is_a?(Class) ? subject : subject.class
  end

  def config
    CrudComponents::Admin::Configuration.new.tap { |c| yield c if block_given? }
  end

  def entries = CrudComponents::Admin.registry.entries

  def gate(ability, conf = config)
    CrudComponents::Admin::Gate.new(conf, ability, entries)
  end

  def wrapped(ability, action = :crud_admin)
    CrudComponents::Admin::Ability.new(ability, action)
  end

  # ── the gate ─────────────────────────────────────────────────────────────
  test 'the default is the ability, asked about :crud_admin' do
    conf = config

    assert conf.cancan_gate?
    assert_equal :crud_admin, conf.auth_action
  end

  test 'a grant on every model opens the gate' do
    assert_equal :allowed, gate(Grants.new([:crud_admin, :all])).verdict
  end

  test 'a grant on one model opens the gate for a limited admin' do
    assert_equal :allowed, gate(Grants.new([:crud_admin, Book])).verdict
  end

  test 'an ability without the admin action is turned away' do
    assert_equal :forbidden, gate(Grants.new([:index, :all])).verdict
  end

  test 'nothing that answers can? is unauthorized, not forbidden' do
    gate = gate(nil)

    assert_equal :unauthorized, gate.verdict
    assert_match(/nothing here answers `can\?`/, gate.unauthorized_message)
    assert_match(/can :crud_admin, :all/, gate.unauthorized_message)
  end

  test 'auth_with :none opens the gate without an ability' do
    assert_equal :open, gate(nil, config { |c| c.auth_with :none }).verdict
  end

  test 'auth_with a block defers to the block' do
    assert_equal :block, gate(nil, config { |c| c.auth_with { nil } }).verdict
  end

  test 'auth_with takes the action to ask about' do
    conf = config { |c| c.auth_with :cancan, action: :backend }

    assert_equal :backend, conf.auth_action
    assert_equal :allowed, gate(Grants.new([:backend, :all]), conf).verdict
    assert_equal :forbidden, gate(Grants.new([:crud_admin, :all]), conf).verdict
  end

  test 'auth_with rejects an unknown mode, and a mode with a block' do
    assert_raises(ArgumentError) { config { |c| c.auth_with :devise } }
    assert_raises(ArgumentError) { config { |c| c.auth_with(:cancan) { nil } } }
  end

  # ── the ability the admin asks ───────────────────────────────────────────
  test 'the admin action answers for every finer one' do
    ability = wrapped(Grants.new([:crud_admin, :all]))

    assert ability.can?(:index, Book)
    assert ability.can?(:destroy, Book.new)
    assert_not ability.cannot?(:update, Book)
  end

  test 'a narrower rule still grants on its own' do
    ability = wrapped(Grants.new([:index, Book]))

    assert ability.can?(:index, Book)
    assert ability.cannot?(:destroy, Book)
  end

  test 'a grant on one model does not reach another' do
    ability = wrapped(Grants.new([:crud_admin, Book]))

    assert ability.can?(:destroy, Book)
    assert ability.cannot?(:destroy, Author)
  end

  test 'the wrapper passes everything else through, so a scope can still be built' do
    assert_equal 'delegated', wrapped(Grants.new).sees_records
  end
end
