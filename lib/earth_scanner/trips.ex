defmodule EarthScanner.Trips do
  @moduledoc """
  Trips context.

  Provides functions to manage trips and their recurring date instances.
  """

  import Ecto.Query, warn: false
  alias Ecto.Multi
  alias EarthScanner.Repo

  alias EarthScanner.Trips.{Trip, TripInstance}
  alias EarthScanner.Accounts.User

  # ---------- FR-29: create trip with all details + FR-36 dates ----------

  @doc """
  Creates a trip for the given admin with one or more date instances.

  ## Returns

    * `{:ok, %Trip{}}` on success (preloaded with instances)
    * `{:error, %Ecto.Changeset{}}` on validation error

  """
  def create_trip(%User{id: admin_id}, attrs) do
    raw_dates = Map.get(attrs, "dates", "") || ""

    case parse_dates(raw_dates) do
      {:error, :no_dates} ->
        changeset =
          %Trip{}
          |> Trip.changeset(Map.put(attrs, "admin_id", admin_id))
          |> Ecto.Changeset.add_error(:base, "at least one trip date is required")

        {:error, changeset}

      {:error, {:invalid_date, value}} ->
        changeset =
          %Trip{}
          |> Trip.changeset(Map.put(attrs, "admin_id", admin_id))
          |> Ecto.Changeset.add_error(:base, "invalid date: #{value}")

        {:error, changeset}

      {:ok, dates} ->
        trip_attrs = Map.put(attrs, "admin_id", admin_id)

        Multi.new()
        |> Multi.insert(:trip, Trip.changeset(%Trip{}, trip_attrs))
        |> Multi.run(:instances, fn repo, %{trip: trip} ->
          instances =
            Enum.map(dates, fn date ->
              TripInstance.changeset(%TripInstance{}, %{
                "trip_id" => trip.id,
                "date" => date,
                "available_tickets" => trip.available_tickets
              })
            end)

          case Enum.split_with(instances, & &1.valid?) do
            {valid, []} ->
              Enum.each(valid, &repo.insert!/1)
              {:ok, valid}

            {_, invalid} ->
              {:error, hd(invalid)}
          end
        end)
        |> Repo.transaction()
        |> case do
          {:ok, %{trip: trip}} ->
            {:ok, Repo.preload(trip, :instances)}

          {:error, _op, changeset, _} ->
            {:error, changeset}
        end
    end
  end

  # FR-29 / FR-36: parse multi-line (or comma-separated) dates
  defp parse_dates(raw) when is_binary(raw) do
    parts =
      raw
      |> String.split(~r/[\n,]+/, trim: true)

    if parts == [] do
      {:error, :no_dates}
    else
      parts
      |> Enum.reduce_while({:ok, []}, fn part, {:ok, acc} ->
        case Date.from_iso8601(String.trim(part)) do
          {:ok, date} ->
            {:cont, {:ok, [date | acc]}}

          {:error, _} ->
            {:halt, {:error, {:invalid_date, part}}}
        end
      end)
      |> case do
        {:ok, dates} -> {:ok, Enum.uniq(Enum.reverse(dates))}
        {:error, _} = err -> err
      end
    end
  end

  # ---------- FR-29: list future trips for admin ----------

  @doc """
  Lists trips created by the given admin that still have at least one future instance.

  Trips are preloaded with their future instances only.
  """
  def list_future_trips_for_admin(%User{id: admin_id}) do
    today = Date.utc_today()

    query =
      from t in Trip,
        where: t.admin_id == ^admin_id,
        join: i in TripInstance,
        on: i.trip_id == t.id and i.date >= ^today,
        preload: [instances: i],
        distinct: true,
        order_by: [asc: t.departure_time]

    Repo.all(query)
  end

  @doc """
  Lists trips created by the given admin that only have past instances.

  Trips are preloaded with their past instances only and ordered by departure_time descending.
  """
  def list_past_trips_by_admin(%User{id: admin_id}) do
    today = Date.utc_today()

    query =
      from t in Trip,
        where: t.admin_id == ^admin_id,
        join: i in TripInstance,
        on: i.trip_id == t.id and i.date < ^today,
        preload: [instances: i],
        distinct: true,
        order_by: [desc: t.departure_time]

    Repo.all(query)
  end

  def get_trip!(id), do: Repo.get!(Trip, id)

  # ---------- FR-36: manage instances (edit/delete) ----------

  def get_trip_instance!(trip_id, id) do
    Repo.get_by!(TripInstance, %{id: id, trip_id: trip_id})
  end

  @doc """
  Updates a single trip instance (e.g. date or available tickets).

  ## Examples

      update_trip_instance(instance, %{available_tickets: 30})

  """
  def update_trip_instance(%TripInstance{} = instance, attrs) do
    instance
    |> TripInstance.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a single trip instance.

  """
  def delete_trip_instance(%TripInstance{} = instance) do
    Repo.delete(instance)
  end
end
