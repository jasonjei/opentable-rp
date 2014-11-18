require 'sinatra'
require 'mechanize'
require 'time'
require 'chronic'
require 'active_support/core_ext'
require 'tzinfo'

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

get '/ip' do
	m = Mechanize.new
	b = m.get("http://www.whatismyipaddress.com").body
	b.match(/(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/).to_s
end


get '/statebird' do
    desired_at = Time.parse(params[:desired_at])
	m = Mechanize.new { |mech| mech.user_agent = 'iPhone' }

    search_page = m.get("http://www.opentable.com/restaurant-search.aspx?startDate=#{CGI.escape(desired_at.strftime("%m/%d/%Y").strip)}&ResTime=#{CGI.escape(desired_at.strftime("%l:%M %p").strip)}&PartySize=#{params[:people]}&PartySizeFake=#{params[:people]}+People&RestaurantID=139246&rid=139246&GeoID=58&txtDateFormat=MM%2Fdd%2Fyyyy&RestaurantReferralID=139246", [], "http://mobile.dudamobile.com/site/statebirdsfcom?url=http%3A%2F%2Fstatebirdsf.com%2Freservations%2F")
    

    return nil if not search_page.forms.first
    return nil if not search_page.forms.first.ClientTimeStamp

    client_timestamp = search_page.forms.first.ClientTimeStamp
    search_results = m.get("http://m.opentable.com/search/results?PartySize=#{params[:people]}&DateInvariantCulture=#{desired_at.to_date.iso8601}T00%3A00%3A00&TimeInvariantCulture=0001-01-01T#{CGI.escape(desired_at.strftime("%T").strip)}&SearchName=State+Bird+Provisions&MetroAreaID=&RegionID=&Latitude=&Longitude=&RestaurantID=139246&PromoID=&PromoType=&PartnerReferralID=&ConfirmationNumber=&ClientTimeStamp=#{client_timestamp}&OfferConfirmNumber=0&ChosenOfferId=0&ReservationStatus=")

    avail_times = search_results.links.select { |v| v.uri.to_s =~ /slotlock/ }
    return nil if avail_times.empty?
    good_times = cleanup_web_times(avail_times,desired_at,params[:tolerance].to_f,params[:tolerance_sign].to_i)

    if good_times.empty?
      return nil
    end

    details_page = good_times.first.click
    if not details_page.forms.first
      return nil
    end

    details_page_form = details_page.forms.first
    details_page_form.FirstName = "#{params[:first_name]}"
    details_page_form.LastName = "#{params[:last_name]}"
    details_page_form.Email = "#{params[:email]}"
    details_page_form.PhoneNumber = "#{params[:phone]}"

    confirm_page = details_page_form.submit details_page_form.buttons.detect { |v| v.value =~ /Confirm/ }
    return confirm_page.body

end

def cleanup_web_times(links,desired_at,tolerance,tolerance_sign)
  Time.zone = "UTC"
  Chronic.time_class = Time.zone

  return [] if links.empty?

  times = links
  times = times - times.select { |v|
    ((tolerance_sign == -1 and Chronic.parse(CGI.parse(URI.parse(v.uri.to_s).query)["DateTime"].join('')) < (desired_at - tolerance.to_f.hours)) ||
    (tolerance_sign == -1 and Chronic.parse(CGI.parse(URI.parse(v.uri.to_s).query)["DateTime"].join('')) > desired_at) ||
    (tolerance_sign == 0 and Chronic.parse(CGI.parse(URI.parse(v.uri.to_s).query)["DateTime"].join('')) > (desired_at + tolerance.to_f.hours)) ||
    (tolerance_sign == 0 and Chronic.parse(CGI.parse(URI.parse(v.uri.to_s).query)["DateTime"].join('')) < (desired_at - tolerance.to_f.hours)) || 
    (tolerance_sign == 1 and Chronic.parse(CGI.parse(URI.parse(v.uri.to_s).query)["DateTime"].join('')) > (desired_at + tolerance.to_f.hours)) ||
    (tolerance_sign == 1 and Chronic.parse(CGI.parse(URI.parse(v.uri.to_s).query)["DateTime"].join('')) < desired_at))
  }
  return times.sort_by { |v| (desired_at - Chronic.parse(CGI.parse(URI.parse(v.uri.to_s).query)["DateTime"].join(''))).abs }
end