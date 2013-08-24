require 'rubygems'
require 'sinatra'
require 'data_mapper'
require 'digest/md5'
require 'dm-core'
DataMapper::setup(:default, "sqlite3://#{Dir.pwd}/App_test.db")

class User
  include DataMapper::Resource  
  property :username, Text, :required => true, :key => true
  property :email, Text, :required => true  
  property :password, Text, :required => true
  property :photo, Text
  property :created_at, DateTime  
  property :updated_at, DateTime  
  has n, :posts
  has n, :messages
  has n, :comments
end 

class Message
  include DataMapper::Resource   
  property :subject, Text, :required => true , :key => true
  property :content, Text, :required => true  
  property :receiver, Text, :required => true  
  property :status, Text, :required => true  
  property :created_at, DateTime  
  property :updated_at, DateTime  
  belongs_to :user
end 

class Post
  include DataMapper::Resource   
  property :title, Text, :required => true , :key => true
  property :content, Text 
  property :photo, Text
  property :video, Text
  property :archive, Text, :required => true  
  property :created_at, DateTime  
  property :updated_at, DateTime  
  belongs_to :user
  has n, :comments
end  

class Comment
  include DataMapper::Resource   
  property :id, Serial  
  property :content, Text, :required => true  
  property :like, Integer, :required => true  
  property :created_at, DateTime  
  property :updated_at, DateTime  
  belongs_to :post
  belongs_to :user
end  

DataMapper.finalize.auto_upgrade!

enable :sessions
APP_SECRET = "AuGmEntTnEmGuA"

#helper
helpers do

  def validate(username, password)
    u = User.get(username)
    if u!=nil
      encrypted_password = Digest::MD5.hexdigest(APP_SECRET + password)
      if (u.username==username and u.password==encrypted_password)
        return true
      end
    else
      return false
    end
  end

  def is_logged_in?
    session["logged_in"] == true
  end

  def clear_session
    session.clear
  end

  def the_user_name
    if is_logged_in? 
      session["username"] 
    else
      "not logged in"
      end
    end
  end

  def get_user(the_user_name)
    if the_user_name !="not logged in"
      current_user = User.get(the_user_name)
    else
      current_user = User.get("anonymous")
    end
    return current_user
  end

  get '/search' do
    puts @new_messages_number
    @found_posts = Post.all(:title.like => "") 
    erb :search
  end

  post '/search' do
    puts @new_messages_number
    str_title="%"+params[:tbftitle]+"%"
    str_content="%"+params[:tbfcontent]+"%"
    str_archive="%"+params[:tbfarchive]+"%"
    @found_posts_title = Post.all(:title.like => str_title) 
    @found_posts_content=@found_posts_title.all(:content.like => str_content)
    if @found_posts_content!=nil
      @found_posts=@found_posts_content
    else
      @found_posts_content=Post.all
    end

    if params[:tbfarchive]!=""
      @found_posts_content.each do |post| 
        file = File.new(post.archive) 
        @text = file.read
        if @text.include? params[:tbfarchive] then
        else
          post.content=""
        end
      end
    end
    erb :search
  end

  get '/my_messages' do
    puts @new_messages_number
    @messages = Message.all(:order => :created_at.desc) 
    erb :my_messages
  end

  post '/my_messages' do
    current_user=get_user(the_user_name)
    new_message=Message.new
    new_message.subject=params[:subject]
    new_message.receiver=params[:to]
    new_message.content=params[:message]
    new_message.status="unread"
    new_message.created_at=Time.now
    new_message.updated_at=Time.now
    new_message.save
    current_user.messages << new_message
    current_user.save
    redirect '/my_messages'
  end

  get '/my_posts' do
    puts @new_messages_number
    @posts = Post.all(:user_username => the_user_name ,:order => :updated_at.desc) 
    erb :my_posts
  end

  get '/' do
    puts "test"
    puts @new_messages_number
    @posts = Post.all :order => :updated_at.desc
    @comments = Comment.all :order => :updated_at.asc
    erb :index
  end

  get '/about' do
    puts @new_messages_number
    erb :about
  end

  get '/login' do
    puts @new_messages_number
    erb :login
  end

  def create_anonymous_if_not_exists
    if User.get("anonymous")==nil
      anonymous=User.new
      anonymous.username="anonymous"
      anonymous.email="ddd"
      encrypted_password = Digest::MD5.hexdigest(APP_SECRET + "anonymouspwd")
      anonymous.password=encrypted_password
      anonymous.created_at=Time.now
      anonymous.updated_at=Time.now
      anonymous.save
    end
  end

  get '/index' do
    puts @new_messages_number
    erb :index
  end

  post '/index' do
    current_user=get_user(the_user_name)
    archive_file_path="./archive/"+params[:title]+"_archive.txt"
    new_post=Post.new
    new_post.title=params[:title]
    new_post.content=params[:content]
    new_post.archive=archive_file_path
    if params['myfile']!=nil
      new_post.photo='./users_photos/' + params['myfile'][:filename]
    end
    if params['myvideo']!=nil
      new_post.video='./users_videos/' + params['myvideo'][:filename]
    end
    new_post.created_at=Time.now
    new_post.updated_at=Time.now
    new_post.save
    current_user.posts << new_post
    current_user.save
    file = File.new(archive_file_path, "w") 
    file.write(params[:title])
    file.write("\n")
    file.write("Posted by: ")
    file.write(the_user_name)
    file.write("\n")
    file.write("Posted on: ")
    file.write(Time.now)
    file.write("\n")
    file.write(params[:content])
    file.close

    if new_post.photo!=nil
      File.open('./public/users_photos/' + params['myfile'][:filename], "w") do |f|
        f.write(params['myfile'][:tempfile].read)
      end
    end

    if new_post.video!=nil
      File.open('./public/users_videos/' + params['myvideo'][:filename], "w") do |f|
        f.write(params['myvideo'][:tempfile].read)
      end
    end
    redirect '/'
  end

  post '/index/delete' do
    p = Post.get(params[:t])
    if p.user_username==the_user_name
      p.destroy
    end
    redirect '/'
  end

  get '/modify' do
    @to_be_modified = Post.get(params[:t])
    if @to_be_modified.user_username==the_user_name
      @to_be_modified = Post.get(params[:t])
      erb :modify
    else
      redirect '/'
    end
  end

  post '/modify' do
    p = Post.get(params[:old_title])
    if p.user_username==the_user_name
      file = File.new(p.archive, "a") 
      file.write("\n_______________________________________________\n")
      file.write(Time.now)
      file.write("\n")
      file.write(params[:content])
      file.close
      p.content=params[:content]
      p.save
      current_user = User.get(the_user_name)
      current_user.posts << p
    end
    redirect '/'
  end

  post '/index/comment' do
    create_anonymous_if_not_exists
    current_user=get_user(the_user_name)
    new_comment=Comment.new
    new_comment.content=params[:comment]
    new_comment.like=0
    new_comment.created_at=Time.now
    new_comment.updated_at=Time.now
    new_comment.save
    @concerned_post=Post.get(params[:concerned])
    @concerned_user=User.get(the_user_name)
    @concerned_post.comments << new_comment
    @concerned_user.comments << new_comment
    @concerned_user.save
    @concerned_post.save
    redirect '/'
  end

  get '/signup' do
    erb :signup
  end

  post '/signup' do
    create_anonymous_if_not_exists()
    new_user=User.new
    new_user.username=params[:username]
    new_user.email=params[:email]
    APP_SECRET = "AuGmEntTnEmGuA"
    encrypted_password = Digest::MD5.hexdigest(APP_SECRET + params[:password])
    new_user.password=encrypted_password
    new_user.photo='./users_photos/' + params['myfile'][:filename]
    new_user.created_at=Time.now
    new_user.updated_at=Time.now
    new_user.save
    File.open('./public/users_photos/' + params['myfile'][:filename], "w") do |f|
      f.write(params['myfile'][:tempfile].read)
    end
    redirect '/signup'
  end

  post '/login' do
    if(validate(params["username"], params["password"]))
      puts params["username"]
      puts "logged in"
      session["logged_in"] = true
      session["username"] = params["username"]
      @message = "You've been logged in.  Welcome back, #{params["username"]}"
      erb :login
      redirect '/'
    else
      puts "error"
      @error_message = "Sorry, those credentials aren't valid."
      erb :login
    end
  end

  get '/logout' do
    clear_session
    @message = "You've been logged out."
    erb :login
  end
