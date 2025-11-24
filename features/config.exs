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

  suite name:          "TripSearch",
        context:       TripSearchContext,
        feature_paths: [
          "features/fr07_search_by_route.feature",
          "features/fr08_filter_results.feature",
          "features/fr09_sort_results.feature",
          "features/fr10_highlight_top_trips.feature",
          "features/fr11_exclude_past_trips.feature",
          "features/fr15_highlight_sold_out_trips.feature"
        ]

  suite name:          "TripPurchase",
        context:       TripPurchaseContext,
        feature_paths: [
          "features/fr12_purchase_ticket.feature",
          "features/fr13_refund_ticket.feature",
          "features/fr14_highlight_purchased_trips.feature"
        ]

end
