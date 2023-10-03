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

  alias Example.Presence

  def mount(_params, _session, socket) do
    {:ok, assign(socket, :count, 0)}
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

  def handle_event("inc", _params, socket) do
    {:noreply, assign(socket, :count, socket.assigns.count + 1)}
  end

  def handle_event("dec", _params, socket) do
    {:noreply, assign(socket, :count, socket.assigns.count - 1)}
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

    live("/", HomeLive, :index)
  end
end

defmodule Example.Endpoint do
  use Phoenix.Endpoint, otp_app: :sample
  socket("/live", Phoenix.LiveView.Socket)
  plug(Example.Router)
end

{:ok, _} = Supervisor.start_link([Example.Endpoint], strategy: :one_for_one)
Process.sleep(:infinity)