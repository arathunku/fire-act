defmodule FireAct.Action do
  alias __MODULE__

  @type assigns :: %{atom => any}
  @type halted :: boolean
  @type failed :: boolean
  @type param :: binary | %{binary => param} | [param]
  @type params :: %{atom => param}

  @type t :: %__MODULE__{
          assigns: assigns,
          halted: halted,
          params: params,
          failed: failed,
          private: assigns
        }

  defstruct halted: false,
            assigns: %{},
            params: %{},
            failed: false,
            private: %{}


  def new(%Plug.Conn{} = conn) do
    new(conn.params, conn.assigns)
  end

  def new(params) do
    new(params, %{})
  end

  def new(%Plug.Conn{} = conn, assigns) do
    new(conn.params, Map.merge(conn.assigns, assigns))
  end

  def new(params, assigns) do
    %__MODULE__{params: params, assigns: assigns}
  end

  @spec assign(t, atom, term) :: t
  def assign(%Action{assigns: assigns} = action, key, value) when is_atom(key) do
    %{action | assigns: Map.put(assigns, key, value)}
  end

  @spec merge_assigns(t, Keyword.t()) :: t
  def merge_assigns(%Action{assigns: assigns} = action, keyword) when is_list(keyword) do
    %{action | assigns: Enum.into(keyword, assigns)}
  end

  def put_private(%Action{private: private} = action, key, value) when is_atom(key) do
    %{action | private: Map.put(private, key, value)}
  end

  def merge_private(%Action{private: private} = action, keyword) when is_list(keyword) do
    %{action | private: Enum.into(keyword, private)}
  end

  def halt(%Action{} = action) do
    %{action | halted: true}
  end

  def fail(%Action{} = action) do
    %{action | failed: true}
    |> halt()
  end
end
