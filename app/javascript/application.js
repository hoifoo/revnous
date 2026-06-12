// Entry point for the build script in your package.json
import "@hotwired/turbo-rails"
import "./controllers"
import "./altcha"
import "./lib/analytics"

import { application } from "./controllers/application"

document.addEventListener('turbo:before-cache', () => {
  application.controllers.forEach(c => {
    if (typeof c.teardown === 'function') c.teardown()
  })
})
