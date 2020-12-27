# frozen_string_literal: true

require_relative '../_lib/collections'
require_relative '../_lib/timestamp'
require 'jekyll'

module Jekyll
  module EventFilters
    include ::DataCollection

    EVENT_CLASS_NAME = 'data-event'

    def event_tag(key, display_text = nil)
      fallback = "<span class='#{EVENT_CLASS_NAME} #{UNKNOWN_REFERENCE_CLASS}'>#{display_text || key}</span>"
      parts = event_data(key)
      return fallback if parts.empty?

      url = relative_url("/#{COLLECTION_MAP_PLURAL['events']}/#{sanitize_url_key(key)}.html")
      return "<a href=#{url} class='#{EVENT_CLASS_NAME}'>#{display_text}</a>" if !display_text.nil?

      data = data_collection_entry('events', key)

      language = data['language']
      language_tag = "lang=#{language} translate" if !language.nil?

      <<~EOM
      <span class="#{EVENT_CLASS_NAME}" #{language_tag}>
        <a href=#{url} itemprop=url>#{data['name']}</a>
      </span>
      EOM
    end

    def relevant_events(raw_timestamp)
      return [] if raw_timestamp.nil?
      timestamp = Timestamp.new(raw_timestamp)

      data = @context.registers[:site].data

      all_events = {
        'event' => data['events'],
      }.reduce([]) { |memo, (type, records)| memo.concat(structure_event_records(records, type)) }
       .select { |event| event['date'] && event['timestamp'].intersect?(timestamp) }
       .sort_by { |event| [event['timestamp'].startsAt.to_f, event['timestamp'].endsAt.to_f] }
    end

    private

    def structure_event_records(records, type)
      records.reduce([]) do |memo, (key, value)|
        next(memo) if value['date'].nil?
        next(memo.push(value)) if value.key?('timestamp')

        timestamp = Timestamp.new(value['date'])
        memo.push(value.merge({
          'endDate' => timestamp.endsAt&.to_s,
          'key' => key,
          'rawTimestamp' => timestamp.raw_timestamp_string,
          'startDate' => timestamp.startsAt&.to_s,
          'timestamp' => timestamp,
          'type' => type,
        }))
      end
    end

    def event_data(key)
      parts = data_collection_entry('events', key)&.clone
      if parts.nil?
        Jekyll.logger.warn('Jekyll::EventFilters:',
                           "Unable to find data for '#{key}'.")
        return []
      end

      return parts.map { |part, value| yield(part, value) } if block_given?
      parts
    end
  end
end
Liquid::Template.register_filter(Jekyll::EventFilters)