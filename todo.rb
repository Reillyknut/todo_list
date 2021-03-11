require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"

configure do
  enable :sessions
  set :session_secret, 'secret'
end

before do
  session[:lists] ||= []
end

get "/" do
  redirect "/lists"
end

# View the list of the lists
get "/lists" do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

# Render the new list form
get "/lists/new" do
  erb :new_list, layout: :layout
end

# Render individual list item
get "/lists/:number" do
  @id = params[:number].to_i
  @list = session[:lists][@id]
  erb :list_page, layout: :layout
end

# Page to edit list item
get "/lists/:number/edit" do
  @id = params[:number].to_i
  @list = session[:lists][@id]
  erb :edit_page, layout: :layout
end

# Returns error message if the name is invalid. Returns nil if name is valid.
def error_for_list_name(name)
  if !(1..100).cover? name.length
    "List name must be between 1 and 100 characters."
  elsif session[:lists].any? { |list| list[:name] == name }
    "List name must be unique."
  end
end

# Error message if list name is invalid
def error_for_todo(name)
  if !(1..100).cover? name.length
    "Todo must be between 1 and 100 characters."
  end
end

# Update existing list item
post "/lists/:number" do
  id = params[:number].to_i
  @list = session[:lists][id]
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :edit_page, layout: :layout
  else
    session[:lists][id][:name] = params[:list_name]
    session[:success] = "List has been updated."
    redirect "/lists/#{id}"
  end
end

# Creates a new list
post "/lists" do
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    session[:lists] << { name: list_name, todos: [] }
    session[:success] = "List has been created."
    redirect "/lists"
  end
end

#checks/unchecks todo box
post "/lists/:number/todos/:id_number" do
  id = params[:number].to_i
  todo_id = params[:id_number].to_i
  is_completed = params[:completed] == "true"
  session[:lists][id][:todos][todo_id][:completed] = is_completed
  session[:success] = "Todo updated."

  redirect "/lists/#{id}"
end

# Deletes current list item
post "/lists/:number/delete" do
  id = params[:number].to_i
  session[:lists].delete_at(id)
  session[:success] = "List has been successfully deleted."

  redirect "/lists"
end

# Deletes current todo item from a list
post "/lists/:number/todos/:id_number/delete" do
  id = params[:number].to_i
  todo_id = params[:id_number].to_i
  session[:lists][id][:todos].delete_at(todo_id)
  session[:success] = "Todo has been successfully deleted."

  redirect "/lists/#{id}"
end

# Adds todo item to current list item
post "/lists/:list_id/todos" do
  @id = params[:list_id].to_i
  @list = session[:lists][@id]
  todo_name = params[:todo].strip

  error = error_for_todo(todo_name)
  if error
    session[:error] = error
    erb :list_page, layout: :layout
  else
    session[:lists][@id][:todos] << { name: todo_name, completed: false }
    session[:success] = "Todo has been created."
    redirect "/lists/#{@id}"
  end
end

# Complete all check box items in a todo list
post "/lists/:number/check_all" do
  id = params[:number].to_i
  todo_id = params[:id_number].to_i
  session[:lists][id][:todos].each { |todo| todo[:completed] = true }
  session[:success] = "All todos completed."

  redirect "/lists/#{id}"
end

helpers do
  def completed_list?(todos)
    todos.all? { |todo| todo[:completed] } && todos.length > 0
  end

  def count_unchecked(todos)
    todos.count { |todo| todo[:completed] == false }
  end

  def list_class(list)
    "complete" if completed_list?(list)
  end

  def sort_lists(lists, &block)
    complete_lists, incomplete_lists = lists.partition { |list| completed_list?(list[:todos]) }

    incomplete_lists.each { |list| yield list, lists.index(list) }
    complete_lists.each { |list| yield list, lists.index(list) }
  end

  def sort_todos(todos, &block)
    complete_todos, incomplete_todos = todos.partition { |todo| todo[:completed] }

    incomplete_todos.each { |todo| yield todo, todos.index(todo) }
    complete_todos.each { |todo| yield todo, todos.index(todo) }
  end
end