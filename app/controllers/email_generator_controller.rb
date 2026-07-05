class EmailGeneratorController < ApplicationController
  include ActionController::Live

  def show
  end

  def create
    response.headers["Content-Type"] = "text/event-stream"
    response.headers["Cache-Control"] = "no-cache"
    response.headers["X-Accel-Buffering"] = "no"

    sse = SSE.new(response.stream, event: "token")

    email_service.generate(
      tone: params[:tone],
      email_type: params[:email_type],
      length: params[:length],
      context: params[:context]
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

  def email_service
    @email_service ||= AI::EmailService.new
  end
end
