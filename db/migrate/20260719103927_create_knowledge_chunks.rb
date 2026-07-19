class CreateKnowledgeChunks < ActiveRecord::Migration[8.0]
  def up
    create_table :knowledge_chunks do |t|
      t.references :knowledge, null: false, foreign_key: true
      t.text :content
      t.integer :position
      t.jsonb :metadata

      t.timestamps
    end

    # Add vector column for embeddings (1536 dimensions for text-embedding-3-small)
    execute "ALTER TABLE knowledge_chunks ADD COLUMN embedding vector(1536);"

    # Add index for fast similarity search (IVFFlat is good for static data)
    # Note: This index requires some data to be efficient, we can add it later
    # execute "CREATE INDEX index_knowledge_chunks_on_embedding ON knowledge_chunks USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);"
  end

  def down
    drop_table :knowledge_chunks
  end
end
