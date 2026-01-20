# License System Implementation TODO

## Completed Tasks

### 1. License Service Implementation
- [x] Create `lib/src/license/license_service.dart` with LicenseService class
- [x] Implement LicenseMode enum (unlicensed, active, expired_readonly, tampered)
- [x] Implement LicensePayload and LicenseState classes
- [x] Add Ed25519 signature verification
- [x] Implement license activation logic
- [x] Add anti-tamper protection with lastSeen timestamp
- [x] Persist license state to ApplicationSupportDirectory/license_state.json

### 2. License Screen UI
- [x] Create `lib/src/screens/license_screen.dart` for license key entry
- [x] Add status display and error handling

### 3. App Architecture Updates
- [x] Modify `lib/main.dart` to initialize LicenseService
- [x] Update `lib/src/screens/boot_gate.dart` to check license status on startup
- [x] Route to license screen if unlicensed or tampered
- [x] Route to main app if active, readonly mode if expired

### 4. Readonly Guards Implementation
- [x] Add license checks in `lib/src/screens/products_screen.dart` for add/edit/delete products
- [x] Add license checks in `lib/src/screens/admin_screen.dart` for investments/expenses
- [x] Add license checks in `lib/src/screens/main_screen.dart` for checkout/sales
- [x] Disable write operations when license mode != active

### 5. Admin License Info
- [x] Update `lib/src/screens/admin_screen.dart` to show license status and details

### 6. Dependencies
- [x] Add `cryptography: ^2.7.0` to `pubspec.yaml`

### 7. Keygen Tool
- [x] Create separate `keygen/` directory with Dart console app
- [x] Implement `keygen/keygen.dart` for generating Ed25519 key pairs
- [x] Add license key generation with payload + signature
- [x] Create `keygen/pubspec.yaml` with cryptography dependency

## Remaining Tasks

### Testing and Validation
- [ ] Test license activation flow
- [ ] Test expiration handling (readonly mode)
- [ ] Test anti-tamper protection
- [ ] Test offline functionality
- [ ] Verify Flutter desktop compilation

### Production Preparation
- [ ] Replace placeholder public/private keys with actual generated keys
- [ ] Update developer credentials in production
- [ ] Test keygen tool functionality
- [ ] Document license key distribution process

## Notes
- App works completely offline after license activation
- License keys use Ed25519 signatures for security
- Anti-tamper protection detects clock manipulation
- Readonly mode allows viewing data but blocks all write operations
- License state persisted locally in JSON format
