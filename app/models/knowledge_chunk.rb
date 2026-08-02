class KnowledgeChunk < ApplicationRecord
  belongs_to :knowledge

  validates :content, presence: true
  validates :position, presence: true, numericality: { only_integer: true, greater_than: 0 }

  # Store additional metadata as JSON
  attribute :metadata, :jsonb, default: {}

  # Scope to find chunks with embeddings
  scope :with_embeddings, -> { where.not(embedding: nil) }

  # Scope to find chunks without embeddings (pending processing)
  scope :pending_embedding, -> { where(embedding: nil) }

  # Similarity search class method
  # Returns chunks ordered by similarity to the given vector
  def self.similar_to(vector, limit: 10)
    where.not(embedding: nil)
         .order(Arel.sql("embedding <=> '#{vector}'::vector"))
         .limit(limit)
  end
end
