class ApplicationController < ActionController::Base
  helper_method :can?, :admin?

  # A deliberately tiny can?-shaped "ability" — the gem integrates with
  # anything that quacks like this (CanCanCan in real apps).
  def can?(action, _subject)
    return true if admin?

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
