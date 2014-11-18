require 'sinatra'
require 'mechanize'

get '/otapi_v3.ashx/*' do
	m = Mechanize.new { |mech| mech.user_agent = 'iPhone' }
	url = "https://secure.opentable.com/api/otapi_v3.ashx/#{params[:splat].first}"
	if request.query_string != ""
		url += "?" + request.query_string
	end
	logger.info "Url #{url}"
	m.get(url).body	
end

post '/otapi_v3.ashx/*' do
	m = Mechanize.new { |mech| mech.user_agent = 'iPhone' }
	url = "https://secure.opentable.com/api/otapi_v3.ashx/#{params[:splat].first}"
	if request.query_string != ""
		url += "?" + request.query_string
	end
	logger.info "Url #{url}"
	body = request.body.read
	logger.info "Body #{body}"

	result = m.post(url, body, { "Content-Type" => "application/x-www-form-urlencoded" }).body
	logger.info "RESULT !!! #{result}"
	result
end