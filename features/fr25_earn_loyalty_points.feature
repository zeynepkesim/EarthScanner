Feature: FR-25 Earn Loyalty Points
  As a logged-in user
  I want to earn loyalty points for every ticket I purchase
  So that I can accumulate rewards for future trips

  Background:
    Given I am a registered user named "Loyal User"
    And there is a trip "Paris Getaway" costing 100.0 EUR
    And I am logged in

  # --- Positive Scenarios ---

  Scenario: User earns points on standard purchase
    When I search for "Paris Getaway"
    And I view the trip details
    And I purchase a ticket
    Then I should see "Trip purchased!"
    And my loyalty points balance should be 100

  Scenario: User earns points on expensive trip
    Given there is a trip "Luxury Cruise" costing 500.0 EUR
    When I search for "Luxury Cruise"
    And I view the trip details
    And I purchase a ticket
    Then I should see "Trip purchased!"
    And my loyalty points balance should increase by 500

  # --- Negative Scenarios ---

  Scenario: No points earned on failed purchase (Sold Out)
    Given there is a trip "Sold Out Trip" costing 50.0 EUR
    And that trip is sold out
    When I search for "Sold Out Trip"
    And I view the trip details
    And I attempt to purchase a ticket
    Then I should see "This trip is sold out"
    And my loyalty points balance should be 0

  # --- Edge Cases ---

  Scenario: User earns 0 points on free trip
    Given there is a trip "Free Ride" costing 0.0 EUR
    When I search for "Free Ride"
    And I view the trip details
    And I purchase a ticket
    Then I should see "Trip purchased!"
    And my loyalty points balance should be 0
