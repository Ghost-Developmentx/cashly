class Result
  attr_reader :data, :error, :status

  def initialize(success:, data: {}, error: nil, status: :ok)
    @success = success
    @data = data
    @error = error
    @status = status
  end

  def success?
    @success
  end

  def failure?
    !@success
  end

  def to_h
    if success?
      { success: true, data: data }
    else
      { success: false, error: error }
    end
  end
end
