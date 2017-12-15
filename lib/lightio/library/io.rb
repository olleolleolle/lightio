require 'forwardable'
module LightIO::Library
  class IO
    include LightIO::Wrap::Wrapper
    wrap ::IO

    extend Forwardable
    def_delegators :@io_watcher, :wait, :wait_readable, :wait_writable

    wrap_blocking_methods :read, :write, exception_symbol: false

    class << self
      def open(*args)
        io = self.new(*args)
        yield io
      ensure
        io.close if io.respond_to? :close
      end

      def pipe(*args)
        r, w = raw_class.pipe
        if block_given?
          begin
            return yield r, w
          ensure
            w.close
            r.close
          end
        end
        [IO._wrap(r), IO._wrap(w)]
      end

      def select(read_fds, write_fds=nil, _except_fds=nil, timeout=nil)
        timer = 0
        # run once ioloop
        LightIO.sleep 0
        loop do
          r_fds = (read_fds || []).select {|fd| fd.closed? ? raise(IOError, 'closed stream') : fd.instance_variable_get(:@io_watcher).readable?}
          w_fds = (write_fds || []).select {|fd| fd.closed? ? raise(IOError, 'closed stream') : fd.instance_variable_get(:@io_watcher).writable?}
          e_fds = []
          if r_fds.empty? && w_fds.empty?
            interval = 0.1
            LightIO.sleep interval
            timer += interval
            if timeout && timer > timeout
              return nil
            end
          else
            return [r_fds, w_fds, e_fds]
          end
        end
      end
    end
  end
end