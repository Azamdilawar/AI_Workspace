namespace :vector do
  desc "Rebuild the IVFFlat vector index (run after adding significant data)"
  task rebuild_index: :environment do
    puts "Rebuilding vector index..."

    # Check if index exists
    index_exists = ActiveRecord::Base.connection.execute(<<-SQL).any?
      SELECT indexname FROM pg_indexes
      WHERE tablename = 'knowledge_chunks'
      AND indexname = 'index_knowledge_chunks_on_embedding'
    SQL

    if index_exists
      puts "Dropping existing index..."
      ActiveRecord::Base.connection.execute("DROP INDEX index_knowledge_chunks_on_embedding")
    end

    # Count vectors
    count = KnowledgeChunk.where.not(embedding: nil).count
    puts "Found #{count} vectors"

    if count == 0
      puts "No vectors yet. Creating index with default lists=100..."
      lists = 100
    else
      # Optimal lists = sqrt(n), minimum 10, maximum 1000
      lists = [[Math.sqrt(count).round, 10].max, 1000].min
      puts "Using #{lists} lists (sqrt of #{count})"
    end

    # Create index
    puts "Creating IVFFlat index..."
    ActiveRecord::Base.connection.execute(<<-SQL)
      CREATE INDEX index_knowledge_chunks_on_embedding
      ON knowledge_chunks
      USING ivfflat (embedding vector_cosine_ops)
      WITH (lists = #{lists});
    SQL

    puts "Index created successfully!"
    puts ""
    puts "Summary:"
    puts "  - Vectors: #{count}"
    puts "  - Lists: #{lists}"
    puts "  - Metric: cosine"
  end

  desc "Show vector index information"
  task index_info: :environment do
    puts "Vector Index Information"
    puts "=" * 50

    # Check if index exists
    result = ActiveRecord::Base.connection.execute(<<-SQL)
      SELECT indexname, indexdef
      FROM pg_indexes
      WHERE tablename = 'knowledge_chunks'
      AND indexname = 'index_knowledge_chunks_on_embedding'
    SQL

    if result.any?
      index = result.first
      puts "Index: #{index['indexname']}"
      puts "Definition: #{index['indexdef']}"
    else
      puts "No vector index found"
    end

    puts ""
    puts "Vector Statistics"
    puts "-" * 50

    # Count total chunks
    total = KnowledgeChunk.count
    puts "Total chunks: #{total}"

    # Count chunks with embeddings
    with_embeddings = KnowledgeChunk.where.not(embedding: nil).count
    puts "With embeddings: #{with_embeddings}"

    # Count chunks without embeddings
    without_embeddings = KnowledgeChunk.where(embedding: nil).count
    puts "Without embeddings: #{without_embeddings}"

    if with_embeddings > 0
      puts ""
      puts "Index Status: #{total == with_embeddings ? 'Fully indexed' : 'Partially indexed'}"
    end
  end
end
