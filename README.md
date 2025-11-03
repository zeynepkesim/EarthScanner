# 🌍 EarthScanner — Explore the Planet

> *“Travel not to discover, but to be discovered.”*  
> A satirical yet smart travel planner platform designed to help users compare, book, and brag about their trips — all while pretending to care about their carbon footprint.

---

## 🧭 Overview

**EarthScanner** is a web-based trip-planning system developed as part of the **Agile Software Development** course.  
The goal is to design and implement a **Minimum Viable Product (MVP)** that enables admins to post travel offers and regular users to search, filter, and purchase trips around the world.

The project follows **Scrum methodology** with six sprints (from environment setup to final presentation).

---

## ✨ Core Features (MVP)

### 👥 User Management
- Registration for two roles: **Admin** and **Regular User**
- Secure authentication (password hashing)
- Login, logout, password change, and account deletion

### 🧳 Trip Management (Admin)
- Create, update, or delete trip offers
- Each trip includes: transportation mode, cities, times, duration, price, CO₂ emissions, and ticket availability
- Automatic price recommendation based on similar trips in the database
- List of past and future trips

### 🌍 Trip Search & Booking (Regular User)
- Search trips by **source** and **destination**
- Filter results by price, duration, CO₂ pollution, departure/arrival time
- Sort results by price, CO₂ degree, or duration
- Highlight: fastest, cheapest, and least-polluting trips
- Book or return tickets (before departure)
- Visual indicators for sold-out or purchased trips
- Display similar recommended trips (top 5 by similarity)
- Save the last 5 searches for quick access

### ⚙️ General Rules
- Unauthorized users can only view the home page and login page
- Admins can only view/manage their own trips
- Regular users can see only their purchased trips
- Secure authentication and access control enforced

---

## 🧩 Additional Features (to be implemented later)
1. **Carbon-Footprint Tracker:** Track and visualize CO₂ emissions of user-purchased trips.  
2. **Gamification System:** Award badges for eco-friendly travel and completed trips.

---

## 🧱 Tech Stack

| Component | Technology |
|------------|-------------|
| Language | Elixir 1.17 + Phoenix 1.7 |
| Database | PostgreSQL 16 |
| Environment | macOS + Colima (Docker Engine alternative) |
| Version Control | GitLab |
| CI/CD | GitLab CI |
| Testing | WhiteBread (acceptance) + Hound (integration) |
| Frontend | Phoenix HEEx templates + TailwindCSS |
| Containerization | Docker / Colima |

---

## ⚙️ Local Setup

### 1️⃣ Prerequisites
- **Elixir ≥ 1.14**, **Phoenix ≥ 1.7**
- **PostgreSQL 16** (local or via Colima)
- **Colima + QEMU** (Docker engine replacement on macOS 12)
- **GitLab account**

### 2️⃣ Run Locally
```bash
# Clone repository
git clone https://gitlab.cs.ut.ee/team-3-asd/earthscanner-asd.git
cd earthscanner-asd

# Install dependencies
mix deps.get

# Setup database
mix ecto.create
mix ecto.migrate

# Start the Phoenix server
mix phx.server
```

## 🤖 AI Usage

This project benefited from AI-assisted development for:

- Identifying and fixing bugs efficiently  
- Improving code readability, comments, and documentation  

All AI-generated code and documentation were **reviewed and validated by the author**  
to ensure **correctness, functionality, and code quality**.