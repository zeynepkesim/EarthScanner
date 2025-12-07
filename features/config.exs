defmodule WhiteBreadConfig do
  use WhiteBread.SuiteConfiguration

  suite(
    name: "All",
    context: WhiteBreadContext,
    feature_paths: ["features/"]
  )

  # FR-02: Admin Creation
  suite(
    name: "AdminCreation",
    context: AdminCreationContext,
    feature_paths: ["features/admin_creation.feature"]
  )

  # FR-05: Change Password
  suite(
    name: "ChangePassword",
    context: ChangePasswordContext,
    feature_paths: ["features/change_password.feature"]
  )

  # FR-33: Delete Trip
  suite(
    name: "DeleteTrip",
    context: DeleteTripContext,
    feature_paths: ["features/fr33_delete_trip.feature"]
  )

  # FR-35: View Trip Details
  suite(
    name: "ViewTripDetails",
    context: ViewTripDetailsContext,
    feature_paths: ["features/fr35_view_trip_details.feature"]
  )

  # Calvin - BDD Passed
  # The system allows to self-register as a regular user (storing, at least: username, password, name,
  # last name, email, birthdate, nationality, residence address, and phone number).
  suite(
    name: "UserRegistration",
    context: UserRegistrationContext,
    feature_paths: ["features/user_registration.feature"]
  )

  # Calvin - BDD Passed
  # The system allows users to log in and log out.
  suite(
    name: "Login",
    context: LoginContext,
    feature_paths: ["features/login.feature"]
  )

  # Calvin - BDD Passed
  # An admin can view the list of past trips they created (already happened).
  # An admin can view the list of future trips they created (to take place in the future).
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

  # FR-07, FR-08, FR-09, FR-11, FR-15: Trip Search Features
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

  # FR-20: Regular User Trip Search
  suite(
    name: "FR20",
    context: FR20RegularUserTripSearchContext,
    feature_paths: ["features/fr20_regular_user_trip_search.feature"]
  )

  # FR-21: Admin Access to Created Trips
  suite(
    name: "FR21AdminAccessTrips",
    context: FR21AdminAccessTripsContext,
    feature_paths: ["features/fr21_admin_access_trips.feature"]
  )

  suite(
    name: "FR23AdminTripDetail",
    context: FR23Context,
    feature_paths: ["features/fr23_admin_trip_detail.feature"]
  )

  # FR-24: User Data Privacy
  suite(
    name: "FR24UserDataPrivacy",
    context: FR24UserDataPrivacyContext,
    feature_paths: ["features/fr24_user_data_privacy.feature"]
  )

  # Calvin - BDD Passed
  # An authenticated regular user can "purchase" a ticket for a trip.
  # An authenticated regular user can also "return" the ticket of a purchased trip.
  # the trips for which a ticket has been "purchased" are visually highlighted in the result search.
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

  # Calvin - BDD Passed
  # As a user, I want to receive notifications for my upcoming trips before 24 hours
  # I want to receive alerts if there are changes to my booked trips.
  suite(
    name: "Notifications",
    context: FR27NotificationsContext,
    feature_paths: [
      "features/fr27_notifications.feature",
      "features/fr28_trip_change_alerts.feature"
    ]
  )

  # Calvin - BDD Passed
  # Logged-in regular users must be able to access the lists of their past purchased and future purchased trips, always with one click.
  suite(
    name: "FR22UserTrips",
    context: FR22UserTripsContext,
    feature_paths: ["features/fr22_user_trips.feature"]
  )

  # NFR-07: Secure Authentication
  suite(
    name: "NFR07SecureAuth",
    context: NFR07SecureAuthenticationContext,
    feature_paths: ["features/nfr07_secure_authentication.feature"]
  )
end
