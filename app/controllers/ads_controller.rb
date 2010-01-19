class AdsController < ApplicationController

  # show one particular ad
  def show
    @ad = Ad.find_by_id(params[:id])
    if (@ad.nil?)
      flash[:warning] = 'Error - That Ad Does Not Exist'
      redirect_to root_path
    end
    
    @category = @ad.category
  end
  
  # destroy ad with that particular hash
  def destroy
    if request.post?
      @ad = Ad.find_by_activation_hash(params[:id])
      if (@ad.nil?)
        flash[:warning] = 'Error - That Ad Does Not Exist'
        redirect_to root_path
        # report to admin?
      else
        # destroy the ad
        @ad.destroy
        flash[:notice] = 'Your Ad Has Been Removed'
        redirect_to root_path
      end
    end
  end
  
  # show a list of ads in a category
  # we need a clever way to do this - if both parent and child categories 
  # have a page slug how to identify one vs. the other?  might be easier to 
  # inherit then do this code checking tfor a blank array..
  def list
    @slug = params[:slug]
    @ads = Ad.all_active_by_slug(params[:slug])
    if !@ads
      flash[:warning] = 'Invalid Request'
      redirect_to root_path
    end
  end
  
  
  # show parent category list for new ad
  def post
    @parents = ParentCategory.find :all, :order => 'name ASC'
  end
  

  # ajaxy function to show subcategories when they select a parent
  def select_category
    @parent_category = ParentCategory.find_by_id(params[:id])
  end
  
  # show the ajaxy form for a new ad
  def show_form
    @category = Category.find_by_id(params[:id])
  end
  
  # ajaxy - create new ad
  def new
    if !(params[:email_verify] && params[:email] =~ /^[a-zA-Z0-9._%+-]+@virginia.edu$/)
      # ^[a-zA-Z0-9._%+-]+@virginia.edu$
      # return an error since email and confirmation don't match
      flash[:warning] = 'Please Provide a @virginia.edu email!'
      #@category = params[:category]
      # TODO
      # can we somehow send them to the last screen?
      redirect_to :controller => 'ads', :action => 'post'
    elsif (params[:email] != params[:email_verify])
      flash[:warning] = 'Your email addresses do not Match!'
      redirect_to :controller => 'ads', :action => 'post'
    elsif !(params[:price] =~ /^[0-9]/)
      flash[:warning] = 'Incorrect price formatting! Please do not in put $ signs!'  
      redirect_to :controller => 'ads', :action => 'post'
    elsif !(params[:course] =~ /^[0-9]/)
      flash[:warning] = 'Please only enter course number eg: "1120" ' 
      redirect_to :controller => 'ads', :action => 'post'
    else
      # email and confirmation match
      @author = Author.find_by_email(params[:email])
      if @author.blank?
        @author = Author.new
        @author.email = params[:email]
        @author.ip = request.env['REMOTE_ADDR']
        @author.save
      end
      @ad = Category.find_by_id(params[:category]).ads.new
      @ad.title = params[:title]
      @ad.price = params[:price]
      @ad.course = params[:course]
      @ad.ad = params[:ad].gsub("\n", "<br/>")
      @ad.expiration = Time.now + 30.days
      @ad.created_at = Time.now
      @ad.author = @author
      
      # record author IP address
      @ad.author_ip = request.env['REMOTE_ADDR']
      @ad.save
      
 

      # send confirmation email with activation url
      Mailman.deliver_confirmation_email(@ad, @author.email)
      flash[:notice] = 'A Confirmation Email Has Been Sent To ' + @author.email
      
    end
  end
  
  # activate an ad that is new but not active yet
  def activate
    @ad = Ad.find_by_activation_hash(params[:activation_hash])
    if (@ad.nil?)
      flash[:warning] = 'Error Activating Your Ad'
      redirect_to root_path
      #report to admin?
    else
      # not sure we need this?
      #respond_to do |format|
        #redirect to confirmation thank you page
        if @ad.activate(params[:activation_hash])
          flash[:notice] = 'Your Ad Has Been Activated - An Email Has Been Sent To ' + @ad.author.email
          Mailman.deliver_activation_email(@ad, @ad.author.email)
          #redirect_to :action => 'show', :id => @ad
          redirect_to :action => 'edit', :activation_hash => @ad.activation_hash
        else
          flash[:warning] = 'Error Activating Your Ad'
          redirect_to root_path
        end
        #format.html {render :action => "confirmed"}
      #end
    end
  end
  
  
  # manage an ad based on the hash
  def manage
    @ad = Ad.find_by_activation_hash(params[:activation_hash])
    if (@ad.nil?)
      flash[:warning] = 'Error - That Ad Does Not Exist'
      redirect_to root_path
      # report to admin?
    else
      # show the ad and let them edit it
      # going to use our own rhtml with edit buttons etc.
      #render :action => 'show'
    end
  end
  
  # edit an ad based on the hash
  def edit
    @ad = Ad.find_by_activation_hash(params[:activation_hash])
    if (@ad.nil?)
      flash[:warning] = 'Error - That Ad Does Not Exist'
      redirect_to root_path
      # report to admin?
    else
      # show the ad and let them edit it
    end
  end
  
  # update an ad after someone edits (via the edit form) and hits 'submit'
  def update
    @ad = Ad.find_by_activation_hash(params[:activation_hash])
    if (@ad.nil?)
      flash[:warning] = 'Error - That Ad Does Not Exist'
      redirect_to root_path
      # report to admin?
    else
      @ad.ad = params[:ad].gsub("\n", "<br/>")
      @ad.title = params[:title]
      if @ad.save
        
        # handle image attachments
        @ad.handle_images(params["image_attachments"])
        
        flash[:notice] = "Ad Updated Successfully"
      else
        flash[:warning] = "Error Updating Ad"
      end
      redirect_to :controller => 'ads', :action => 'manage', :activation_hash => @ad.activation_hash
    end    
  end
  
  def delete_image
    @ad = Ad.find_by_activation_hash(params[:activation_hash])
    @ad_image = @ad.ad_images.find_by_id(params[:id])
    
    if @ad_image.destroy
      flash[:notice] = "Ad Image Deleted"
    else
      flash[:warning] = "Unable to Find Ad Image to Delete"
    end
    
    redirect_to :controller => 'ads', :action => 'manage', :activation_hash => @ad.activation_hash
  end
  
  
  # rss feed for the whole site
  def feed
    @ads = Ad.all_active
    
    respond_to do |format|
      format.rss { render :layout => false }
      format.atom # index.atom.builder
    end
  end
  
  # rss feed for just one category
  def category_feed
    @ads = Ad.all_active_by_slug(params[:slug])
    
    respond_to do |format|
      format.rss { render :layout => false }
      format.atom # index.atom.builder
    end
  end
  
  
end
