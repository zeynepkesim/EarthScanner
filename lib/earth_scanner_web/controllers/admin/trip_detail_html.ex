defmodule EarthScannerWeb.Admin.TripDetailHTML do
  use EarthScannerWeb, :html

  embed_templates "trip_detail_html/*"

  # Format duration from minutes to human-readable format
  def format_duration(minutes) when is_integer(minutes) do
    hours = div(minutes, 60)
    remaining_minutes = rem(minutes, 60)

    cond do
      hours == 0 ->
        "#{remaining_minutes} minutes"

      remaining_minutes == 0 ->
        "#{hours} #{if hours == 1, do: "hour", else: "hours"}"

      true ->
        "#{hours} #{if hours == 1, do: "hour", else: "hours"} #{remaining_minutes} minutes"
    end
  end

  def format_duration(_), do: "N/A"

  # Generate appropriate confirmation message based on sold tickets status
  def delete_confirmation_message(has_sold_tickets) do
    if has_sold_tickets do
      "This trip has sold tickets. You will be redirected to confirm deletion. Continue?"
    else
      "Are you sure you want to delete this trip? This action cannot be undone."
    end
  end
end
