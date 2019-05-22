defmodule FireActTest.NestedActionsWithRollbacksTest do
  use ExUnit.Case

  defmodule CreateUser do
    use FireAct.Handler

    def handle(action, params) do
      if params[:fail_create] do
        action
        |> assign(:create, :error)
        |> fail()
      else
        action
        |> assign(:create, :ok)
      end
    end

    def rollback(action) do
      rollbacks = action.assigns[:rollbacks] || []

      action
      |> assign(:rollbacks, [1 | rollbacks])
    end
  end

  defmodule SendConfirmationEmail do
    use FireAct.Handler

    def handle(action, params) do
      if params[:fail_confirmation] do
        action
        |> assign(:confirmation, :error)
        |> fail()
      else
        action
        |> assign(:confirmation, :ok)
      end
    end

    def rollback(action) do
      rollbacks = action.assigns[:rollbacks] || []

      action
      |> assign(:rollbacks, [2 | rollbacks])
    end
  end

  defmodule LogActivity do
    use FireAct.Handler

    def handle(action, params) do
      if params[:fail_log_activity] do
        action
        |> assign(:log_activity, :error)
        |> fail()
      else
        action
        |> assign(:log_activity, :ok)
      end
    end

    def rollback(action) do
      rollbacks = action.assigns[:rollbacks] || []

      action
      |> assign(:rollbacks, [3 | rollbacks])
    end
  end

  defmodule UserRegistration do
    use FireAct.Handler
    alias FireActTest.NestedActionsWithRollbacksTest, as: Test

    plug(Test.CreateUser)
    plug(Test.SendConfirmationEmail)
    plug(Test.LogActivity)
  end

  defmodule UserRegistrationWithRollback do
    use FireAct.Handler
    alias FireActTest.NestedActionsWithRollbacksTest, as: Test

    def handle(action, _) do
      FireAct.run(action, [
        Test.CreateUser,
        Test.SendConfirmationEmail,
        Test.LogActivity
      ])
    end
  end

  test "Success flow" do
    {:ok, action} = FireAct.run(UserRegistration, %{})

    assert action.assigns[:create] == :ok
    assert action.assigns[:confirmation] == :ok
    assert action.assigns[:log_activity] == :ok
  end

  test "create fail" do
    {:error, action} = FireAct.run(UserRegistration, %{fail_create: true})

    assert action.assigns[:create] == :error
    assert action.assigns[:confirmation] == nil
    assert action.assigns[:log_activity] == nil
  end

  test "confirmation email fail" do
    {:error, action} = FireAct.run(UserRegistration, %{fail_confirmation: true})

    assert action.assigns[:create] == :ok
    assert action.assigns[:confirmation] == :error
  end

  test "check UserRegistrationWithRollback" do
    {:ok, action} = FireAct.run(UserRegistrationWithRollback, %{})

    assert action.assigns[:create] == :ok
    assert action.assigns[:confirmation] == :ok
    assert action.assigns[:log_activity] == :ok
  end

  test "when one of the steps fails, execute rollbacks in correct order" do
    {:error, action} = FireAct.run(UserRegistrationWithRollback, %{fail_log_activity: true})

    assert action.assigns[:rollbacks] == [1, 2]
  end
end
