require 'httparty'

module OpenamAuth
  class Openam
    include HTTParty

    # COOKIE_NAME_FOR_TOKEN = "/identity/getCookieNameForToken"
    # IS_TOKEN_VALID = "/identity/isTokenValid"
    # USER_ATTRIBUTES = "/identity/attributes"
    # LOGIN_URL = "/UI/Login?goto="
    # LOGOUT_URL = "/identity/logout"
    COOKIE_NAME_FOR_TOKEN = "/identity/getCookieNameForToken"
    IS_TOKEN_VALID = "/json/sessions/"
    USER_ATTRIBUTES = "/json/users/"
    LOGIN_URL = "/XUI/#login/"
    LOGOUT_URL = "/identity/logout"

    def initialize
      @base_url = OpenamConfig.openam_url
      @self_url = OpenamConfig.self_url
    end

    def cookie_name
      response = self.class.post("#{@base_url}#{COOKIE_NAME_FOR_TOKEN}",{})
      response.body.split('=').last.strip
    end

    def token_cookie(request, cookie_name)
      token_cookie = CGI.unescape(request.cookies.fetch(cookie_name, nil).to_s.gsub('+', '%2B'))
      token_cookie != '' ? token_cookie : nil
    end

    def valid_token?(token)
      response = self.class.post("#{@base_url}#{IS_TOKEN_VALID}#{token}?_action=validate",:headers => { 'Content-Type' => 'application/json' })
      # response.body.split('=').last.strip == 'true'
      JSON.parse(response.body)
    end

    def openam_user(token_cookie_name, token, uid)
      self.class.cookies({ token_cookie_name => token })
      response = self.class.get("#{@base_url}#{USER_ATTRIBUTES}" + uid, :headers =>  { 'Content-Type' => 'application/json' }, token_cookie_name => token)
      JSON.parse(response.body)
    end

    def login_url
      "#{@base_url}#{LOGIN_URL}#{@self_url}"
    end

    def logout(token)
      self.class.post("#{@base_url}#{LOGOUT_URL}", {:subjectid => "#{token}" })
    end

    def user_hash(response)
      opensso_user = Hash.new{ |h,k| h[k] = Array.new }
      attribute_name = ''
      lines = response.split(/\n/)
      lines.each do |line|
        line = line.strip
        if line.match(/^userdetails.attribute.name=/)
          attribute_name = line.gsub(/^userdetails.attribute.name=/, '').strip
        elsif line.match(/^userdetails.attribute.value=/)
          opensso_user[attribute_name] << line.gsub(/^userdetails.attribute.value=/, '').strip
        end
      end
      opensso_user
    end
  end
end
