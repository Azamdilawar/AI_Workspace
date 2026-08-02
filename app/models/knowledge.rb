class Knowledge < ApplicationRecord
  has_many :knowledge_chunks, dependent: :destroy

  validates :title, presence: true
  validates :content, presence: true
  validates :source_type, presence: true, inclusion: { in: %w[manual upload url] }

  # Store additional metadata as JSON
  attribute :metadata, :jsonb, default: {}

  scope :by_source, ->(source_type) { where(source_type: source_type) }
end
