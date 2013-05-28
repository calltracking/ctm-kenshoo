require 'sinatra'
require 'openssl'
require 'base64'
require 'json'
require 'thread'
require 'curb'
require 'uri'

# handle an incoming ctm webhook request and forward to kenshoo as a tracking event
=begin

get the clickid from the Landing URL 
k_clickid

# kenshoo: https://148.xg4ken.com/media/redir.php?track=1&token=4cc651ab-d9bb-4c1f-a47b-8cfa5df6d150&type=call&val=24.60&orderId=&promoCode=&valueCurrency=USD&GCID=&kw=&product=
=end
post '/process' do
  request_sig = request.env['HTTP_X_CTM_SIGNATURE']
  request_time = request.env['HTTP_X_CTM_TIME']
  puts "sig: #{request_sig}, time: #{request_time}"
  digest = OpenSSL::Digest::Digest.new('sha1')
  post_data = request.body.read#env["rack.input"].read
  verify = Base64.encode64(OpenSSL::HMAC.digest(digest, ENV['CTM_SECRET'], request_time + post_data)).strip
  if verify != request_sig
    puts "request invalid"
    return [403, {'Content-Type' => 'text/json'}, {'error' => 'invalid request'}.to_json]
  end
  puts "request valid"
#  t = Thread.new do
    puts "parse call"
    call = JSON.parse(post_data)
    if !call['location'] || !call['location'].match(/k_clickid=/) # nothing to do here...
      puts "no tracking id: #{call['location'].inspect}"
      return
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
#  end
  [200, {'Content-Type' => 'text/json'}, post_data]
end
