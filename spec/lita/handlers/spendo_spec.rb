require "spec_helper"

describe Lita::Handlers::Spendo, lita_handler: true do

  it { is_expected.to route_command("spendo").to(:show) }

  describe '#show' do
    before(:each) do
      subject.billing_history = double(latest: "message")
    end

    it 'shows the message' do
      send_command("spendo")
      expect(replies.first).to eq("message")
    end

  end
end
