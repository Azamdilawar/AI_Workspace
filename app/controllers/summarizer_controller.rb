class SummarizerController < ApplicationController
  include ActionController::Live

  def show
  end

  def create
    response.headers["Content-Type"] = "text/event-stream"
    response.headers["Cache-Control"] = "no-cache"
    response.headers["X-Accel-Buffering"] = "no"

    sse = SSE.new(response.stream, event: "token")

    summarizer_service.summarize(
      summary_type: params[:summary_type],
      length: params[:length],
      tone: params[:tone],
      text: params[:text]
    ) do |delta|
      sse.write({ content: delta })
    end

    sse.write({}, event: "done")
  rescue AI::Error => e
    sse.write({ error: e.message }, event: "error")
  ensure
    sse.close
  end

  private

  def summarizer_service
    @summarizer_service ||= AI::SummarizerService.new
  end
end
