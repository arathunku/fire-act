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

    def validate_params(action, chset) do
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

    def data(action), do: action.assigns.resource

    def validate_params(_action, chset) do
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
    {:ok, _action} =
      FireAct.run(PlugBeforeChangeset, %{
        age: "20"
      })
  end

  test "allow for prefilling data with existing object" do
    assert %{name: "Foo", age: nil} == PrefillChangesetData.new(%{name: "Foo"}, %{age: nil}).changes

    # Test string params (like from form in Phoenix Controller)
    %{name: "Foo", age: 20} = PrefillChangesetData.new(%{name: "Foo"}, %{"age" => 20}).changes

    %{name: nil, age: 20} = PrefillChangesetData.new(%{"age" => 20}).changes

    {:ok, _action} =
      FireAct.run(
        PrefillChangesetData,
        %{
          age: "20"
        },
        %{resource: %{name: "Foo"}}
      )
  end

  test "action is always insert" do
    :insert = PrefillChangesetData.new(%{age: "20"}, %{resource: %{}}).action

    FireAct.run(PrefillChangesetData, %{age: ""}, %{resource: %{}})
    |> case do
      {:error, %{assigns: %{error: error}}} ->
        assert :insert = error.action
    end
  end

  describe "supports embedded schemas" do
    defmodule SetPostComments do
      use FireAct.Handler
      use Ecto.Schema

      @primary_key false
      embedded_schema do
        field(:post_id, :id)

        embeds_many :comments, Comment do
          field(:content, :string)
        end
      end

      use FireAct.ChangesetParams

      def new(params \\ %{}), do: cast(%__MODULE__{}, params)
      def handle(action, _) do
        action
      end

      def cast(data, params), do:
        data
        |> Ecto.Changeset.cast(params, ~w(post_id)a)
        |> Ecto.Changeset.validate_required(~w(post_id)a)
        |> Ecto.Changeset.cast_embed(:comments, required: true, with: &comment_changeset/2)

      def validate_params(_action, params) do
        cast(%__MODULE__{}, params)
      end

      def comment_changeset(chset, params) do
        chset
        |> Ecto.Changeset.cast(params, ~w(content)a)
        |> Ecto.Changeset.validate_required(~w(content)a)
      end
    end

    test "supports embedded schema" do
      %{} = SetPostComments.new(%{}).changes

      {:ok, _} = SetPostComments
      |> FireAct.run(%{post_id: 1, comments: [%{content: "xx"}]}, %{})
    end

    test "validates for errors" do
      SetPostComments
      |> FireAct.run(%{post_id: 1}, %{})
      |> case do
        {:error, %{assigns: %{error: _error}}} ->
          :ok
      end
    end

    test "validates for errors inside nested structure" do
      SetPostComments
      |> FireAct.run(%{post_id: 1, comments: [%{content: nil}]}, %{})
      |> case do
        {:error, %{assigns: %{error: _error}}} ->
          :ok
      end

      SetPostComments
      |> FireAct.run(%{post_id: 1, comments: [%{content: "hi"}]}, %{})
      |> case do
        {:ok, %{assigns: _}} ->
          :ok
      end
    end
  end
end
