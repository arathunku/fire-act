defmodule FireAct do
  @moduledoc """
  Inspired by Plug, a helper module for defining action handlers with
  optional params validations via Ecto.Changeset.

  Perfect for extracting logic outside the controller endpoints.


  Example usage:

  ```
  defmodule RegisterUser do
    use FireAct.Handler
    use FireAct.ChangesetParams, %{
      age: :integer,
      email: :string
    }

    def handle(action, permitted_params) do
      MyApp.User.create_changeset(permitted_params)
      |> MyApp.Repo.insert()
      |> case do
        {:ok, user} ->
          action |> assign(:user, user)
        {:error, error} ->
          action |> assign(:error, error) |> fail()
      end
    end

    def validate_params(_action, changeset) do
      changeset
      |> validate_email()
      |> validate_required([:age, :email])
    end

    defp validate_email(changeset) do
      if "valid@example.com" == get_field(changeset, :email) do
        changeset
      else
        changeset
        |> add_error(:email, "only valid@example.com is OK")
      end
    end
  end

  {:ok, %{assigns: %{user: user}}} = FireAct.run(RegisterUser, %{
    age: 1,
    email: "valid@example.com"
  })
  ```
  """
  alias FireAct.Action

  @plug_init_mode Application.get_env(:fire_act, :plug_init_mode, :runtime)

  def run(handlers), do: Action.new(%{}, %{}) |> do_run(List.wrap(handlers), [])

  def run(%Action{} = action, handlers) do
    do_run(action, List.wrap(handlers), [])
  end

  def run(handlers, params), do: Action.new(params, %{}) |> do_run(List.wrap(handlers), [])

  def run(handlers, params, assigns),
    do: Action.new(params, assigns) |> do_run(List.wrap(handlers), [])

  def plug_init_mode do
    @plug_init_mode
  end

  defp do_run(%Action{} = action, [], _), do: {:ok, action}

  defp do_run(%Action{} = action, [handler | handlers], executed_handlers) do
    handler.call(action, [])
    |> case do
      {code, %Action{} = action} when code in ~w(ok error)a -> action
      action -> action
    end
    |> case do
      %Action{failed: true} = action ->
        rollback_handlers(action, executed_handlers)

      %Action{failed: false} = action ->
        do_run(action, handlers, [handler | executed_handlers])
    end
  end

  defp rollback_handlers(action, []), do: {:error, action}

  defp rollback_handlers(action, [handler | executed_handlers]) do
    case handler.rollback(action) do
      %FireAct.Action{} = action ->
        rollback_handlers(action, executed_handlers)

      _ ->
        rollback_handlers(action, executed_handlers)
    end
  end
end
