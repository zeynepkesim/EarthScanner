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

    get "/profile/edit", ProfileController, :edit
    put "/profile", ProfileController, :update
    get "/users/delete", ProfileController, :confirm_delete
    post "/users/delete", ProfileController, :delete

    get "/users/change-password", ProfileController, :edit_password
    post "/users/change-password", ProfileController, :update_password

    get "/search", TripSearchController, :new
    get "/search/results", TripSearchController, :index
    # Public trips listing for users
    get "/trips", TripsController, :index
    get "/trips/:id", TripsController, :show
    post "/trips/:trip_id/purchase", TripPurchaseController, :create
  end

  scope "/admin", EarthScannerWeb do
    pipe_through [:browser, :require_admin]

    get "/users/new", AdminUserController, :new
    post "/users", AdminUserController, :create

    # FR-29
    get "/trips", TripController, :index
    get "/trips/new", TripController, :new
    post "/trips", TripController, :create
    get "/trips/:id/edit", TripController, :edit
    put "/trips/:id", TripController, :update
    delete "/trips/:id", TripController, :delete

    # FR-35: View Trip Details
    get "/trips/:id", Admin.TripDetailController, :show

    # FR-33: Delete Trip
    delete "/trips/:id", Admin.TripDetailController, :delete
    get "/trips/:id/confirm-delete", Admin.TripDetailController, :confirm_delete
    post "/trips/:id/force-delete", Admin.TripDetailController, :force_delete

    # FR-36
    get "/trips/:trip_id/instances/:id/edit", TripInstanceController, :edit
    put "/trips/:trip_id/instances/:id", TripInstanceController, :update
    delete "/trips/:trip_id/instances/:id", TripInstanceController, :delete

    # Past / Future trips admin views
    get "/past-trips", Admin.PastTripsController, :index
    get "/past-trips/:id", Admin.PastTripsController, :show

    get "/future-trips", Admin.FutureTripsController, :index
    get "/future-trips/:id", Admin.FutureTripsController, :show
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
