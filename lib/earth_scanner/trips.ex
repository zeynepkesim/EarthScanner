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
  alias EarthScanner.Purchases.Purchase

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

  @doc """
  Lists all trips created by the given admin with all their instances (past and future).

  Trips are ordered by departure_time ascending.
  """
  def list_all_trips_for_admin(%User{id: admin_id}) do
    query =
      from t in Trip,
        where: t.admin_id == ^admin_id,
        preload: :instances,
        order_by: [asc: t.departure_time]

    Repo.all(query)
  end

  def get_trip!(id), do: Repo.get!(Trip, id)

  @doc """
  Updates a trip with new attributes.

  ## Examples

      update_trip(trip, %{price: 50, available_tickets: 25})

  """
  def update_trip(%Trip{} = trip, attrs) do
    trip
    |> Trip.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a trip and all its instances.

  """
  def delete_trip(%Trip{} = trip) do
    Repo.delete(trip)
  end

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

  # FR-35: Get trip with all details for admin
  @doc """
  Gets a trip by ID with all its instances and preloaded data.
  Ensures the trip belongs to the given admin.

  Returns `{:ok, trip}` or `{:error, :not_found}` or `{:error, :unauthorized}`.
  """
  def get_trip_for_admin(trip_id, %User{id: admin_id, role: "admin"}) do
    trip =
      Trip
      |> Repo.get(trip_id)
      |> Repo.preload([
        :admin,
        instances: from(i in TripInstance, order_by: [asc: i.date])
      ])

    cond do
      is_nil(trip) ->
        {:error, :not_found}

      trip.admin_id != admin_id ->
        {:error, :unauthorized}

      true ->
        {:ok, trip}
    end
  end

  # FR-33: Check if any tickets have been sold for this trip
  @doc """
  Checks if any tickets have been sold for any instance of the given trip.

  Returns `true` if at least one purchase exists, `false` otherwise.
  """
  def trip_has_sold_tickets?(trip_id) do
    query =
      from p in Purchase,
        join: i in TripInstance,
        on: p.trip_instance_id == i.id,
        where: i.trip_id == ^trip_id,
        limit: 1

    Repo.exists?(query)
  end

  # FR-33: Delete trip with validation
  @doc """
  Deletes a trip if it belongs to the admin and meets deletion criteria.

  Returns:
    - `{:ok, trip}` on successful deletion
    - `{:error, :not_found}` if trip doesn't exist
    - `{:error, :unauthorized}` if trip doesn't belong to admin
    - `{:error, :past_trip}` if trip is in the past
    - `{:error, :has_sold_tickets}` if tickets have been sold (needs confirmation)
  """
  def delete_trip(trip_id, %User{id: admin_id, role: "admin"}) do
    with {:ok, trip} <- get_trip_for_admin(trip_id, %User{id: admin_id, role: "admin"}),
         :ok <- validate_trip_is_future(trip),
         :ok <- validate_no_sold_tickets(trip_id) do
      Repo.delete(trip)
    end
  end

  # FR-33: Force delete trip (when admin confirms despite sold tickets)
  @doc """
  Force deletes a trip even if tickets have been sold.
  Use this when admin explicitly confirms deletion.

  Returns `{:ok, trip}` or error tuple.
  """
  def force_delete_trip(trip_id, %User{id: admin_id, role: "admin"}) do
    with {:ok, trip} <- get_trip_for_admin(trip_id, %User{id: admin_id, role: "admin"}),
         :ok <- validate_trip_is_future(trip) do
      # Delete all purchases first (cascade will handle this, but explicit is better)
      Repo.delete(trip)
    end
  end

  defp validate_trip_is_future(trip) do
    today = Date.utc_today()

    has_future_instance =
      Enum.any?(trip.instances, fn instance ->
        Date.compare(instance.date, today) in [:gt, :eq]
      end)

    if has_future_instance do
      :ok
    else
      {:error, :past_trip}
    end
  end

  defp validate_no_sold_tickets(trip_id) do
    if trip_has_sold_tickets?(trip_id) do
      {:error, :has_sold_tickets}
    else
      :ok
    end
  end

  #fr-32

  def get_trip(id), do: Repo.get(Trip, id)

  def get_trip_by_id(id) do
    get_trip(id)
  end

end
