require 'sinatra/base'
require 'logger'
require 'yaml'

class Pan < Sinatra::Base

    log = Logger.new("#{File.dirname(__FILE__)}/log.log")
    yaml_config = YAML.load_file('config.yaml')

    use Rack::Auth::Basic, "Restricted Area" do |username, password|
        username == yaml_config["username"] and password == yaml_config["password"]
    end

    post '/:script' do
        script_name = params['script']
        script_path = "./scripts/#{script_name}"

        if !File.file?(script_path)
            log.info "Script '#{script_name} does not exist'"
            return 404
        end

        log.info "Run script '#{script_name}'"
        run_output = %x( #{script_path} )
        log.info run_output
        return 200
    end
end