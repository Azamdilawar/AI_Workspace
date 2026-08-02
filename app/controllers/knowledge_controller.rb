class KnowledgeController < ApplicationController
  before_action :set_knowledge, only: [:show, :destroy]

  def index
    @knowledges = Knowledge.order(created_at: :desc)
  end

  def show
  end

  def new
    @knowledge = Knowledge.new
  end

  def create
    @knowledge = Knowledge.new(knowledge_params)

    if params[:knowledge][:file].present?
      handle_file_upload
    elsif params[:knowledge][:content].present?
      handle_text_input
    else
      render :new, status: :unprocessable_entity and return
    end

    if @knowledge.save
      process_knowledge(@knowledge)
      redirect_to @knowledge, notice: "Document was successfully created and processed."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    @knowledge.destroy
    redirect_to knowledge_index_url, notice: "Document was successfully deleted."
  end

  private

  def set_knowledge
    @knowledge = Knowledge.find(params[:id])
  end

  def knowledge_params
    params.require(:knowledge).permit(:title, :source_type, :content)
  end

  def handle_file_upload
    file = params[:knowledge][:file]
    content = file.read
    title = params[:knowledge][:title].presence || file.original_filename

    @knowledge.title = title
    @knowledge.content = content
    @knowledge.source_type = "upload"
  end

  def handle_text_input
    @knowledge.source_type = "manual"
  end

  def process_knowledge(knowledge)
    service = KnowledgeBase::EmbeddingService.new(knowledge)
    result = service.process

    if result[:success]
      Rails.logger.info "[KnowledgeController] Processed #{result[:chunks_count]} chunks for knowledge ##{knowledge.id}"
    else
      Rails.logger.error "[KnowledgeController] Failed to process: #{result[:error]}"
    end
  rescue StandardError => e
    Rails.logger.error "[KnowledgeController] Error processing: #{e.message}"
  end
end
