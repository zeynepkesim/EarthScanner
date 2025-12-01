Feature: NFR-03 Usability & Accessibility
  As a user with accessibility needs
  I want the interface to be accessible via keyboard and screen readers
  So that I can navigate and use the trip search functionality

  Background:
    Given there are trips available from "Tallinn" to "Tartu"

  # NFR-03: Positive Scenario - Keyboard Navigation
  Scenario: User can navigate sort dropdown with keyboard
    When I visit the search results page
    And I press Tab to focus on the sort dropdown
    Then the sort dropdown should be focused
    And I should be able to change sorting with arrow keys

  # NFR-03: Positive Scenario - ARIA Labels
  Scenario: Screen reader announces sort dropdown properly
    When I visit the search results page
    Then the sort dropdown should have an accessible label
    And the sort dropdown should have a description for screen readers

  # NFR-03: Positive Scenario - Filter Removal
  Scenario: User can remove filters with keyboard
    Given I have applied a price filter
    When I visit the search results page
    And I press Tab to focus on the filter removal button
    And I press Enter
    Then the filter should be removed

  # NFR-03: Negative Scenario - Missing Focus
  Scenario: Elements without proper focus indicators fail accessibility
    When I visit the search results page
    And I tab through interactive elements
    Then all interactive elements should have visible focus indicators

  # NFR-03: Edge Case - High Contrast Mode
  Scenario: Interface maintains readability in high contrast
    When I visit the search results page with high contrast mode
    Then all text should have sufficient contrast ratio
    And all interactive elements should be clearly visible
