require "spec_helper"

describe Lita::Handlers::BillingHistory do
  it { is_expected.to respond_to :latest }
end