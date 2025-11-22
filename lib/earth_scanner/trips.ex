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

  # fr-32

  def get_trip(id), do: Repo.get(Trip, id)

  def get_trip_by_id(id) do
    get_trip(id)
  end

  # fr-34
  def compute_recommended_price(transport_mode, duration_hours) do
    lower = duration_hours * 0.8
    upper = duration_hours * 1.2

    matches =
      Trip
      |> where([t], t.transport_mode == ^transport_mode)
      |> where([t], t.duration_hours >= ^lower and t.duration_hours <= ^upper)
      |> Repo.all()

    case matches do
      [] ->
        {:error, :no_matches}

      list ->
        avg_price =
          list
          |> Enum.map(& &1.price)
          |> Enum.sum()
          |> Kernel./(length(list))

        {:ok, %{avg_price: Float.round(avg_price, 2), count: length(list)}}
    end
  end

  # ---------------------- Public search & helpers -----------------------

  @doc """
  Search for future trips matching source and destination patterns.

  Accepts SQL LIKE/ILIKE patterns (e.g. "%Paris%") or plain strings.
  Returns a list of `Trip` structs (not preloaded with instances).
  """
  def search_future_trips(source_pattern, destination_pattern) do
    today = Date.utc_today()

    query =
      from t in Trip,
        where:
          ilike(t.source_city, ^source_pattern) and
            ilike(t.destination_city, ^destination_pattern),
        join: i in TripInstance,
        on: i.trip_id == t.id and i.date >= ^today,
        distinct: true,
        order_by: [asc: t.departure_time]

    Repo.all(query)
  end

  @doc """
  Simple paginated search helper. Returns a map with :trips, :total, :page, :per_page.
  """
  def search_future_trips_paginated(source, destination, params) do
    page =
      case params["page"] do
        p when is_binary(p) ->
          case Integer.parse(p) do
            {i, _} when i > 0 -> i
            _ -> 1
          end

        p when is_integer(p) and p > 0 ->
          p

        _ ->
          1
      end

    per_page =
      case params["per_page"] do
        p when is_binary(p) ->
          case Integer.parse(p) do
            {i, _} when i > 0 -> i
            _ -> 10
          end

        p when is_integer(p) and p > 0 ->
          p

        _ ->
          10
      end

    # Build base query
    today = Date.utc_today()

    base_q =
      from t in Trip,
        where: ilike(t.source_city, ^source) and ilike(t.destination_city, ^destination),
        join: i in TripInstance,
        on: i.trip_id == t.id and i.date >= ^today,
        distinct: true,
        order_by: [asc: t.departure_time]

    # Total count (distinct trips)
    ids_query = from t in subquery(base_q), select: t.id
    total = ids_query |> Repo.all() |> length()

    offset = (page - 1) * per_page

    trips =
      base_q
      |> limit(^per_page)
      |> offset(^offset)
      |> Repo.all()

    %{trips: trips, total: total, page: page, per_page: per_page}
  end

  @doc """
  Preloads only future instances for the given trip or list of trips.
  """
  def preload_future_instances(trips) do
    today = Date.utc_today()

    Repo.preload(trips,
      instances: from(i in TripInstance, where: i.date >= ^today, order_by: [asc: i.date])
    )
  end

  @doc """
  Returns a purchase summary for the given user as a map with two MapSets:
    - :trip_ids -> MapSet of trip ids the user has purchased
    - :instance_ids -> MapSet of trip_instance ids the user has purchased

  If `user` is nil, returns empty sets.
  """
  def purchase_summary_for_user(nil) do
    %{trip_ids: MapSet.new(), instance_ids: MapSet.new()}
  end

  def purchase_summary_for_user(%User{id: user_id}) do
    query =
      from p in Purchase,
        join: i in TripInstance,
        on: p.trip_instance_id == i.id,
        where: p.user_id == ^user_id,
        select: {i.trip_id, p.trip_instance_id}

    pairs = Repo.all(query)

    {trip_ids, instance_ids} =
      Enum.reduce(pairs, {MapSet.new(), MapSet.new()}, fn {trip_id, inst_id}, {tset, iset} ->
        {MapSet.put(tset, trip_id), MapSet.put(iset, inst_id)}
      end)

    %{trip_ids: trip_ids, instance_ids: instance_ids}
  end

  @doc """
  Public getter for a trip by id, preloading only future instances.
  """
  def get_public_trip!(id) do
    today = Date.utc_today()

    Trip
    |> Repo.get!(id)
    |> Repo.preload(
      instances: from(i in TripInstance, where: i.date >= ^today, order_by: [asc: i.date])
    )
  end

  # ---------------------- Recommendations (similar trips) -----------------------

  @doc """
  Finds up to 5 similar trips based on source city, destination city, and price proximity.

  Excludes the current trip and returns only trips with future instances.
  Similarity scoring:
    - Exact source & destination match: highest weight
    - Price within ±30% of the given trip's price
    - Results ordered by similarity score (descending)
  """
  def find_similar_trips(%Trip{
        id: trip_id,
        source_city: source,
        destination_city: dest,
        price: price
      }) do
    today = Date.utc_today()
    price_decimal = Decimal.to_float(price)
    price_tolerance = price_decimal * 0.3
    min_price = price_decimal - price_tolerance
    max_price = price_decimal + price_tolerance

    query =
      from t in Trip,
        where:
          t.id != ^trip_id and
            t.source_city == ^source and
            t.destination_city == ^dest and
            t.price >= ^min_price and
            t.price <= ^max_price,
        join: i in TripInstance,
        on: i.trip_id == t.id and i.date >= ^today,
        group_by: t.id,
        select: t,
        order_by: [asc: fragment("ABS(? - ?)", t.price, ^price_decimal)],
        limit: 5

    results = Repo.all(query)

    # Preload instances for each trip
    preload_future_instances(results)
  end

  @doc """
  Simple version: find similar trips given a trip id.
  """
  def find_similar_trips(trip_id) do
    case get_trip(trip_id) do
      nil -> []
      trip -> find_similar_trips(trip)
    end
  end
end
