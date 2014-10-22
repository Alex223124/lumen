Lumen::App.controllers do
  
  get '/groups/:slug/check' do
    site_admins_only!
    @group = Group.find_by(slug: params[:slug]) || not_found
    @group.check!
    redirect "/groups/#{@group.slug}"
  end   
  
  get '/groups/:slug/edit' do
    @group = Group.find_by(slug: params[:slug])
    group_admins_only!
    erb :'groups/build'
  end
  
  post '/groups/:slug/edit' do
    @group = Group.find_by(slug: params[:slug])
    group_admins_only!
    if @group.update_attributes(params[:group])
      flash[:notice] = "<strong>Great!</strong> The group was updated successfully."
      redirect "/groups/#{@group.slug}"
    else
      flash.now[:error] = "<strong>Oops.</strong> Some errors prevented the group from being saved."
      erb :'groups/build'
    end    
  end   
  
  get '/groups/:slug/emails' do
    @group = Group.find_by(slug: params[:slug])
    group_admins_only!
    erb :'group_administration/emails'
  end
  
  post '/groups/:slug/emails' do
    @group = Group.find_by(slug: params[:slug])
    group_admins_only!
    if @group.update_attributes(params[:group])
      flash[:notice] = "<strong>Great!</strong> The group emails were updated successfully."
      redirect "/groups/#{@group.slug}"
    else
      flash.now[:error] = "<strong>Oops.</strong> Some errors prevented the emails from being saved."
      erb :'group_administration/emails'
    end    
  end 
  
  
  get '/groups/:slug/landing_tab' do
    @group = Group.find_by(slug: params[:slug])
    group_admins_only!
    erb :'group_administration/landing_tab'
  end
  
  post '/groups/:slug/landing_tab' do
    @group = Group.find_by(slug: params[:slug])
    group_admins_only!
    if @group.update_attributes(params[:group])
      flash[:notice] = "<strong>Great!</strong> The landing tab was updated successfully."
      redirect "/groups/#{@group.slug}"
    else
      flash.now[:error] = "<strong>Oops.</strong> Some errors prevented the landing tab from being saved."
      erb :'group_administration/landing_tab'
    end    
  end   
  
  get '/groups/:slug/manage_members' do
    @group = Group.find_by(slug: params[:slug])
    group_admins_only!
    @view = params[:view] ? params[:view].to_sym : :admins
    @memberships = case @view
    when :admins
      @group.memberships.where(:admin => true)
    when :others
      @group.memberships.where(:admin.ne => true)
    when :not_completed_signup
      @group.memberships.where(:status => 'pending')
    when :no_picture
      @group.memberships.where(:account_id.in => Account.where(:has_picture => false).only(:id).map(&:id))
    when :no_affiliations
      @group.memberships.where(:account_id.nin => Affiliation.only(:account_id).map(&:account_id))
    when :notification_level_none
      @group.memberships.where(:notification_level => 'none')
    when :connected_to_twitter
      @group.memberships.where(:account_id.in => ProviderLink.where(provider: 'Twitter').only(:account_id).map(&:account_id))
    when :geocoding_failed
      @group.memberships.where(:account_id.in => Account.where(:location.ne => nil, :coordinates => nil).only(:id).map(&:id))
    when :requests
      @group.membership_requests.where(:status => 'pending') # quacks like a membership
    end
    @memberships = case @view
    when :connected_to_twitter
      @memberships.sort_by { |membership| membership.account.provider_links.find_by(provider: 'Twitter').created_at }.reverse
    when :requests
      @memberships.order(:created_at.desc)
    else
      @memberships.sort_by { |membership| membership.account.name }
    end
    erb :'group_administration/manage_members'
  end
   
  get '/groups/:slug/remove_member/:account_id' do
    @group = Group.find_by(slug: params[:slug])
    group_admins_only!
    @membership = @group.memberships.find_by(account_id: params[:account_id])
    @membership.destroy
    flash[:notice] = "#{@membership.account.name} was removed from the group"
    redirect back
  end 
  
  get '/groups/:slug/receive_membership_requests/:account_id' do
    @group = Group.find_by(slug: params[:slug])
    group_admins_only!
    @membership = @group.memberships.find_by(account_id: params[:account_id])
    @membership.update_attribute(:receive_membership_requests, true)
    flash[:notice] = "#{@membership.account.name} will now be notified of membership requests"
    redirect back
  end   
  
  get '/groups/:slug/stop_receiving_membership_requests/:account_id' do
    @group = Group.find_by(slug: params[:slug])
    group_admins_only!
    @membership = @group.memberships.find_by(account_id: params[:account_id])
    @membership.update_attribute(:receive_membership_requests, false)
    flash[:notice] = "#{@membership.account.name} will no longer be notified of membership requests"
    redirect back
  end   
  
  get '/groups/:slug/make_admin/:account_id' do
    @group = Group.find_by(slug: params[:slug])
    group_admins_only!
    @membership = @group.memberships.find_by(account_id: params[:account_id])
    @membership.update_attribute(:admin, true)
    flash[:notice] = "#{@membership.account.name} was made an admin"
    redirect back
  end   
  
  get '/groups/:slug/unadmin/:account_id' do
    @group = Group.find_by(slug: params[:slug])
    group_admins_only!
    @membership = @group.memberships.find_by(account_id: params[:account_id])
    @membership.update_attribute(:admin, false)
    @membership.update_attribute(:receive_membership_requests, false)
    flash[:notice] = "#{@membership.account.name}'s admin rights were revoked"
    redirect back
  end   

  get '/groups/:slug/set_notification_level/:account_id' do
    @group = Group.find_by(slug: params[:slug])
    group_admins_only!
    @membership = @group.memberships.find_by(account_id: params[:account_id])
    @membership.update_attribute(:notification_level, params[:level])
    flash[:notice] =  "#{@membership.account.name}'s notification options were updated"
    redirect back
  end   
  
  post '/groups/:slug/invite' do 
    @group = Group.find_by(slug: params[:slug])
    group_admins_only!
    notices = []
    data = params[:data] || "#{params[:name]}\t#{params[:email]}"
    data.split("\n").reject { |line| line.blank? }.each { |line|
      name, email = line.split("\t")
      if !email
        notices << "Please provide an email address for #{name}"
        next
      end
      name.strip!
      email.strip!
      
      if !(@account = Account.find_by(email: /^#{Regexp.escape(email)}$/i))   
        @new_account = true
        @account = Account.new({
            :name => name,
            :password => Account.generate_password(8),
            :email => email
          })
        @account.password_confirmation = @account.password
        if !@account.save
          notices << "Failed to create an account for #{email} - is this a valid email address?"
          next
        end
      else
        @new_account = false
      end
      
      if @group.memberships.find_by(account: @account)
        notices << "#{email} is already a member of this group."
        next
      end
      
      @membership = @group.memberships.build :account => @account
      @membership.admin = true if params[:admin]
      @membership.status = 'confirmed' if params[:status] == 'confirmed'
      @membership.save
      
      group = @group # instance var not available in defaults block
      Mail.defaults do
        delivery_method :smtp, group.smtp_settings
      end    
      
      sign_in_details = ''
      if @membership.status == 'pending'
        sign_in_details << "You need to sign in to start receiving email notifications. "
      end
      if @new_account
        sign_in_details << "Sign in at http://#{ENV['DOMAIN']}/sign_in with the email address #{@account.email} and the password #{@account.password}."
      else
        sign_in_details << "Check it out at http://#{ENV['DOMAIN']}/groups/#{@group.slug}."
      end
               
      b = @group.invite_email
      .gsub('[firstname]',@account.name.split(' ').first)
      .gsub('[admin]', current_account.name)
      .gsub('[sign_in_details]', sign_in_details)      
            
      mail = Mail.new
      mail.to = @account.email
      mail.from = "#{@group.slug} <#{@group.email('-noreply')}>"
      mail.subject = @group.invite_email_subject
      mail.html_part do
        content_type 'text/html; charset=UTF-8'
        body b
      end
      mail.deliver              
      notices << "#{email} was added to the group."
    }
    flash[:notice] = notices.join('<br />') if !notices.empty?
    redirect back
  end
  
  get '/groups/:slug/reminder' do
    @group = Group.find_by(slug: params[:slug])
    group_admins_only!
    membership = @group.memberships.find_by(account_id: params[:account_id])
    @account = membership.account
    @issue = case params[:issue].to_sym
    when :not_completed_signup
      "signed in to complete your profile"
    when :no_affiliations
      "provided your organisational affiliations"
    when :no_picture
      "uploaded a profile picture"
    end

    group = @group # instance var not available in defaults block
    Mail.defaults do
      delivery_method :smtp, group.smtp_settings
    end    
    
    b = @group.reminder_email
    .gsub('[firstname]',@account.name.split(' ').first)
    .gsub('[admin]', current_account.name)
    .gsub('[issue]',@issue)
            
    mail = Mail.new
    mail.to = @account.email
    mail.from = "#{@group.slug} <#{@group.email('-noreply')}>"
    mail.cc = current_account.email
    mail.subject = @group.reminder_email_subject
    mail.html_part do
      content_type 'text/html; charset=UTF-8'
      body b
    end
    mail.deliver    
    membership.update_attribute(:reminder_sent, Time.now)
    redirect back
  end
          
  get '/groups/:slug/didyouknows' do
    @group = Group.find_by(slug: params[:slug])
    group_admins_only!       
    erb :'group_administration/didyouknows'
  end  
  
  post '/groups/:slug/didyouknows/add' do
    @group = Group.find_by(slug: params[:slug])
    group_admins_only!
    @group.didyouknows.create :body => params[:body]
    redirect back
  end    
  
  get '/groups/:slug/didyouknows/:id/destroy' do
    @group = Group.find_by(slug: params[:slug])
    group_admins_only!
    @group.didyouknows.find(params[:id]).destroy
    redirect back
  end 
  
  get '/groups/:slug/process_membership_request/:id' do
    @group = Group.find_by(slug: params[:slug])
    group_admins_only!
    membership_request = @group.membership_requests.find(params[:id])    
    if params[:accept]
      @account = membership_request.account      
      if @account.sign_ins.count == 0
        password = Account.generate_password(8)
        @account.update_attribute(:password, password) 
        sign_in_details = "You need to sign in to start receiving email notifications. Sign in at http://#{ENV['DOMAIN']}/sign_in with the email address #{@account.email} and the password #{password}."
      else
        sign_in_details = "Sign in at http://#{ENV['DOMAIN']}/sign_in."
      end
    
      group = @group # instance var not available in defaults block
      Mail.defaults do
        delivery_method :smtp, group.smtp_settings
      end      
      
      b = @group.membership_request_acceptance_email
      .gsub('[firstname]',@account.name.split(' ').first)
      .gsub('[sign_in_details]', sign_in_details)
              
      mail = Mail.new
      mail.to = @account.email
      mail.from = "#{@group.slug} <#{@group.email('-noreply')}>"
      mail.subject = @group.membership_request_acceptance_email_subject
      mail.html_part do
        content_type 'text/html; charset=UTF-8'
        body b
      end
      mail.deliver      
            
      membership_request.update_attribute(:status, 'accepted')
      @group.memberships.create(:account => @account)      
    else
      membership_request.update_attribute(:status, 'rejected')
    end
    redirect back
  end
  
  get '/groups/:slug/stats' do    
    @group = Group.find_by(slug: params[:slug]) || not_found
    group_admins_only!
      
    @c = {}    
    @group.conversations.where(:hidden.ne => true).only(:id, :account_id).each_with_index { |conversation|
      @c[conversation.account_id] = [] if !@c[conversation.account_id]
      @c[conversation.account_id] << conversation.id
    }
        
    @cp = {}  
    @group.conversation_posts.where(:hidden.ne => true).only(:id, :account_id).each_with_index { |conversation_post|
      @cp[conversation_post.account_id] = [] if !@cp[conversation_post.account_id]
      @cp[conversation_post.account_id] << conversation_post.id    
    }
    
    @e = {}
    @group.events.only(:id, :account_id).each { |event|
      @e[event.account_id] = [] if !@e[event.account_id]
      @e[event.account_id] << event.id
    }    
    
    erb :'group_administration/stats'
  end  
      
end