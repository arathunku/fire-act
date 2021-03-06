defmodule FireAct.ChangesetParams do
  @callback cast(any, Map.t()) :: Ecto.Changeset.t()
  @callback validate_params(FireAct.Action.t(), Map.t()) :: Ecto.Changeset.t()

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
  defmacro __using__(opts) when is_list(opts) do
    define_changeset_helpers(opts)
  end

  defmacro __using__([]) do
    define_changeset_helpers([])
  end

  defmacro __using__(schema) do
    define_changeset_helpers(schema: schema)
  end

  def define_changeset_helpers(opts) do
    quote do
      @behaviour FireAct.ChangesetParams
      opts = unquote(opts)

      if opts[:schema] do
        @schema opts[:schema]

        def schema(), do: @schema
      end

      @changeset_action opts[:changeset_action] || :insert
      @error_key opts[:error_key] || :error
      def error_key(), do: @error_key

      plug(:validate_passed_params)

      if opts[:halt_on_error] != false do
        plug(:halt_on_params_error)
      end

      import Ecto.Changeset

      if opts[:schema] do
        def new(params), do: cast(params)
        def new(data, params), do: cast(data, params)

        def validate_params(_action, changeset), do: changeset

        def data(_action), do: %{}

        def process_params(%FireAct.Action{} = action, params) do
          validate_params(action, cast(data(action), params))
          |> apply_action(@changeset_action)
        end

        def cast(params) do
          FireAct.ChangesetParams.cast(schema(), %{}, params)
        end

        def cast(data, params) do
          FireAct.ChangesetParams.cast(schema(), data, params)
        end

        defoverridable new: 1, new: 2, validate_params: 2, data: 1
      else
        def process_params(%FireAct.Action{} = action, params) do
          validate_params(action, params)
          |> apply_action(@changeset_action)
        end
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

  def cast(schema, data, params) do
    types = Enum.into(schema, %{})

    changeset =
      {data, types}
      |> Ecto.Changeset.cast(params, Map.keys(types))
      |> Map.put(:action, :insert)

    initial_map =
      Map.keys(types)
      |> Enum.reduce(%{}, fn key, acc ->
        Map.put(acc, key, Ecto.Changeset.get_field(changeset, key))
      end)

    put_in(changeset.changes, Map.merge(initial_map, changeset.changes))
  end
end
