Feature: FR-19 Account Access Links on Homepage
  As any user
  I want the home page to always show account access links
  So that I can easily access my account features

  Scenario: Positive - unauthenticated user sees login and register
    Given I am not logged in
    When I visit the home page
    Then I should see login and register options

  Scenario: Positive - authenticated user sees profile and logout
    Given I am logged in as a regular user
    When I visit the home page
    Then I should see profile and logout options

  Scenario: Negative - unauthenticated user does not see profile
    Given I am not logged in
    When I visit the home page
    Then I should not see profile in header

  Scenario: Negative - unauthenticated user does not see logout
    Given I am not logged in
    When I visit the home page
    Then I should not see logout in header

  Scenario: Negative - authenticated user sees different account options
    Given I am logged in as a regular user
    When I visit the home page
    Then account section shows correct options for authenticated users

  Scenario: Negative - home page is always accessible
    Given I am not logged in
    When I visit the home page
    Then the page loads successfully

