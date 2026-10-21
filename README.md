# 🌍 EarthScanner — Explore the Planet

*“Travel not to discover, but to be discovered.”*

A satirical yet smart travel planner platform designed to help users compare, book, and brag about their trips — all while pretending to care about their carbon footprint.

## 🧭 Overview

EarthScanner is a web-based trip-planning and booking system developed as part of the Agile Software Development course at the University of Tartu. Admins post travel offers, and regular users search, filter, book and refund trips around the world.

The project followed Scrum over six sprints, from environment setup to the final presentation.

## ✨ Features

### 👥 User Management
- Registration for two roles: Admin and Regular User
- Secure authentication with password hashing (PBKDF2)
- Login, logout, password change and account deletion

### 🧳 Trip Management (Admin)
- Create, update or delete trip offers
- Each trip includes transportation mode, cities, times, duration, price, CO₂ emissions and ticket availability
- Recurring trip dates
- Automatic price recommendation based on transport mode and CO₂ level
- Lists of past and future trips
- Trips with sold tickets cannot be deleted

### 🌍 Trip Search & Booking (Regular User)
- Search trips by source and destination
- Filter results by price, duration, CO₂ emissions and departure/arrival time
- Sort results by price, CO₂ emissions or duration
- Highlights for the fastest, cheapest and least-polluting trips
- Book tickets, or refund them before departure
- Visual indicators for sold-out and purchased trips
- Up to five similar trips on the same route within a close price range
- The last five searches saved for quick access

### 🎁 Loyalty Points & Notifications
- Earn loyalty points for every ticket purchase and redeem them on later purchases, with an audit log of point changes
- In-app reminders for upcoming trips
- Alerts to ticket holders when an admin changes a trip, including email notifications with retries

### ⚙️ Access Rules
- Unauthorized users can only view the home page and the login page
- Admins can only view and manage their own trips
- Regular users can only see their own purchases and personal data

## 🧱 Tech Stack

| Component | Technology |
|---|---|
| Language | Elixir 1.15+ |
| Framework | Phoenix 1.8 |
| Database | PostgreSQL |
| Frontend | Phoenix HEEx templates + Tailwind CSS |
| Email | Swoosh |
| Testing | ExUnit, WhiteBread (BDD acceptance tests), Hound (browser automation) |
| CI | GitLab CI (format check and tests against PostgreSQL) |
| Containerization | Docker, Docker Compose |

## ⚙️ Local Setup

### Prerequisites
- Elixir 1.15 or newer
- PostgreSQL (local, or through Docker / Colima)

### Run Locally

```bash
# Clone the repository
git clone https://github.com/zeynepkesim/EarthScanner.git
cd EarthScanner

# Install dependencies
mix deps.get

# Set up the database
mix ecto.create
mix ecto.migrate

# Start the Phoenix server
mix phx.server
```

The app runs at [http://localhost:4000](http://localhost:4000).

### Run Tests

```bash
mix test
```

For building and running the app with Docker, see [DEPLOYMENT.md](DEPLOYMENT.md).

## 🤖 AI Usage

This project benefited from AI-assisted development for:
- Identifying and fixing bugs efficiently
- Improving code readability, comments and documentation

All AI-generated code and documentation were reviewed and validated by the author to ensure correctness, functionality and code quality.
