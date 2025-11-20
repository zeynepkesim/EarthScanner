defmodule WhiteBreadConfig do
  use WhiteBread.SuiteConfiguration

  suite name:          "All",
        context:       WhiteBreadContext,
        feature_paths: ["features/"]

  suite name:          "AdminTrips",
        context:       AdminTripsContext,
        feature_paths: ["features/admin_views_past_trips.feature", "features/admin_views_future_trips.feature"]

  suite name:          "AdminRecurringTrips",
        context:       AdminRecurringTripsContext,
        feature_paths: ["features/admin_creates_recurring_trip.feature"]

  suite name:          "AdminEditTrips",
        context:       AdminEditTripsContext,
        feature_paths: ["features/admin_edit_trip.feature"]
end
