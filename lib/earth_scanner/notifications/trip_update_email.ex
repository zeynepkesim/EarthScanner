defmodule EarthScanner.Notifications.TripUpdateEmail do
  import Swoosh.Email

  alias EarthScanner.Formatters.TripChangeFormatter

  def build(user, trip, diff) do
    subject = "[EarthScanner] Trip update: #{trip.source_city} → #{trip.destination_city}"

    # prepare a data map for the formatter
    base = %{
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "trip_name" => Map.get(trip, :name) || "#{trip.source_city} → #{trip.destination_city}",
      "from" => trip.source_city,
      "to" => trip.destination_city
    }

    data =
      Enum.reduce(diff, base, fn {k, {old, new}}, acc ->
        case to_string(k) do
          "co2_level" ->
            Map.merge(acc, %{"co2_old" => old, "co2_new" => new})

          "recommended_price" ->
            Map.merge(acc, %{
              "recommended_price_old" => new_decimal_to_float(old),
              "recommended_price_new" => new_decimal_to_float(new)
            })

          other ->
            Map.put(acc, to_string(other), %{"old" => old, "new" => new})
        end
      end)

    body_text = TripChangeFormatter.format_multiline(data)

    new()
    |> to({user.name || user.username || "", user.email})
    |> from({"EarthScanner", "no-reply@earthscanner.test"})
    |> subject(subject)
    |> text_body(body_text)
  end

  defp new_decimal_to_float(%Decimal{} = d), do: Decimal.to_float(d)
  defp new_decimal_to_float(v) when is_binary(v), do: String.to_float(v)
  defp new_decimal_to_float(v) when is_number(v), do: v
  defp new_decimal_to_float(_), do: 0.0
end
