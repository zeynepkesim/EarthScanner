defmodule EarthScannerWeb.Router do
  use EarthScannerWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {EarthScannerWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug EarthScannerWeb.FetchCurrentUser
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :require_admin do
    plug EarthScannerWeb.RequireAdmin
  end

  scope "/", EarthScannerWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/users/register", UserRegistrationController, :new
    post "/users/register", UserRegistrationController, :create
    get "/users/login", SessionController, :new
    post "/users/login", SessionController, :create
    delete "/users/logout", SessionController, :delete

    get "/profile", ProfileController, :show

    # teammate's profile edit/delete routes
    get "/profile/edit", ProfileController, :edit
    put "/profile", ProfileController, :update
    get "/users/delete", ProfileController, :confirm_delete
    post "/users/delete", ProfileController, :delete

    # your change-password routes
    get "/users/change-password", ProfileController, :edit_password
    post "/users/change-password", ProfileController, :update_password
  end

  scope "/admin", EarthScannerWeb do
    pipe_through [:browser, :require_admin]

    get "/users/new", AdminUserController, :new
    post "/users", AdminUserController, :create
  end

  if Application.compile_env(:earth_scanner, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: EarthScannerWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
