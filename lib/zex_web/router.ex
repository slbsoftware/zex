defmodule ZexWeb.Router do
  use ZexWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ZexWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :ensure_session_id
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", ZexWeb do
    pipe_through :browser

    # get "/", PageController, :home
    live "/", GameLive
  end

  if Application.compile_env(:zex, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: ZexWeb.Telemetry
    end
  end

  def ensure_session_id(conn, _) do
    sid = get_session(conn, :session_id)
    if sid do
      IO.puts("have session id #{sid}")
      conn
    else
      sid = Ecto.UUID.generate()
      IO.puts("generate session id #{sid}")
      put_session(conn, :session_id, sid)
    end
  end
end
