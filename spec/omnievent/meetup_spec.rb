# frozen_string_literal: true

RSpec.describe OmniEvent::Strategies::Meetup do
  let(:group_events_json) { File.read(File.join(File.expand_path("..", __dir__), "fixtures", "group_events.json")) }
  let(:group_events_hash) { JSON.parse(group_events_json) }
  let(:url) { "https://api.meetup.com/gql" }
  let(:urlname) { "aix-en-provence" }
  let(:first_page_body) do
    {
      query: OmniEvent::Strategies::Meetup::GROUP_EVENTS_QUERY,
      variables: {
        urlname: urlname,
        itemsNum: OmniEvent::Strategies::Meetup::PAGE_LIMIT
      }
    }
  end
  let(:second_page_body) do
    {
      query: OmniEvent::Strategies::Meetup::GROUP_EVENTS_QUERY,
      variables: {
        urlname: urlname,
        itemsNum: OmniEvent::Strategies::Meetup::PAGE_LIMIT,
        cursor: group_events_hash["data"]["groupByUrlname"]["unifiedEvents"]["pageInfo"]["endCursor"]
      }
    }
  end

  before do
    OmniEvent::Builder.new do
      provider :meetup, { token: "12345" }
    end
  end

  describe "list_events" do
    before do
      stub_request(:post, url)
        .with(body: first_page_body.to_json, headers: { "Authorization" => "Bearer 12345" })
        .to_return(body: group_events_json, headers: { "Content-Type" => "application/json" })
      stub_request(:post, url)
        .with(body: second_page_body.to_json, headers: { "Authorization" => "Bearer 12345" })
        .to_return(body: group_events_json, headers: { "Content-Type" => "application/json" })
    end

    it "returns an event list" do
      events = OmniEvent.list_events(:meetup, group_urlname: urlname)

      expect(events.size).to eq(4)
      expect(events).to all(be_kind_of(OmniEvent::EventHash))
    end

    it "returns valid events" do
      events = OmniEvent.list_events(:meetup, group_urlname: urlname)

      expect(events).to all(be_valid)
    end

    it "returns events with metadata" do
      events = OmniEvent.list_events(:meetup, group_urlname: urlname)
      uid = group_events_hash["data"]["groupByUrlname"]["unifiedEvents"]["edges"][0]["node"]["id"]

      expect(events.first.metadata.uid).to eq(uid)
    end
  end
end
