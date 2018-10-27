defmodule FireActTest.ChangesetParamsTest do
  defmodule RegisterUser do
    use FireAct.Handler

    use FireAct.ChangesetParams, %{
      age: :integer
    }

    @adult_age 18

    def handle(action, permitted_params) do
      %{age: _age} = permitted_params

      action
      |> assign(:success, Map.get(action.assigns, :success, 0) + 1)
    end

    def validate_params(_action, changeset) do
      if get_field(changeset, :age) >= @adult_age do
        changeset
      else
        changeset
        |> add_error(:age, "only adults are allowed.")
      end
    end
  end

  defmodule UnhaltedRegisterUser do
    use FireAct.Handler

    use FireAct.ChangesetParams,
      schema: %{
        age: :integer
      },
      halt_on_error: false

    # Params are nil because they didn't pass the validation
    def handle(action, nil) do
      action
      |> assign(:msg, "fail")
    end

    def handle(action, _permitted_params) do
      action
      |> assign(:msg, "success")
    end
  end

  defmodule PlugBeforeChangeset do
    use FireAct.Handler

    plug(:set_resource)

    use FireAct.ChangesetParams,
      schema: %{
        age: :integer
      }

    def handle(action, _) do
      action.assigns.resource

      action
    end

    defp validate_params(action, chset) do
      action.assigns.resource

      chset
    end

    def set_resource(action, _) do
      action
      |> assign(:resource, %{id: 1})
    end
  end

  defmodule PrefillChangesetData do
    use FireAct.Handler

    use FireAct.ChangesetParams,
      schema: %{
        name: :string,
        age: :integer
      }

    def handle(action, _) do
      action
    end

    defp data(action), do: action.assigns.resource

    defp validate_params(action, chset) do
      chset
      |> Ecto.Changeset.validate_required([:name, :age])
    end
  end

  use ExUnit.Case
  doctest FireAct.ChangesetParams

  test "run number fail - wrong age" do
    {:error, action} =
      FireAct.run(RegisterUser, %{
        age: "n"
      })

    refute action.assigns[:success]
    assert action.assigns[:permitted_params] == nil
    assert !!action.assigns[:error]
  end

  test "run fail - wrong age" do
    {:error, action} =
      FireAct.run(RegisterUser, %{
        age: 10
      })

    refute action.assigns[:success]
    assert action.assigns[:permitted_params] == nil
    assert !!action.assigns[:error]
  end

  test "run success" do
    {:ok, action} =
      FireAct.run(RegisterUser, %{
        age: 20
      })

    assert action.assigns[:success] == 1

    assert action.assigns[:permitted_params] == %{
             age: 20
           }
  end

  test "success even when params validation fails" do
    {:ok, action_failed} =
      FireAct.run(UnhaltedRegisterUser, %{
        age: "abcd"
      })

    {:ok, action_success} =
      FireAct.run(UnhaltedRegisterUser, %{
        age: "20"
      })

    assert action_failed.assigns[:msg] == "fail"
    assert action_success.assigns[:msg] == "success"
  end

  test "plugs before changeset" do
    {:ok, action} =
      FireAct.run(PlugBeforeChangeset, %{
        age: "20"
      })
  end

  test "allow for prefilling data with existing object" do
    %{name: "Foo", age: nil} =
      PrefillChangesetData.new(%{name: "Foo"}, %{age: nil}).changes

    # Test string params (like from form in Phoenix Controller)
    %{name: "Foo", age: 20} =
      PrefillChangesetData.new(%{name: "Foo"}, %{"age" => 20}).changes

    %{name: nil, age: 20} =
      PrefillChangesetData.new(%{"age" => 20}).changes

    {:ok, action} =
      FireAct.run(
        PrefillChangesetData,
        %{
          age: "20"
        },
        %{resource: %{name: "Foo"}}
      )
  end
end
