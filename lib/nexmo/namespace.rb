require 'net/http'
require 'json'

module Nexmo
  class Namespace
    def initialize(client)
      @client = client

      @http = Net::HTTP.new(host, Net::HTTP.https_default_port)
      @http.use_ssl = true
      @failed_deliveries = []
    end

    private

    Get = Net::HTTP::Get
    Put = Net::HTTP::Put
    Post = Net::HTTP::Post
    Delete = Net::HTTP::Delete

    def host
      'api.nexmo.com'
    end

    def authorization_header?
      false
    end

    def json_body?
      false
    end

    def logger
      @client.logger
    end

    def request(path, params: nil, type: Get, &block)
      uri = URI('https://' + host + path)

      unless authorization_header?
        params ||= {}
        params[:api_key] = @client.api_key
        params[:api_secret] = @client.api_secret
      end

      unless type::REQUEST_HAS_BODY || params.nil? || params.empty?
        uri.query = Params.encode(params)
      end

      message = type.new(uri.request_uri)
      message['Authorization'] = @client.authorization if authorization_header?
      message['User-Agent'] = @client.user_agent

      encode_body(params, message) if type::REQUEST_HAS_BODY

      logger.info('Nexmo API request', method: message.method, path: uri.path)

      response = @http.request(message)

      parse(response, &block)
    end

    def persistent_request(to_array, path, params: nil, type: Get, &block)
      Net::HTTP.start(host, Net::HTTP.https_default_port, use_ssl: true) do |http|
        @http = http
        to_array.each do |to|
          params['to'] = to
          params['text'] = yield(to, params['text']) if block_given?
          attempts = 0
          begin
            messages = request(path, params: params, type: type).messages
            case messages.first&.status
            when '0'
              logger.info("Message successfully sent to #{to}.")
            when '1'
              logger.error('Sms Limit reached')
              attempts > 5 ? @failed_deliveries << messages : raise(Nexmo::Error)
            else
              @failed_deliveries << messages
            end
          rescue Nexmo::Error => error
            attempts += 1
            sleep 1
            retry
          end
        end
      end
      @failed_deliveries
    end

    def encode_body(params, message)
      if json_body?
        message['Content-Type'] = 'application/json'
        message.body = JSON.generate(params)
      else
        message.form_data = params
      end
    end

    def parse(response, &block)
      logger.info('Nexmo API response',
        host: host,
        status: response.code,
        type: response.content_type,
        length: response.content_length,
        trace_id: response['x-nexmo-trace-id'])

      case response
      when Net::HTTPNoContent
        :no_content
      when Net::HTTPSuccess
        parse_success(response, &block)
      else
        handle_error(response)
      end
    end

    def parse_success(response)
      if response['Content-Type'].split(';').first == 'application/json'
        JSON.parse(response.body, object_class: Nexmo::Entity)
      elsif block_given?
        yield response
      else
        response.body
      end
    end

    def handle_error(response)
      logger.debug(response.body)

      case response
      when Net::HTTPUnauthorized
        raise AuthenticationError
      when Net::HTTPClientError
        raise ClientError
      when Net::HTTPServerError
        raise ServerError
      else
        raise Error
      end
    end
  end
end
