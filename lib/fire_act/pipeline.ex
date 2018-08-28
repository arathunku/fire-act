defmodule FireAct.Pipeline do
  @moduledoc false

  @doc false
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      import FireAct.Pipeline

      Module.register_attribute(__MODULE__, :plugs, accumulate: true)
      @before_compile FireAct.Pipeline

      @doc false
      def init(opts), do: opts

      @doc false
      def call(action, _) do
        action =
          if action.private[:fire_act_handler] do
            action
          else
            update_in(
              action.private,
              &(&1
                |> Map.put(:fire_act_handler, __MODULE__))
            )
          end

        fire_act_handler_pipeline(action, :handle)
      end

      @doc false
      def action(%FireAct.Action{} = action, _options) do
        apply(__MODULE__, :handle, [action, action.params])
      end

      defoverridable init: 1, call: 2, action: 2
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    handle = {:action, [], true}
    plugs = [handle | Module.get_attribute(env.module, :plugs)]

    {action, body} =
      FireAct.Builder.compile(env, plugs,
        log_on_halt: :debug,
        init_mode: FireAct.plug_init_mode()
      )

    quote do
      defoverridable action: 2

      def action(var!(action_before), opts) do
        var!(_action_after) = super(var!(action_before), opts)
      end

      defp fire_act_handler_pipeline(unquote(action), var!(handle)) do
        var!(action) = unquote(action)
        var!(handler) = __MODULE__
        _ = var!(action)
        _ = var!(handler)
        _ = var!(handle)

        unquote(body)
      end
    end
  end

  @doc """
  Stores a plug to be executed as part of the plug pipeline.
  """
  defmacro plug(plug)

  defmacro plug({:when, _, [plug, guards]}), do: plug(plug, [], guards)

  defmacro plug(plug), do: plug(plug, [], true)

  @doc """
  Stores a plug with the given options to be executed as part of
  the plug pipeline.
  """
  defmacro plug(plug, opts)

  defmacro plug(plug, {:when, _, [opts, guards]}), do: plug(plug, opts, guards)

  defmacro plug(plug, opts), do: plug(plug, opts, true)

  defp plug(plug, opts, guards) do
    quote do
      @plugs {unquote(plug), unquote(opts), unquote(Macro.escape(guards))}
    end
  end
end
