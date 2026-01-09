# Vasool Drive - Frontend

The mobile application interface for the Vasool Drive Daily Finance Collection System, built with **Flutter**.

## 📱 Overview
This application serves two primary user roles:
1. **Field Agents**: Collecting payments, managing daily routes, and viewing performance stats.
2. **Admins**: Monitoring operations, approving collections, and managing the entire system.

## 🔑 Key Modules

### Authentication
- **Login**: Secure PIN + Face Verification flow.
- **Biometric Enrollment**: Integrated camera module for capturing and verifying agent faces.

### Agent Features
- **My Lines**: Tabbed view of daily customers (Pending/Collected).
- **Collection Entry**: Fast, secure payment recording with GPS tagging.
- **My Stats**: Personal performance dashboard with AI insights.

### Admin Features
- **Dashboard**: High-level financial overview and quick actions.
- **Collection Review**: Unified interface to approve/reject agent collections.
- **User Management**: Create and manage staff accounts.
- **Analytics**: Deep dives into risk and worker performance.
- **Master Settings**: Configure interest rates, grace periods, and system rules.

## 🚀 Setup & Run

1. **Install Flutter**: Ensure the Flutter SDK is installed and added to your PATH.
2. **Install Dependencies**:
   ```bash
   flutter pub get
   ```
3. **Run the App**:
   ```bash
   flutter run
   ```

## 📦 Key Dependencies
- `provider`: State management.
- `http`: API communication.
- `flutter_secure_storage`: Secure token storage.
- `intl`: Date and currency formatting.
- `camera`: Biometric features.
- `fl_chart`: Analytics visualization.
