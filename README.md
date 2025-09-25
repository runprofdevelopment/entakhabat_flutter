# Entkhabat Flutter App

A Flutter application with GetX state management and Firebase integration.

## Features

- ✅ Flutter 3.32.2
- ✅ GetX for state management, routing, and dependency injection
- ✅ Firebase Core integration
- ✅ Firebase Authentication
- ✅ Cloud Firestore
- ✅ Firebase Storage
- ✅ Firebase Analytics
- ✅ Firebase Crashlytics

## Setup

### Prerequisites

- Flutter SDK (3.32.2 or higher)
- Dart SDK (3.8.1 or higher)
- Firebase CLI
- FlutterFire CLI

### Installation

1. Clone the repository
2. Navigate to the project directory:
   ```bash
   cd entkhabat
   ```

3. Install dependencies:
   ```bash
   flutter pub get
   ```

4. Run the app:
   ```bash
   flutter run
   ```

## Project Structure

```
lib/
├── controllers/
│   └── counter_controller.dart    # GetX controller example
├── services/
│   └── firebase_service.dart      # Firebase service
├── firebase_options.dart          # Firebase configuration
└── main.dart                      # App entry point
```

## Firebase Configuration

The app is configured with Firebase project: `entakhabat-29d30`

### Firebase Services Used

- **Firebase Core**: App initialization
- **Firebase Auth**: User authentication
- **Cloud Firestore**: Database
- **Firebase Storage**: File storage
- **Firebase Analytics**: App analytics
- **Firebase Crashlytics**: Crash reporting

### Platform Support

- ✅ Android
- ✅ iOS
- ❌ Web (not configured)
- ❌ macOS (not configured)
- ❌ Windows (not configured)
- ❌ Linux (not configured)

## GetX Features Demonstrated

1. **State Management**: Counter controller with reactive state
2. **Dependency Injection**: Automatic controller injection
3. **Navigation**: GetMaterialApp for enhanced navigation
4. **Reactive UI**: Obx widget for reactive updates

## Usage Examples

### State Management with GetX

```dart
// Controller
class CounterController extends GetxController {
  var count = 0.obs;
  
  void increment() => count++;
  void decrement() => count--;
  void reset() => count.value = 0;
}

// Usage in UI
Obx(() => Text('${controller.count}'))
```

### Firebase Operations

```dart
// Add document
await firebaseService.addDocument('users', {
  'name': 'John Doe',
  'email': 'john@example.com'
});

// Get documents stream
Stream<QuerySnapshot> users = firebaseService.getDocuments('users');
```

## Development

### Adding New Features

1. Create controllers in `lib/controllers/`
2. Create services in `lib/services/`
3. Create models in `lib/models/` (if needed)
4. Create views in `lib/views/` (if needed)

### Firebase Rules

Make sure to configure appropriate Firebase Security Rules for your collections.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is licensed under the MIT License.
