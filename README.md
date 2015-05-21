# lita-spendo

Spendo will watch the DynamoDB table created by (https://github.com/chalfant/lambda-billing) and send room messages when the Alert Level changes, along with an image based on the Alert Level.

## Installation

Add lita-spendo to your Lita instance's Gemfile:

``` ruby
gem "lita-spendo"
```

## Configuration

Spendo relies on the aws-sdk gem so it requires an AWS account. The account requires read access to the DynamoDB table holding your billing history.

### Required attributes

* `base_image_url` (String) - Base url for alert images. Images should be named 'n.jpg' where n is the alert level. We suggest increasingly-scary clown photos.
* `accounts` (Array) - Array of hashes containing account information. Each hash should look like this:

``` ruby
{
  'nickname'              => 'foo',
  'aws_account_id'        => ENV['AWS_ACCOUNT_ID'],
  'aws_access_key_id'     => ENV['AWS_ACCESS_KEY_ID'],
  'aws_secret_access_key' => ENV['AWS_SECRET_ACCESS_KEY'],
  'aws_region'            => 'us-east-1',
  'room'                  => 'shell', # or room JID or whatever
  'dynamodb_table'        => 'BillingHistory'
}
```

### Optional attributes

* `time_between_polls` (Integer) - Spendo will wait this many seconds between polls to the BillingHistory table. Defaults to one hour (3600 seconds).

## Usage

`lita spendo foo` - display current billing alert level for account foo.
