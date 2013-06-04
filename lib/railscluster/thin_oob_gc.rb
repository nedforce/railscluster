if defined?(Thin)
  class Thin::Backends::Base
    def connection_finished_with_oobgc(connection)
      connection_finished_without_oobgc(connection)
      if empty?
        GC::Profiler.clear if GC::Profiler.enabled?
        GC.start
      end
    end
    alias_method_chain :connection_finished, :oobgc
  end
end