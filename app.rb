require 'sinatra/base'
require 'openssl'
require 'base64'
require 'json'
require 'curb'
require 'uri'

# handle an incoming ctm webhook request and forward to kenshoo as a tracking event
=begin

get the clickid from the Landing URL 
k_clickid

# kenshoo: https://148.xg4ken.com/media/redir.php?track=1&token=4cc651ab-d9bb-4c1f-a47b-8cfa5df6d150&type=call&val=24.60&orderId=&promoCode=&valueCurrency=USD&GCID=&kw=&product=
=end
class KenshooApp < Sinatra::Base

  def process_call(call)
    if !call['location'] || !call['location'].match(/k_clickid=/) # nothing to do here...
      puts "no tracking id: #{call['location'].inspect}"
      return [201, {'Content-Type' => 'text/json'}, nil] # really a noop
    end
    puts "parsed call: #{call.inspect}"
    uri = URI.parse(call['location'])
    params = {}
    uri.query.split('&').each {|kv| k,v = kv.split('='); params[k] = v }
    k_clickid = params['k_clickid']
    gclid = params['gclid']
    search_keywords = params['search']
    search_keywords = URI.escape(search_keywords) if search_keywords
    url = "https://148.xg4ken.com/media/redir.php?track=1&token=#{k_clickid}&type=call&val=#{call['duration']}&orderId=#{call['id']}&promoCode=&valueCurrency=USD&GCID=#{gclid}&kw=#{search_keywords}&product="
    puts "send pixel request: #{url}"
    r = Curl.get(url)
    puts r.header_str
    puts r.body_str
    [201, {'Content-Type' => 'text/json'}, nil]
  end

  def verify_request(request)
    request_sig = request.env['HTTP_X_CTM_SIGNATURE']
    request_time = request.env['HTTP_X_CTM_TIME']
    puts "sig: #{request_sig}, time: #{request_time}"
    digest = OpenSSL::Digest::Digest.new('sha1')
    post_data = request.body.read#env["rack.input"].read
    verify = Base64.encode64(OpenSSL::HMAC.digest(digest, ENV['CTM_SECRET'], request_time + post_data)).strip
    if verify != request_sig
      return nil
    end
    JSON.parse(post_data)
  end

  post '/process' do
    call = verify_request(request)
    return [403, {'Content-Type' => 'text/json'}, {'error' => 'invalid request'}.to_json] if call.nil?

    process_call(call)

  end

  run! if app_file == $0
end
