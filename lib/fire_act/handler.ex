defmodule FireAct.Handler do
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      import FireAct.Handler
      import FireAct.Action, except: [new: 0, new: 1, new: 2]

      use FireAct.Pipeline, opts

      def handle(action, _params), do: action

      def rollback(action), do: action

      defoverridable handle: 2, rollback: 1
    end
  end
end
