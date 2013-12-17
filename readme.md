# Put HTML

Upload an HTML file <1mb to an S3 bucket, then serve it.

Right now you need 10+ htmls in your amazon s3 bucket to start. Also setup a
Twitter app for Sign-In at dev.twitter.com

Set up in your env:

- AWS_ACCESS_KEY_ID
- AWS_SECRET_ACCESS_KEY
- AWS_BUCKET_NAME
- TWITTER_CONSUMER_KEY
- TWITTER_CONSUMER_SECRET

run: rackup config.rb

Try it here: http://puthtml.herokuapp.com
