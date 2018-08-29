defmodule FireAct.Builder do
  @moduledoc false

  defmacro __using__(opts) do
    quote do
      @plug_builder_opts unquote(opts)

      def init(opts) do
        opts
      end

      def call(action, opts) do
        plug_builder_call(action, opts)
      end

      defoverridable init: 1, call: 2

      import FireAct.Action
      import FireAct.Builder, only: [plug: 1, plug: 2, builder_opts: 0], warn: false

      Module.register_attribute(__MODULE__, :plugs, accumulate: true)
      @before_compile FireAct.Builder
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    plugs = Module.get_attribute(env.module, :plugs)

    plugs =
      if builder_ref = get_plug_builder_ref(env.module) do
        traverse(plugs, builder_ref)
      else
        plugs
      end

    builder_opts = Module.get_attribute(env.module, :plug_builder_opts)
    {action, body} = FireAct.Builder.compile(env, plugs, builder_opts)

    quote do
      defp plug_builder_call(unquote(action), opts), do: unquote(body)
    end
  end

  defp traverse(tuple, ref) when is_tuple(tuple) do
    tuple |> Tuple.to_list() |> traverse(ref) |> List.to_tuple()
  end

  defp traverse(map, ref) when is_map(map) do
    map |> Map.to_list() |> traverse(ref) |> Map.new()
  end

  defp traverse(list, ref) when is_list(list) do
    Enum.map(list, &traverse(&1, ref))
  end

  defp traverse(ref, ref) do
    {:unquote, [], [quote(do: opts)]}
  end

  defp traverse(term, _ref) do
    term
  end

  # defmacro plug(plug, opts \\ []) do
  #   quote do
  #     @plugs {unquote(plug), unquote(opts), true}
  #     def plugs, do: @plugs
  #   end
  # end

  defmacro builder_opts() do
    quote do
      FireAct.Builder.__builder_opts__(__MODULE__)
    end
  end

  @doc false
  def __builder_opts__(module) do
    get_plug_builder_ref(module) || generate_plug_builder_ref(module)
  end

  defp get_plug_builder_ref(module) do
    Module.get_attribute(module, :plug_builder_ref)
  end

  defp generate_plug_builder_ref(module) do
    ref = make_ref()
    Module.put_attribute(module, :plug_builder_ref, ref)
    ref
  end

  def compile(env, pipeline, builder_opts) do
    action = quote do: action
    init_mode = builder_opts[:init_mode] || :compile

    unless init_mode in [:compile, :runtime] do
      raise ArgumentError, """
      invalid :init_mode when compiling #{inspect(env.module)}.

      Supported values include :compile or :runtime. Got: #{inspect(init_mode)}
      """
    end

    ast =
      Enum.reduce(pipeline, action, fn {plug, opts, guards}, acc ->
        {plug, opts, guards}
        |> init_plug(init_mode)
        |> quote_plug(acc, env, builder_opts)
      end)

    {action, ast}
  end

  # Initializes the options of a plug in the configured init_mode.
  defp init_plug({plug, opts, guards}, init_mode) do
    case Atom.to_charlist(plug) do
      ~c"Elixir." ++ _ -> init_module_plug(plug, opts, guards, init_mode)
      _ -> init_fun_plug(plug, opts, guards)
    end
  end

  defp init_module_plug(plug, opts, guards, :compile) do
    initialized_opts = plug.init(opts)

    if function_exported?(plug, :call, 2) do
      {:module, plug, escape(initialized_opts), guards}
    else
      raise ArgumentError, message: "#{inspect(plug)} plug must implement call/2"
    end
  end

  defp init_module_plug(plug, opts, guards, :runtime) do
    {:module, plug, quote(do: unquote(plug).init(unquote(escape(opts)))), guards}
  end

  defp init_fun_plug(plug, opts, guards) do
    {:function, plug, escape(opts), guards}
  end

  defp escape(opts) do
    Macro.escape(opts, unquote: true)
  end

  # `acc` is a series of nested plug calls in the form of
  # plug3(plug2(plug1(action))). `quote_plug` wraps a new plug around that series
  # of calls.
  defp quote_plug({plug_type, plug, opts, guards}, acc, env, builder_opts) do
    call = quote_plug_call(plug_type, plug, opts)

    error_message =
      case plug_type do
        :module -> "expected #{inspect(plug)}.call/2 to return a FireAct.Action"
        :function -> "expected #{plug}/2 to return a FireAct.Action"
      end <> ", all plugs must receive an action and return an action"

    {fun, meta, [arg, [do: clauses]]} =
      quote do
        case unquote(compile_guards(call, guards)) do
          %FireAct.Action{halted: true} = action ->
            unquote(log_halt(plug_type, plug, env, builder_opts))
            action

          %FireAct.Action{} = action ->
            unquote(acc)

          _ ->
            raise unquote(error_message)
        end
      end

    generated? = :erlang.system_info(:otp_release) >= '19'

    clauses =
      Enum.map(clauses, fn {:->, meta, args} ->
        if generated? do
          {:->, [generated: true] ++ meta, args}
        else
          {:->, Keyword.put(meta, :line, -1), args}
        end
      end)

    {fun, meta, [arg, [do: clauses]]}
  end

  defp quote_plug_call(:function, plug, opts) do
    quote do: unquote(plug)(action, unquote(opts))
  end

  defp quote_plug_call(:module, plug, opts) do
    quote do: unquote(plug).call(action, unquote(opts))
  end

  defp compile_guards(call, true) do
    call
  end

  defp compile_guards(call, guards) do
    quote do
      case true do
        true when unquote(guards) -> unquote(call)
        true -> action
      end
    end
  end

  defp log_halt(plug_type, plug, env, builder_opts) do
    if level = builder_opts[:log_on_halt] do
      message =
        case plug_type do
          :module -> "#{inspect(env.module)} halted in #{inspect(plug)}.call/2"
          :function -> "#{inspect(env.module)} halted in #{inspect(plug)}/2"
        end

      quote do
        require Logger
        # Matching, to make Dialyzer happy on code executing FireAct.Builder.compile/3
        _ = Logger.unquote(level)(unquote(message))
      end
    else
      nil
    end
  end
end
