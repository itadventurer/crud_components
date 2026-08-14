module CrudComponents
  module Admin
    # Every registered model's CRUD, in one controller. The model comes from the
    # route's `crud_model` default, so a request can only ever name a model the
    # registry drew a route for.
    class ResourcesController < ApplicationController
      before_action :set_entry
      before_action :set_record, only: %i[show edit update destroy delete]
      before_action :build_record, only: %i[new create]
      before_action :authorize_action!

      def index
        @owner = owner
        @query = CrudComponents::Query.new(@model, params, fieldset: @entry.fieldset, ability: admin_ability)
        @records = paginate(@query.apply(base_scope))
      end

      def show; end

      def new; end

      def edit; end

      def create
        @record.assign_attributes(record_params(:create))
        if @record.save
          redirect_to after_save_path(@record), notice: saved_notice(:created)
        else
          render :new, status: :unprocessable_entity
        end
      end

      def update
        if @record.update(record_params(:update))
          redirect_to after_save_path(@record), notice: saved_notice(:updated)
        else
          render :edit, status: :unprocessable_entity
        end
      end

      # The confirmation step: what goes with it, before anything goes.
      def delete
        @dependents = Dependents.new(@record)
      end

      def destroy
        @record.destroy!
        redirect_to index_path, notice: saved_notice(:destroyed)
      rescue ActiveRecord::InvalidForeignKey, ActiveRecord::DeleteRestrictionError => e
        redirect_to after_save_path(@record), alert: e.message
      end

      # The ticked rows, each checked against the ability on its own.
      def destroy_selected
        records = CrudComponents.selected(base_scope, params).select { |record| allowed?(:destroy, record) }
        records.each(&:destroy!)
        redirect_to index_path,
                    notice: t('crud_components.admin.notices.destroyed_selected', count: records.size,
                              default: '%{count} deleted.')
      rescue ActiveRecord::InvalidForeignKey, ActiveRecord::DeleteRestrictionError => e
        redirect_to index_path, alert: e.message
      end

      private

      def set_entry
        @entry = admin_registry[params[:crud_model]]
        raise ActiveRecord::RecordNotFound, "no admin entry for #{params[:crud_model].inspect}" unless @entry

        @model = @entry.model
      end

      # A nested index (`/admin/publishers/tor-books/books`) renders the owner's
      # association; everything else renders the model's own scope.
      def base_scope
        return admin_scope(@entry) unless owner

        owner.public_send(params[:crud_association])
      end

      def owner_entry
        return @owner_entry if defined?(@owner_entry)

        @owner_entry = params[:crud_owner] && admin_registry[params[:crud_owner]]
      end

      def owner
        return @owner if defined?(@owner)

        entry = owner_entry
        return @owner = nil unless entry

        record = find_record(admin_scope(entry), params["#{entry.singular_route_key}_id"], entry)
        raise ForbiddenError, "not allowed to show this #{entry.model.model_name.human}" unless allowed?(:show, record)

        @owner = record
      end

      def set_record
        @record = find_record(base_scope, params[:id])
      end

      def build_record
        @record = @model.new
      end

      # A URL segment matches `identify_by` first, then the primary key — so a
      # model whose `to_param` is a slug and one that uses ids both resolve.
      def find_record(scope, param, entry = @entry)
        key = entry.param_key
        found = key.to_s == 'id' ? nil : scope.find_by(key => param)
        found ||= scope.find_by(entry.model.primary_key => param)
        raise ActiveRecord::RecordNotFound, "#{entry.model}: no record for #{param.inspect}" unless found

        found
      end

      # The engine's own actions, mapped to the RESTful one an ability knows.
      ACTION_PERMISSIONS = { destroy_selected: :destroy, delete: :destroy }.freeze

      # Otherwise the action the request performs is the one authorized.
      # CanCanCan aliases :new to :create and :edit to :update, so a rule
      # written either way still applies; an ability that tells them apart is
      # asked the narrower question of the two.
      def authorize_action!
        subject = @record || @model
        permission = ACTION_PERMISSIONS.fetch(action_name.to_sym, action_name.to_sym)

        authorize!(permission, subject) if respond_to?(:authorize!, true)

        return if allowed?(permission, subject)

        raise ForbiddenError, "not allowed to #{permission} this #{@model.model_name.human}"
      end

      def allowed?(permission, subject)
        ability = admin_ability
        ability.nil? || ability.can?(permission, subject)
      end

      def record_params(action)
        permitted = CrudComponents.permitted_attributes(@model, action: action, ability: admin_ability)
        return {} if permitted.empty?

        params.require(@model.model_name.param_key).permit(*permitted)
      end

      def paginate(scope)
        return scope unless scope.respond_to?(:page)

        scope = scope.page(params[:page])
        scope.respond_to?(:per) ? scope.per(admin_config.per_page) : scope
      end

      # One controller serves every model, so `url_for(action:)` cannot tell the
      # resources apart — go through the entry's own named helpers.
      def index_path = public_send("#{@entry.route_key}_path")

      def after_save_path(record)
        return public_send("#{@entry.singular_route_key}_path", record) if @entry.allows?(:show)
        return public_send("edit_#{@entry.singular_route_key}_path", record) if @entry.allows?(:edit)

        index_path
      end

      def saved_notice(key)
        t("crud_components.admin.notices.#{key}", model: @model.model_name.human,
                                                  default: "%{model} #{key}.")
      end
    end
  end
end
