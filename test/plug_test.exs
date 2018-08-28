defmodule FireActionTest.PlugTest do
  defmodule RegisterUser do
    use FireAct.Handler

    def handle(action, params) do
      action
      |> assign(:params, params)
      |> assign(:success, Map.get(action.assigns, :success, 0) + 1)
    end
  end

  use ExUnit.Case

  test "run number fail - wrong age" do
    {:ok, action} =
      %Plug.Conn{params: %{"test" => "1"}}
      |> FireAct.run(RegisterUser)

    assert action.assigns[:success]
    assert action.params == %{"test" => "1"}
    assert action.assigns[:params] == %{"test" => "1"}
  end
end
