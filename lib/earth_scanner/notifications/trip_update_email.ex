defmodule EarthScanner.Notifications.TripUpdateEmail do
  import Swoosh.Email

  def build(user, trip, diff) do
    subject = "[EarthScanner] Trip update: #{trip.source_city} → #{trip.destination_city}"

    body_text =
      "Trip #{trip.id} has been updated.\n\nChanges:\n" <>
        (diff |> Enum.map(fn {k, {old, new}} -> "- #{k}: #{inspect(old)} -> #{inspect(new)}\n" end) |> Enum.join(""))

    new()
    |> to({user.name || user.username || "", user.email})
    |> from({"EarthScanner", "no-reply@earthscanner.test"})
    |> subject(subject)
    |> text_body(body_text)
  end
end
