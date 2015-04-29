require 'aws-sdk'

module Lita
  module Handlers
    class BillingHistory
      # we need a dynamodb query like:
      # hash_key: $account_id
      # sort descending
      # limit 1
      def latest
        account = '618024093898'
        ddb = Aws::DynamoDB::Resource.new()
        table = ddb.table('BillingHistory')
        opts = {
          key_condition_expression: 'Account = :account',
          expression_attribute_values: {":account" => account},
          scan_index_forward: false,
          limit: 1
        }
        results = table.query opts
        results.inspect
      end
    end

    class Spendo < Handler

      config :aws_account_id
      config :dynamodb_table

      route(/^spendo$/, :show, command: true, help: {
        "spendo" => "show current billing level"
      })

      def show(response)
        message = billing_history.latest
        response.reply message
      end

      attr_writer :billing_history

      def billing_history
        if @billing_history.nil?
          @billing_history = BillingHistory.new
        end
        @billing_history
      end
    end

    Lita.register_handler(Spendo)
  end
end
