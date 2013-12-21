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

We're using `foreman` so that things match Heroku as closely as possible, thanks to it using the Procfile and a .env file with key/value pairs. You can start the app up via foreman using the following:

`bundle exec foreman start`

Before pushing to production (especially on Heroku) you'll either want to figure out how automatic asset compilation works or precompile your assets manually with this command:

`RACK_ENV=production rake assets:precompile`

If you're not feeling adventurous, try the prototype here: http://puthtml.com
