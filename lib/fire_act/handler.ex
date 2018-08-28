defmodule FireAct.Handler do
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      import FireAct.Handler
      import FireAct.Action

      use FireAct.Pipeline, opts

      # use FireAct.Builder, unquote(opts)

      # def handle(action, _params) do
      #   action
      # end

      # plug :action
      # defoverridable [action: 2, handle: 2]
    end
  end
end
