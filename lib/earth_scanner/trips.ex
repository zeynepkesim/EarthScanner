defmodule EarthScanner.Trips do
  @moduledoc """
  Trips context.

  Provides functions to manage trips and their recurring date instances.
  """

  import Ecto.Query, warn: false
  alias Ecto.{Changeset, Multi}
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

  # ---------- FR-07: User Search by Source + Destination ----------

  @doc """
  Searches trips by source and destination, returning only future trips
  (departure_time > now()).

  params = %{"source" => "...", "destination" => "..."} plus extra filters later.
  """
  def search_future_trips(source, destination, _params \\ %{}) do
    now = DateTime.utc_now()

    query =
      from t in Trip,
        where:
          ilike(t.source_city, ^source) and
            ilike(t.destination_city, ^destination) and
            t.departure_time > ^now,
        order_by: [asc: t.departure_time]

    Repo.all(query)
  end

  @doc """
  Searches trips by source & destination, returning future trips only,
  with simple limit/offset pagination.

  params must contain:
    - "page" (optional)
    - "per_page" (optional)
  """
  def search_future_trips_paginated(source, destination, params) do
    now = DateTime.utc_now()

    # Default page params
    page =
      params
      |> Map.get("page", "1")
      |> String.to_integer()

    per_page =
      params
      |> Map.get("per_page", "5")
      |> String.to_integer()

    offset = (page - 1) * per_page

    base_query =
      Trip
      |> where(
        [t],
        ilike(t.source_city, ^source) and
          ilike(t.destination_city, ^destination) and
          t.departure_time > ^now
      )
      |> maybe_filter_min(:price, params["min_price"])
      |> maybe_filter_max(:price, params["max_price"])
      |> maybe_filter_min(:duration_minutes, params["min_duration"])
      |> maybe_filter_max(:duration_minutes, params["max_duration"])
      |> maybe_filter_min(:co2_level, params["min_co2"])
      |> maybe_filter_max(:co2_level, params["max_co2"])
      |> maybe_filter_datetime_min(:departure_time, params["min_departure"])
      |> maybe_filter_datetime_max(:departure_time, params["max_departure"])
      |> maybe_filter_datetime_min(:arrival_time, params["min_arrival"])
      |> maybe_filter_datetime_max(:arrival_time, params["max_arrival"])

    # total count (for next/prev buttons)
    total =
      base_query
      |> select([t], count(t.id))
      |> Repo.one()

    # paginated result
    sort_param = params["sort"]

    trips =
      base_query
      |> apply_sort(sort_param)
      |> limit(^per_page)
      |> offset(^offset)
      |> Repo.all()

    %{
      trips: trips,
      total: total,
      page: page,
      per_page: per_page
    }
  end

  # --- Numeric min ---
  defp maybe_filter_min(query, _field, nil), do: query
  defp maybe_filter_min(query, _field, ""), do: query

  defp maybe_filter_min(query, field, value) do
    case Integer.parse(value) do
      {int, _} ->
        where(query, [t], field(t, ^field) >= ^int)

      :error ->
        query
    end
  end

  # --- Numeric max ---
  defp maybe_filter_max(query, _field, nil), do: query
  defp maybe_filter_max(query, _field, ""), do: query

  defp maybe_filter_max(query, field, value) do
    case Integer.parse(value) do
      {int, _} ->
        where(query, [t], field(t, ^field) <= ^int)

      :error ->
        query
    end
  end

  # --- Datetime min ---
  defp maybe_filter_datetime_min(query, _field, nil), do: query
  defp maybe_filter_datetime_min(query, _field, ""), do: query

  defp maybe_filter_datetime_min(query, field, value) do
    case DateTime.from_iso8601(value) do
      {:ok, dt, _} ->
        where(query, [t], field(t, ^field) >= ^dt)

      _ ->
        query
    end
  end

  # --- Datetime max ---
  defp maybe_filter_datetime_max(query, _field, nil), do: query
  defp maybe_filter_datetime_max(query, _field, ""), do: query

  defp maybe_filter_datetime_max(query, field, value) do
    case DateTime.from_iso8601(value) do
      {:ok, dt, _} ->
        where(query, [t], field(t, ^field) <= ^dt)

      _ ->
        query
    end
  end

  # --- Sorting helper ---
  defp apply_sort(query, nil), do: query
  defp apply_sort(query, ""), do: query

  defp apply_sort(query, "price_asc"), do: order_by(query, [t], asc: t.price)
  defp apply_sort(query, "price_desc"), do: order_by(query, [t], desc: t.price)

  defp apply_sort(query, "co2_asc"), do: order_by(query, [t], asc: t.co2_level)
  defp apply_sort(query, "co2_desc"), do: order_by(query, [t], desc: t.co2_level)

  defp apply_sort(query, "duration_asc"), do: order_by(query, [t], asc: t.duration_minutes)
  defp apply_sort(query, "duration_desc"), do: order_by(query, [t], desc: t.duration_minutes)

  # default fallback: order by soonest departure
  defp apply_sort(query, _), do: order_by(query, [t], asc: t.departure_time)

  # ---------- Purchases & Public Trip Helpers ----------

  @doc """
  Returns the given trip preloaded with its upcoming instances for public pages.
  """
  def get_public_trip!(trip_id) do
    today = Date.utc_today()

    Trip
    |> Repo.get!(trip_id)
    |> Repo.preload(
      instances: from(i in TripInstance, where: i.date >= ^today, order_by: [asc: i.date])
    )
  end

  @doc """
  Preloads future instances for the provided list of trips.
  """
  def preload_future_instances(trips) do
    today = Date.utc_today()

    Repo.preload(trips,
      instances: from(i in TripInstance, where: i.date >= ^today, order_by: [asc: i.date])
    )
  end

  @doc """
  Returns a summary of the trips/instances purchased by the given user.
  """
  def purchase_summary_for_user(nil) do
    %{trip_ids: MapSet.new(), instance_ids: MapSet.new()}
  end

  def purchase_summary_for_user(%User{id: user_id}) do
    purchases =
      from(p in Purchase,
        join: i in TripInstance,
        on: i.id == p.trip_instance_id,
        where: p.user_id == ^user_id,
        select: %{trip_id: i.trip_id, instance_id: p.trip_instance_id}
      )
      |> Repo.all()

    %{
      trip_ids: purchases |> Enum.map(& &1.trip_id) |> MapSet.new(),
      instance_ids: purchases |> Enum.map(& &1.instance_id) |> MapSet.new()
    }
  end

  @doc """
  Purchases a ticket for the given trip instance on behalf of the user.
  Decrements the available ticket count if the instance is still available.
  """
  def purchase_trip_instance(%User{id: user_id}, trip_instance_id) do
    with {:ok, instance} <- fetch_instance(trip_instance_id),
         :ok <- validate_instance_for_purchase(instance) do
      Multi.new()
      |> Multi.insert(
        :purchase,
        Purchase.changeset(%Purchase{}, %{user_id: user_id, trip_instance_id: instance.id})
      )
      |> Multi.update(
        :instance,
        Changeset.change(instance, %{available_tickets: instance.available_tickets - 1})
      )
      |> Repo.transaction()
      |> case do
        {:ok, %{purchase: purchase}} ->
          {:ok, purchase}

        {:error, :purchase, %Ecto.Changeset{} = changeset, _} ->
          handle_purchase_error(changeset)

        {:error, _step, reason, _} ->
          {:error, reason}
      end
    end
  end

  def purchase_trip_instance(_, _), do: {:error, :invalid_user}

  @doc """
  Returns (refunds) a previously purchased trip instance ticket for the given user.
  Increases the available ticket count when the trip instance is still in the future.
  """
  def return_trip_instance_purchase(%User{id: user_id}, trip_instance_id) do
    with {:ok, instance} <- fetch_instance(trip_instance_id),
         {:ok, purchase} <- fetch_purchase(user_id, instance.id),
         :ok <- ensure_future_instance(instance) do
      Multi.new()
      |> Multi.delete(:purchase, purchase)
      |> Multi.update(
        :instance,
        Changeset.change(instance, %{available_tickets: instance.available_tickets + 1})
      )
      |> Repo.transaction()
      |> case do
        {:ok, _} -> {:ok, :refunded}
        {:error, _step, reason, _} -> {:error, reason}
      end
    end
  end

  def return_trip_instance_purchase(_, _), do: {:error, :invalid_user}

  defp fetch_instance(instance_id) do
    case Repo.get(TripInstance, instance_id) do
      nil -> {:error, :not_found}
      %TripInstance{} = instance -> {:ok, instance}
    end
  end

  defp fetch_purchase(user_id, instance_id) do
    case Repo.get_by(Purchase, user_id: user_id, trip_instance_id: instance_id) do
      nil -> {:error, :not_found}
      %Purchase{} = purchase -> {:ok, purchase}
    end
  end

  defp validate_instance_for_purchase(%TripInstance{available_tickets: tickets} = instance) do
    today = Date.utc_today()

    cond do
      Date.compare(instance.date, today) == :lt ->
        {:error, :past_instance}

      tickets <= 0 ->
        {:error, :sold_out}

      true ->
        :ok
    end
  end

  defp ensure_future_instance(%TripInstance{} = instance) do
    today = Date.utc_today()

    if Date.compare(instance.date, today) in [:gt, :eq] do
      :ok
    else
      {:error, :past_instance}
    end
  end

  defp handle_purchase_error(%Ecto.Changeset{errors: errors}) do
    cond do
      Keyword.has_key?(errors, :user_id) -> {:error, :already_purchased}
      true -> {:error, :unknown}
    end

  end
end
