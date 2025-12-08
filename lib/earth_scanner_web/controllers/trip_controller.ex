defmodule EarthScannerWeb.TripController do
  use EarthScannerWeb, :controller
  import Phoenix.Component, only: [to_form: 1]

  alias EarthScanner.Trips
  alias EarthScanner.Trips.Trip

  plug :require_admin

  defp require_admin(conn, _opts) do
    case conn.assigns[:current_user] do
      %{role: "admin"} ->
        conn

      _ ->
        conn
        |> put_flash(:error, "You must be an admin to access this page.")
        |> redirect(to: ~p"/")
        |> halt()
    end
  end

  # FR-29: List all trips created by admin
  def index(conn, _params) do
    admin = conn.assigns.current_user
    trips = Trips.list_all_trips_for_admin(admin)

    render(conn, :index, trips: trips)
  end

  # FR-29: Show trip creation form
  def new(conn, _params) do
    changeset = Trip.changeset(%Trip{}, %{})
    render(conn, :new, form: to_form(changeset))
  end

  # FR-29: Create trip with all details
  # FR-36: Process recurring dates
  def create(conn, %{"trip" => trip_params}) do
    admin = conn.assigns.current_user

    case Trips.create_trip(admin, trip_params) do
      {:ok, _trip} ->
        conn
        |> put_flash(:info, "Trip created successfully.")
        |> redirect(to: ~p"/admin/trips")

      {:error, %Ecto.Changeset{} = changeset} ->
        changeset = Map.put(changeset, :action, :insert)
        render(conn, :new, form: to_form(changeset))
    end
  end

  def edit(conn, %{"id" => id}) do
    trip = Trips.get_trip!(id)
    changeset = Trip.changeset(trip, %{})
    read_only = DateTime.compare(trip.departure_time, DateTime.utc_now()) == :lt
    render(conn, :edit, form: to_form(changeset), trip: trip, read_only: read_only)
  end

  def update(conn, %{"id" => id, "trip" => trip_params}) do
    trip = Trips.get_trip!(id)

    # FR-32: Check for critical changes on trips with sold tickets
    has_purchases =
      Ecto.assoc(trip, :purchases)
      |> EarthScanner.Repo.exists?()

    critical_fields = [
      "departure_time",
      "dates",
      "source_city",
      "destination_city",
      "arrival_time"
    ]

    is_critical_change =
      Enum.any?(critical_fields, fn field -> Map.has_key?(trip_params, field) end)

    case Trips.update_trip(trip, trip_params) do
      {:ok, _trip} ->
        msg =
          if has_purchases and is_critical_change do
            "Trip updated. WARNING: This trip has sold tickets. Please notify affected users."
          else
            "Trip updated successfully."
          end

        conn
        |> put_flash(:info, msg)
        |> redirect(to: ~p"/admin/trips")

      {:ok, _trip, _diff} ->
        # The Trips context may return a diff of changes as a 3-tuple.
        msg =
          if has_purchases and is_critical_change do
            "Trip updated. WARNING: This trip has sold tickets. Please notify affected users."
          else
            "Trip updated successfully."
          end

        conn
        |> put_flash(:info, msg)
        |> redirect(to: ~p"/admin/trips")

      {:error, %Ecto.Changeset{} = changeset} ->
        trip = Trips.get_trip!(id)
        read_only = DateTime.compare(trip.departure_time, DateTime.utc_now()) == :lt
        render(conn, :edit, form: to_form(changeset), trip: trip, read_only: read_only)
    end
  end

  def delete(conn, %{"id" => id}) do
    trip = Trips.get_trip!(id)
    {:ok, _} = Trips.delete_trip(trip)

    conn
    |> put_flash(:info, "Trip deleted successfully.")
    |> redirect(to: ~p"/admin/trips")
  end
end
