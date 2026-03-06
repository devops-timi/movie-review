# 🎬 CineVault — Movie Review App

A full-stack Tier-3 demo app with fictional movies and user reviews.

**Stack:** Next.js 14 · Node.js (Express) · MySQL 8 · Nginx

---

## Architecture

```
Browser
  └─► Nginx :80
        ├─► Next.js Frontend  :3000  (React SSR/SSG pages)
        └─► /api/* → Node.js Backend :3010 (REST API)
                         └─► MySQL :3306
```

---

## Project Structure

```
movie-review-app/
├── database/
│   ├── schema.sql          # Table definitions
│   └── seed.sql            # 10 fictional movies + 16 reviews
│
├── backend/
│   ├── src/
│   │   ├── server.js           # Entry point
│   │   ├── app.js              # Express app + middleware
│   │   ├── config/
│   │   │   └── database.js     # MySQL pool
│   │   ├── models/
│   │   │   ├── Movie.js        # Movie queries
│   │   │   ├── Review.js       # Review queries
│   │   │   └── Genre.js        # Genre queries
│   │   ├── controllers/
│   │   │   ├── movieController.js
│   │   │   ├── reviewController.js
│   │   │   └── genreController.js
│   │   ├── routes/
│   │   │   ├── movies.js
│   │   │   ├── reviews.js          # Nested under /movies/:slug
│   │   │   ├── reviewsStandalone.js # /reviews/:id CRUD
│   │   │   └── genres.js
│   │   └── middleware/
│   │       ├── validation.js   # express-validator rules
│   │       └── errorHandler.js
│   ├── .env.example
│   ├── Dockerfile
│   └── package.json
│
├── frontend/
│   ├── src/
│   │   ├── app/
│   │   │   ├── layout.tsx      # Root layout (Navbar + Footer)
│   │   │   ├── page.tsx        # Homepage
│   │   │   ├── not-found.tsx
│   │   │   ├── globals.css
│   │   │   ├── movies/
│   │   │   │   ├── page.tsx            # Movie listing + filters
│   │   │   │   └── [slug]/
│   │   │   │       ├── page.tsx        # Movie detail (SSR)
│   │   │   │       └── ReviewSection.tsx  # Client: form + reviews
│   │   │   └── admin/
│   │   │       └── page.tsx    # Movie management (add/delete)
│   │   ├── components/
│   │   │   ├── layout/
│   │   │   │   ├── Navbar.tsx
│   │   │   │   └── Footer.tsx
│   │   │   └── ui/
│   │   │       ├── MovieCard.tsx
│   │   │       ├── ReviewCard.tsx
│   │   │       └── ReviewForm.tsx
│   │   ├── lib/
│   │   │   ├── api.ts          # All API call functions
│   │   │   └── utils.ts        # Formatting helpers
│   │   └── types/
│   │       └── index.ts        # TypeScript interfaces
│   ├── next.config.js
│   ├── .env.local.example
│   ├── Dockerfile
│   └── package.json
│
├── nginx/
│   └── nginx.conf
├── docker-compose.yml
└── README.md
```

---

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/health` | Health check |
| GET | `/api/genres` | All genres with counts |
| GET | `/api/movies` | Paginated movies (filter: `genre`, `year`, `page`, `limit`) |
| GET | `/api/movies/:slug` | Single movie with avg rating |
| POST | `/api/movies` | Create movie |
| PUT | `/api/movies/:id` | Update movie |
| DELETE | `/api/movies/:id` | Delete movie |
| GET | `/api/movies/:slug/reviews` | Paginated reviews for movie |
| POST | `/api/movies/:slug/reviews` | Submit review |
| GET | `/api/reviews/recent` | Latest reviews across all movies |
| PUT | `/api/reviews/:id` | Update review |
| DELETE | `/api/reviews/:id` | Delete review |

---

## Quick Start (Docker)

```bash
git clone <repo>
cd movie-review-app
docker-compose up --build
```

Open: http://localhost

---

## Manual Setup

### 1. Database
```bash
mysql -u root -p < database/schema.sql
mysql -u root -p movie_reviews < database/seed.sql
```

### 2. Backend
```bash
cd backend
cp .env.example .env   # edit DB credentials
npm install
npm run dev            # http://localhost:3010
```

### 3. Frontend
```bash
cd frontend
cp .env.local.example .env.local
npm install
npm run dev            # http://localhost:3000
```

### 4. Nginx (optional, production)
```bash
sudo cp nginx/nginx.conf /etc/nginx/conf.d/movie-review.conf
sudo nginx -t && sudo systemctl reload nginx
```
