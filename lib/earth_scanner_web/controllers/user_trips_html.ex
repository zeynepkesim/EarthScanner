defmodule EarthScannerWeb.UserTripsHTML do
  use EarthScannerWeb, :html

  embed_templates "user_trips_html/*"

  def format_instance_date(%Date{} = date) do
    Calendar.strftime(date, "%b %d, %Y")
  end

  def format_instance_date(_), do: "--"

  def format_departure(%DateTime{} = dt) do
    Calendar.strftime(dt, "%b %d, %Y at %H:%M %Z")
  end

  def format_departure(_), do: "--"
end
