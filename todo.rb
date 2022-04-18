require "sinatra"
require "sinatra/reloader" if development?
require "tilt/erubis"
require "sinatra/content_for"

configure do 
  enable :sessions 
  set :session_secret, 'secret'
end

helpers do 
  def list_complete?(list)
    todos_count(list) > 0 && todos_remaining_count(list) == 0 
  end

  def list_class(list)
    "complete" if list_complete?(list)
  end

  def todos_count(list)
    list[:todos].size
  end

  def todos_remaining_count(list)
    list[:todos].select {|todo| !todo[:completed]}.size 
  end

  def sort_lists(lists, &block)
    complete_lists, incomplete_lists = lists.partition{|list| list_complete?(list)}

    incomplete_lists.each{|list| yield list, lists.index(list)}
    complete_lists.each {|list| yield list, lists.index(list)}
  end

  def sort_todos(todos, &block)
    complete_todos, incomplete_todos = todos.partition{|todo| todo[:completed]}

    incomplete_todos.each{|todo| yield todo, todos.index(todo)}
    complete_todos.each{|todo| yield todo, todos.index(todo)}
  end
end

before do 
  session[:lists] ||= []
end

get "/" do 
  redirect "/lists"
end

# GET /lists        -> view all lists 
# GET /lists/new    -> new list form
# POST /lists       -> create new list 
# GET /lists/1      -> view a single list 

# View list of lists
get "/lists" do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

# Render the new list form
get "/lists/new" do 
  erb :new_list, layout: :layout
end

# Return an error message if the name is invalid. Return nil if name is valid. 
def error_for_list_names(name) 
  if !(1..100).cover? name.size 
    "List name must be between 1 and 100 characters."
  elsif session[:lists].any?{|list| list[:name] == name}
    "List name must be unique."
  end
end

def next_list_id(lists)
  max = lists.map{|list| list[:id]}.max || 0
  max + 1 
end

# Create a new list
post "/lists" do 
  list_name = params[:list_name].strip
  error = error_for_list_names(list_name)

  if error 
    session[:error] = error 
    erb :new_list, layout: :layout
  else  
    id = next_list_id(session[:lists])
    session[:lists] << {id: id, name: list_name, todos: []}
    session[:success] = "The list has been created."
    redirect "/lists"
  end
end

get "/lists/:id" do 
  @list_id = params[:id].to_i

  redirect "/lists" if session[:lists].none?{|list| list[:id] == @list_id}

  @list = session[:lists].find{|list| list[:id] == @list_id}
  erb :list, layout: :layout
end

# Edit an existing todo list
get "/lists/:id/edit" do 
  @list_id = params[:id].to_i
  @list = session[:lists].find{|list| list[:id] == @list_id}
  erb :edit_list, layout: :layout
end

post "/lists/:id" do 
  list_name = params[:list_name].strip
  @list_id = params[:id].to_i
  @list = session[:lists].find{|list| list[:id] == @list_id}

  error = error_for_list_names(list_name)
  if error 
    session[:error] = error 
    erb :edit_list, layout: :layout
  else  
    @list[:name] = list_name
    session[:success] = "The list has been updated."
    redirect "/lists/#{params[:id]}"
  end
end

def error_for_todo(name) 
  if !(1..100).cover? name.size 
    "Todo must be between 1 and 100 characters."
  end
end

def next_todo_id(todos)
  max = todos.map {|todo| todo[:id] }.max || 0
  max + 1 
end

# Add a new todo to a list 
post "/lists/:list_id/todos" do
  @list_id = params[:list_id].to_i
  @list = session[:lists].find{|list| list[:id] == @list_id}
  text = params[:todo].strip
  error = error_for_todo(text)

  if error 
    session[:error] = error 
    erb :list, layout: :layout
  else  
    id = next_todo_id(@list[:todos])
    @list[:todos] << {id: id, name: params[:todo], completed: false}
    session[:success] = "The todo was added."
    redirect "/lists/#{@list_id}"
  end
end

# Delete a todo list
post "/lists/:id/destroy" do
  id = params[:id].to_i
  session[:lists].reject! {|list| list[:id] == id}

  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    "/lists"
  else
    session[:success] = "The list has been deleted."
    redirect "/lists"
  end
end


# Delete a todo from a list
post "/lists/:list_id/todos/:id/destroy" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  todo_id = params[:id].to_i
  @list[:todos].reject! {|todo| todo[:id] == todo_id}

  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    status 204
  else
    session[:success] = "The todo has been deleted."
    redirect "/lists/#{@list_id}"
  end
end

# Update status of a todo 
post "/lists/:list_id/todos/:id" do 
  @list_id = params[:list_id].to_i
  @list = session[:lists].find{|list| list[:id] == @list_id}
  todo_id = params[:id].to_i 
  is_completed = params[:completed] == "true"

  todo = @list[:todos].find{|todo| todo[:id] == todo_id}
  todo[:completed] = is_completed

  session[:success] = "The todo has been updated."
  redirect "/lists/#{@list_id}"
end

#mark all todos as complete for a list 
post "/lists/:id/complete_all" do 
  @list_id = params[:id].to_i
  @list = session[:lists].find{|list| list[:id] == @list_id}

  @list[:todos].each do |todo|
    todo[:completed] = true
  end

  session[:success] = "All todos have been completed."
  redirect "/lists/#{@list_id}"
end