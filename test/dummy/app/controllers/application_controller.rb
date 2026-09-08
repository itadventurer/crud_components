# frozen_string_literal: true

class ApplicationController < ActionController::Base
  helper_method :can?, :admin?

  # A deliberately tiny can?-shaped "ability" — the gem integrates with
  # anything that quacks like this (CanCanCan in real apps).
  def can?(action, subject)
    # Reviews are never deleted one by one, not even by an admin — deleting the
    # book they belong to takes them along all the same, which is what the
    # confirmation page points out.
    return false if action.to_sym == :destroy && (subject.is_a?(Review) || subject == Review)

    return true if admin?
    # The admin's gate, what the default `auth_with :cancan` asks.
    return false if action.to_sym == :access && subject == :crud_admin

    # Only admins may even open the property definitions — the admin UI drops a
    # model you cannot :index from its sidebar and dashboard.
    return false if action.to_sym == :index && subject == PropertyDefinition

    # :new and :create are separate questions for an ability that is not
    # CanCanCan (which aliases one to the other): everyone may open the comment
    # form, only admins may save it.
    model = subject.is_a?(Class) ? subject : subject.class
    return false if action.to_sym == :create && model == Comment

    !%i[manage destroy].include?(action.to_sym)
  end

  def admin?
    session[:admin].present?
  end

  def toggle_admin
    session[:admin] = session[:admin] ? nil : true
    redirect_back_or_to(root_path)
  end
end
