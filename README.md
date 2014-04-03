# Railscluster Deployment

This Gem enables quick deployment to railscluster.nl hosting. We make some assumptions about your setup, these can be overwritten in your deploy.rb. See section settings below for details.

## Usage
1. Add the gem to you Gemfile: 

```ruby
gem 'railscluster'
```

2. Setup Capistrano with `bundle exec capify .`
3. Replace the content of your deploy.rb with the following:

```ruby
# Keep after settings
require 'railscluster/capistrano'
```
4. Customize any settings. See sections below.

5. Setup the environment: `cap deploy:setup`

6. Deploy: cap deploy

That should be all!

## Settings
To deploy to RailsCluster only three settings need to be provided, these can be set in your deploy.rb as follows or be provided via prompt during deployment. Settings these settings need to be kept *before* the require.

```ruby
set :account,     'account_name'
set :repository,  'https://github.com/your/application.git'
set :branch,      'master'
```

Further settings have defaults that should be fine in most cases, however you can override/set them as needed. The most important settings you can use:

```ruby
:hard_restart # Restart by stop-start, defaults to true. Set to false to use a one-by-one restart.

:app_shared_children # Add folder and files to be symlinked into shared beyond the following defauts: tmp/pids, config/database.yml, public/uploads and private/uploads

:dbtype # Postgresql or Mysql, defaults to postgresql.

:scm    # Version control used, defaults to git.

:local_precompile # Precompile locally, defaults to false.

:airbrake_enabled # Load airbreak capistrano integration, defaults to false.

```

