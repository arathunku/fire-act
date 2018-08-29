defmodule FireActionTest.PlugTest do
  use ExUnit.Case

  defmodule RegisterUser do
    use FireAct.Handler

    def handle(action, _params) do
      action
    end
  end

  test "check action from Plug.Conn" do
    %FireAct.Action{
      params: %{"test" => "1"},
      private: %{
        fire_act_handler: RegisterUser
      }
    } =
      %Plug.Conn{params: %{"test" => "1"}}
      |> FireAct.action(RegisterUser)
  end
end
