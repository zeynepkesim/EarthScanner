defmodule WhiteBreadConfig do
  use WhiteBread.SuiteConfiguration

  suite name:          "All",
        context:       WhiteBreadContext,
        feature_paths: ["features/"]

  suite name:          "AdminTrips",
        context:       AdminTripsContext,
        feature_paths: ["features/admin_views_past_trips.feature", "features/admin_views_future_trips.feature"]
end
