Application.put_env(:sample, Example.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 5001],
  server: true,
  live_view: [signing_salt: "aaaaaaaa"],
  secret_key_base: String.duplicate("a", 64)
)

Mix.install([
  {:plug_cowboy, "~> 2.5"},
  {:jason, "~> 1.0"},
  {:phoenix, "~> 1.7.0"},
  {:phoenix_live_view, "~> 0.19.0"}
])

defmodule Example.ErrorView do
  def render(template, _), do: Phoenix.Controller.status_message_from_template(template)
end

defmodule Example.Presence do
  use Phoenix.Presence,
    otp_app: :sample,
    pubsub_server: Example.PubSub
end

defmodule Example.HomeLive do
  use Phoenix.LiveView, layout: {__MODULE__, :live}
  @presence "sample:presence"
  alias Example.Presence

  def mount(params, _session, socket) do
    current_user = %{
      id: params["name"],
      full_name: params["name"]
    }

    {:ok, _} =
      Presence.track(self(), @presence, current_user.id, %{
        name: current_user.full_name,
        joined_at: :os.system_time(:seconds)
      })
      Phoenix.PubSub.subscribe(Example.PubSub, @presence)

    {:ok,
     socket
     |> assign(:online_users_map, %{})
     |> assign_search()
     |> handle_joins(Presence.list(@presence))}
  end

  defp assign_search(socket) do
    searched_notes =
      [
        %{
          id: 1,
          text: "test",
          user_online?: true,
          author: %{id: 1}
        }
      ]

    |> Enum.map(fn x ->
      Map.put(x, :user_online?, Map.has_key?(socket.assigns.online_users_map, x.author.id))
    end)
    |> IO.inspect(label: "searched_notes ################")
    socket
    |> stream(:searched_notes, searched_notes, reset: true)
  end


  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff", payload: diff}, socket) do
    {
      :noreply,
      socket
      |> handle_leaves(diff.leaves)
      |> handle_joins(diff.joins)
    }
  end

  defp handle_joins(socket, joins) do
    IO.inspect(joins, label: "entered handle join s################")

    Enum.reduce(joins, socket, fn {user, %{metas: [meta | _]}}, socket ->
      socket
      # |> assign(:online_users_map, Map.put(socket.assigns.online_users_map, user, meta))
      |> assign(:online_users_map, Map.put(socket.assigns.online_users_map, user, meta))
      # commenting this assign_search out will help avoid the issue.
      |> assign_search()
    end)
  end

  defp handle_leaves(socket, leaves) do
    Enum.reduce(leaves, socket, fn {user, _}, socket ->
      socket
      |> assign(:online_users_map, Map.delete(socket.assigns.online_users_map, user))
      |> assign_search()
    end)
  end

  defp phx_vsn, do: Application.spec(:phoenix, :vsn)
  defp lv_vsn, do: Application.spec(:phoenix_live_view, :vsn)

  def render("live.html", assigns) do
    ~H"""
    <script src={"https://cdn.jsdelivr.net/npm/phoenix@#{phx_vsn()}/priv/static/phoenix.min.js"}></script>
    <script src={"https://cdn.jsdelivr.net/npm/phoenix_live_view@#{lv_vsn()}/priv/static/phoenix_live_view.min.js"}></script>

    <script>
      let liveSocket = new window.LiveView.LiveSocket("/live", window.Phoenix.Socket)
      liveSocket.connect()
    </script>
    <style>
      * { font-size: 1.1em; }
    </style>
    <%= @inner_content %>
    """
  end

  def render(assigns) do
    ~H"""
      <div>
        <%= inspect(@streams.searched_notes) %>
        <ul phx-update="stream" id="searched_notes">
          <li
            :for={{dom_id, note} <- @streams.searched_notes}
            class="py-2 sm:pb-2 mt-2 flex flex-col border border-t-1 border-r-0 border-l-0 border-b-0 "
            id={dom_id}
          >
            <div class="flex flex-col mt-2 ml-14">
              <div class="truncate  text-base  text-gray-900 dark:text-white">
                <%= Phoenix.HTML.raw(note.text) %>
              </div>
            </div>
          </li>
        </ul>
      </div>
    """
  end

end

defmodule Example.Router do
  use Phoenix.Router
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug(:accepts, ["html"])
  end

  scope "/", Example do
    pipe_through(:browser)

    live("/:name", HomeLive, :index)
  end
end

defmodule Example.Endpoint do
  use Phoenix.Endpoint, otp_app: :sample
  socket("/live", Phoenix.LiveView.Socket)
  plug(Example.Router)
end

{:ok, _} = Supervisor.start_link([Example.Endpoint,  {Phoenix.PubSub, name: Example.PubSub}, Example.Presence], strategy: :one_for_one)
Process.sleep(:infinity)
