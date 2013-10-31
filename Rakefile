require "bundler/gem_tasks"

module Bundler
  class GemHelper
  protected
    def rubygem_push(path)
      Bundler.with_clean_env do
        out, status = sh("gem inabox #{path}")
        raise "You should configure your Geminabox url: gem inabox -c" if out[/Enter the root url/]
        Bundler.ui.confirm "Pushed #{name} #{version} to Geminabox"
      end
    end
  end
end