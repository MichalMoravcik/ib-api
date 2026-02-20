module IB
  module Plugins
    def activate_plugin *names
      root = Pathname(__dir__).parent.parent
      names.map { |y| y.to_s.gsub('_', '-') }.each do |n|
        if @plugins.include? n
          IB::Connection.logger.debug "Already activated plugin #{n}"
        else
          # root=  base directory of the ib-api source
          # plugins are defined in ib-api/plugins/ib
          filename = root.join('plugins', 'ib', n + '.rb')
          if filename.exist?
            begin
              # Use require_relative to ensure consistent loading
              require filename.to_s
              @plugins << n
              true # return value
            rescue LoadError => e
              error "Could not load Plugin `#{n}` --> #{filename} (#{e.message})"
            end
          else
            error "Plugin `#{n}` not found in `plugins/ib/`"
            nil
          end
        end
      end
    end
  end
end
