class ApplicationController < ActionController::Base
  helper_method :can?, :admin?

  # A deliberately tiny can?-shaped "ability" — the gem integrates with
  # anything that quacks like this (CanCanCan in real apps).
  def can?(action, subject)
    return true if admin?
    # Only admins may even open the property definitions — the admin UI drops a
    # model you cannot :index from its sidebar and dashboard.
    return false if action.to_sym == :index && subject == PropertyDefinition

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
