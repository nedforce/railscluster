require 'bundler/deployment'

Capistrano::Configuration.instance(:must_exist).load do
  before "deploy:finalize_update" do
    bundle.install if changed? 'Gemfile.lock'
  end
  Bundler::Deployment.define_task(self, :task, :except => { :no_release => true })
  set :bundle_cmd, 'bundle'
  set :rake, lambda { "bundle exec rake" }

  namespace :bundle do
    # Only execute clean if you know that a rollback will not be necessary.
    desc "Clean the current Bundler environment"
    task :clean do
      run "cd #{latest_release}; RAILS_ENV=#{rails_env} #{bundle_cmd} clean"
    end
  end
end
