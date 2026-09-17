# frozen_string_literal: true

module CrudComponents
  module Presenters
    # The `filters/_values` control: a multiple select of the values occurring
    # in the list, and the data the crud-value-filter controller builds its
    # popover from.
    class ValueFilter < Base
      # Defaults of `crud_components.filter.values.*`. The counts are filled in
      # by the controller: they reach it as `{count}` / `{total}`.
      TEXTS = {
        all: 'All', some: '%<count>s of %<total>s', blank: '(empty)', search: 'Search values',
        select_all: 'Select all (%<count>s)', select_none: 'Select none', shown: '%<count>s shown',
        shown_of: '%<count>s of %<total>s shown', cancel: 'Cancel'
      }.freeze
      PLACEHOLDERS = { count: '{count}', total: '{total}' }.freeze

      # The controller's class names, by the part they style.
      CSS_KEYS = {
        button: :value_filter_button, menu: :value_filter_menu, search: :value_filter_search,
        links: :value_filter_links, link: :value_filter_link, count: :value_filter_count,
        list: :value_filter_list, option: :value_filter_option, checkbox: :value_filter_checkbox,
        label: :value_filter_label, actions: :value_filter_actions, cancel: :button, apply: :button_primary
      }.freeze

      def initialize(view:, field:, query:, form_id:, autosubmit:)
        super(view: view)
        @field = field
        @query = query
        @form_id = form_id
        @autosubmit = autosubmit
      end

      def selected = @query.values(@field.name.to_s)

      # [label, value] pairs: "(empty)" first when the column is nullable, then
      # up to `value_filter_inline_limit` values plus the selected ones.
      def options
        @options ||= (blank_option + values.first)
      end

      def data
        { controller: 'crud-value-filter',
          crud_value_filter_url_value: url,
          crud_value_filter_field_value: @field.name,
          crud_value_filter_param_value: @query.param_name(@field.name.to_s),
          crud_value_filter_choices_param_value: choices_param,
          crud_value_filter_term_param_value: term_param,
          crud_value_filter_source_value: @form_id || Filter::CHOICES_SOURCE,
          crud_value_filter_label_value: @field.human_name,
          crud_value_filter_null_value: CrudComponents::NULL_FILTER_VALUE,
          crud_value_filter_total_value: values.last + blank_option.size,
          crud_value_filter_remote_value: values.last > config.value_filter_inline_limit,
          crud_value_filter_autosubmit_value: @autosubmit,
          crud_value_filter_texts_value: texts.to_json,
          crud_value_filter_css_value: classes.to_json }
      end

      private

      def values
        @values ||= @field.filter_values(@query, selected: selected)
      end

      def blank_option
        @field.filter_includes_null? ? [[texts[:blank], CrudComponents::NULL_FILTER_VALUE]] : []
      end

      def texts
        @texts ||= TEXTS.to_h do |key, default|
          [key, view.t("crud_components.filter.values.#{key}", default: default, **PLACEHOLDERS)]
        end.merge(apply: view.t('crud_components.filter.apply', default: 'Apply'))
      end

      def classes
        CSS_KEYS.transform_values { |key| css[key] }
      end

      def choices_param = @query.param_name(Query::CHOICES_PARAM)
      def term_param = @query.param_name(Query::TERM_PARAM)

      def url
        kept = view.request.query_parameters.except(choices_param, term_param)
        kept.any? ? "#{view.request.path}?#{kept.to_query}" : view.request.path
      end
    end
  end
end
