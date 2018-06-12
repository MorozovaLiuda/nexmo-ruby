require 'minitest/autorun'
require 'webmock/minitest'
require 'nexmo'

module Nexmo
  class Test < Minitest::Test
    def api_key
      'nexmo-api-key'
    end

    def api_secret
      'nexmo-api-secret'
    end

    def api_key_and_secret
      {api_key: api_key, api_secret: api_secret}
    end

    def signature_secret
      'nexmo-signature-secret'
    end

    def application_id
      'nexmo-application-id'
    end

    def private_key
      File.read(File.expand_path(File.join(File.dirname(__FILE__), '..', 'private_key.txt')))
    end

    def client
      @client ||= Nexmo::Client.new({
        api_key: api_key,
        api_secret: api_secret,
        signature_secret: signature_secret,
        application_id: application_id,
        private_key: private_key
      })
    end

    def headers
      {'Content-Type' => 'application/x-www-form-urlencoded'}
    end

    def bearer_token
      /\ABearer (.+)\.(.+)\.(.+)\z/
    end

    def response
      {body: '{"key":"value"}', headers: response_headers}
    end

    def response_headers
      {'Content-Type' => 'application/json;charset=utf-8'}
    end

    def response_object
      Nexmo::Entity.new(key: 'value')
    end

    def msisdn
      '447700900000'
    end

    def stub_sms_request(recipient: '447700900000', status: '0', uri: 'https://rest.nexmo.com/sms/json')
      params = { from: 'Ruby', text: 'Hello from Ruby!', to: recipient }
      stub_request(:post, uri)
        .with(headers: headers, body: params.merge(api_key_and_secret))
        .to_return({ body: { messages: [{ status: status }] }.to_json, headers: response_headers})
    end
  end
end
