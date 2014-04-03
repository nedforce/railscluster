Capistrano::Configuration::Actions::Invocation.class_eval do
  def get_rails_env
    capture 'echo $RAILS_ENV'
  end

  def get_backend
    capture 'echo $RAILS_BACKEND'
  end
end

require 'capistrano/recipes/deploy/scm/git'
module Capistrano
  module Deploy
    module SCM
      class Git

        def query_revision(revision)
          return revision
        end

        def export(revision, destination)
          if variable(:git_enable_submodules) || !variable(:repository).include?('git.nedforce.nl')
            checkout(revision, destination) << " && rm -Rf #{destination}/.git"
          else
            git    = command
            remote = origin

            args = []

            args << "--verbose" if verbose.nil?
            args << "--prefix=#{destination[1..-1]}/"
            args << "--remote #{variable(:repository)}"

            execute = []
            execute << "#{git} archive #{args.join(' ')} #{revision} | (tar -x -C / -f -)"

            execute.compact.join(" && ").gsub(/\s+/, ' ')
          end
        end
      end
    end
  end
end
