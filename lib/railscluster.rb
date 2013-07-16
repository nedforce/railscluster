require "railscluster/version"

module Railscluster
  class ContinuousIntegration < Rails::Railtie
    rake_tasks do
      load File.join(File.dirname(__FILE__),'tasks/continuous_integration.rake')
    end
  end
end
