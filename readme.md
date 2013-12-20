# Put HTML

Upload an HTML file <1mb to an S3 bucket, then serve it.

Make sure that AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, and AWS_BUCKET_NAME are set in your env. Then go crazy.

We're using `foreman` so that things match Heroku as closely as possible, thanks to it using the Procfile and a .env file with key/value pairs. You can start the app up via foreman using the following:

`bundle exec foreman start`


If you're not feeling adventurous, try the prototype here: http://puthtml.com
