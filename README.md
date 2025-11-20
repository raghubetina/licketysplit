# Lickety Split

The objective of the app is to make it easy to split the check at restaurants when dining with groups:

- One person uploads a photo of a receipt along with a comma separated list of names of people in the party. We create a "Check".
- We use the OpenAI API + Structured Outputs to itemize the receipt.
- The person shares the URL of the check with the group.
- Underneath each line item are checkboxes for each party member. People check off the items they participated in.
- We need to account for:
  - Global fees like taxes, surcharges, tip, etc, that should be split proportionate to consumption.
  - Global discounts that should be split proportionate to consumption.
  - Item specific discounts that should be applied to only the person who had that item.
  - Addons to specific items.
  - Certain people in the party who are being treated (e.g. for their birthday). Their bill should be split evenly among all other participants.

First, what do you think of the above idea? Any issues that I'm not foreseeing?

Second, look at the draft data model in `tmp/data_model.png`. What do you think?

## Requirements

- Ruby 3.4.4
- PostgreSQL
- Node.js >= 20.0.0
- Yarn

## Setup

1. Clone the repository
2. Install dependencies:
   ```bash
   bundle install
   yarn install
   ```

3. Setup database:
   ```bash
   rails db:create
   rails db:migrate
   rails db:seed
   ```

4. Copy environment variables:
   ```bash
   cp .env.example .env
   ```
   Edit `.env` with your configuration

## Development

Start the development server:
```bash
bin/dev
```

## Testing

Run the test suite:
```bash
bundle exec rspec
```

## Code Quality

Ruby linting:
```bash
bundle exec standardrb
bundle exec standardrb --fix
```

HTML+ERB analysis:
```bash
bundle exec herb analyze .
bundle exec herb parse app/views/path/to/file.html.erb
```
JavaScript/CSS linting:
```bash
yarn lint
yarn fix:prettier
```

ERB linting:
```bash
bundle exec erb_lint --lint-all
bundle exec erb_lint --lint-all --autocorrect
```

Security scanning:
```bash
bundle exec brakeman
bundle exec bundle-audit check
```

## Performance & N+1 Prevention

This app uses a two-pronged approach to prevent N+1 queries:

### Goldiloader (Prevention)
Automatically eager loads associations when accessed to prevent N+1 queries from occurring.
- Works in all environments (development, test, production)
- Disable for specific associations: `has_many :posts, -> { auto_include(false) }`
- Disable for code blocks: `Goldiloader.disabled { ... }`


### Bullet (Detection)
- Detects N+1 queries and suggests fixes in development and test
- Logs to server console and displays in HTML footer
- Unused eager loading detection is disabled to work well with Goldiloader
- View N+1 warnings in:
- Browser footer (development only)
- Rails server log
- Browser console

## Background Jobs

This app uses Solid Queue (Rails 8 default) for background job processing.

## Documentation

- Generate ERD: `bundle exec erd`
- Annotate models: `bundle exec annotaterb models`

## Error Monitoring

This app uses Rollbar for error tracking. Set your access token:
```bash
ROLLBAR_ACCESS_TOKEN=your_token_here
```

Visit [rollbar.com](https://rollbar.com) to sign up and get your access token.
## Performance Monitoring

This app uses Skylight for performance monitoring. Set your authentication token:
```bash
SKYLIGHT_AUTHENTICATION=your_token_here
```

Visit [skylight.io](https://skylight.io) to sign up and get your authentication token.
## Analytics

This app uses Ahoy for tracking and Blazer for analytics dashboards.

- View analytics dashboard: `/analytics`
- **Authentication:** Check `.env` file for auto-generated credentials
- **Username:** `admin`
- **Password:** Unique 16-character password in `.env` file
- Track custom events in JavaScript:
```javascript
ahoy.track("Event Name", {property: "value"});
```
- Track events in Ruby:
```ruby
ahoy.track "Event Name", property: "value"
```

Sample queries are available in `db/blazer_queries.yml`.

### Securing Blazer in Production

The dashboard uses basic authentication with a unique auto-generated password.
For production, you can:
1. Keep the strong auto-generated password
2. Use your app's authentication (e.g., Devise) instead
3. Create a read-only database user for Blazer
4. Restrict access by IP or VPN
## Deployment to Render.com

This app is configured for easy deployment to Render.com.

### Quick Deploy

1. Push your code to GitHub
2. Connect your repository to Render
3. Render will automatically detect the `render.yaml` blueprint
4. Set the `RAILS_MASTER_KEY` environment variable in the Render dashboard:
   - Find your key in `config/master.key`
   - Add it as an environment variable (not synced from the blueprint)

### What's Configured

- **Build script**: `bin/render-build.sh` handles dependencies, migrations, and assets
- **Database**: PostgreSQL database automatically provisioned
- **Health checks**: Rails 8's `/up` endpoint for monitoring
- **Concurrency**: `WEB_CONCURRENCY=2` to prevent memory issues
- **Background jobs**: Background jobs run in a separate worker service for better resource isolation.

### Manual Deployment

If you prefer manual setup instead of the blueprint:

1. Create a new Web Service on Render
2. Connect your repository
3. Set Build Command: `./bin/render-build.sh`
4. Set Start Command: `bundle exec puma -C config/puma.rb`
5. Add PostgreSQL database
6. Set environment variables:
   - `DATABASE_URL` (from database)
   - `RAILS_MASTER_KEY` (from config/master.key)
   - `WEB_CONCURRENCY=2`

7. Create a Background Worker service:
   - Build Command: `bundle install`
   - Start Command: `bundle exec rake solid_queue:start`
   - Add same `DATABASE_URL` and `RAILS_MASTER_KEY`

Learn more: [Render Rails 8 Deployment Guide](https://render.com/docs/deploy-rails-8)
