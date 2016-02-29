class AddContentsToPosts < ActiveRecord::Migration
  def change
    add_column :posts, :contents, :text
  end
end
