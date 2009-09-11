require 'test/unit'
require 'test/unit/assertions'
require 'rexml/document'

#--
# Og related assertions.
#++

module Test::Unit::Assertions

  STATUS_MAP = {
    :success => 200,
    :ok => 200,
    :redirect => 307
  }
  
  # :section: General assertions.

  # Check the status of the response.
  
  def assert_response(options = {})
    unless options.is_a? Hash
      options = { :status => options }
    end
    msg = options[:msg]
    if status = options.fetch(:status, :success)
      status = STATUS_MAP[status] if STATUS_MAP.has_key?(status)
      assert_status(status, msg)
    end
  end

  def assert_status(status, msg)
    msg = format_msg("Status not '#{status}'", msg)
    assert_block(msg) { @context.status == status }
  end
    
  #--
  # Compile some helpers.
  #++
  
  for m in [:get, :post, :put, :delete, :head]
    eval %{
      def assert_#{m}(uri, headers = {}, params = {}, session = nil)
        #{m}(uri, headers, params, session)
        assert_response :success
      end 
    }
  end
  
  def assert_output(options = {})
    msg = options[:msg]
    if re = options[:match] || options[:contains]
      assert_output_match(re, msg)
    end
    if re = options[:no_match] || options[:contains_no]
      assert_output_not_match(re, msg)
    end
    if content_type = options[:content_type]
      assert_content_type(content_type, msg)
    end
  end
  
  def assert_output_match(re, msg)
    msg = format_msg("Rendered output does not match '#{re.source}'", msg)
    assert_block(msg) { @context.body =~ Regexp.new(re) }
  end
  alias_method :assert_output_contains, :assert_output_match

  def assert_output_not_match(re, msg)
    msg = format_msg("Rendered output matches '#{re.source}'", msg)
    assert_block(msg) { @context.out =~ Regexp.new(re) }
  end
  alias_method :assert_output_contains_not, :assert_output_match

  def assert_content_type(ctype, msg)
    msg = format_msg("Content type is not '#{ctype}' as expected", msg)
    assert_block(msg) { @context.content_type == ctype }
  end    
  
  # :section: Session related assertions.

  def assert_session(options = {})
    msg = options[:msg]
    if key = options[:has]
      assert_session_has(key, msg)
    end
    if key = options[:has_no] || options[:no]
      assert_session_has_no(key, msg)
    end
    if key = options[:key] and value = options[:value]
      assert_session_equal(key, value, msg)
    end    
  end

  def assert_session_has(key, msg = nil)
    msg = format_msg("Object '#{key}' not found in session", msg)
    assert_block(msg) {  @context.session[key] }
  end

  def assert_session_has_no(key, msg = nil)
    msg = format_msg("Unexpected object '#{key}' found in session", msg)
    assert_block(msg) { !@context.session[key] }
  end
  
  def assert_session_equal(key, value, msg = nil)
    msg = format_msg("The value of session object '#{key}' is '#{@context.session[key]}' but was expected '#{value}'", msg)
    assert_block(msg) { @context.session[key] == value }
  end

  # :section: Cookies related assertions.

  def assert_cookie(options = {})
    msg = options[:msg]
    if key = options[:has]
      assert_cookie_has(key, msg)
    end
    if key = options[:has_no] || options[:no]
      assert_cookie_has_no(key, msg)
    end
    if key = options[:key] and value = options[:value]
      assert_cookie_equal(key, value, msg)
    end    
  end

  def assert_cookie_has(name, msg = nil)
    msg = format_msg("Cookie '#{name}' not found", msg)
    assert_block(msg) { @context.response_cookie(name) }
  end

  def assert_cookie_has_no(name, msg = nil)
    msg = format_msg("Unexpected cookie '#{name}' found", msg)
    assert_block(msg) { !@context.response_cookie(name) }
  end
  
  def assert_cookie_equal(name, value, msg = nil)
    unless cookie = @context.response_cookie(name)
      msg = format_msg("Cookie '#{name}' not found", msg)
      assert_block(msg) { false }
    end
    msg = format_msg("The value of cookie '#{name}' is '#{cookie.value}' but was expected '#{value}'", msg)
    assert_block(msg) { cookie.value == value }
  end

  # :section: Nitro::Template related assertions.
  
  # :section: Redirection assertions.

  def assert_redirected(options = {})
    msg = options[:msg]
    
    msg = format_msg("No redirection (status = #{@context.status})", msg)
    assert_block(msg) { @context.redirect? }
    
    if to = options[:to]
      msg = format_msg("Not redirected to '#{to}'", msg)
      assert_block(msg) { @context.response_headers['location'] == "http://#{to}" }
    end
  end

  def assert_not_redirected(options = {})
    msg = options[:msg]
    msg = format_msg("Unexpected redirection (location = '#{@context.response_headers['location']}')", msg)
    assert_block(msg) { !@context.redirect? }
  end
  
  # :section: Utility methods 

  def format_msg(message, extra) # :nodoc:
    extra += ', ' if extra
    return "#{extra}#{message}"
  end

end
