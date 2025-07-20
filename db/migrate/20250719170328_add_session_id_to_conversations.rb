class AddSessionIdToConversations < ActiveRecord::Migration[7.1]
  def change
    add_column :conversations, :session_id, :string
    change_column_null :conversations, :user_id, true
    add_index :conversations, :session_id
  end
end
