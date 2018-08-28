defmodule FireAct.ChangesetParams do
  @moduledoc """
  Params validation based on Ecto.Changeset.

  ## Examples

    iex> {:ok, %FireAct.Action{} = action} = FireAct.run(RegisterUser, %{"age" => 18})
    iex> action.assigns[:permitted_params]
    %{age: 18}

    iex> {:error, %FireAct.Action{} = action} = FireAct.run(RegisterUser, %{"age" => "n"})
    iex> action.assigns[:permitted_params] == nil
    true
    iex> action.assigns[:error].errors
    [age: {"is invalid", [type: :integer, validation: :cast]}]

  """
  defmacro __using__(opts) do
    quote do
      opts = unquote(opts)

      opts =
        if is_map(opts) do
          [schema: opts]
        else
          opts
        end

      @schema Keyword.fetch!(opts, :schema)
      @changeset_action Keyword.get(opts, :changeset_action, :insert)
      @error_key Keyword.get(opts, :error_key, :error)
      def schema(), do: @schema
      def error_key(), do: @error_key

      plug(:validate_passed_params)

      if opts[:halt_on_error] != false do
        plug(:halt_on_params_error)
      end

      import Ecto.Changeset

      def new(), do: cast(%{})
      def validate_params(_action, changeset), do: changeset

      defoverridable new: 0, validate_params: 2, schema: 0

      def process_params(%FireAct.Action{} = action, params) do
        validate_params(action, cast(params))
        |> apply_action(@changeset_action)
      end

      def cast(params) do
        FireAct.ChangesetParams.cast(schema(), params)
      end

      def validate_passed_params(%FireAct.Action{} = action, _) do
        FireAct.ChangesetParams.validate_passed_params(__MODULE__, action)
      end

      def halt_on_params_error(%FireAct.Action{} = action, _) do
        if !!Map.get(action.assigns, error_key()) do
          action
          |> FireAct.Action.fail()
        else
          action
        end
      end

      def action(%FireAct.Action{} = action, _opts \\ []) do
        apply(__MODULE__, :handle, [action, action.assigns[:permitted_params]])
      end
      defoverridable action: 2
    end
  end

  def validate_passed_params(module, action) do
    module.process_params(action, action.params)
    |> case do
      {:ok, permitted_params} ->
        action
        |> FireAct.Action.assign(:permitted_params, permitted_params)

      {:error, error} ->
        action
        |> FireAct.Action.assign(module.error_key(), error)
    end
  end

  def cast(schema, params) do
    data = %{}
    types = Enum.into(schema, %{})

    empty_map =
      Map.keys(types)
      |> Enum.reduce(%{}, fn key, acc -> Map.put(acc, key, nil) end)

    changeset =
      {data, types}
      |> Ecto.Changeset.cast(params, Map.keys(types))

    put_in(changeset.changes, Map.merge(empty_map, changeset.changes))
  end
end
