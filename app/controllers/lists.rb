Lumen::App.controllers do
  
  get '/groups/:slug/lists' do
    @group = Group.find_by(slug: params[:slug])
    membership_required! unless @group.open?
    @lists = @group.lists.order_by(:title.asc)      
    if request.xhr?
      partial :'lists/lists', :locals => {:lists => @lists}
    else
      membership_required!
      erb :'groups/lists'
    end        
  end
  
  post '/groups/:slug/lists/create' do
    @group = Group.find_by(slug: params[:slug])
    membership_required!
    if params[:title]
      @list = @group.lists.create :title => params[:title], :account => current_account
      redirect "/groups/#{@group.slug}/lists/#{@list.id}"
    else
      redirect back
    end
  end  
  
  get '/groups/:slug/lists/:id/destroy' do
    @group = Group.find_by(slug: params[:slug])
    membership_required!
    @group.lists.find(params[:id]).destroy
    flash[:notice] = 'The list was deleted.'
    redirect "/groups/#{@group.slug}/lists"
  end   
   
  get '/groups/:slug/lists/:id', :provides => [:html, :csv] do
    @group = Group.find_by(slug: params[:slug])
    membership_required! unless @group.open?
    @list = @group.lists.find(params[:id])
    case content_type
    when :html
      erb :'lists/list'     
    when :csv
      CSV.generate do |csv|
        csv << (fields = [:title,:link,:address,:content])
        @list.list_items.each do |list_item|
          csv << fields.map { |f| list_item.send(f) }
        end
      end      
    end
  end
    
  post '/groups/:slug/lists/:id/add' do
    @group = Group.find_by(slug: params[:slug])
    membership_required!
    @list = @group.lists.find(params[:id])
    data = params[:data] || "#{params[:title]}\t#{params[:link]}\t#{params[:address]}\t#{params[:content]}"
    data.split("\n").reject { |line| line.blank? }.each { |line|      
      title, link, address, content = line.split("\t")
      title.strip! if title
      link.strip! if link
      address.strip! if address
      content.strip! if content
      @list.list_items.create :title => title, :link => link, :address => address, :content => content, :account => current_account
    }
    redirect "/groups/#{@group.slug}/lists/#{@list.id}"
  end
    
  get '/groups/:slug/lists/:id/vote/:list_item_id/:val' do
    @group = Group.find_by(slug: params[:slug])
    membership_required!
    @list = @group.lists.find(params[:id])
    @list_item = @list.list_items.find(params[:list_item_id])
    @list_item.list_item_votes.create(value: params[:val], account: current_account)
    redirect "/groups/#{@group.slug}/lists/#{@list.id}"
  end 
  
  get '/groups/:slug/lists/:id/destroy/:list_item_id' do
    @group = Group.find_by(slug: params[:slug])
    membership_required!
    @list = @group.lists.find(params[:id])
    @list_item = @list.list_items.find(params[:list_item_id])
    @list_item.destroy
    redirect "/groups/#{@group.slug}/lists/#{@list.id}"
  end       
  
  get '/groups/:slug/lists/:id/new' do
    @group = Group.find_by(slug: params[:slug])
    membership_required!
    @list = @group.lists.find(params[:id])
    @list_item = @list.list_items.build
    erb :'lists/list_item'
  end
  
  post '/groups/:slug/lists/:id/new' do
    @group = Group.find_by(slug: params[:slug])
    membership_required!
    @list = @group.lists.find(params[:id])
    @list_item = @list.list_items.build(params[:list_item])
    @list_item.account = current_account
    if @list_item.save  
      flash[:notice] = "<strong>Great!</strong> The item was created successfully."
      redirect "/groups/#{@group.slug}/lists/#{@list.id}"
    else
      flash.now[:error] = "<strong>Oops.</strong> Some errors prevented the item from being saved."
      erb :'lists/list_item'
    end
  end   
  
  get '/groups/:slug/lists/:id/edit/:list_item_id' do
    @group = Group.find_by(slug: params[:slug])
    membership_required!
    @list = @group.lists.find(params[:id])
    @list_item = @list.list_items.find(params[:list_item_id])
    erb :'lists/list_item'
  end
  
  post '/groups/:slug/lists/:id/edit/:list_item_id' do
    @group = Group.find_by(slug: params[:slug])
    membership_required!
    @list = @group.lists.find(params[:id])
    @list_item = @list.list_items.find(params[:list_item_id])
    if @list_item.update_attributes(params[:list_item])
      flash[:notice] = "<strong>Great!</strong> The item was updated successfully."
      redirect "/groups/#{@group.slug}/lists/#{@list.id}"
    else
      flash.now[:error] = "<strong>Oops.</strong> Some errors prevented the item from being saved."
      erb :'lists/list_item'
    end
  end   
      
end