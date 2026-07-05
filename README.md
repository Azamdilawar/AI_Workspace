# AI Workspace

AI Workspace is a production-quality Rails application designed for future integration of AI utilities. In Phase 0, we establish the project architecture, layout structure, test harnesses, and security scan pipelines.

---

## Tech Stack
- **Ruby on Rails 8.0.5**
- **Ruby 3.2.2** (managed via `rbenv`)
- **PostgreSQL** Database
- **Tailwind CSS** (via `tailwindcss-rails`)
- **Hotwire** (Turbo + Stimulus)
- **OpenAI Ruby SDK** (`ruby-openai`)
- **Dotenv** (`dotenv-rails`)
- **Testing**: RSpec, FactoryBot, Faker
- **Linting & Security**: RuboCop, Brakeman, Bullet

---

## Folder Architecture & Design
Future AI services (e.g. chats, summaries, email drafts) will be stored inside the dedicated namespaces:
- `app/services/ai/`

Placeholder controller pages:
- **Dashboard**: `DashboardController#show` (mapped as root)
- **AI Chat**: `ChatController#show`
- **Email Generator**: `EmailGeneratorController#show`
- **Summarizer**: `SummarizerController#show`
- **Settings**: `SettingsController#show`

---

## Environment Configuration
Copy page variables config from `.env.example`:
```bash
cp .env.example .env
```

Contents inside `.env`:
- `OPENAI_API_KEY`: API key for OpenAI authentications.
- `DEFAULT_MODEL`: Model family preset (e.g. `gpt-4o`).
- `DEFAULT_TEMPERATURE`: LLM generation temperature (e.g. `0.7`).

---

## Setup & Installations

1. **Verify Ruby version (needs Ruby >= 3.2.0)**:
   ```bash
   ruby -v
   ```
2. **Install Dependencies**:
   ```bash
   bundle install
   ```
3. **Database Configuration**: Ensure PostgreSQL is running locally, then initialize the schemas:
   ```bash
   bin/rails db:create db:migrate
   ```

---

## Running the Application
To run the server along with Tailwind asset recompilation, use:
```bash
bin/dev
# or
bin/rails server
```
Go to [http://localhost:3000](http://localhost:3000) in your browser.

---

## Verification & Code Quality

Run tests, style checks, and security analyses:
- **RSpec Suite**: `bundle exec rspec`
- **Code Linter**: `bundle exec rubocop`
- **Security Check**: `bundle exec brakeman`
