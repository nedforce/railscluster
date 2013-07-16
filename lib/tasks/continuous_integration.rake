task :ci => :continuous_integration
task :continuous_integration => "continuous_integration:default"

namespace :continuous_integration do
  task :default do 
    begin
      ActiveRecord::Schema.verbose = false
      Rake::Task['continuous_integration:setup'].invoke
      Rake::Task['continuous_integration:test'].invoke
    ensure
      Rake::Task['continuous_integration:cleanup'].invoke
    end
  end 

  task :test do
    begin
      require 'simplecov'
      SimpleCov.start 'rails' do
        add_filter 'vendor'
        # Dir['app/*'].each do |group|
        #   add_group group, "app/#{group}"
        # end
        minimum_coverage = 0
        maximum_coverage_drop = 100
      end
    rescue LoadError
      puts "==============================================================================="
      puts "=== Add simplecov to your gemfile for the test group to calculate coverage. ==="
      puts "==============================================================================="
    ensure
      Rake::Task['test:units'].execute        if Dir.exists? 'test/unit'
      Rake::Task['test:functionals'].execute  if Dir.exists? 'test/functional'
      Rake::Task['test:integration'].execute  if Dir.exists? 'test/integration'
      Rake::Task['cucumber'].execute          if Dir.exists? 'features'
    end
  end

  task :setup => [:db, "db:drop", "db:create", "db:schema:load"]

  task :db do 
    puts "Setting up database..."

    Rails.env = "test"
    database  = ENV['DB_NAME']    || "ci_#{File.basename(Rails.root)}_test"
    adapter   = ENV['DB_ADAPTER'] || 'postgresql'
    host      = ENV['DB_HOST']    || 'postgresql'
    user      = ENV['DB_USER']    || 'ci'
    database_yml = <<-EOF
test:
  min_messages: warning
  adapter: #{adapter}
  host: #{host}
  username: #{user}
  password: #use PG_PASS
  database: #{database}
EOF
    File.write(File.join(Rails.root, 'config', 'database.yml'), database_yml)
  end

  task :cleanup do 
    puts "Cleaning up..."
    Rake::Task["db:drop"].execute
  end
end