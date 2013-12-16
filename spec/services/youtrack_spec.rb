require 'spec_helper'

describe Service::YouTRACK do
  it 'should have a title' do
    Service::YouTRACK.title.should == 'YouTRACK'
  end

  let(:service) { described_class.new('event_name', {}, {}) }
  let(:config) do
    {
        :url      => 'http://youtrack/youtrack',
        :project  => 'MOBILE',
        :username => 'username',
        :password => 'password'
    }
  end
  let(:issue) do
    {
        :title                  => 'foo title',
        :method                 => 'method name',
        :impact_level           => 1,
        :impacted_devices_count => 1,
        :crashes_count          => 1,
        :app                    => {
            :name              => 'foo name',
            :bundle_identifier => 'foo.bar.baz'
        },
        :url                    => 'http://foo.com/bar'
    }
  end

  describe :login do
    it 'should return true' do
      mock_faraday = double('Faraday', :status => 200, :headers => {'set-cookie' => 'cookie'})
      service.should_receive(:http_post)
      .with("#{config[:url]}/rest/user/login", {:login => config[:username], :password => config[:password]})
      .and_return(mock_faraday)
      res = service.send :login, config
      res.should be_true
    end

    it 'should return false if fail' do
      mock_faraday = double('Faraday', :status => 500, :headers => {'set-cookie' => 'cookie'})
      service.should_receive(:http_post)
      .with("#{config[:url]}/rest/user/login", {:login => config[:username], :password => config[:password]})
      .and_return(mock_faraday)
      res = service.send :login, config
      res.should be_false
    end
  end


  describe :receive_verification do
    it 'Should succeed if login' do
      service.should_receive(:login).with(config).and_return(true)
      response = service.receive_verification(config, '')
      response.should == [true, 'YouTRACK connection OK']
    end
    it 'Should fail if wrong credentials' do
      service.should_receive(:login).with(config).and_return(false)
      response = service.receive_verification(config, '')
      response.should == [false, 'Oops! Please check your settings again.']
    end
    it 'Should fail if exception' do
      service.should_receive(:login).with(config).and_raise
      response = service.receive_verification(config, '')
      response.should == [false, 'Oops! Please check your settings again.']
    end
  end

  describe :receive_issue_impact_change do
    it 'Should succeed' do
      service.should_receive(:login).with(config).and_return(true)
      mock_params = double('Request', :params => Hash.new) # can't make this work double('params').should_receive(:update).with(...) meaning I can't test the message itself
      mock_faraday = double('Faraday', :status => 201)
      service.should_receive(:http_method).with(:put, 'http://youtrack/youtrack/rest/issue').and_yield(mock_params).and_return(mock_faraday)
      service.receive_issue_impact_change(config, issue)
    end

    it 'Should fail if post fail' do
      service.should_receive(:login).with(config).and_return(true)
      mock_faraday = double('Faraday', :status => 500, :body => 'fail')
      service.should_receive(:http_method).with(:put, 'http://youtrack/youtrack/rest/issue').and_return(mock_faraday)
      expect { service.receive_issue_impact_change(config, issue) }.to raise_exception 'YouTRACK issue Create Failed: 500, body: fail'
    end

    it 'Should fail if wrong login' do
      service.should_receive(:login).with(config).and_return(false)
      expect { service.receive_issue_impact_change(config, issue) }.to raise_exception 'Invalid login'
    end
  end
end
