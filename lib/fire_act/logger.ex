defmodule FireAct.Logger do
  require Logger

  def init(opts) do
    opts
  end

  def call(action, _opts) do
    Logger.debug(fn -> "Test logger action=#{inspect(action)}" end)

    action
  end
end
