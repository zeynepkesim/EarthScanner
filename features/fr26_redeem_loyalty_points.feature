Feature: FR-26 Redeem Loyalty Points
  As a logged-in user
  I want to redeem my loyalty points when purchasing a ticket
  So that I can get discounts

  Background:
    Given I am a registered user named "Loyal User"
    And there is a trip "Paris Getaway" costing 100.0 EUR
    And I am logged in

  # --- Positive Scenarios ---

  Scenario: User redeems points for partial discount
    Given I have 500 loyalty points
    When I search for "Paris Getaway"
    And I view the trip details
    And I choose to redeem my points
    And I purchase a ticket
    Then I should see "Trip purchased!"
    And my loyalty points balance should be 50

  Scenario: User redeems points for full discount
    Given I have 2000 loyalty points
    When I search for "Paris Getaway"
    And I view the trip details
    And I choose to redeem my points
    And I purchase a ticket
    Then I should see "Trip purchased!"
    And my loyalty points balance should be 1000

  # --- Negative Scenarios ---

  Scenario: User with 0 points cannot get discount
    Given I have 0 loyalty points
    When I search for "Paris Getaway"
    And I view the trip details
    # Even if UI allows clicking (or we simulate it), logic should prevent discount
    And I choose to redeem my points
    And I purchase a ticket
    Then I should see "Trip purchased!"
    And my loyalty points balance should be 100

  # --- Edge Cases ---

  Scenario: User has exactly enough points for max discount
    Given I have 1000 loyalty points
    When I search for "Paris Getaway"
    And I view the trip details
    And I choose to redeem my points
    And I purchase a ticket
    Then I should see "Trip purchased!"
    And my loyalty points balance should be 0
