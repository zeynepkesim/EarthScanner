Feature: FR-14 Highlight Purchased Trips
  Context: TripPurchaseContext

  Scenario: Purchased trip shows a badge on the detail page
    Given I am logged in as a normal user
    And a future trip with available tickets exists
    And I have already purchased that trip date
    When I visit that trip's detail page
    Then I should see the purchased badge on the trip page

  Scenario: Non-purchased trip hides the purchased badge
    Given I am logged in as a normal user
    And a future trip with available tickets exists
    And I have not purchased that trip date
    When I visit that trip's detail page
    Then I should not see the purchased badge on the trip page
