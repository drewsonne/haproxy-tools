require 'spec_helper'

describe HAProxy::Treetop::ConfigParser do
  before(:each) do
    @parser = HAProxy::Treetop::ConfigParser.new
  end

  def parse_file(filename)
    @result = @parser.parse(File.read(filename))
    if @result.nil?
      puts
      puts "Failure Reason:  #{@parser.failure_reason}"
    end

    # HAProxy::Treetop.print_node(@result, 0, :max_depth => 3)
  end

  def parse_single_pool
    parse_file('spec/fixtures/simple.haproxy.cfg')
  end

  def parse_multi_pool
    parse_file('spec/fixtures/multi-pool.haproxy.cfg')
  end

  it "can parse servers from a backend server block" do
    parse_multi_pool

    backend = @result.backends.first
    backend.servers.size.should == 4
    backend.servers[0].name.should == 'prd_www_1'
    backend.servers[0].host.should == '10.214.78.95'
    backend.servers[0].port.should == '8000'
  end

  it 'can parse a service address from a frontend header' do
    parse_multi_pool

    frontend = @result.frontends.first
    frontend.frontend_header.service_address.host.content.should == '*'
    frontend.frontend_header.service_address.port.content.should == '85'
  end

  it 'can parse a service address from a listen header' do
    parse_single_pool

    listener = @result.listeners.first
    listener.listen_header.service_address.host.content.should == '55.55.55.55'
    listener.listen_header.service_address.port.content.should == '80'
  end

  it 'can parse a file with a listen section' do
    parse_single_pool

    @result.elements
    @result.class.should == HAProxy::Treetop::ConfigurationFile
    @result.elements.size.should == 5

    @result.elements[0].class.should == HAProxy::Treetop::CommentLine
    @result.elements[1].class.should == HAProxy::Treetop::BlankLine

    @result.global.should == @result.elements[2]
    @result.elements[2].class.should == HAProxy::Treetop::GlobalSection

    @result.defaults[0].should == @result.elements[3]
    @result.elements[3].class.should == HAProxy::Treetop::DefaultsSection

    @result.listeners[0].should == @result.elements[4]
    @result.elements[4].class.should == HAProxy::Treetop::ListenSection
  end

  it 'can parse a file with frontend/backend sections' do
    parse_multi_pool

    @result.class.should == HAProxy::Treetop::ConfigurationFile
    @result.elements.size.should == 5

    @result.global.should == @result.elements[0]
    @result.elements[0].class.should == HAProxy::Treetop::GlobalSection

    @result.defaults[0].should == @result.elements[1]
    @result.elements[1].class.should == HAProxy::Treetop::DefaultsSection

    @result.frontends[0].should == @result.elements[2]
    @result.elements[2].class.should == HAProxy::Treetop::FrontendSection

    @result.backends[0].should == @result.elements[3]
    @result.backends[1].should == @result.elements[4]
    @result.elements[3].class.should == HAProxy::Treetop::BackendSection
    @result.elements[4].class.should == HAProxy::Treetop::BackendSection
  end

  it 'can parse userlist sections' do
    parse_single_pool

    # The two userlists are functionally the same, so we should store them in a similiar manner.
    ['L1','L2'].each do |userlist_name|
      l = @result.userlists.detect { |userlist|
        userlist.name.content == userlist_name
      }

      l.should be # Make sure we have a userlist.

      # Only difference between the two objects should be the grouping method.
      # This will be interpreted at parse time, and used at render time.
      case userlist_name
        when 'L1'
          l.grouping.should == HAProxy::Userlist::GROUP
        when 'L2'
          l.grouping.should == HAProxy::Userlist::USER
      end

      l.group('G1').users.keys.should == ['tiger','scott']
      l.group('G2').users.keys.should == ['xdb','scott']

      l.user('tiger').password_type.should == 'md5'
      l.user('tiger').password.should == '$6$k6y3o.eP$JlKBx(...)xHSwRv6J.C0/D7cV91'

      l.user('scott').password_type.should == 'insecure-password'
      l.user('scott').password.should == 'elgato'

      l.user('tiger').groups.keys.should == ['G1']
      l.user('scott').groups.keys.should == ['G1','G2']
    end

  end
  
  it 'can parse valid units of time'
  it 'can parse strings with escaped spaces'
  it 'can parse files with escaped quotes'
  it 'can parse keywords with hyphens'
end

