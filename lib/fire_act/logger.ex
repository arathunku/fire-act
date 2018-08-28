defmodule FireAct.Logger do
  require Logger

  def init(opts) do
    opts
  end

  def call(action, _opts) do
    Logger.info("Test logger action=#{inspect(action)}")

    action
  end
end
