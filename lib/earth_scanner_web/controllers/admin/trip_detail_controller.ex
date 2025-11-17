defmodule EarthScannerWeb.Admin.TripDetailController do
  use EarthScannerWeb, :controller

  alias EarthScanner.Trips

  plug :require_admin

  defp require_admin(conn, _opts) do
    case conn.assigns[:current_user] do
      %{role: "admin"} -> conn
      _ ->
        conn
        |> put_flash(:error, "You must be an admin to access this page.")
        |> redirect(to: ~p"/")
        |> halt()
    end
  end

  # FR-35: Show trip details
  def show(conn, %{"id" => id}) do
    admin = conn.assigns.current_user

    case Trips.get_trip_for_admin(id, admin) do
      {:ok, trip} ->
        is_future = is_future_trip?(trip)
        has_sold_tickets = Trips.trip_has_sold_tickets?(trip.id)

        render(conn, :show,
          trip: trip,
          is_future: is_future,
          has_sold_tickets: has_sold_tickets
        )

      {:error, :not_found} ->
        conn
        |> put_flash(:error, "Trip not found.")
        |> redirect(to: ~p"/admin/trips")

      {:error, :unauthorized} ->
        conn
        |> put_flash(:error, "You are not authorized to view this trip.")
        |> redirect(to: ~p"/admin/trips")
    end
  end

  # FR-33: Delete trip (with confirmation if tickets sold)
  def delete(conn, %{"id" => id}) do
    admin = conn.assigns.current_user

    case Trips.delete_trip(id, admin) do
      {:ok, _trip} ->
        conn
        |> put_flash(:info, "Trip deleted successfully.")
        |> redirect(to: ~p"/admin/trips")

      {:error, :not_found} ->
        conn
        |> put_flash(:error, "Trip not found.")
        |> redirect(to: ~p"/admin/trips")

      {:error, :unauthorized} ->
        conn
        |> put_flash(:error, "You are not authorized to delete this trip.")
        |> redirect(to: ~p"/admin/trips")

      {:error, :past_trip} ->
        conn
        |> put_flash(:error, "Cannot delete past trips.")
        |> redirect(to: ~p"/admin/trips")

      {:error, :has_sold_tickets} ->
        conn
        |> put_flash(
          :warning,
          "This trip has sold tickets. Please confirm deletion on the next page."
        )
        |> redirect(to: ~p"/admin/trips/#{id}/confirm-delete")
    end
  end

  # FR-33: Show confirmation page for trips with sold tickets
  def confirm_delete(conn, %{"id" => id}) do
    admin = conn.assigns.current_user

    case Trips.get_trip_for_admin(id, admin) do
      {:ok, trip} ->
        if Trips.trip_has_sold_tickets?(trip.id) do
          render(conn, :confirm_delete, trip: trip)
        else
          conn
            |> put_flash(:info, "No sold tickets. You can delete this trip normally.")
            |> redirect(to: ~p"/admin/trips/#{id}")
        end

      {:error, _} ->
        conn
        |> put_flash(:error, "Trip not found or unauthorized.")
        |> redirect(to: ~p"/admin/trips")
    end
  end

  # FR-33: Force delete after confirmation
  def force_delete(conn, %{"id" => id}) do
    admin = conn.assigns.current_user

    case Trips.force_delete_trip(id, admin) do
      {:ok, _trip} ->
        conn
        |> put_flash(:info, "Trip deleted successfully (including all sold tickets).")
        |> redirect(to: ~p"/admin/trips")

      {:error, :not_found} ->
        conn
        |> put_flash(:error, "Trip not found.")
        |> redirect(to: ~p"/admin/trips")

      {:error, :unauthorized} ->
        conn
        |> put_flash(:error, "You are not authorized to delete this trip.")
        |> redirect(to: ~p"/admin/trips")

      {:error, :past_trip} ->
        conn
        |> put_flash(:error, "Cannot delete past trips.")
        |> redirect(to: ~p"/admin/trips")
    end
  end

  defp is_future_trip?(trip) do
    today = Date.utc_today()

    Enum.any?(trip.instances, fn instance ->
      Date.compare(instance.date, today) in [:gt, :eq]
    end)
  end
end
