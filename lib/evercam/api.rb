# Copyright © 2014, Evercam.

module Evercam
  class API
    # Include the module components.
    include Apps
    include Cameras
    include CloudRecording
    include MotionDetection
    include Logs
    include Models
    include Public
    include Shares
    include Snapshots
    include Users
    include Vendors
    include Webhooks
    include Archives
    include Snapmails

    # Constructor for the API class.
    #
    # ==== Parameters
    # options::  A Hash of additional options to be used by the instance. At
    #            a minimum this must include keys for :api_id and :api_key.
    def initialize(options={})
       @api_id  = options[:api_id]
       @api_key = options[:api_key]
       @agent   = options[:agent]
       @requester_ip   = options[:requester_ip]
       @country = options[:country]
       @code    = options[:country_code]
       @logger  = NullLogger.new(STDOUT)
       @host    = "media.evercam.io"
       @port    = nil
       @scheme  = "https"
       @version = "2"
       assign_options(options)
    end

    # This method will ping Evercam and provide feedback details that include
    # whether the API credentials provided are valid.
    def test
       handle_response(call("/test"))
    end

    private

    # This method is used internally by the class to assign recognised options
    # to class settings.
    #
    # ==== Parameters
    # options::  A Hash of the options to be processed.
    def assign_options(options)
       @logger  = options[:logger] if options.include?(:logger)
       @host    = options[:host] if options.include?(:host)
       @port    = options[:port] if options.include?(:port)
       @scheme  = options[:scheme] if options.include?(:scheme)
       @version = options[:version] if options.include?(:version)
    end

    # This method makes the actual call to the API endpoint for a request.
    #
    # ==== Parameters
    # path::        The path to the API endpoint to be called.
    # verb::        The HTTP verb to be used when making the request. Defaults
    #               to :get.
    # parameters::  A Hash of the parameters to be sent with the request.
    #               Defaults to an empty Hash and need not include the
    #               requesters API credentials as these are added to the
    #               request automatically.
    def call(path, verb=:get, parameters={})
       connection = Faraday.new(url: base_url) do |faraday|
          faraday.request :url_encoded
          faraday.use FaradayMiddleware::FollowRedirects
          faraday.adapter :typhoeus
       end

       values = {}.merge(parameters)
       if @api_id && @api_key
          values = values.merge(api_id: @api_id, api_key: @api_key)
       end

       values = values.merge(agent: @agent) if @agent
       values = values.merge(requester_ip: @requester_ip) if @requester_ip
       values = values.merge(u_country_code: @code) if @code
       values = values.merge(u_country: @country) if @country

       started  = Time.now
       response = nil
       case verb
          when :get
             @logger.info "GET #{endpoint_url(path)}"
             @logger.info "Parameters: #{values}"
             response = connection.get(api_path(path), values)
          when :delete
             @logger.info "DELETE #{endpoint_url(path)}"
             @logger.info "Parameters: #{values}"
             response = connection.delete(api_path(path), values)
          when :patch
             @logger.info "PATCH #{endpoint_url(path)}"
             @logger.info "Parameters: #{values}"
             response = connection.patch(api_path(path), values)
          when :post
             @logger.info "POST #{endpoint_url(path)}"
             @logger.info "Parameters: #{values}"
             response = connection.post(api_path(path), values)
          when :put
             @logger.info "PUT #{endpoint_url(path)}"
             @logger.info "Parameters: #{values}"
             response = connection.put(api_path(path), values)
          else
             message = "Unrecognised HTTP method '#{verb}' specified for request."
             @logger.error message
             raise EvercamError.new(message)
       end
       finished = Time.now
       @logger.info "API Call Took: #{finished - started}"
       response
    end

    # This method provides generic processing of responses from a call to the
    # API. The response status is first checked to see whether a success code
    # was returned from the server. The response will then be checked for
    # contents and an error raised if there are none. The contents will then
    # be checked to see if they contain an error response and an error raised
    # if this is the case. Finally, if all is well the parsed contents are
    # returned.
    def handle_response(response)
       data = nil
       if (200..299).include?(response.status)
          if !response.body.nil? && response.body.strip != ''
             data = parse_response_body(response)
             if data.nil?
                message = "API call failed to return any data or "\
                          "contained data that could not be parsed."
                @logger.error message
                raise EvercamError.new(message, "invalid_response", response.status)
             end
             handle_error_response(data, response.status) if data.include?("message")
          end
       else
          @logger.error "API call returned with a status of #{response.status}."
          handle_error_response(parse_response_body(response), response.status)
       end
       data
    end

    # This method is similar to the handle_response method with the exception
    # that, if the request returns a success status, the method returns the
    # response body as is, without trying to parse it as JSON.
    #
    # ==== Parameters
    # response::  The request response to be handled.
    def handle_raw(response)
       data = nil
       if !(200..299).include?(response.status)
          data    = parse_response_body(response)
          message = nil
          if !data.nil? && data.include?("message")
             handle_error_response(data, response.status)
          else
             message = "Evercam API call returned a #{response.status} code. "\
                       "Response body was '#{response.body}'."
             @logger.error message
             raise EvercamError.new(message, "invalid_response", response.status)
          end
       else
          data = response.body
       end
       data
    end

    # This method encapsulates the functionality and error handling for
    # parsing the contents of an API response. The nethod returns nil if it
    # is unable to parse out contents from the response.
    #
    # ==== Parameters
    # response::  The API call response to be parsed.
    def parse_response_body(response)
       contents = nil
       if !response.body.nil? && response.body.strip != ""
          begin
             contents = JSON.parse(response.body)
          rescue => error
             @logger.error "Error interpreting response for API call.\nCause: #{error}"
          end
       end
       contents
    end

    # This method fetches the base URL component for all API endpoints and
    # constructs it from settings within the class instance.
    def base_url
       url = StringIO.new
       url << @scheme << "://" << @host
       url << ":" << @port if !@port.nil?
       url.string
    end

    # This method generates a versioned path for an API endpoint.
    #
    # ==== Parameters
    # suffix::  The API call dependent part of the path.
    def api_path(suffix)
       ((/.+\..+$/ =~ suffix) != 0) ? "/v#{@version}#{suffix}" : "/v#{@version}#{suffix}"
    end

    # This method generates the fully qualified URL for an API endpoint.
    #
    # ==== Parameters
    # suffix::  The API call dependent part of the path.
    def endpoint_url(suffix)
       "#{base_url}#{api_path(suffix)}"
    end

    # This method processes a standard Evercam API error response to raise
    # an exception from it.
    #
    # ==== Parameters
    # data::    The parsed response data.
    # status::  The HTTP status code associated with the response.
    def handle_error_response(data, status)
       message = (data["message"] || "Evercam API call returned an error.")
       @logger.error "API response contains error details.\nMessage: #{message}\n"\
                     "Code: #{data["code"]}\nStatus: #{status}"
       raise EvercamError.new(message, data["code"], status, *data["context"])
    end
  end
end
