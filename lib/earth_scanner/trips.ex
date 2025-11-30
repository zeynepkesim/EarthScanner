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
    changeset = Trip.changeset(trip, attrs)

    # compute simple diff for changed fields: %{field => {old, new}}
    watched = Map.keys(changeset.changes)

    diff =
      watched
      |> Enum.reduce(%{}, fn key, acc ->
        old = Map.get(trip, key)
        new = Map.get(changeset.changes, key)
        Map.put(acc, to_string(key), {old, new})
      end)

    case Repo.update(changeset) do
      {:ok, trip} ->
        # After successful update, notify purchasers synchronously (no worker)
        notify_trip_change(trip, diff)
        {:ok, trip, diff}

      other ->
        other
    end
  end

  defp notify_trip_change(trip, diff) when diff == %{} do
    :ok
  end

  defp notify_trip_change(trip, diff) do
    # find unique purchasers for this trip
    purchasers = list_purchasers_for_trip(trip.id)

    Enum.each(purchasers, fn user ->
      # create in-app notification (best-effort)
      sanitized = sanitize_diff_for_storage(diff)
      attrs = %{
        "user_id" => user.id,
        "kind" => "trip_change",
        "payload" => %{"trip_id" => trip.id, "diff" => sanitized}
      }

      try do
        EarthScanner.Notifications.create_notification(attrs)
      rescue
        _ -> :ok
      end

      # send email synchronously
      try do
        email = EarthScanner.Notifications.TripUpdateEmail.build(user, trip, diff)
        EarthScanner.Mailer.deliver(email)
      rescue
        _ -> :ok
      end
    end)

    :ok
  end

  defp sanitize_diff_for_storage(diff) when is_map(diff) do
    diff
    |> Enum.map(fn {k, {old, new}} ->
      {k, %{"old" => old, "new" => new}}
    end)
    |> Enum.into(%{})
  end
  defp sanitize_diff_for_storage(_), do: %{}

  @doc """
  Lists unique purchasers (users) for a given trip id.
  Returns a list of `EarthScanner.Accounts.User` structs.
  """
  def list_purchasers_for_trip(trip_id) do
    query =
      from u in User,
        join: p in Purchase,
        on: p.user_id == u.id,
        join: i in TripInstance,
        on: p.trip_instance_id == i.id,
        where: i.trip_id == ^trip_id,
        distinct: u.id,
        select: u

    Repo.all(query)
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
  Gets a trip instance by id and preloads the associated trip.
  Returns `nil` if not found.
  """
  def get_instance_with_trip(id) do
    Repo.get(TripInstance, id)
    |> case do
      nil ->
        nil
      instance ->
        Repo.preload(instance, :trip)
    end
  end

  @doc """
  Lists purchases for a given user with the trip_instance and trip preloaded.
  """
  def list_purchases_for_user_with_trip(user_id) do
    from(p in Purchase, where: p.user_id == ^user_id, preload: [trip_instance: :trip])
    |> Repo.all()
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
      # Ensure associated purchases are removed first, then delete the trip.
      # Load instances so we can find related purchases.
      Repo.transaction(fn ->
        # delete purchases for instances that belong to this trip
        from(p in Purchase,
          join: i in TripInstance,
          on: p.trip_instance_id == i.id,
          where: i.trip_id == ^trip.id
        )
        |> Repo.delete_all()

        # delete the trip (instances should be cascade-deleted if configured)
        Repo.delete!(trip)
      end)
      |> case do
        {:ok, _} -> {:ok, trip}
        {:error, _} = err -> err
      end
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

    # Trip schema stores duration in minutes; convert hour bounds to minutes
    lower_minutes = round(lower * 60)
    upper_minutes = round(upper * 60)

    matches =
      Trip
      |> where([t], t.transport_mode == ^transport_mode)
      |> where([t], t.duration_minutes >= ^lower_minutes and t.duration_minutes <= ^upper_minutes)
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
  Backwards compatible API: accepts source, destination and params and
  returns a list of trips. Tests in the suite call this arity.
  """
  def search_future_trips(source, destination, _params) do
    # Delegate to the higher-level `search/1` which applies the same
    # filtering semantics used by the controllers and tests.
    search(%{"source" => source, "destination" => destination})
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
            _ -> 5
          end

        p when is_integer(p) and p > 0 ->
          p

        _ ->
          5
      end

    # Build base query with filters
    now = DateTime.utc_now()

    base_q =
      from t in Trip,
        where:
          ilike(t.source_city, ^source) and
            ilike(t.destination_city, ^destination) and
            t.departure_time > ^now,
        distinct: true

    # Apply numeric filters for price
    base_q =
      case params["min_price"] do
        nil ->
          base_q

        "" ->
          base_q

        v when is_binary(v) ->
          case Integer.parse(v) do
            {i, _} -> from q in base_q, where: q.price >= ^i
            :error -> base_q
          end

        _ ->
          base_q
      end

    base_q =
      case params["max_price"] do
        nil ->
          base_q

        "" ->
          base_q

        v when is_binary(v) ->
          case Integer.parse(v) do
            {i, _} -> from q in base_q, where: q.price <= ^i
            :error -> base_q
          end

        _ ->
          base_q
      end

    # Apply filters for duration
    base_q =
      case params["min_duration"] do
        nil ->
          base_q

        "" ->
          base_q

        v when is_binary(v) ->
          case Integer.parse(v) do
            {i, _} -> from q in base_q, where: q.duration_minutes >= ^i
            :error -> base_q
          end

        _ ->
          base_q
      end

    base_q =
      case params["max_duration"] do
        nil ->
          base_q

        "" ->
          base_q

        v when is_binary(v) ->
          case Integer.parse(v) do
            {i, _} -> from q in base_q, where: q.duration_minutes <= ^i
            :error -> base_q
          end

        _ ->
          base_q
      end

    # Apply filters for CO2
    base_q =
      case params["min_co2"] do
        nil ->
          base_q

        "" ->
          base_q

        v when is_binary(v) ->
          case Integer.parse(v) do
            {i, _} -> from q in base_q, where: q.co2_level >= ^i
            :error -> base_q
          end

        _ ->
          base_q
      end

    base_q =
      case params["max_co2"] do
        nil ->
          base_q

        "" ->
          base_q

        v when is_binary(v) ->
          case Integer.parse(v) do
            {i, _} -> from q in base_q, where: q.co2_level <= ^i
            :error -> base_q
          end

        _ ->
          base_q
      end

    # Apply filters for departure time
    base_q =
      case params["min_departure"] do
        nil ->
          base_q

        "" ->
          base_q

        v when is_binary(v) ->
          case DateTime.from_iso8601(v) do
            {:ok, dt, _} -> from q in base_q, where: q.departure_time >= ^dt
            {:ok, dt} -> from q in base_q, where: q.departure_time >= ^dt
            _ -> base_q
          end

        _ ->
          base_q
      end

    base_q =
      case params["max_departure"] do
        nil ->
          base_q

        "" ->
          base_q

        v when is_binary(v) ->
          case DateTime.from_iso8601(v) do
            {:ok, dt, _} -> from q in base_q, where: q.departure_time <= ^dt
            {:ok, dt} -> from q in base_q, where: q.departure_time <= ^dt
            _ -> base_q
          end

        _ ->
          base_q
      end

    # Apply filters for arrival time
    base_q =
      case params["min_arrival"] do
        nil ->
          base_q

        "" ->
          base_q

        v when is_binary(v) ->
          case DateTime.from_iso8601(v) do
            {:ok, dt, _} -> from q in base_q, where: q.arrival_time >= ^dt
            {:ok, dt} -> from q in base_q, where: q.arrival_time >= ^dt
            _ -> base_q
          end

        _ ->
          base_q
      end

    base_q =
      case params["max_arrival"] do
        nil ->
          base_q

        "" ->
          base_q

        v when is_binary(v) ->
          case DateTime.from_iso8601(v) do
            {:ok, dt, _} -> from q in base_q, where: q.arrival_time <= ^dt
            {:ok, dt} -> from q in base_q, where: q.arrival_time <= ^dt
            _ -> base_q
          end

        _ ->
          base_q
      end

    # Apply sorting
    base_q =
      case params["sort"] do
        "price_asc" -> from q in base_q, order_by: [asc: q.price]
        "price_desc" -> from q in base_q, order_by: [desc: q.price]
        "co2_asc" -> from q in base_q, order_by: [asc: q.co2_level]
        "co2_desc" -> from q in base_q, order_by: [desc: q.co2_level]
        "duration_asc" -> from q in base_q, order_by: [asc: q.duration_minutes]
        "duration_desc" -> from q in base_q, order_by: [desc: q.duration_minutes]
        _ -> from q in base_q, order_by: [asc: q.departure_time]
      end

    # Total count
    total = base_q |> Repo.all() |> length()

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

  @doc """
  Returns a trip visible to the given user.

  - If `user` is `nil` (anonymous), returns the public trip (future instances only) or `{:error, :not_found}`.
  - If `user.role == "admin"`, delegates to `get_trip_for_admin/2` (which checks ownership).
  - If `user.role == "user"`, returns the public trip (future instances only).

  This centralizes authorization so controllers won't accidentally leak admin-only data.
  """
  def get_trip_for_user(nil, _id), do: {:error, :unauthorized}

  def get_trip_for_user(%User{role: "admin", id: admin_id}, id) do
    # FR-24: Admins can ONLY view trips they created
    case Repo.get(Trip, id) do
      nil ->
        {:error, :not_found}

      %Trip{admin_id: ^admin_id} = trip ->
        # Admin owns this trip
        trip =
          Repo.preload(trip, [:admin, instances: from(i in TripInstance, order_by: [asc: i.date])])

        {:ok, trip}

      %Trip{} ->
        # Admin doesn't own this trip
        {:error, :unauthorized}
    end
  end

  def get_trip_for_user(%User{role: "user"}, id) do
    # FR-24: Regular users can view ANY trip (for booking purposes)
    # They see public information only (future instances)
    case Repo.get(Trip, id) do
      nil ->
        {:error, :not_found}

      %Trip{} = trip ->
        trip = preload_future_instances(trip)
        {:ok, trip}
    end
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

  def find_similar_trips(trip_id) do
    case get_trip(trip_id) do
      nil -> []
      trip -> find_similar_trips(trip)
    end
  end

  @doc """
  High-level search API used by controllers and tests.

  Accepts a map of params with string keys, e.g.
    %{"source" => "Tartu", "destination" => "Tallinn", "min_price" => "10", "sort" => "price_asc"}

  Returns a list of `Trip` structs (only future trips are considered).
  """
  def search(params) when is_map(params) do
    src = params["source"] || ""
    dst = params["destination"] || ""

    # Don't run a query if required fields missing
    if String.trim(src) == "" or String.trim(dst) == "" do
      []
    else
      source = "%#{src}%"
      destination = "%#{dst}%"

      base_q =
        from t in Trip,
          where:
            ilike(t.source_city, ^source) and ilike(t.destination_city, ^destination) and
              t.departure_time > ^DateTime.utc_now(),
          distinct: true

      # apply numeric filters
      base_q =
        case params["min_price"] do
          nil ->
            base_q

          v when is_binary(v) ->
            case Float.parse(v) do
              {f, _} -> from q in base_q, where: q.price >= ^f
              :error -> base_q
            end

          _ ->
            base_q
        end

      base_q =
        case params["max_price"] do
          nil ->
            base_q

          v when is_binary(v) ->
            case Float.parse(v) do
              {f, _} -> from q in base_q, where: q.price <= ^f
              :error -> base_q
            end

          _ ->
            base_q
        end

      base_q =
        case params["max_co2"] do
          nil ->
            base_q

          v when is_binary(v) ->
            case Integer.parse(v) do
              {i, _} -> from q in base_q, where: q.co2_level <= ^i
              :error -> base_q
            end

          _ ->
            base_q
        end

      # sorting
      base_q =
        case params["sort"] do
          "price_asc" -> from q in base_q, order_by: [asc: q.price]
          "price_desc" -> from q in base_q, order_by: [desc: q.price]
          "co2_asc" -> from q in base_q, order_by: [asc: q.co2_level]
          "co2_desc" -> from q in base_q, order_by: [desc: q.co2_level]
          "duration_asc" -> from q in base_q, order_by: [asc: q.duration_minutes]
          "duration_desc" -> from q in base_q, order_by: [desc: q.duration_minutes]
          _ -> from q in base_q, order_by: [asc: q.departure_time]
        end

      trips = Repo.all(base_q)

      # preload only future instances
      preload_future_instances(trips)
    end
  end

  @doc """
  Purchases a trip instance for the given user.

  Returns `{:ok, purchase}` on success or `{:error, reason}` where reason is
  `:past_instance`, `:sold_out` or other Repo errors.
  """
  def purchase_trip_instance(%User{id: user_id} = _user, instance_id) do
    today = Date.utc_today()

    case Repo.get(TripInstance, instance_id) do
      nil ->
        {:error, :not_found}

      %TripInstance{} = instance ->
        cond do
          Date.compare(instance.date, today) == :lt ->
            {:error, :past_instance}

          instance.available_tickets <= 0 ->
            {:error, :sold_out}

          # Prevent duplicate purchases by the same user for the same instance
          Repo.get_by(Purchase, user_id: user_id, trip_instance_id: instance.id) != nil ->
            {:error, :already_purchased}

          true ->
            Ecto.Multi.new()
            |> Ecto.Multi.insert(
              :purchase,
              Purchase.changeset(%Purchase{}, %{user_id: user_id, trip_instance_id: instance.id})
            )
            |> Ecto.Multi.update(
              :decrement,
              TripInstance.changeset(instance, %{
                available_tickets: instance.available_tickets - 1
              })
            )
            |> Repo.transaction()
            |> case do
              {:ok, %{purchase: purchase}} -> {:ok, purchase}
              {:error, _op, changeset, _} -> {:error, changeset}
            end
        end
    end
  end

  @doc """
  Returns a previously made purchase (refund) by the user for the given instance.

  Returns `{:ok, purchase}` on success, or `{:error, :not_found}` if no purchase,
  or `{:error, :past_instance}` if the instance is in the past.
  """
  def return_trip_instance_purchase(%User{id: user_id} = _user, instance_id) do
    today = Date.utc_today()

    case Repo.get(TripInstance, instance_id) do
      nil ->
        {:error, :not_found}

      %TripInstance{} = instance ->
        if Date.compare(instance.date, today) == :lt do
          {:error, :past_instance}
        else
          query =
            from p in Purchase,
              where: p.user_id == ^user_id and p.trip_instance_id == ^instance_id,
              limit: 1

          case Repo.one(query) do
            nil ->
              {:error, :not_found}

            %Purchase{} = purchase ->
              Ecto.Multi.new()
              |> Ecto.Multi.delete(:delete_purchase, purchase)
              |> Ecto.Multi.update(
                :inc_instance,
                TripInstance.changeset(instance, %{
                  available_tickets: instance.available_tickets + 1
                })
              )
              |> Repo.transaction()
              |> case do
                {:ok, %{delete_purchase: deleted}} -> {:ok, deleted}
                {:error, _op, changeset, _} -> {:error, changeset}
              end
          end
        end
    end
  end

  # ---------- FR-10: Top trips (fastest, cheapest, greenest) ----------

  @doc """
  Computes top trips (fastest, cheapest, greenest) from the given list.

  Tie-breaking is deterministic:
    * Fastest  -> duration_minutes -> price -> id
    * Cheapest -> price -> duration_minutes -> id
    * Greenest -> co2_level -> price -> duration_minutes -> id
  """
  def compute_top_trips([]) do
    # When there are no trips, safely return nils so the view can handle it.
    %{fastest: nil, cheapest: nil, greenest: nil}
  end

  def compute_top_trips(trips) when is_list(trips) do
    %{
      fastest: pick_fastest(trips),
      cheapest: pick_cheapest(trips),
      greenest: pick_greenest(trips)
    }
  end

  # Picks the fastest trip using duration as main metric.
  # Tie-breaking uses price and then id to keep the result deterministic.
  defp pick_fastest(trips) do
    Enum.min_by(trips, fn trip ->
      {
        trip.duration_minutes || 0,
        normalize_price(trip.price),
        trip.id || 0
      }
    end)
  end

  # Picks the cheapest trip using price as main metric.
  # Tie-breaking uses duration and then id.
  defp pick_cheapest(trips) do
    Enum.min_by(trips, fn trip ->
      {
        normalize_price(trip.price),
        trip.duration_minutes || 0,
        trip.id || 0
      }
    end)
  end

  # Picks the greenest trip using CO₂ as main metric.
  # Tie-breaking uses price, then duration, then id.
  defp pick_greenest(trips) do
    Enum.min_by(trips, fn trip ->
      {
        trip.co2_level || 0,
        normalize_price(trip.price),
        trip.duration_minutes || 0,
        trip.id || 0
      }
    end)
  end

  # Normalizes different price representations to a float for comparison.
  defp normalize_price(%Decimal{} = price), do: Decimal.to_float(price)
  defp normalize_price(price) when is_integer(price), do: price * 1.0
  defp normalize_price(price) when is_float(price), do: price
  defp normalize_price(_), do: 0.0
end
