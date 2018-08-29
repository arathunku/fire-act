defmodule FireAct.Handler do
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      import FireAct.Handler
      import FireAct.Action

      use FireAct.Pipeline, opts

      def handle(action, _params), do: action

      def rollback(action), do: action

      defoverridable handle: 2, rollback: 1
    end
  end

  def organize(action, handlers), do: do_organize(action, handlers, [])

  defp do_organize(action, [], _executed_handlers), do: action

  defp do_organize(action, [handler | handlers], executed_handlers) do
    action
    |> FireAct.Action.put_private(:fire_act_handler, handler)
    |> FireAct.run()
    |> case do
      {:ok, action} ->
        do_organize(action, handlers, [handler | executed_handlers])

      {:error, action} ->
        rollback_handlers(action, executed_handlers)
    end
  end

  defp rollback_handlers(action, []), do: action

  defp rollback_handlers(action, [handler | executed_handlers]) do
    case handler.rollback(action) do
      %FireAct.Action{} = action ->
        rollback_handlers(action, executed_handlers)

      _ ->
        rollback_handlers(action, executed_handlers)
    end
  end
end
