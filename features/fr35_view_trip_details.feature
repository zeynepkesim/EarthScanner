Feature: View Trip Details (FR-35)
  As an Admin
  I want to view all details of a trip I created
  So that I can evaluate all trip information clearly.

  Background:
    Given an admin user exists and is logged in

  # ========== POSITIVE CASES ==========

  @future_trip_details
  Scenario: Admin views details of a future trip they created
    Given a future trip exists owned by the admin
    When the admin visits the trip details page
    Then the admin should see all trip attributes displayed
    And the admin should see the Edit button
    And the admin should see the Delete button

  @past_trip_details
  Scenario: Admin views details of a past trip they created
    Given a past trip exists owned by the admin
    When the admin visits the trip details page
    Then the admin should see all trip attributes displayed
    And the admin should NOT see the Edit button
    And the admin should NOT see the Delete button
    And the admin should see read-only booking statistics

  # ========== NEGATIVE CASES ==========

  @unauthorized_admin
  Scenario: Admin cannot view details of another admin's trip
    Given a future trip exists owned by another admin
    When the admin tries to visit the trip details page
    Then the admin should see "You are not authorized to view this trip."

  @unauthorized_user
  Scenario: Regular user cannot view admin trip details
    Given a future trip exists owned by another admin
    And a normal user is logged in
    When the user visits the trip details page
    Then the user should see "You are not authorized" or be redirected

  @nonexistent_trip
  Scenario: Cannot view details of a trip that doesn't exist
    When the admin tries to view trip with ID 999999
    Then the admin should see "Trip not found."

  @unauthenticated_access
  Scenario: Unauthenticated user cannot view trip details
    Given I am logged out
    When an anonymous user tries to view a trip details page
    Then they should be redirected to the login page