Feature: FR-18 Recent Searches
  As a user
  I want to see my recent searches

  Scenario: Positive - recent searches shown
    Given I have performed 3 searches
    When I visit the search page
    Then I should see the recent searches section

  Scenario: Negative - no recent searches
    Given I have performed 0 searches
    When I visit the search page
    Then I should see the recent searches section
