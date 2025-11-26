defmodule EarthScannerWeb.NotificationsController do
  use EarthScannerWeb, :controller

  alias EarthScanner.Trips

  def index(conn, _params) do
    case conn.assigns[:current_user] do
      %{} = user ->
        reminders = compute_due_reminders_for_user(user.id)
        render(conn, "index.html", reminders: reminders, current_scope: "user")

      _ ->
        conn
        |> put_flash(:error, "Please log in to view notifications.")
        |> redirect(to: ~p"/users/login")
    end
  end

  defp compute_due_reminders_for_user(user_id) do
    Trips.list_purchases_for_user_with_trip(user_id)
    |> Enum.reduce([], fn p, acc ->
      inst = Map.get(p, :trip_instance)
      trip = Map.get(inst || %{}, :trip)

      case build_departure_datetime(trip, inst) do
        {:ok, dep_dt} ->
          secs = DateTime.diff(dep_dt, DateTime.utc_now(), :second)

          if secs <= 24 * 3600 && secs >= 0 do
            [%{purchase: p, departure: dep_dt, trip: trip, instance: inst} | acc]
          else
            acc
          end

        _ ->
          acc
      end
    end)
    |> Enum.reverse()
  end

  defp build_departure_datetime(%{departure_time: %DateTime{} = dep_dt}, %{date: %Date{} = date}) do
    case Time.new(dep_dt.hour, dep_dt.minute, dep_dt.second) do
      {:ok, time} ->
        case DateTime.new(date, time, "Etc/UTC") do
          {:ok, dt, _} -> {:ok, dt}
          {:ok, dt} -> {:ok, dt}
          {:error, _} = err -> err
        end

      {:error, _} = err -> err
    end
  end

  defp build_departure_datetime(_, _), do: {:error, :invalid_data}
end
