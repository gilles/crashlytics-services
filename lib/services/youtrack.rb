class Service::YouTRACK < Service::Base
  title 'YouTRACK'

  string :url,
         :label => 'URL to YouTRACK:'
  string :project,
         :label => 'YouTRACK Project:'
  string :username,
         :placeholder => 'username',
         :label       => 'Username:'
  password :password,
           :placeholder => 'password',
           :label       => 'Password:'

  page 'Project', [:url, :project]
  page 'Login Information', [:username, :password]

  def receive_issue_impact_change(config, payload)
    res = login(config)
    unless res
      raise 'Invalid login'
    end

    if payload[:impacted_devices_count] == 1
      users_text = 'This issue is affecting at least 1 user who has crashed '
    else
      users_text = "This issue is affecting at least #{payload[:impacted_devices_count]} users who have crashed"
    end

    if payload[:crashes_count] == 1
      crashes_text = 'at least 1 time.'
    else
      crashes_text = "at least #{payload[:crashes_count]} times."
    end

    issue_description = [
        'Crashlytics detected a new issue.',
        "#{payload[:title]} in #{payload[:method]}\n",
        "#{users_text} #{crashes_text}\n",
        "More information: #{payload[:url]}"
    ].join("\n")

    params = {
        :project     => config[:project],
        :summary     => "[Crashlytics] #{payload[:title]}",
        :description => issue_description
    }

    resp = http_method :put, "#{config[:url]}/rest/issue" do |req|
      req.params.update(params)
    end
    if resp.status != 201
      raise "YouTRACK issue Create Failed: #{ resp.status }, body: #{ resp.body }"
    end
  end

  def receive_verification(config, _)
    res = login(config)
    puts res
    if res
      [true, 'YouTRACK connection OK']
    else
      log "HTTP Error: status code: #{res.status}, body: #{res.body}"
      [false, 'Oops! Please check your settings again.']
    end
  rescue => e
    log "Rescued a verification error in jira: (url=#{config[:project_url]}) #{e}"
    [false, 'Oops! Please check your settings again.']
  end

  private

  def login(config)
    res = http_post "#{config[:url]}/rest/user/login", {:login => config[:username], :password => config[:password]}
    # I tries too add faraday cookie middleware without success, do it manually
    http.headers['Cookie'] = res.headers['set-cookie']
    ret = res.status == 200
    ret
  end

end
