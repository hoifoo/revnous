# ALTCHA CAPTCHA Troubleshooting Guide

## Common Issues in Production

### 1. Environment Variable Not Set
**Symptom**: Logs show "Using default HMAC key"
**Solution**: Verify the environment variable is set in production

Check if `ALTCHA_HMAC_KEY` is properly loaded:
```bash
# On production server
rails c
puts ENV['ALTCHA_HMAC_KEY']
```

If it returns `nil`, the environment variable is not loaded. Make sure:
- `config/application.yml` is deployed (if using figaro)
- Environment variables are set in your deployment system (Kamal, etc.)
- The app was restarted after setting variables

### 2. Challenge Expiration
**Symptom**: Users fill out form slowly and CAPTCHA fails
**Solution**: Challenge now expires after 15 minutes (increased from 5 minutes)

Check logs for:
```
ALTCHA FAILED: Challenge expired
```

### 3. CORS Issues
**Symptom**: Challenge request fails to load
**Solution**: Verify CORS headers allow the challenge endpoint

Check browser console for CORS errors. The endpoint should be accessible:
```
GET /altcha/challenge
```

### 4. SSL Certificate Issues
**Symptom**: Challenge request fails on HTTPS
**Solution**: Verify SSL certificate is valid

Test the challenge endpoint:
```bash
curl https://yourdomain.com/altcha/challenge
```

### 5. Time Sync Issues
**Symptom**: Challenge fails immediately even though just generated
**Solution**: Check server time synchronization

```bash
# On production server
date
timedatectl status
```

Ensure NTP is enabled and time is synchronized.

## Debugging Steps

### Step 1: Check Production Logs
Look for ALTCHA-related log entries:

```bash
# View recent logs
tail -f log/production.log | grep ALTCHA
```

### Step 2: Test Challenge Generation
```bash
# In production console
rails c

# Test challenge generation
hmac_key = ENV['ALTCHA_HMAC_KEY']
options = Altcha::ChallengeOptions.new(
  hmac_key: hmac_key,
  max_number: 100000,
  expires: (Time.now + 15.minutes).to_i
)
challenge = Altcha.create_challenge(options)
puts challenge.inspect
```

### Step 3: Test Challenge Verification
```bash
# In production console
rails c

# You'll need a real challenge payload from the browser
# Get it from the form submission
payload = {
  algorithm: "SHA-256",
  challenge: "...",
  number: 12345,
  salt: "...",
  signature: "...",
  expires: ...
}

result = Altcha.verify_solution(payload, ENV['ALTCHA_HMAC_KEY'], true)
puts "Verification result: #{result}"
```

### Step 4: Check Network Request
In browser DevTools:
1. Open Network tab
2. Fill out contact form
3. Look for request to `/altcha/challenge`
4. Verify it returns 200 OK with valid JSON
5. Look for the form submission POST request
6. Check if `altcha` parameter is included

## Log Interpretation

### Successful Flow
```
ALTCHA Challenge generation START
ALTCHA ENV KEY present: true
ALTCHA Current time: 1234567890
ALTCHA Challenge created successfully (expires: 1234568790)

[User submits form]

ALTCHA Verification START
ALTCHA Payload received: {...}
ALTCHA ENV KEY present: true
ALTCHA Current time: 1234567900
ALTCHA Parsed payload: {...}
ALTCHA Challenge expires: 1234568790 (current: 1234567900)
ALTCHA Verification result: true
```

### Failed Flow Examples

**Expired Challenge**:
```
ALTCHA FAILED: Challenge expired (expires: 1234567890, now: 1234568900)
```

**Missing Environment Variable**:
```
ALTCHA FAILED: Using default HMAC key - environment variable not set!
```

**Invalid Payload**:
```
ALTCHA JSON parse error: unexpected token
ALTCHA Raw payload: undefined
```

## Quick Fixes

### Fix 1: Restart Application
```bash
# Restart your Rails application
# For Kamal
kamal app restart

# For Systemd
sudo systemctl restart your-app

# For Passenger
passenger-config restart-app /path/to/app
```

### Fix 2: Verify Environment Variables
Check your deployment configuration:

**For Kamal** (`config/deploy.yml`):
```yaml
env:
  secret:
    - ALTCHA_HMAC_KEY
```

**For Figaro** (`config/application.yml`):
```yaml
production:
  ALTCHA_HMAC_KEY: your-key-here
```

### Fix 3: Clear Browser Cache
Sometimes the CAPTCHA widget caches incorrectly:
1. Clear browser cache
2. Hard reload (Ctrl+Shift+R or Cmd+Shift+R)
3. Try incognito/private window

### Fix 4: Update ALTCHA Widget
Make sure you're using the latest version:
```html
<script type="module" src="https://cdn.jsdelivr.net/npm/altcha/dist/altcha.min.js"></script>
```

## Testing in Production

### Safe Test
You can test without spamming your Telegram:

1. Comment out the Telegram notification line in `contacts_controller.rb`:
```ruby
# InternalEventJob.perform_later(telegram_message)
```

2. Test the form submission
3. Check logs for ALTCHA verification
4. Uncomment the line when done

### Alternative: Use Rails Console
```bash
rails c

# Simulate the verification process
params = {
  contact: {
    name: "Test",
    email: "test@test.com",
    subject: "Test",
    message: "Test"
  },
  altcha: '{"algorithm":"SHA-256","challenge":"...","number":12345,"salt":"...","signature":"..."}'
}

# This won't actually work in console, but you can test the verification method
# by copying it to a temporary method
```

## Contact for Help

If none of these solutions work, check:
1. Production logs: `log/production.log`
2. Server error logs: `/var/log/nginx/error.log` (if using nginx)
3. Application error tracking service (if configured)

Common patterns to grep for:
```bash
grep -i "altcha" log/production.log
grep -i "captcha" log/production.log
grep -i "verification failed" log/production.log
```
