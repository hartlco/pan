require 'sinatra/base'
require 'logger'
require 'yaml'
require 'net/http'
require "base64"
require 'octokit'
require 'json'
require 'net/http'
require 'net/https'
require 'base64'

class Pan < Sinatra::Base
    log = Logger.new("#{File.dirname(__FILE__)}/log.log")
   
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

    post '/upload/media' do
      headerToken = request.env["HTTP_AUTHORIZATION"]
      if !checkAuthorization(request.env["HTTP_AUTHORIZATION"])
        puts headerToken
        puts "Wrong token"
        return 401
      end

      @filename = params[:file][:filename]
        file = params[:file][:tempfile]

        data = file.read
        
        token = ENV["GITHUB_ACCESS_TOKEN"]
        path = "#{ENV["IMAGE_PATH"]}/#{@filename}"
        client = Octokit::Client.new(:access_token => token)
        commitResource = client.create_contents(
          ENV["GITHUB_REPOSITORY_NAME"],
          path,
          "Adding asset",
          data
        )

        downloadURL = commitResource.to_hash[:content][:download_url]
        response.headers["Location"] = downloadURL
    end

    get '/micropub/main' do
      content_type :json
      { "media-endpoint": ENV["MEDIAENDPOINT_URL"]}.to_json
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
      filecontent = "---\nauthor: #{ENV["AUTHOR_NAME"]}\nlayout: status\ndate: #{date}\n---\n#{content}"
      token = ENV["GITHUB_ACCESS_TOKEN"]

      client = Octokit::Client.new(:access_token => token)
      client.create_contents(
        ENV["GITHUB_REPOSITORY_NAME"],
        "contents/_posts/#{file}.md",
        "Adding post",
        filecontent
        )
        "success"
    end  
end
