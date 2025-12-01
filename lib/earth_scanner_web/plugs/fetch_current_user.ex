defmodule EarthScannerWeb.FetchCurrentUser do
  @moduledoc false
  import Plug.Conn
  alias EarthScanner.Accounts
  alias EarthScanner.Trips
  alias EarthScanner.Notifications

  def init(opts), do: opts

  def call(conn, _opts) do
    user =
      conn
      |> get_session(:user_id)
      |> case do
        nil -> nil
        id -> Accounts.get_user_by_id(id)
      end

    # compute a lightweight notification count for header badge
    notification_count =
      if user do
        reminder_count =
          Trips.list_purchases_for_user_with_trip(user.id)
          |> Enum.reduce(0, fn p, acc ->
            inst = Map.get(p, :trip_instance)
            trip = Map.get(inst || %{}, :trip)

            case build_departure_datetime(trip, inst) do
              {:ok, dep_dt} ->
                secs = DateTime.diff(dep_dt, DateTime.utc_now(), :second)
                if secs <= 24 * 3600 && secs >= 0, do: acc + 1, else: acc

              _ ->
                acc
            end
          end)

        unread = Notifications.unread_count_for_user(user.id) || 0

        reminder_count + unread
      else
        0
      end

    conn
    |> assign(:current_user, user)
    |> assign(:notification_count, notification_count)
  end

  defp build_departure_datetime(%{departure_time: %DateTime{} = dep_dt}, %{date: %Date{} = date}) do
    case Time.new(dep_dt.hour, dep_dt.minute, dep_dt.second) do
      {:ok, time} ->
        case DateTime.new(date, time, "Etc/UTC") do
          {:ok, dt, _} -> {:ok, dt}
          {:ok, dt} -> {:ok, dt}
          {:error, _} = err -> err
        end

      {:error, _} = err ->
        err
    end
  end

  defp build_departure_datetime(_, _), do: {:error, :invalid_data}
end
