# FireAct

Plug inspired/based helper for defining action handlers with
optional params validations via Ecto.Changeset.

Perfect for extracting logic outside the controller endpoints.

[Documentation](https://hexdocs.pm/fire_act/)

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `fire_act` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:fire_act, "~> 0.1.0"}
  ]
end
```


## Basic example usage

Please also read documentation and tests.

```elixir
defmodule MyApp.RegisterUser do
  use FireAct.Handler
  use FireAct.ChangesetParams, %{
    age: :number,
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
