require 'sinatra/base'
require 'logger'
require 'yaml'
require 'net/http'
require "base64"
require 'octokit'
require 'json'
require 'net/http'
require 'net/https'

class Pan < Sinatra::Base
    log = Logger.new("#{File.dirname(__FILE__)}/log.log")
    yaml_config = YAML.load_file('config.yaml')

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
    
    post '/upload/media' do
      @filename = params[:file][:filename]
        file = params[:file][:tempfile]

		    uploadPath = yaml_config['uploadPath']
        File.open("#{uploadPath}/#{@filename}", 'wb') do |f|
          f.write(file.read)
        end
      
      	sharePath = yaml_config["sharePath"]
        response.headers["Location"] = "#{sharePath}/#{@filename}"
    end

    get '/micropub/main' do
      content_type :json
      { "media-endpoint": yaml_config["endpointURL"]}.to_json
    end

    def checkAuthorization(token)
      uri = URI('https://tokens.indieauth.com/token')

      # Create client
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    
      # Create Request
      req =  Net::HTTP::Get.new(uri)
      # Add headers
      authorizationValue = "#{token}"

      req.add_field "Authorization", authorizationValue
    
      # Fetch Request
      res = http.request(req)
      body = res.body

      if res.code != '200'
        return false
      end

      decodedBody = URI.decode_www_form(body)
      correctMeURI = decodedBody.assoc('me').last == 'https://hartl.co/'

      return correctMeURI
    end
    
    post '/micropub/main' do
      headerToken = request.env["HTTP_AUTHORIZATION"]
      if !checkAuthorization(request.env["HTTP_AUTHORIZATION"])
        puts headerToken
        puts "Wrong token"
        return 401
      end
      
      content = params[:content]
      puts content
      

      file = Time.now.strftime("%Y-%m-%d-%H-%M")
      date = Time.now.strftime("%Y-%m-%d %H:%M")
      filecontent = "---\nauthor: Martin Hartl\nlayout: status\ndate: #{date}\n---\n#{content}"
      token = yaml_config["githubtoken"]

      client = Octokit::Client.new(:access_token => token)
      client.create_contents("hartlco/hartlco-jekyll",
        "contents/_posts/#{file}.md",
        "Adding post",
        filecontent)
      
      print "success"
    end  
end