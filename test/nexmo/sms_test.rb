require_relative './test'

class NexmoSMSTest < Nexmo::Test
  def sms
    Nexmo::SMS.new(client)
  end

  def uri
    'https://rest.nexmo.com/sms/json'
  end

  def test_send_method
    params = {from: 'Ruby', to: msisdn, text: 'Hello from Ruby!'}

    request = stub_request(:post, uri).with(headers: headers, body: params.merge(api_key_and_secret)).to_return(response)

    assert_equal response_object, sms.send(params)
    assert_requested request
  end

  def test_bulk_send_method_success
    recipients = ['1234567', '7891012']
    recipients.each{ |recipient| stub_sms_request(recipient: recipient) }

    params = { from: 'Ruby', text: 'Hello from Ruby!' }
    assert_equal [], sms.bulk_send(recipients, params) # No failed Deliveries
  end

  # Slow (12 sec) Test! Run at your own risk
  # [12.06.2018] - passes
  # def test_bulk_send_method_throttled
  #   recipients = ['1234567', '7891012']
  #   recipients.each{ |recipient| stub_sms_request(recipient: recipient, status: '1') }

  #   params = { from: 'Ruby', text: 'Hello from Ruby!' }
  #   assert_equal [[Nexmo::Entity.new(status: '1')]] * 2, sms.bulk_send(recipients, params)
  # end

  def test_bulk_send_method_fail
    recipients = ['1234567', '7891012']
    recipients.each{ |recipient| stub_sms_request(recipient: recipient, status: '2') }

    params = { from: 'Ruby', text: 'Hello from Ruby!' }
    assert_equal [[Nexmo::Entity.new(status: '2')]] * 2, sms.bulk_send(recipients, params)
  end

  def test_mapping_underscored_keys_to_hyphenated_string_keys
    params = {'status-report-req' => '1'}

    request = stub_request(:post, uri).with(headers: headers, body: params.merge(api_key_and_secret)).to_return(response)

    assert_equal response_object, sms.send(status_report_req: 1)
    assert_requested request
  end
end
