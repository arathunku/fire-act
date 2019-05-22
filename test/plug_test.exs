defmodule FireActionTest.PlugTest do
  use ExUnit.Case

  defmodule RegisterUser do
    use FireAct.Handler

    def handle(action, _params) do
      action
    end
  end

  describe "#Action.new" do
    test "copies params from Plug.Conn" do
      action =
        %Plug.Conn{params: %{"test" => "1"}}
        |> FireAct.Action.new()

      assert %FireAct.Action{
               params: %{"test" => "1"}
             } == action
    end

    test "merges assigns with assigns from Plug.Conn" do
      action =
        %Plug.Conn{params: %{"test" => "1"}, assigns: %{a: 2}}
        |> FireAct.Action.new(%{b: 2})

      assert %FireAct.Action{
               params: %{"test" => "1"},
               assigns: %{a: 2, b: 2}
             } == action
    end
  end
end
