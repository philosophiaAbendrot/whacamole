whacamole
=========

[![Build Status](https://travis-ci.org/arches/whacamole.png)](https://travis-ci.org/arches/whacamole)

Whacamole keeps track of your Heroku dynos' memory usage and restarts large dynos before they start
swapping to disk (aka get super slow).

Here’s what Heroku says about dyno memory usage:

> Dynos are available in 1X or 2X sizes and are allocated 512MB or 1024MB respectively.
>
> Dynos whose processes exceed their memory quota are identified by an R14 error in the logs. This doesn’t terminate the process, but it does warn of deteriorating application conditions: memory used above quota will swap out to disk, which substantially degrades dyno performance.
>
> If the memory size keeps growing until it reaches three times its quota, the dyno manager will restart your dyno with an R15 error.
>
> - From https://devcenter.heroku.com/articles/dynos on 8/8/13

Heroku dynos swap to disk for up to 3GB. That is not good and that is the problem whacamole addresses.

# Usage

Enable log-runtime-metrics on your heroku app:

```bash
$ heroku labs:enable log-runtime-metrics --app YOUR_APP_NAME
```

Add whacamole to your gemfile:

```ruby
gem 'whacamole'
```

Create a config file with your app info. Personally I put it in my Rails app at config/whacamole.rb. The
most important parts are your app name and your Heroku api token (which can be found by running `heroku auth:token`
on the command line).

```ruby
Whacamole.configure("HEROKU APP NAME") do |config|
  config.api_token = ENV['HEROKU_API_TOKEN'] # you could also paste your token in here as a string
end

# you can monitor multiple apps at once, just add more configure blocks
Whacamole.configure("ANOTHER HEROKU APP") do |config|
  config.api_token = ENV['HEROKU_API_TOKEN'] # you could also paste your token in here as a string
end
```

Add whacamole to your Procfile, specifying the config file you created:

```ruby
whacamole: bundle exec whacamole -c ./config/whacamole.rb
```

Start foreman, and you're done!

```bash
# locally
$ foreman start whacamole

# on heroku
$ heroku ps:scale whacamole=1 --app YOUR_APP_NAME
```
