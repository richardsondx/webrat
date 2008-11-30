require "webrat/core/form"
require "webrat/core/locators"
require "webrat/core_extensions/deprecate"

module Webrat
  # An HTML element (link, button, field, etc.) that Webrat expected was not found on the page
  class NotFoundError < WebratError
  end
  
  class Scope
    include Logging
    include Locators
    
    def self.from_page(session, response, response_body) #:nodoc:
      new(session) do
        @response = response
        @response_body = response_body
      end
    end
    
    def self.from_scope(session, scope, selector) #:nodoc:
      new(session) do
        @scope = scope
        @selector = selector
      end
    end
    
    def initialize(session, &block) #:nodoc:
      @session = session
      instance_eval(&block) if block_given?
      
      labels
      fields
      forms # preload
      areas # preload
      links # preload
    end
    
    # Verifies an input field or textarea exists on the current page, and stores a value for
    # it which will be sent when the form is submitted.
    #
    # Examples:
    #   fill_in "Email", :with => "user@example.com"
    #   fill_in "user[email]", :with => "user@example.com"
    #
    # The field value is required, and must be specified in <tt>options[:with]</tt>.
    # <tt>field</tt> can be either the value of a name attribute (i.e. <tt>user[email]</tt>)
    # or the text inside a <tt><label></tt> element that points at the <tt><input></tt> field.
    def fill_in(field_locator, options = {})
      field = locate_field(field_locator, TextField, TextareaField, PasswordField)
      field.raise_error_if_disabled
      field.set(options[:with])
    end

    webrat_deprecate :fills_in, :fill_in
    
    def set_hidden_field(field_locator, options = {})
      field = locate_field(field_locator, HiddenField)
      field.set(options[:to])
    end
    
    # Verifies that an input checkbox exists on the current page and marks it
    # as checked, so that the value will be submitted with the form.
    #
    # Example:
    #   check 'Remember Me'
    def check(field_locator)
      locate_field(field_locator, CheckboxField).check
    end

    webrat_deprecate :checks, :check
    
    # Verifies that an input checkbox exists on the current page and marks it
    # as unchecked, so that the value will not be submitted with the form.
    #
    # Example:
    #   uncheck 'Remember Me'
    def uncheck(field_locator)
      locate_field(field_locator, CheckboxField).uncheck
    end

    webrat_deprecate :unchecks, :uncheck
    
    # Verifies that an input radio button exists on the current page and marks it
    # as checked, so that the value will be submitted with the form.
    #
    # Example:
    #   choose 'First Option'
    def choose(field_locator)
      locate_field(field_locator, RadioField).choose
    end

    webrat_deprecate :chooses, :choose
    
    # Verifies that a an option element exists on the current page with the specified
    # text. You can optionally restrict the search to a specific select list by
    # assigning <tt>options[:from]</tt> the value of the select list's name or
    # a label. Stores the option's value to be sent when the form is submitted.
    #
    # Examples:
    #   select "January"
    #   select "February", :from => "event_month"
    #   select "February", :from => "Event Month"
    def select(option_text, options = {})
      option = find_select_option(option_text, options[:from])
      option.choose
    end

    webrat_deprecate :selects, :select
    
    DATE_TIME_SUFFIXES = {
      :year   => '1i',
      :month  => '2i',
      :day    => '3i',
      :hour   => '4i',
      :minute => '5i'
    }

    # Verifies that date elements (year, month, day) exist on the current page 
    # with the specified values. You can optionally restrict the search to a specific
    # date's elements by assigning <tt>options[:from]</tt> the value of the date's 
    # label. Selects all the date elements with date provided.  The date provided may
    # be a string or a Date/Time object.
    #
    # Rail's convention is used for detecting the date elements. All elements
    # are assumed to have a shared prefix.  You may also specify the prefix
    # by assigning <tt>options[:id_prefix]</tt>.
    #
    # Examples:
    #   select_date "January 23, 2004"
    #   select_date "April 26, 1982", :from => "Birthday"
    #   select_date Date.parse("December 25, 2000"), :from => "Event"
    #   select_date "April 26, 1982", :id_prefix => 'birthday'
    def select_date(date_to_select, options ={})
      date = date_to_select.is_a?(Date) || date_to_select.is_a?(Time) ? 
                date_to_select : Date.parse(date_to_select) 
      
      id_prefix = locate_id_prefix(options) do
        year_field = FieldByIdLocator.new(self, /(.*?)_#{DATE_TIME_SUFFIXES[:year]}$/).locate
        raise NotFoundError.new("No date fields were found") unless year_field && year_field.id =~ /(.*?)_1i/
        $1
      end
        
      select date.year, :from => "#{id_prefix}_#{DATE_TIME_SUFFIXES[:year]}"
      select date.strftime('%B'), :from => "#{id_prefix}_#{DATE_TIME_SUFFIXES[:month]}"
      select date.day, :from => "#{id_prefix}_#{DATE_TIME_SUFFIXES[:day]}"
    end

    webrat_deprecate :selects_date, :select_date

    # Verifies that time elements (hour, minute) exist on the current page 
    # with the specified values. You can optionally restrict the search to a specific
    # time's elements by assigning <tt>options[:from]</tt> the value of the time's 
    # label. Selects all the time elements with date provided.  The time provided may
    # be a string or a Time object.
    #
    # Rail's convention is used for detecting the time elements. All elements are
    # assumed to have a shared prefix. You may specify the prefix by assigning
    # <tt>options[:id_prefix]</tt>.
    #
    # Note: Just like Rails' time_select helper this assumes the form is using
    # 24 hour select boxes, and not 12 hours with AM/PM.
    # 
    # Examples:
    #   select_time "9:30"
    #   select_date "3:30PM", :from => "Party Time"
    #   select_date Time.parse("10:00PM"), :from => "Event"
    #   select_date "10:30AM", :id_prefix => 'meeting'
    def select_time(time_to_select, options ={})
      time = time_to_select.is_a?(Time) ? time_to_select : Time.parse(time_to_select) 

      id_prefix = locate_id_prefix(options) do
        hour_field = FieldByIdLocator.new(self, /(.*?)_#{DATE_TIME_SUFFIXES[:hour]}$/).locate
        raise NotFoundError.new("No time fields were found") unless hour_field && hour_field.id =~ /(.*?)_4i/
        $1
      end
        
      select time.hour.to_s.rjust(2,'0'), :from => "#{id_prefix}_#{DATE_TIME_SUFFIXES[:hour]}"
      select time.min.to_s.rjust(2,'0'), :from => "#{id_prefix}_#{DATE_TIME_SUFFIXES[:minute]}"
    end

    webrat_deprecate :selects_time, :select_time
   
    # Verifies and selects all the date and time elements on the current page. 
    # See #select_time and #select_date for more details and available options.
    #
    # Examples:
    #   select_datetime "January 23, 2004 10:30AM"
    #   select_datetime "April 26, 1982 7:00PM", :from => "Birthday"
    #   select_datetime Time.parse("December 25, 2000 15:30"), :from => "Event"
    #   select_datetime "April 26, 1982 5:50PM", :id_prefix => 'birthday'
    def select_datetime(time_to_select, options ={})
      time = time_to_select.is_a?(Time) ? time_to_select : Time.parse(time_to_select) 
      
      options[:id_prefix] ||= (options[:from] ? FieldByIdLocator.new(self, options[:from]).locate : nil)
      
      select_date time, options
      select_time time, options
    end

    webrat_deprecate :selects_datetime, :select_datetime
    
    # Verifies that an input file field exists on the current page and sets
    # its value to the given +file+, so that the file will be uploaded
    # along with the form. An optional <tt>content_type</tt> may be given.
    #
    # Example:
    #   attaches_file "Resume", "/path/to/the/resume.txt"
    #   attaches_file "Photo", "/path/to/the/image.png", "image/png"
    def attach_file(field_locator, path, content_type = nil)
      locate_field(field_locator, FileField).set(path, content_type)
    end

    webrat_deprecate :attaches_file, :attach_file
    
    def click_area(area_name)
      find_area(area_name).click
    end
    
    webrat_deprecate :clicks_area, :click_area
    
    # Issues a request for the URL pointed to by a link on the current page,
    # follows any redirects, and verifies the final page load was successful.
    # 
    # click_link has very basic support for detecting Rails-generated 
    # JavaScript onclick handlers for PUT, POST and DELETE links, as well as
    # CSRF authenticity tokens if they are present.
    #
    # Javascript imitation can be disabled by passing the option :javascript => false
    #
    # Passing a :method in the options hash overrides the HTTP method used
    # for making the link request
    # 
    # It will try to find links by (in order of precedence):
    #   innerHTML, with simple &nbsp; handling
    #   title
    #   id
    #    
    # innerHTML and title are matchable by text subtring or Regexp
    # id is matchable by full text equality or Regexp
    # 
    # Example:
    #   click_link "Sign up"
    #   click_link "Sign up", :javascript => false
    #   click_link "Sign up", :method => :put
    def click_link(text_or_title_or_id, options = {})
      find_link(text_or_title_or_id).click(options)
    end

    webrat_deprecate :clicks_link, :click_link
    
    # Verifies that a submit button exists for the form, then submits the form, follows
    # any redirects, and verifies the final page was successful.
    #
    # Example:
    #   click_button "Login"
    #   click_button
    #
    # The URL and HTTP method for the form submission are automatically read from the
    # <tt>action</tt> and <tt>method</tt> attributes of the <tt><form></tt> element.
    def click_button(value = nil)
      find_button(value).click
    end

    webrat_deprecate :clicks_button, :click_button
    
    def submit_form(id)
      form = forms.detect { |f| f.matches_id?(id) }
      form.submit
    end
    
    def dom # :nodoc:
      return @dom if @dom
      
      if @selector
        @dom = scoped_dom
      else
        @dom = page_dom
      end
      
      return @dom
    end
    
  protected
  
    def page_dom #:nodoc:
      return @response.dom if @response.respond_to?(:dom)
      dom = Webrat::XML.document(@response_body)
      Webrat.define_dom_method(@response, dom)
      return dom
    end
    
    def scoped_dom #:nodoc:
      Webrat::XML.document("<html>" + Webrat::XML.to_html(Webrat::XML.css_search(@scope.dom, @selector).first) + "</html>")
    end
    
    def locate_field(field_locator, *field_types) #:nodoc:
      if field_locator.is_a?(Field)
        field_locator
      else
        field(field_locator, *field_types)
      end
    end
    
    def locate_id_prefix(options, &location_strategy) #:nodoc:
      return options[:id_prefix] if options[:id_prefix]
      
      if options[:from]
        if (label = LabelLocator.new(self, options[:from]).locate)
          label.for_id
        else
          raise NotFoundError.new("Could not find the label with text #{options[:from]}")
        end
      else
        yield
      end
    end
    
    def areas #:nodoc:
      Webrat::XML.css_search(dom, Area.css_search).map do |element| 
        area = Area.new(@session, element)
        @session.elements[Webrat::XML.xpath_to(element)] = area
        area
      end
    end
    
    def links #:nodoc:
      Webrat::XML.css_search(dom, Link.css_search).map do |element|
        link = Link.new(@session, element)
        @session.elements[Webrat::XML.xpath_to(element)] = link
        link
      end
    end
    
    def forms #:nodoc:
      return @forms if @forms
      
      @forms = Webrat::XML.css_search(dom, Form.css_search).map do |element|
        form = Form.new(@session, element)
        @session.elements[Webrat::XML.xpath_to(element)] = form
        form
      end
    end
    
    def fields
      return @fields if @fields
      
      @fields = []
      
      [SelectField, TextareaField, ButtonField, CheckboxField, PasswordField,
       RadioField, FileField, ResetField, TextField, HiddenField].each do |field_class|
        @fields += Webrat::XML.xpath_search(dom, *field_class.xpath_search).map do |element| 
          field = field_class.new(self, element)
          @session.elements[Webrat::XML.xpath_to(element)] = field
          field
        end
      end
      
      @fields
    end
    
    def labels
      @labels ||= Webrat::XML.css_search(dom, "label").map do |element|
        label = Label.new(self, element)
        @session.elements[Webrat::XML.xpath_to(element)] = label
        label
      end
    end
    
  end
end
