class ApplicationController < ActionController::Base
  helper_method :can?, :admin?

  # A deliberately tiny can?-shaped "ability" — the gem integrates with
  # anything that quacks like this (CanCanCan in real apps).
  def can?(action, subject)
    return true if admin?

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
    redirect_back fallback_location: root_path
  end
end
