require "spec_helper"

describe Lita::Handlers::Spendo, lita_handler: true do

  it { is_expected.to route_command("spendo").to(:show) }

  describe '#show' do
    before(:each) do
      robot.config.handlers.spendo.base_image_url = 'http://foo.com'

      results = {
        'Account'        => "foo",
        'TotalFees'      => 100.0,
        'ExpectedFees'   => 100.0,
        'AlertLevel'     => 3,
        'FeesByCategory' => { 'Foo' => 33.0 }
      }
      subject.billing_history = double(latest: results)

      send_command("spendo")
    end

    it 'shows the message' do
      expect(replies.first).not_to be_nil
    end

    it 'shows the account' do
      expect(replies.first).to include("<br>Account: foo")
    end

    it 'shows the url' do
      expect(replies.first).to include("http://foo.com/3.jpg")
    end

  end
end
