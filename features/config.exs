defmodule WhiteBreadConfig do
  use WhiteBread.SuiteConfiguration

  suite(
    name: "All",
    context: WhiteBreadContext,
    feature_paths: ["features/"]
  )

  suite(
    name: "AdminTrips",
    context: AdminTripsContext,
    feature_paths: [
      "features/admin_views_past_trips.feature",
      "features/admin_views_future_trips.feature"
    ]
  )

  suite(
    name: "AdminRecurringTrips",
    context: AdminRecurringTripsContext,
    feature_paths: ["features/admin_creates_recurring_trip.feature"]
  )

  suite(
    name: "AdminEditTrips",
    context: AdminEditTripsContext,
    feature_paths: ["features/admin_edit_trip.feature"]
  )

  suite(
    name: "TripSearch",
    context: TripSearchContext,
    feature_paths: [
      "features/fr07_search_by_route.feature",
      "features/fr08_filter_results.feature",
      "features/fr09_sort_results.feature",
      "features/fr11_exclude_past_trips.feature",
      "features/fr15_highlight_sold_out_trips.feature"
    ]
  )

  suite(
    name: "FRBDD",
    context: FRBDDContext,
    feature_paths: [
      "features/fr16_view_trip.feature",
      "features/fr17_similar_trips.feature",
      "features/fr18_recent_searches.feature",
      "features/fr34_recommended_price.feature"
    ]
  )

  suite(
    name: "FR19AccountAccess",
    context: FR19Context,
    feature_paths: ["features/fr19_account_access_links.feature"]
  )

  suite(
    name: "FR23AdminTripDetail",
    context: FR23Context,
    feature_paths: ["features/fr23_admin_trip_detail.feature"]
  )

  suite(
    name: "TripPurchase",
    context: TripPurchaseContext,
    feature_paths: [
      "features/fr12_purchase_ticket.feature",
      "features/fr13_refund_ticket.feature",
      "features/fr14_highlight_purchased_trips.feature"
    ]
  )

  suite(
    name: "TopTrips",
    context: TopTripsContext,
    feature_paths: ["features/fr10_highlight_top_trips.feature"]
  )

  suite(
    name: "LoyaltyPoints",
    context: LoyaltyPointsContext,
    feature_paths: [
      "features/fr25_earn_loyalty_points.feature",
      "features/fr26_redeem_loyalty_points.feature"
    ]
  )

  suite(
    name: "PointsSecurity",
    context: LoyaltyPointsContext,
    feature_paths: ["features/nfr09_points_security.feature"]
  )

  suite(
    name: "Accessibility",
    context: AccessibilityContext,
    feature_paths: ["features/nfr03_accessibility.feature"]
  )

  suite(
    name: "Notifications",
    context: FR27NotificationsContext,
    feature_paths: [
      "features/fr27_notifications.feature",
      "features/fr28_trip_change_alerts.feature"
    ]
  )

  suite(
    name: "FR22UserTrips",
    context: FR22UserTripsContext,
    feature_paths: ["features/fr22_user_trips.feature"]
  )

  suite(
    name: "DeleteAccount",
    context: DeleteAccountContext,
    feature_paths: ["features/fr06_delete_account.feature"]
  )
end
