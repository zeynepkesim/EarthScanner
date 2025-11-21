Feature: FR-13 Refund Trip Ticket
  As a traveler
  I want to refund a previously purchased ticket
  So that I can free my seat when I no longer need it.

  Context: TripPurchaseContext

  Scenario: Logged in user refunds a purchased trip instance
    Given I am logged in as a normal user
    And a future trip with available tickets exists
    And I have already purchased that trip date
    When I visit that trip's detail page
    And I refund that trip purchase
    Then I should see a refund confirmation message

  Scenario: Logged in user cannot refund a past trip date
    Given I am logged in as a normal user
    And a future trip with available tickets exists
    And I have already purchased that trip date
    And that trip date has already passed
    When I visit that trip's detail page
    Then I should be redirected to the trips page for past trips
