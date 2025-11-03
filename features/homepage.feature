Feature: Homepage Welcome

  Scenario: Visiting the root page shows the Phoenix welcome text
    Given I am a visitor
    When I visit the homepage
    Then I should see a Phoenix welcome message
