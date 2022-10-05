# frozen_string_literal: true

require_relative "../../omnievent/meetup/version"
require "omnievent/strategies/api"

module OmniEvent
  module Strategies
    # Strategy for listing events from Meetup
    class Meetup < OmniEvent::Strategies::API
      class Error < StandardError; end

      include OmniEvent::Strategy

      option :name, "meetup"
      option :group_urlname, ""

      PAGE_LIMIT = 20
      GROUP_EVENTS_QUERY = %{
        query($urlname: String!, $itemsNum: Int!, $cursor: String) {
          groupByUrlname(urlname: $urlname) {
            unifiedEvents(input: {first: $itemsNum, after: $cursor}) {
              count
              pageInfo {
                endCursor
              }
              edges {
                node {
                  id
                  title
                  description
                  dateTime
                  endTime
                  eventUrl
                  createdAt
                  status
                  topics {
                    count
                    pageInfo {
                      endCursor
                    }
                    edges {
                      node {
                        name
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }

      def raw_events
        response = perform_request(path: "gql", method: "POST", body: request_body)
        return [] unless response && response["data"] && response["data"]["groupByUrlname"]

        count = response["data"]["groupByUrlname"]["unifiedEvents"]["count"].to_i
        retrieved = 0
        events = []

        while retrieved < count
          events += response["data"]["groupByUrlname"]["unifiedEvents"]["edges"].map do |edge|
            event = edge["node"]
            event["topics"] = edge["node"]["topics"]["edges"].map { |e| e["node"]["name"] }
            event
          end
          retrieved = events.size
          cursor = response["data"]["groupByUrlname"]["unifiedEvents"]["pageInfo"]["endCursor"]
          response = perform_request(path: "gql", method: "POST", body: request_body(cursor: cursor))
        end

        events
      end

      def event_hash(raw_event)
        data = {
          start_time: format_time(raw_event["dateTime"]),
          end_time: format_time(raw_event["endTime"]),
          name: raw_event["title"],
          description: raw_event["description"],
          url: raw_event["eventUrl"]
        }

        metadata = {
          uid: raw_event["id"],
          status: convert_status(raw_event["status"]),
          created_at: format_time(raw_event["createdAt"]),
          taxonomies: raw_event["topics"]
        }

        OmniEvent::EventHash.new(
          provider: name,
          data: data,
          metadata: metadata
        )
      end

      def request_url
        "https://api.meetup.com"
      end

      def request_headers
        {
          "Authorization" => "Bearer #{options.token}",
          "Content-Type" => "application/json"
        }
      end

      def request_body(opts = {})
        variables = {
          urlname: options.group_urlname,
          itemsNum: PAGE_LIMIT
        }.merge(opts)

        {
          query: GROUP_EVENTS_QUERY,
          variables: variables
        }.to_json
      end

      def convert_status(raw_status)
        case raw_status.downcase
        when "draft"
          "draft"
        when "published", "active", "past", "autosched"
          "published"
        when "cancelled", "cancelled_perm"
          "cancelled"
        else
          "published"
        end
      end
    end
  end
end
