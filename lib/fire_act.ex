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
      %{email: _email, age: _age} = permitted_params

      User.changeset(permitted_params)
      |> Repo.update!()
    end

    def validate_params(_action, changeset) do
      if "valid@example.com" == get_field(changeset, :email) do
        changeset
      else
        changeset
        |> add_error(:email, "only invalid@example.com")
      end
    end
  end

  {:ok, action} = FireAct.run(RegisterUser, %{
    age: 1,
    email: "valid@example.com"
  })
  ```
  """
  alias FireAct.Action

  def run(%Action{} = action), do: run(action, [])

  def run(%Action{} = action, opts) do
    handler = action.private |> Map.fetch!(:fire_act_handler)

    handler.call(action, opts)
    |> handle_action_result()
  end

  if Code.ensure_loaded?(Plug) do
    def run(%Plug.Conn{} = conn, handler) do
      action(handler, conn.params)
      |> Map.put(:assigns, conn.assigns)
      |> run()
    end
  end

  def run(handler, params) when is_atom(handler) do
    action(handler, params)
    |> run()
  end

  defp handle_action_result(%Action{failed: true} = action) do
    {:error, action}
  end

  defp handle_action_result(%Action{failed: false} = action) do
    {:ok, action}
  end

  def action(handler, params \\ %{}, assigns \\ %{}) do
    %Action{params: params, assigns: assigns}
    |> Action.put_private(:fire_act_handler, handler)
  end

  def plug_init_mode do
    # Application.get_env(:fire_act, :plug_init_mode, :compile)
    :runtime
  end
end
