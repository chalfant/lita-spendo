require 'aws-sdk'
require 'json'

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

      LAST_RECORD_KEY = 'last_record'

      config :aws_account_id, type: String
      config :dynamodb_table, type: String, default: 'BillingHistory'
      config :base_image_url, type: String
      config :room,           type: String
      config :time_between_polls, type: Integer, default: 60*60

      route(/^spendo$/, :show, command: true, help: {
        "spendo" => "show current billing level"
      })

      on(:connected) do |payload|
        if config.room
          # join the alert room
          robot.join config.room
        end

        # set up a timer to poll DynamoDB
        every(config.time_between_polls) do |timer|
          check_for_alerts
        end
      end

      def show(response)
        message, url = create_message

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

      def create_message
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

        return [message, url]
      end

      # write current data to redis
      # BigDecimals get saved as strings which fail to
      # deserialize as integers (but do deserialize as floats)
      def save_billing_data(data)
        redis.set LAST_RECORD_KEY, data.to_json
      end

      # read previous data from redis
      def load_billing_data
        data = redis.get LAST_RECORD_KEY
        return nil if data.nil?

        JSON.parse(data)
      end

      def alert_level_changed?(previous, current)
        previous['AlertLevel'].to_f != current['AlertLevel'].to_f
      end

      def check_for_alerts
        log.debug "checking for alerts"
        current_data = billing_history.latest
        last_data    = load_billing_data

        if last_data && alert_level_changed?(last_data, current_data)
          message, url = create_message
          target = Source.new(room: config.room)
          robot.send_messages(target, message, url)
        else
          log.debug "alert level unchanged"
        end

        save_billing_data current_data
      end
    end

    Lita.register_handler(Spendo)
  end
end
