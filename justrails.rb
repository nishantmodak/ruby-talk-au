require 'rack'
require 'tilt'

module JustRails
  class Application
    def call(env)

      request = Rack::Request.new(env)
      
      kontroller_class, act = parse_request(request)
      rack_app = kontroller_class.action(act)
      rack_app.call(env)
      # controller = kontroller_class.new(env)
      # response = controller.send(action)
      
      # Rack::Response.new(response)
    end

    def parse_request(req)
      _, kont, action, _after = req.path_info.split('/', 4)
      kont = kont.capitalize # Products
      kont += 'Controller'   # ProductsController
      
      [Object.const_get(kont), action]
    end
  end

  class Controller
    def initialize(env)
      @env = env
      @routing_params = {}
    end

    def env
      @env
    end

    def request
      @request = Rack::Request.new(env)
    end

    def params
      request.params.merge @routing_params
    end

    def self.action(act, rparams = {})
      proc { |e| self.new(e).dispatch(act, rparams) }
    end

    def dispatch(action, routing_params = {})
      @routing_params = routing_params
      text = self.send(action)
      if get_response
        st, hd, rs = get_response.to_a
        [st, hd, rs]
      else
        [200, {'Content-Type' => 'text/html'}, [text].flatten]
      end
    end

    def controller_name
      JustRails.to_underscore(self.class.to_s.gsub(/Controller$/, ''))
    end

    def render_view(view_name, locals = {})
      file = File.join(File.dirname(__FILE__), 'app','views', controller_name, "#{view_name}.html.erb")
      tempalte = Tilt.new(file)
      tempalte.render(self, locals.merge(:env => env))
    end

    def response(text, status = 200, headers = {})
      fail 'Already responded' if @response
      body = [text].flatten
      @response = Rack::Response.new(body, status, headers)
    end

    def render(*args)
      response(render_view(*args))
    end

    def get_response
      @response
    end
  end

  def self.to_underscore(string)
    string.gsub(/::/, '/')
    .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
    .gsub(/([a-z\d])([A-Z])/, '\1_\2')
    .tr('-', '_')
    .downcase
  end

  class Object
      def self.const_missing(name)
        @looked_for ||= {}
        str_name = name.to_s
        fail "Class not found: #{name}" if @looked_for[str_name]
        @looked_for[str_name] = 1
        file = JustRails.to_underscore(str_name)
        require file
        klass = const_get(name)
        return klass if klass
        fail "Class not found: #{name}"
      end
    end
      

end
  