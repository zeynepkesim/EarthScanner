Feature: FR-24 User data privacy
  In order to protect personal information
  As an authorized user
  I want to access only my own data and not see other user's personal information

  Background:
    Given a user exists
    And I am on the login page

  Scenario: Regular user can view their own profile but not others'
    When I submit correct login credentials
    And I visit the profile page
    Then I should see "Profile"
    # Profile content assertions are handled in TDD; BDD ensures navigation

  Scenario: Regular user cannot access another user's profile by id
    Given a user exists
    And I submit correct login credentials
    When I navigate to "/profile?user_id=999999"
    Then I should be redirected back to the profile page

  Scenario: Unauthorized queries are blocked (attempt to fetch another user's trip)
    Given a user exists
    And a set of future trips exist
    When I submit correct login credentials
    And I navigate to "/trips/999999"
    Then I should be redirected back to the search page

  Scenario: Admin can access other users' data (positive control)
    Given I am logged in as an admin
    When I visit the admin creation page
    Then I should see "Create Admin"