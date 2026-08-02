class AddEmbeddingIndexToKnowledgeChunks < ActiveRecord::Migration[8.0]
  def up
    # IVFFlat index for fast cosine similarity search
    # lists = 100 → good for up to ~10,000 vectors
    # vector_cosine_ops → optimized for cosine distance
    execute <<-SQL
      CREATE INDEX index_knowledge_chunks_on_embedding
      ON knowledge_chunks
      USING ivfflat (embedding vector_cosine_ops)
      WITH (lists = 100);
    SQL
  end

  def down
    execute "DROP INDEX index_knowledge_chunks_on_embedding"
  end
end
