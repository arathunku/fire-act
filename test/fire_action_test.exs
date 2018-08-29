defmodule FireActTest do
  defmodule RegisterUser do
    use FireAct.Handler
    plug(FireAct.Logger)
    plug(:action)
    plug(:emit_event)

    def handle(action, params) do
      if params[:success] do
        action
        |> assign(:success, params[:success] + 1)
      else
        action
        |> fail()
      end
    end

    def emit_event(action, _) do
      if action.assigns[:success] > action.params[:success] do
        action
        |> assign(:event_emitted, true)
      else
        action
      end
    end
  end

  defmodule Halted do
    use FireAct.Handler

    plug(:step, :first)
    plug(:step, :second)
    plug(:authorize)
    plug(:step, :end_of_chain_reached)

    def step(action, step), do: assign(action, step, true)

    def authorize(action, _) do
      action
      |> assign(:authorize_reached, true)
      |> halt()
    end
  end

  defmodule Ordered do
    use FireAct.Handler

    plug(:step, :one)
    # step two
    plug(:action)
    plug(:step, :three)

    def step(action, step),
      do: assign(action, :steps, (action.assigns[:steps] || []) ++ [step])

    def handle(action, _),
      do: step(action, :two)
  end

  use ExUnit.Case
  doctest FireAct

  test "run success" do
    {:ok, action} =
      FireAct.run(RegisterUser, %{
        success: 1
      })

    assert action.assigns[:success] == 2
    assert action.assigns[:event_emitted]
  end

  test "run fail" do
    {:error, action} = FireAct.run(RegisterUser, %{})

    refute action.assigns[:event_emitted]
  end

  test "run halted" do
    {:ok, action} = FireAct.action(Halted, %{}) |> FireAct.run()

    assert action.halted
    assert action.assigns[:first]
    assert action.assigns[:second]
    assert action.assigns[:authorize_reached]
    refute action.assigns[:end_of_chain_reached]
  end

  test "steps order" do
    {:ok, action} = FireAct.action(Ordered, %{}) |> FireAct.run()

    assert action.assigns[:steps] == [:one, :two, :three]
  end

  test "#action" do
    %FireAct.Action{
      params: %{a: 1},
      assigns: %{
        b: 2
      }
    } = FireAct.action(Halted, %{a: 1}, %{b: 2})
  end
end
