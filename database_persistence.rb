require "pg"

class DatabasePersistence
  def initialize(logger)
    @logger = logger
    @db = if Sinatra::Base.production?
            PG.connect(ENV['DATABASE_URL'])
          else
            PG.connect(dbname: "todos")
          end
  end

  def query(sql, *params)
    @logger.info "#{sql}: #{params}"
    @db.exec_params(sql, params)
  end

  def find_list(id)
    sql = <<~SQL
    SELECT l.*
      , count(CASE WHEN t.completed = 'f' THEN t.completed END) todos_remaining_count
      , count(t.id ) todos_count
      FROM lists l 
      LEFT JOIN todos t on l.id = t.list_id
      WHERE l.id = $1
      GROUP BY l.id
      ORDER BY l.name;
    SQL

    result = query(sql, id)
    
    list_tuple = result.first

    todos = find_todos_for_list(id)

    { id: list_tuple["id"].to_i, 
      name: list_tuple["name"], 
      todos: todos,
      todos_count: list_tuple["todos_count"].to_i, 
      todos_remaining_count: list_tuple["todos_remaining_count"].to_i }
  end

  def all_lists
    list_sql = <<~SQL
      select l.*
        , count(case when t.completed = 'f' then t.completed end) todos_remaining_count
        , count(t.id ) todos_count
        from lists l 
        LEFT JOIN todos t on l.id = t.list_id
        group by l.id;
    SQL

    lists_result = query(list_sql)

    lists_result.map do |list_tuple|
      { id: list_tuple["id"].to_i, 
        name: list_tuple["name"], 
        todos_count: list_tuple["todos_count"].to_i, 
        todos_remaining_count: list_tuple["todos_remaining_count"].to_i }
    end
  end

  def create_list(list_name)
    sql = "INSERT INTO lists (name) VALUES ($1)"
    query(sql, list_name)
  end

  def delete_list(id)
    sql = "DELETE FROM lists WHERE id = $1"
    query(sql, id)
  end

  def update_list_name(id, new_name)
    sql = "UPDATE lists SET name = $1 WHERE id = $2"
    query(sql, new_name, id)
  end

  def create_new_todo(list_id, todo_name)
    sql = "INSERT INTO todos (name, list_id) VALUES ($1, $2)"
    query(sql, todo_name, list_id)
  end

  def delete_todo_from_list(list_id, todo_id)
    # list = find_list(list_id)
    # list[:todos].reject! { |todo| todo[:id] == todo_id }

    sql = "DELETE FROM todos WHERE id = $1 and list_id = $2;"
    query(sql, todo_id, list_id)
  end

  def update_todo_status(list_id, todo_id, status)
    sql = "UPDATE todos SET completed = $1 WHERE id = $2 and list_id = $3"
    query(sql, status, todo_id, list_id)
  end
  
  def mark_all_todos_complete(list_id)
    # list = find_list(list_id)
    
    # list[:todos].each do |todo|
    #   todo[:completed] = true
    # end
    sql = "UPDATE todos SET completed = true WHERE list_id = $1"
    query(sql, list_id)
  end

  def disconnect
    @db.close
  end

  private

  def find_todos_for_list(list_id)
    todos_sql = "SELECT * FROM todos where list_id = $1"
    todos_result = query(todos_sql, list_id)
    
    todos = todos_result.map do |todo_tuple|
      { id: todo_tuple["id"].to_i,
        name: todo_tuple["name"],
        completed: todo_tuple["completed"] == "t" }
    end
  end
end
