class Conversation < ApplicationRecord
  has_many :messages, -> { order(:created_at) }, dependent: :destroy, inverse_of: :conversation

  validates :title, presence: true
end
