Capistrano::Configuration.instance(:must_exist).load do
  require 'whenever/capistrano'

  set :whenever_command,      "#{bundle_cmd} exec whenever"
  set :whenever_environment,  defer { rails_env }
end