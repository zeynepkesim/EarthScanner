# FR-32 – Update Trip
Feature: Admin updates a future trip
  As an Admin
  I want to update the information of a planned future trip
  So that I can correct errors or alter travel details

  Background:
    Given an admin user "admin@example.com" with password "Password123!" exists

  @happy_path
  Scenario: Successful update of a future trip
    Given a future trip exists with id "42" created by "admin@example.com"
    When I log in as "admin@example.com" with password "Password123!"
    And I navigate to the trip edit page for trip "42"
    And I update the trip with:
      | picture_url        | https://example.com/trip-new.jpg |
      | transport_mode     | plane                            |
      | source_city        | Tallinn                          |
      | destination_city   | Paris                            |
      | departure_time     | 2025-12-01T10:00:00Z             |
      | arrival_time       | 2025-12-01T13:00:00Z             |
      | price              | 180.0                            |
      | co2_level          | 220                              |
      | available_tickets  | 45                               |
    And I submit the trip update
    Then I should see a confirmation that the trip was updated
    And the updated data should appear immediately in the trip details page

  @read_only_past_trip
  Scenario: Failing to edit a past trip
    Given a past trip exists with id "99"
    When I log in as "admin@example.com" with password "Password123!"
    And I navigate to the trip edit page for trip "99"
    Then I should see that the trip is read-only
    And I should not be able to submit updates
    And I should see an error saying "Past trips cannot be modified"

  @warning_on_critical_change
  Scenario: Warning when modifying critical data of a trip with sold tickets
    Given a future trip exists with id "55" and it has sold tickets
    When I log in as "admin@example.com" with password "Password123!"
    And I navigate to the trip edit page for trip "55"
    And I change the trip departure_time to "2025-12-10T09:00:00Z"
    And I submit the trip update
    Then I should see a warning about changing critical information
    And I should be asked to confirm the change
    When I confirm the update
    Then I should see a confirmation that the trip was updated
