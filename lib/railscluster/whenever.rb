Capistrano::Configuration.instance(:must_exist).load do
  require "whenever/capistrano/recipes"

  # Write the new cron jobs near the end.
  before "deploy:finalize_update" do
    whenever.update_crontab if changed? 'config/schedule.rb'
  end

  # If anything goes wrong, undo.
  after "deploy:rollback", "whenever:update_crontab"

  set :whenever_command,      "#{bundle_cmd} exec whenever"
  set :whenever_environment,  defer { rails_env }
end