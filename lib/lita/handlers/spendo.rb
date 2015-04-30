require 'aws-sdk'

module Lita
  module Handlers
    class BillingHistory
      attr_accessor :account, :table_name

      def initialize(params={})
        @account    = params[:aws_account_id]
        @table_name = params[:dynamodb_table]
      end

      def latest
        ddb = Aws::DynamoDB::Resource.new()
        table = ddb.table(table_name)
        opts = {
          key_condition_expression: 'Account = :account',
          expression_attribute_values: {":account" => account},
          scan_index_forward: false,
          limit: 1
        }
        results = table.query opts
        results.items.first
      end
    end

    class Spendo < Handler

      config :aws_account_id, type: String
      config :dynamodb_table, type: String, default: 'BillingHistory'
      config :base_image_url, type: String

      route(/^spendo$/, :show, command: true, help: {
        "spendo" => "show current billing level"
      })

      def show(response)
        data = billing_history.latest

        account          = data['Account']
        current_fees     = data['TotalFees'].to_f
        expected_fees    = data['ExpectedFees'].to_f
        alert_level      = data['AlertLevel'].to_i
        categorized_fees = data['FeesByCategory']

        message = "The current fees alert threshold has been reached.\n"
        message << "\nAccount: #{account}"
        message << "\nCurrent fees: $#{current_fees}"
        message << "\nExpected monthly fees: $#{expected_fees}" # TODO
        message << "\nFee level is at #{alert_level * 25}% of expected"
        message << "\n\n Fee Category Breakdown\n\n"

        categorized_fees.each_pair do |k,v|
          value = v.to_f
          next if value == 0.0
          message << "#{k.ljust(20)}: $#{sprintf('%8.2f', value.round(2))}\n"
        end

        url = config.base_image_url + "/#{alert_level}.jpg"

        response.reply message
        response.reply url
      end

      attr_writer :billing_history

      def billing_history
        if @billing_history.nil?
          params = {
            aws_account_id: config.aws_account_id,
            dynamodb_table: config.dynamodb_table
          }
          @billing_history = BillingHistory.new(params)
        end
        @billing_history
      end
    end

    Lita.register_handler(Spendo)
  end
end
