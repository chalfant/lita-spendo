# lita-spendo

Spendo will watch the DynamoDB table created by (https://github.com/chalfant/lambda-billing) and send room messages when the Alert Level changes, along with an image based on the Alert Level.

## Installation

Add lita-spendo to your Lita instance's Gemfile:

``` ruby
gem "lita-spendo"
```

## Configuration

Spendo relies on the aws-sdk gem. You must either specify the AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY environment variables or, if you are running on EC2, rely on IAM instance roles. The account requires read access to the DynamoDB table holding your billing history.

### Required attributes

* `aws_account_id` (String) - Account number for your AWS account
* `base_image_url` (String) - Base url for alert images. Images should be named 'n.jpg' where n is the alert level. We suggest increasingly-scary clown photos.

### Optional attributes

* `dynamodb_table` (String) - Name of the DynamoDB table containing billing history (defaults to 'BillingHistory')

## Usage

TODO: Describe the plugin's features and how to use them.
