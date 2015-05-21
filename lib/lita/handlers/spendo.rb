require 'aws-sdk'
require 'json'

module Lita
  module Handlers
    class BillingHistory
      attr_accessor :account, :table_name

      def initialize(params={})
        @aws_access_key_id     = params['aws_access_key_id']
        @aws_secret_access_key = params['aws_secret_access_key']
        @aws_region            = params['aws_region']
        @account               = params['aws_account_id']
        @table_name            = params['dynamodb_table']
      end

      def latest
        credentials = Aws::Credentials.new(@aws_access_key_id, @aws_secret_access_key)
        ddb = Aws::DynamoDB::Resource.new(region: @aws_region, credentials: credentials)
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

      config :base_image_url,     type: String
      config :time_between_polls, type: Integer, default: 60*60

      # array of hashes, each hash describing a different
      # account to monitor.
      # config.accounts = [
      #   {
      #     'aws_account_id'        => 'foo',
      #     'dynamodb_table'        => 'BillingHistory',
      #     'room'                  => 'shell',
      #     'aws_access_key_id'     => 'foo',
      #     'aws_secret_access_key' => 'foo',
      #     'nickname'              => 'foo'
      #   }
      # ]
      config :accounts,       type: Array

      route(/^spendo\s+(\S+)$/, :show, command: true, help: {
        "spendo account_name" => "show current billing level for account_name"
      })

      on(:connected) do
        config.accounts.each do |account|
          setup account
        end
      end

      def setup(account)
        if account['room']
          robot.join account['room']
        end

        every(config.time_between_polls) do |timer|
          check_for_alerts account
        end
      end

      def show(response)
        account_nick = response.match_data[1]
        account      = lookup_account account_nick
        message, url = create_message account

        response.reply message
        response.reply url
      end

      def create_client(account)
        params = account.dup

        BillingHistory.new(params)
      end

      def lookup_account(nickname)
        config.accounts.select {|a| a['nickname'] == nickname }.first
      end

      def create_message(account)
        client = create_client account
        data   = client.latest

        account_id       = data['Account']
        current_fees     = data['TotalFees'].to_f
        expected_fees    = data['ExpectedFees'].to_f
        alert_level      = data['AlertLevel'].to_i
        categorized_fees = data['FeesByCategory']

        message = "/code The current fees alert threshold has been reached.\n"
        message << "\nAccount: #{account['nickname']} #{account_id}"
        message << "\nCurrent fees: $#{current_fees}"
        message << "\nExpected monthly fees: $#{expected_fees}" # TODO
        message << "\nFee level is at #{alert_level * 25}% of expected"
        message << "\n\n Fee Category Breakdown\n\n"

        categorized_fees.keys.sort.each do |k|
          category = k.strip.ljust(20)
          value = categorized_fees[k].to_f
          next if value == 0.0
          amount = sprintf('%8.2f', value.round(2))
          message << "#{category}: $#{amount}\n"
        end

        url = config.base_image_url + "/#{alert_level}.jpg"

        return [message, url]
      end

      def account_key(account)
        account[:aws_account_id] + '_' + LAST_RECORD_KEY
      end

      # write current data to redis
      # BigDecimals get saved as strings which fail to
      # deserialize as integers (but do deserialize as floats)
      def save_billing_data(account, data)
        key = account_key account
        redis.set key, data.to_json
      end

      # read previous data from redis
      def load_billing_data(account)
        key = account_key account
        data = redis.get key
        return nil if data.nil?

        JSON.parse(data)
      end

      def alert_level_changed?(previous, current)
        previous['AlertLevel'].to_f != current['AlertLevel'].to_f
      end

      def check_for_alerts(account)
        log.debug "checking for alerts"
        client       = create_client account
        current_data = client.latest
        last_data    = load_billing_data(account)

        if last_data && alert_level_changed?(last_data, current_data)
          message, url = create_message account
          target = Source.new(room: account['room'])
          robot.send_messages(target, message, url)
        else
          log.debug "alert level unchanged"
        end

        save_billing_data account, current_data
      end
    end

    Lita.register_handler(Spendo)
  end
end
