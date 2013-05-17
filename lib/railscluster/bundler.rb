require 'bundler/capistrano'

Capistrano::Configuration.instance(:must_exist).load do

  set :bundle_cmd, 'bundle'
  set :rake, lambda { "#{bundle_cmd} exec rake" }

  namespace :bundle do
    # Only execute clean if you know that a rollback will not be necessary.
    desc "Clean the current Bundler environment"
    task :clean do
      run "cd #{latest_release}; RAILS_ENV=#{rails_env} #{bundle_cmd} clean"
    end
  end
end
