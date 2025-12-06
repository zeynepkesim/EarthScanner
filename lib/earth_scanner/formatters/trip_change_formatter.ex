defmodule EarthScanner.Formatters.TripChangeFormatter do
  @moduledoc """
  Helpers to render trip change logs in a human-friendly way.

  The functions accept a map (string or atom keys) containing fields like:
    - "timestamp" / :timestamp (ISO8601)
    - "trip_name" / :trip_name
    - "from" / :from_location / :from_city
    - "to" / :to_location / :to_city
    - "co2_old" / :co2_old / "co2_level" / :co2_level
    - "co2_new" / :co2_new
    - "recommended_price_old" / :recommended_price_old / "recommended_price" / :recommended_price
    - "recommended_price_new" / :recommended_price_new

  It produces a multiline human readable string and a compact one-line notification.
  """

  @doc "Returns a multiline, readable description of the trip change."
  def format_multiline(data) when is_map(data) do
    time = format_time(data)
    trip_name = get_any(data, ["trip_name", :trip_name, "name", :name]) || "Unnamed trip"

    from =
      get_any(data, ["from", :from, "from_location", :from_location, "from_city", :from_city]) ||
        "?"

    to = get_any(data, ["to", :to, "to_location", :to_location, "to_city", :to_city]) || "?"

    {co2_old, co2_new} =
      parse_pair(data, ["co2_old", :co2_old, "co2_level", :co2_level], ["co2_new", :co2_new])

    {price_old, price_new} =
      parse_pair_float(
        data,
        [
          "recommended_price_old",
          :recommended_price_old,
          "recommended_price",
          :recommended_price
        ],
        ["recommended_price_new", :recommended_price_new]
      )

    co2_diff = co2_new - co2_old
    co2_pct = pct(co2_old, co2_diff)

    price_diff = price_new - price_old
    price_pct = pct_float(price_old, price_diff)

    """
    Trip updated — #{trip_name}
    Route: #{from} → #{to}
    When: #{time}
    Changes:
    - CO2 level: #{co2_old} → #{co2_new} (#{sign_word(co2_diff)} by #{abs(co2_diff)}; #{co2_pct})
    - Recommended price: #{format_price(price_old)} → #{format_price(price_new)} (#{sign_symbol(price_diff)}#{format_price(abs(price_diff))}; #{price_pct})
    """
  end

  @doc "Returns a compact one-line notification."
  def format_compact(data) when is_map(data) do
    time = format_time(data)
    trip_name = get_any(data, ["trip_name", :trip_name, "name", :name]) || "Unnamed trip"

    from =
      get_any(data, ["from", :from, "from_location", :from_location, "from_city", :from_city]) ||
        "?"

    to = get_any(data, ["to", :to, "to_location", :to_location, "to_city", :to_city]) || "?"

    {co2_old, co2_new} =
      parse_pair(data, ["co2_old", :co2_old, "co2_level", :co2_level], ["co2_new", :co2_new])

    {price_old, price_new} =
      parse_pair_float(
        data,
        [
          "recommended_price_old",
          :recommended_price_old,
          "recommended_price",
          :recommended_price
        ],
        ["recommended_price_new", :recommended_price_new]
      )

    co2_diff = co2_new - co2_old
    co2_pct = pct(co2_old, co2_diff)

    price_diff = price_new - price_old
    price_pct = pct_float(price_old, price_diff)

    compact_price_old = format_price(price_old)
    compact_price_new = format_price(price_new)

    "#{trip_name} (#{from} → #{to}) updated (#{time}): CO2 #{sign_symbol(co2_diff)}#{abs(co2_diff)} (#{co2_pct}); Price #{compact_price_old} → #{compact_price_new} (#{price_pct})."
  end

  defp format_time(data) do
    raw =
      get_any(data, ["timestamp", :timestamp, "time", :time]) ||
        DateTime.utc_now() |> DateTime.to_iso8601()

    case DateTime.from_iso8601(to_string(raw)) do
      {:ok, dt, _} -> Calendar.strftime(dt, "%b %d, %Y %H:%M:%S %Z")
      _ -> to_string(raw)
    end
  end

  defp get_any(map, keys) when is_map(map) and is_list(keys) do
    Enum.find_value(keys, fn k -> Map.get(map, k) end)
  end

  defp parse_pair(map, old_keys, new_keys) do
    old = get_any(map, old_keys) |> to_integer()
    new = get_any(map, new_keys) |> to_integer()
    {old, new}
  end

  defp parse_pair_float(map, old_keys, new_keys) do
    old = get_any(map, old_keys) |> to_float()
    new = get_any(map, new_keys) |> to_float()
    {old, new}
  end

  defp to_integer(nil), do: 0
  defp to_integer(i) when is_integer(i), do: i

  defp to_integer(s) when is_binary(s) do
    case Integer.parse(s) do
      {i, _} ->
        i

      :error ->
        case Float.parse(s) do
          {f, _} -> round(f)
          :error -> 0
        end
    end
  end

  defp to_float(nil), do: 0.0
  defp to_float(f) when is_float(f), do: f
  defp to_float(i) when is_integer(i), do: i / 1

  defp to_float(s) when is_binary(s) do
    case Float.parse(s) do
      {f, _} ->
        f

      :error ->
        case Integer.parse(s) do
          {i, _} -> i / 1
          :error -> 0.0
        end
    end
  end

  defp pct(0, _diff), do: "N/A"

  defp pct(base, diff) do
    pct = diff / base * 100
    "#{Float.round(pct, 1)}%"
  end

  defp pct_float(0.0, _), do: "N/A"

  defp pct_float(base, diff) do
    pct = diff / base * 100
    "#{Float.round(pct, 1)}%"
  end

  defp format_price(n) when is_number(n) do
    "$" <> :erlang.float_to_binary(Float.round(n, 2), decimals: 2)
  end

  defp sign_word(n) when n >= 0, do: "increase"
  defp sign_word(_), do: "decrease"

  defp sign_symbol(n) when n >= 0, do: "+"
  defp sign_symbol(_), do: "-"

  @doc "Format a single field change into a readable string suitable for UI rendering."
  def format_field_change(field, change) do
    field_s = to_string(field)

    case change do
      %{"old" => old, "new" => new} ->
        format_field_change_pair(field_s, old, new)

      {old, new} when is_tuple(change) or (is_list(change) and length(change) == 2) ->
        # tuple like {old, new}
        {o, n} = change
        format_field_change_pair(field_s, o, n)

      _ ->
        "#{field_s}: #{inspect(change)}"
    end
  end

  defp format_field_change_pair("available_tickets", old, new) do
    old_i = to_integer(old)
    new_i = to_integer(new)
    diff = new_i - old_i
    sign = if diff >= 0, do: "+", else: "-"
    "Tickets: #{old_i} → #{new_i} (#{sign}#{abs(diff)})"
  end

  defp format_field_change_pair("co2_level", old, new) do
    old_i = to_integer(old)
    new_i = to_integer(new)
    diff = new_i - old_i
    pct = pct(old_i, diff)
    "CO2: #{old_i} → #{new_i} (#{sign_word(diff)} by #{abs(diff)}; #{pct})"
  end

  defp format_field_change_pair("recommended_price", old, new) do
    old_f = to_float(old)
    new_f = to_float(new)
    diff = new_f - old_f
    pct = pct_float(old_f, diff)

    "Price: #{format_price(old_f)} → #{format_price(new_f)} (#{sign_symbol(diff)}#{format_price(abs(diff))}; #{pct})"
  end

  defp format_field_change_pair(_field, old, new) do
    "#{_field}: #{inspect(old)} → #{inspect(new)}"
  end
end
