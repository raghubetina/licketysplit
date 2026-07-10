// Entry point for the build script in your package.json
import '@hotwired/turbo-rails'
import 'turbo-refresh-animations'
import './controllers'

// Ahoy analytics tracking
import ahoy from 'ahoy.js'

// Track page views
ahoy.trackView()

// Example: Track custom events
// ahoy.track("Clicked Button", {button: "signup"});
