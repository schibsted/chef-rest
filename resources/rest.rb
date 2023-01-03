# coding: UTF-8

resource_name 'rest'
provides 'rest'

# (C) Schibsted Products and Technology 2022, 2023
# Written by Nicolai Langfeldt (nicolai.langfeldt@schibsted.com)

unified_mode true

def whyrun_supported?
  true
end

# rubocop:disable Metrics/ParameterLists, Style/LambdaCall

# Please see README.md at the cookbook level.

property :url, String,
         default: '',
         description: 'The URL of the endpoint you want to call. No default.'
         
property :basicauth, String,
         default: '',
         description: 'The basic auth string if needed. username:password formated. ' \
                      'No default.'

property :content_type, String,
         default: 'application/json',
         description: 'The content type of the document you want to send ' \
                      '(with PUT or POST). Default is application/json'

property :document, String,
         default: '',
         description: 'The document you want to pass (with PUT or POST). ' \
                      'There is no default.'

# If https and the server is not using a proper certificate then
# override the certificate with a anternative CA, or just disable CA
# checking by marking it insecure.

property :ca, String,
         default: '',
         description: 'For HTTPS: If you\'re using a custom CA for the service and ' \
                      'want to verify it, pass the path here. No default.'

property :insecure, [true, false],
         default: false,
         description: 'For HTTPS: Set to true if you don\'t care to verify the sites ' \
                      'certificate.  The default is false.'

# Ways to check if the response was OK
#
# The 'fails' will always be checked first.
#
# You _have_ to have a list of HTTP response codes in ok_codes, but
# you may give it as '.*' which will match anything.
#

# Lists HTTP response codes that are taken as OK.
# https://developer.mozilla.org/en-US/docs/Web/HTTP/Status The
# document content will also have to pass the json and string tests
# before considered as OK response.  List numbers or strings.  Strings
# are interpreted as regular expressions
property :ok_codes, [Array, Integer, String],
         default: '20[012]',
         description: 'For matching with the HTTP result code. ' \
                      'A single integer or string. The string will be interpreted ' \
                      'as a regular expression.  Or a array of integers and/or strings.  ' \
                      'Default is 20[012] for matching 200, 201, and 202.'

# { 'created': true, 'found': true } or for a nested key: { 'document.created.[0]': true }
# Lists are considered as 'or' not 'and'.
# A value of 'nil' means nothing to check.
property :ok_json, [Array, Hash, nil],
         default: nil
property :fail_json, [Array, Hash, nil],
         default: nil
# Fail json or strings.  If a list any
property :ok_string, [Array, String, nil],
         default: nil,
         description: 'A string to look for that makes the result OK. No default.'

property :fail_string, [Array, String, nil],
         default: nil,
         description: 'A string to look for that makes the result a fail. No default.'

# REST based guards.

property :only_if_REST, [Hash, nil],
         default: nil,
         description: <<~DESCRIPTION
           Corresponding to only_if and not_if, make a REST query to see
           if the resource needs doing.  The properties set in the
           resource will be used, e.g. ca, insecure, basicauth,
           ok_codes, ok_json, fail_json, fail_string.  They can be
           overridden if you supply a hash of attributes such as

             only_if_REST ({ url: 'http://localhost/user/santaclaus', ok_codes: 404 })

           which would be true if santaclaus does not exist.  You'll
           need to supply the URL unless you're reusing that too.  The
           default HTTP method will be GET.

           You need to use the specific hash syntax shown above.

         DESCRIPTION

property :not_if_REST, [Hash, nil],
         default: nil,
         description: 'not_if using REST.  See only_if_REST.'

# The action starts here

# The HTTP method corresponds to the chef resource action.  The
# following actions are supported:
# - :GET
# - :DELETE
# - :PUT, :POST, :PATCH - these expect a document to submit to the server

default_action :GET

action :GET do
  new_resource.url = new_resource.name if new_resource.url.eql?('')
  do_query 'GET', new_resource.url
end

action :PUT do
  new_resource.url = new_resource.name if new_resource.url.eql?('')
  do_query 'PUT', new_resource.url
end

action :POST do
  new_resource.url = new_resource.name if new_resource.url.eql?('')
  do_query 'POST', new_resource.url
end

action :PATCH do
  new_resource.url = new_resource.name if new_resource.url.eql?('')
  do_query 'PATCH', new_resource.url
end

action :DELETE do
  new_resource.url = new_resource.name if new_resource.url.eql?('')
  do_query 'DELETE', new_resource.url
end


action_class do
  require 'pp'

  # I wanted to use a class for this but could not find a way to
  # do it within the framework of chef.  So in this case I'll carry the
  # query context in a Struct instead.
  #
  # Up to three contects are needed:
  # - resource main context
  # - only-if-REST context and
  # - not-if-REST context
  #
  # The two guards may specify totaly different options and contexts
  # from the main query.
  
  Curl = Struct.new(:cmd, :url, :http_method, :document,
                    :ok_codes, :ok_json, :fail_json,
                    :ok_string, :fail_string,
                    # Returned values:
                    :ret_doc, :headers, :http_reply, :is_json, :errors,
                    # Methods
                    :process, :is_ok, :to_string,
                    # Misc
                    :_no_raise, :_debug)
  
  def rest_query(action: 'GET',
                 url: new_resource.url,
                 basicauth: new_resource.basicauth,
                 content_type: new_resource.content_type,
                 document: new_resource.document,
                 ca: new_resource.ca,
                 insecure: new_resource.insecure,
                 ok_codes: new_resource.ok_codes,
                 ok_json: new_resource.ok_json,
                 fail_json: new_resource.fail_json,
                 ok_string: new_resource.ok_string,
                 fail_string: new_resource.fail_string,
                 no_raise: false,
                 debug: false)

    # Need the action to be a string for the rest of the code.
    action = action.to_s unless action.is_a?(String)

    raise "Method for #{action} is not done" \
      unless %w[DELETE GET POST PUT PATCH].include?(action)

    this = Curl.new(%W[curl -i --silent --tr-encoding -X #{action}])

    this.cmd.push('-u', basicauth, '--basic') unless basicauth.eql?('')

    if insecure
      this.cmd.push('-k')
    elsif !ca.eql?('')
      this.cmd.push('--cacert', ca)
    end

    if %w[POST PUT PATCH].include?(action)
      raise "No document given for #{action} #{url}" \
        if document.nil? || document.empty?

      this.cmd.push('-H', "Content-Type: #{content_type}",
                    '--data-binary', '@-')
    else
      raise "Document should not be given for #{action} #{url}" \
        unless document.nil? || document.empty?
    end

    # Last argument
    this.cmd.push(url)

    # And save the rest of the query context
    this.url         = url
    this.http_method = action
    this.document    = document
    this.ok_codes    = ok_codes
    this.ok_json     = ok_json
    this.fail_json   = fail_json
    this.ok_string   = ok_string
    this.fail_string = fail_string
    this._no_raise   = no_raise
    this._debug      = debug
    # Returned things
    this.ret_doc     = nil
    this.headers     = nil
    this.http_reply  = nil
    this.is_json     = false

    # Make into array if it isn't already a array
    this.ok_codes = [this.ok_codes] if
      this.ok_codes.is_a?(String) || this.ok_codes.is_a?(Integer)

    # Sorta object methods
    this.process   = proc { _execute(this) }
    this.is_ok     = proc { _is_ok(this) }
    this.to_string = proc { _string(this) }
    
    return this
  end

    
  def _execute(this)
    # Handling this correctly is tricky: Curl might not be able to
    # terminate and set exit status until it's STDOUT and STDERR has
    # been drained.  So first drain them.  And THEN check the exit
    # status and any error messages.  If that is OK then we check the
    # HTTP headers and content.
    curl_in, curl_out, curl_err, curl_wait = Open3.popen3(*this.cmd)

    curl_in.write(this.document) \
      if %w[POST PUT PATCH].include?(this.http_method)

    curl_in.close

    # First collect headers
    this.headers = []

    curl_out.each_line do |line|
      line.chomp!
      break if line.eql?(''); # Empty line is end of headers
      
      this.headers << line
    end
    this.http_reply = this.headers.shift

    # Then collect any document that come after the headers
    this.ret_doc = curl_out.read

    # And any errors last, in case there were transfer errors.  We do
    # not expect the error output to overflow the socket buffer (4K)
    # and cause a lockup.
    this.errors = curl_err.read
    
    raise "curl of #{this.url} failed: #{this.errors}, exit status #{curl_wait.value}" \
      if curl_wait.value != 0

    curl_err.close
    curl_out.close

    # Find encoding of received document, and correct the encoding of
    # the document if needed.  This does assume that the charset
    # header responds with a normalized name which matches the names
    # used by ruby.  And that curl does not already fix this.
    content_charset = /^content-type:.* charset=([^ ]*)/i

    encoding = ''
    this.headers.grep(content_charset).each do |header|
      encoding = content_charset.match(header).captures[0]
    end

    puts "DEBUG: Got document: #{this.ret_doc}" if this._debug

    # Not tooo sure about this
    this.ret_doc.force_encoding(encoding).encode('UTF-8') \
      if encoding != '' && this.ret_doc.encoding.to_s != encoding

    # If the returned document is json then convert it.
    this.is_json = !this.headers.grep(%r{application/json}i).empty?

    begin
      if this.is_json
        puts 'DEBUG: Returned document is JSON, converting to variable' \
          if this._debug
        this.ret_doc = JSON.parse(this.ret_doc)
      end
    rescue
      # Not sure if this should be fatal or not, but do not want to
      # spew response document at user.
      raise 'JSON error in response document'
    end
  end

  
  def _string(this)
    "#{this.http_method} #{this.url}"
  end


  def json_lookup(spec, json, debug)
    # Pick out the k)ey path to look in, and the v)alue to look for

    # Hash keys often turn out to be symbols. Make string.
    k = spec.keys[0]
    k = k.to_s unless k.is_a?(String)
    k = k.split('.')
    v = spec.values[0]

    puts "DEBUG: Json_lookup: Looking for #{spec} in #{json}" if debug
    puts "DEBUG: Key path: #{k}" if debug

    # "cursor" into the json we're looking in
    i = json
    k.each do |key|
      puts "DEBUG: *** Looking up key '#{key}' (#{key.class}) in #{i}" if debug

      case
      when i.is_a?(Hash)
        puts 'DEBUG: Lookup is in Hash' if debug
        unless i.key?(key)
          puts "DEBUG: Have key #{key} but no match for it" if debug
          return false
        end
      when i.is_a?(Array)
        puts 'DEBUG: Lookup is in Array' if debug
        if key =~ /^[^0-9]*$/
          puts "DEBUG: Lookup key /#{key}/ is not integer => false" if debug
          return false
        end
        key = key.to_i
        if i[key].nil?
          puts "DEBUG: Have key #{key} and got nil => false" if debug
          return false
        end
      else
        puts 'DEBUG: Not a Array and not a Hash? => false' if debug
        return false
      end
      i = i[key]
    end
    # After looking up all the way 
    puts "DEBUG: Result: #{i.class} == #{v.class} && #{i} == #{v}" if debug
    if i.is_a?(String)
      return false unless v.is_a?(String)
      
      # If a string, and the other one is too do a substring search
      return !i.index(v).nil?
    end
    
    return i.class == v.class && i == v
  end

  
  def _is_ok(this)
    ok = _check_http_result(this)
    unless ok
      return false if this._no_raise
      
      raise "REST query (#{this.to_string.()}) failed with #{this.http_reply}"
    end

    if this.ok_json
      unless this.is_json
        return false if this._no_raise

        raise "Returned document at #{this.url} is not json so can't check against ok_json specification"
      end
      r = json_lookup(this.ok_json, this.ret_doc, this._debug)
      puts "DEBUG: Json lookup #{this.ok_json} in #{this.ret_doc} got: #{r}"\
        if this._debug
      return r
    end
    
    return true
  end

    
  def _check_http_result(this)
    # Check if the HTTP result code is on the list of OK result codes?
    code = this.http_reply.split(/ +/, 4)[1]

    this.ok_codes.each do |ok_code|
      puts "DEBUG: Comparing #{code} with #{ok_code}" if this._debug
      case
      when ok_code.is_a?(String)
        puts 'DEBUG: Checking regular expression match' if this._debug
        if code =~ /#{ok_code}/
          puts 'DEBUG: Match! => true (http result code is ok)' if this._debug
          return true
        end
      when ok_code.is_a?(Integer)
        puts 'DEBUG: Checking literal match' if this._debug
        if code.to_i == ok_code
          puts 'DEBUG: Match! => true (http result code is ok)' if this._debug
          return true
        end
      else
        raise "ok_codes contains #{ok_code} which I don't know what to do with"
      end
    end

    print 'DEBUG: HTTP result code did not match. FAIL' if this._debug
    return false
  end

  
  def the_guards_pass
    # Return true if the REST guards allow convergence of this
    # resource
    #
    # !!!! Careful, contents under presure  !!!!
    # !!!! If handled without due care this !!!!
    # !!!! will blow up in your face!       !!!!
    # !!!!                                  !!!!
    # !!!!    * Always run tests after*     !!!!
    # !!!!                                  !!!!
    #
    # check only_if_REST and not_if_REST guards, if set. If both are
    # set, only_if_REST will be processed first.

    only_if = true
    not_if = false
    
    if property_is_set?(:only_if_REST)
      new_resource.only_if_REST[:no_raise] = true
      begin
        check = rest_query(**new_resource.only_if_REST)
      rescue ArgumentError
        raise 'Parameter error in only_if_REST. Please refer to documentation.'
      end
      puts "\nDEBUG: Evaluating only-if guard: #{check.http_method} "\
           "#{check.url}" if check._debug
      check.process.()
      only_if = check.is_ok.()
      puts "DEBUG: only_if == #{only_if}" if check._debug
    end

    return false if only_if == false
    
    if property_is_set?(:not_if_REST)
      new_resource.not_if_REST[:no_raise] = true
      begin
        check = rest_query(**new_resource.not_if_REST)
      rescue ArgumentError
        raise 'Parameter error in not_if_REST. Please refer to documentation.'
      end
      puts "\nDEBUG: Evaluating not-if guard: #{check.http_method} "\
           "#{check.url}" if check._debug
      check.process.()
      not_if = check.is_ok.()
      puts "DEBUG: not_if == #{not_if}" if check._debug
    end

    return false if not_if == true

    return true
  end


  def do_query(action, url)
    return unless the_guards_pass

    converge_by "Converging #{action} #{url} query" do
      begin
        curl = rest_query(action: action, url: url)
      rescue ArgumentError
        raise 'Internal error setting up (primary) query'
      end
      curl.process.()
      curl.is_ok.()
    end
  end
end

# rubocop:enable Metrics/ParameterLists, Style/LambdaCall
