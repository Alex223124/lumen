Lumen::App.controllers do
  
  before do
    @env = {
      :APP_NAME => 'App name (lowercase, no spaces) - Heroku app name if using Heroku',
      :HEROKU_API_KEY => 'Heroku API key',

      :DOMAIN => 'Domain of Lumen install',
      :MAIL_DOMAIN => 'Domain from which mails will be sent and received',

      :VIRTUALMIN_IP => 'IP for Virtualmin installation',
      :VIRTUALMIN_USERNAME => 'Username for Virtualmin',
      :VIRTUALMIN_PASSWORD => 'Password for Virtualmin',

      :S3_BUCKET_NAME => 'S3 bucket name',
      :S3_ACCESS_KEY => 'S3 access key',
      :S3_SECRET => 'S3 secret',  

      :SITE_NAME => 'Name of site e.g. Lumen Users Network',
      :SITE_NAME_DEFINITE => "Name of site with 'the' if appropriate e.g. The Lumen Users Network",
      :SITE_NAME_SHORT => 'Short site name e.g. LUN',
      :NOREPLY_NAME => "Name of email sender for general emails",
      :NOREPLY_SIG => "Email signature for general emails",
      :HELP_ADDRESS => 'Email address for general queries',

      :ENV_FIELDS_ACCOUNT => 'Extra fields for the Account model e.g. biography:wysiwyg,research_proposal:file',
      :ENV_FIELDS_EVENT => 'Extra fields for the Event model',
  
      :AFFILIATION_POSITIONS => 'Comma-separated list of acceptable positions e.g. Novice,Intermediate,Master',
      :ACCOUNT_TAGS_PREDEFINED => ['Turns the tagships profile field into a series of checkboxes'],
      :AUTO_JOIN_VIA_TAGS => ['Automatically joins people to groups based on their account tags'],
          
      :HIDE_SEARCH_MEMBERSHIPS => ['Hides group memberships on profile search results'],
      :HIDE_SEARCH_TAGS => ['Hides tags on profile search results'],
      :HIDE_ORGANISATIONS_TAB => ['Hides the \'organisations\' tab'],
      :HIDE_SECTORS_TAB => ['Hides the \'sectors\' tab'],
      :HIDE_DIRECTORY_TAB => ['Hides the \'All groups\' tab'],
      :HIDE_DIGEST_TAB => ['Hides the \'Digest\' tab'],
      :HIDE_NEWS_TAB => ['Hides the \'News\' tab'],
      :HIDE_WALL_TAB => ['Hides the \'Wall\' tab'],
      :USE_TAGGED_POSTS => ['Uses the \'tagged posts\' wall style'],
      :HIDE_HOME_WALL_COMPOSE_BOX => ['Hides the homepage wall compose box'],      
      :HIDE_MAP_FORM => ['Hides map form'],
      
      :SHOW_PEOPLE_BY_DEFAULT => ['Shows people on maps by default'],
      :SHOW_SPACES_BY_DEFAULT => ['Shows spaces on maps by default'],
      :SHOW_ORGS_BY_DEFAULT => ['Shows organisations on maps by default'],
  
      :STACKED_HOME => ['Hides the homepage tabs and stacks the content instead'],
    
      :ICON_ORGANISATIONS => 'Alternative Font Awesome icon name for organisations tab',
      :ICON_SECTORS => 'Alternative Font Awesome icon name for sectors tab',
    
      :NEWSME_SWITCH_HOUR => "Hour to switch over to today's news summaries e.g. 11",  

      :FACEBOOK_KEY => 'Facebook API key',
      :FACEBOOK_SECRET => 'Facebook API secret',
      :LINKEDIN_KEY => 'LinkedIn API key',
      :LINKEDIN_SECRET => 'LinkedIn API secret',
      :GOOGLE_KEY => 'Google API key',
      :GOOGLE_SECRET => 'Google API secret',
      :TWITTER_KEY => 'Twitter API key',
      :TWITTER_SECRET => 'Twitter API secret',

      :AIRBRAKE_HOST => 'Airbrake host (no http://)',
      :AIRBRAKE_API_KEY => 'Airbrake API key'  
    } 
    
    @fragments = {
      :'about' => 'Text of about page',
      :'sign-in' => 'Text displayed on sign in page',
      :'first-time' => 'Text displayed on account edit page upon first login',
      :'home' => 'If defined, creates a default landing tab on the homepage with this text',
      :'public-homepage' => 'If defined, creates a public homepage with this HTML',
      :'head' => 'Extra content for &lt;head&gt;',
      :'navbar' => 'Extra content for the navbar',
      :'tip-affiliations' => 'Tip for affiliations field on account edit page',
      :'tip-location' => 'Tip for location field on account edit page',
      :'reminder' => 'Alternative text for reminder emails',
      :'invite' => 'Additional text for invite emails'
    }    
  
    @translations = %w{organisation organisations host_organisation sector sectors position positions account_tagship account_tagships}
  end
  
  get '/config' do
    site_admins_only!
    if ENV['HEROKU_API_KEY'] and ENV['VIRTUALMIN_IP']
      Net::SSH.start(ENV['VIRTUALMIN_IP'], ENV['VIRTUALMIN_USERNAME'], :password => ENV['VIRTUALMIN_PASSWORD']) do |ssh|
        result = ''
        ssh.exec!("ls /notify") do |channel, stream, data|
          result << data
        end
        @notification_script = result.include?("#{ENV['APP_NAME']}.php")      
      end
    end
    erb :config
  end
     
  post '/config' do
    site_admins_only!
    heroku = Heroku::API.new
    params[:edited].each { |k|
      if params[k]
        heroku.put_config_vars(ENV['APP_NAME'], k => params[k])
      else
        heroku.delete_config_var(ENV['APP_NAME'], k)
      end
    } if params[:edited]
    flash[:notice] = "Your config vars were updated. There may be a short delay before your changes are reflected on this page."
    redirect '/config'
  end  
  
  get '/config/restart' do
    site_admins_only!
    heroku = Heroku::API.new
    heroku.post_ps_restart(ENV['APP_NAME'])
    redirect '/config'
  end
    
  get '/config/create_notification_script' do
    site_admins_only!
    require 'net/scp'
    Net::SSH.start(ENV['VIRTUALMIN_IP'], ENV['VIRTUALMIN_USERNAME'], :password => ENV['VIRTUALMIN_PASSWORD']) do  |ssh|
      ssh.exec!("mkdir /notify")
      ssh.exec!("chmod 777 /notify")
      Net::SCP.start(ENV['VIRTUALMIN_IP'], ENV['VIRTUALMIN_USERNAME'], :password => ENV['VIRTUALMIN_PASSWORD']) do |scp|
        scp.upload! StringIO.new(erb(:'notify/notify.php', :layout => false)), "/notify/#{ENV['APP_NAME']}.php"
        scp.upload! Padrino.root('app','views','notify','PlancakeEmailParser.php'), "/notify"
      end
      ssh.exec!("chmod 777 /notify/*")
    end
    redirect '/config'
  end  
    
end