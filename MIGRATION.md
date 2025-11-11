# Migration Guide: Alerter 1.x → 2.0

This guide helps you migrate from the original Objective-C alerter (using NSUserNotification) to the new Golang-based alerter 2.0 (using UserNotifications framework).

## Overview

Alerter 2.0 is **backward compatible** with 1.x command-line arguments. Most scripts will work without changes. However, there are some important differences to be aware of.

## System Requirements Change

| Version | Minimum macOS | API Used |
|---------|---------------|----------|
| 1.x | macOS 10.8 | NSUserNotification (deprecated) |
| 2.0 | macOS 10.14 | UNUserNotificationCenter (modern) |

**Action Required:** If you need to support macOS 10.8-10.13, continue using alerter 1.x. For macOS 10.14+, upgrade to 2.0.

## Installation Changes

### Old Method (1.x)
```bash
# Download precompiled binary from releases
unzip alerter-1.x.zip
cp alerter /usr/local/bin/
```

### New Method (2.0)
```bash
# Build from source
git clone https://github.com/vjeantet/alerter.git
cd alerter
make install
```

Or manually:
```bash
go build -o alerter .
cp alerter /usr/local/bin/
```

## Authorization Behavior

### 1.x Behavior
- Implicit authorization
- Notifications could appear without explicit user consent
- No initial permission prompt

### 2.0 Behavior
- **Explicit authorization required**
- First run shows system permission dialog
- Authorization is cached after approval
- User can manage permissions in System Preferences

**Migration Impact:** Users will see a permission prompt on first use. This is expected macOS behavior for modern apps.

## Code Signing

### 1.x
- Code signing optional
- Worked without signing in most cases

### 2.0
- **Code signing recommended** (especially for authorization dialogs)
- Required for proper system integration

**Action Required:**
```bash
# Self-sign for local use
codesign --force --sign - alerter

# Or use developer certificate
codesign --force --sign "Developer ID Application: Your Name" alerter
```

## API Changes

### No Breaking Changes ✅

All 1.x command-line options are supported in 2.0:

- `-message` → ✅ Works
- `-title` → ✅ Works
- `-subtitle` → ✅ Works
- `-actions` → ✅ Works
- `-reply` → ✅ Works
- `-timeout` → ✅ Works
- `-sound` → ✅ Works
- `-group` → ✅ Works
- `-remove` → ✅ Works
- `-list` → ✅ Works
- `-json` → ✅ Works
- `-appIcon` → ✅ Works (implementation updated)
- `-contentImage` → ✅ Works (now uses attachments)
- `-sender` → ✅ Works
- `-ignoreDnD` → ✅ Works

### Minor Behavioral Differences

#### 1. Image Handling

**1.x:**
- Used private APIs for `_identityImage` and `contentImage`
- Direct image rendering

**2.0:**
- Uses official `UNNotificationAttachment` API
- `contentImage` now uses attachment system
- More reliable but may have slight visual differences

#### 2. Action Dropdown

**1.x:**
- Used private `_alternateActionButtonTitles` API
- Custom dropdown implementation

**2.0:**
- Uses official `UNNotificationCategory` and `UNNotificationAction`
- Standard macOS action menu
- More native appearance

#### 3. JSON Output Format

**1.x:**
```json
{
  "activationType": "actionClicked",
  "activationValue": "Yes",
  "deliveredAt": "2025-01-15 10:30:00",
  "activationAt": "2025-01-15 10:30:05"
}
```

**2.0:**
```json
{
  "activationType": "actionClicked",
  "activationValue": "Yes",
  "activationValueIndex": "0",
  "deliveredAt": "2025-01-15 10:30:00 +0000",
  "activationAt": "2025-01-15 10:30:05 +0000"
}
```

**Changes:**
- Added `activationValueIndex` for action button index
- Date format now includes timezone (`+0000`)

**Migration:** Update JSON parsers to handle the new field (optional) and date format.

## Script Migration Examples

### Example 1: Basic Notification

**1.x and 2.0 (Identical):**
```bash
#!/bin/bash
alerter -message "Backup complete" -title "Backup" -sound default
```

**No changes needed!** ✅

### Example 2: Capture User Response

**1.x:**
```bash
#!/bin/bash
RESPONSE=$(alerter -message "Deploy?" -actions "Yes,No")

if [ "$RESPONSE" = "Yes" ]; then
    echo "Deploying..."
fi
```

**2.0:**
```bash
#!/bin/bash
RESPONSE=$(alerter -message "Deploy?" -actions "Yes,No")

if [ "$RESPONSE" = "Yes" ]; then
    echo "Deploying..."
fi
```

**No changes needed!** ✅

### Example 3: JSON Processing

**1.x:**
```bash
#!/bin/bash
RESULT=$(alerter -message "Choose" -actions "A,B,C" -json)
TYPE=$(echo "$RESULT" | jq -r '.activationType')
VALUE=$(echo "$RESULT" | jq -r '.activationValue')
```

**2.0:**
```bash
#!/bin/bash
RESULT=$(alerter -message "Choose" -actions "A,B,C" -json)
TYPE=$(echo "$RESULT" | jq -r '.activationType')
VALUE=$(echo "$RESULT" | jq -r '.activationValue')
INDEX=$(echo "$RESULT" | jq -r '.activationValueIndex // empty')  # New field
```

**Migration:** Optionally capture the new `activationValueIndex` field.

### Example 4: Group Management

**1.x and 2.0 (Identical):**
```bash
#!/bin/bash
# Send notification
alerter -message "Process running..." -group "process-1"

# Later: Remove notification
alerter -remove "process-1"

# Or list notifications
alerter -list "process-1"
```

**No changes needed!** ✅

## Testing Your Migration

### Step 1: Install Both Versions

```bash
# Keep 1.x as alerter-old
cp /usr/local/bin/alerter /usr/local/bin/alerter-old

# Install 2.0 as alerter
make install
```

### Step 2: Test Side-by-Side

```bash
# Test with old version
alerter-old -message "Test 1.x" -title "Old"

# Test with new version
alerter -message "Test 2.0" -title "New"
```

### Step 3: Validate Scripts

Run your existing scripts with 2.0 and verify:

1. ✅ Notifications appear correctly
2. ✅ Actions work as expected
3. ✅ Reply notifications function
4. ✅ JSON output can be parsed
5. ✅ Timeouts work correctly
6. ✅ Sound plays

### Step 4: Check Authorization

```bash
# First run will prompt for permissions
alerter -message "Permission test" -title "Alerter 2.0"
```

Approve the permission request when prompted.

## Common Migration Issues

### Issue 1: "Authorization denied"

**Cause:** User hasn't granted notification permissions.

**Solution:**
1. Go to System Preferences → Notifications
2. Find "Terminal" (or your sender app)
3. Enable notifications

### Issue 2: Build fails with CGo errors

**Cause:** Missing Xcode Command Line Tools or Go not configured for CGo.

**Solution:**
```bash
xcode-select --install
export CGO_ENABLED=1
make clean && make build
```

### Issue 3: Notifications don't appear

**Cause:** Do Not Disturb enabled, or notification settings disabled.

**Solution:**
```bash
# Use ignoreDnD flag
alerter -message "Test" -ignoreDnD

# Or disable Do Not Disturb in System Preferences
```

### Issue 4: Images not displaying

**Cause:** Image path or URL incorrect, or unsupported format.

**Solution:**
```bash
# Use absolute paths
alerter -contentImage "/Users/yourname/Pictures/image.png" -message "Test"

# Or URLs
alerter -contentImage "https://example.com/image.png" -message "Test"

# Supported formats: PNG, JPEG, GIF
```

### Issue 5: Code signing warnings

**Cause:** Binary not signed.

**Solution:**
```bash
# Sign the binary
codesign --force --sign - /usr/local/bin/alerter
```

## Rollback Plan

If you encounter critical issues:

```bash
# Restore 1.x version
cp /usr/local/bin/alerter-old /usr/local/bin/alerter

# Or download from releases
# https://github.com/vjeantet/alerter/releases/tag/v1.x.x
```

## Benefits of Upgrading

Despite the minor migration effort, upgrading to 2.0 provides:

1. ✅ **Future-proof** - Uses current macOS APIs
2. ✅ **Better compatibility** - Works on macOS 11.0+ (Big Sur and later)
3. ✅ **More stable** - Official APIs instead of private methods
4. ✅ **Better maintained** - Go codebase easier to maintain
5. ✅ **Enhanced features** - Action index tracking in JSON output

## Support

If you encounter migration issues:

1. Check this guide first
2. Review the [README-GOLANG.md](README-GOLANG.md)
3. Check [GitHub Issues](https://github.com/vjeantet/alerter/issues)
4. Open a new issue with:
   - macOS version
   - Error messages
   - Script example that's failing

## Timeline Recommendation

- **Immediate:** Test 2.0 in development environment
- **Week 1:** Migrate non-critical scripts
- **Week 2-3:** Migrate production scripts
- **Month 1:** Complete migration

## Conclusion

Alerter 2.0 maintains full backward compatibility while providing a modern, future-proof foundation. Most migrations require **zero code changes**. The main differences are:

1. Minimum macOS version (10.14+)
2. Initial permission prompt
3. Code signing recommended
4. Minor JSON format enhancements

The migration is straightforward and the benefits of using modern APIs make it worthwhile for long-term maintenance.
