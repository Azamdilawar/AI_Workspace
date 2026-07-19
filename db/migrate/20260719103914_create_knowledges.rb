class CreateKnowledges < ActiveRecord::Migration[8.0]
  def change
    create_table :knowledges do |t|
      t.string :title
      t.text :content
      t.string :source_type
      t.jsonb :metadata

      t.timestamps
    end
  end
end
