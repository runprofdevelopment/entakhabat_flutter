# Responsive Design Guide for Entkhabat Flutter App

## Overview
This guide explains how to make your Flutter app responsive using the utilities and widgets provided.

## Responsive Utilities

### 1. ResponsiveUtils Class
Located in `lib/utils/responsive_utils.dart`

#### Basic Usage:
```dart
// Get screen dimensions
double width = ResponsiveUtils.screenWidth(context);
double height = ResponsiveUtils.screenHeight(context);

// Get responsive sizes
double fontSize = ResponsiveUtils.getFontSize(context, 0.04); // 4% of screen width
double buttonSize = ResponsiveUtils.getButtonSize(context, 0.15); // 15% of screen width
double imageSize = ResponsiveUtils.getImageSize(context, 0.6); // 60% of screen width

// Get responsive spacing
double spacing = ResponsiveUtils.getHeight(context, 0.02); // 2% of screen height
```

#### Responsive Breakpoints:
```dart
if (ResponsiveUtils.isMobile(context)) {
  // Mobile layout
} else if (ResponsiveUtils.isTablet(context)) {
  // Tablet layout
} else if (ResponsiveUtils.isDesktop(context)) {
  // Desktop layout
}
```

#### Responsive Text Styles:
```dart
TextStyle style = ResponsiveUtils.getResponsiveTextStyle(
  context,
  fontSizePercentage: 0.04,
  fontWeight: FontWeight.bold,
  color: Colors.red,
);
```

### 2. Responsive Widgets
Located in `lib/widgets/responsive_wrapper.dart`

#### ResponsiveWrapper:
```dart
ResponsiveWrapper(
  padding: ResponsiveUtils.getPadding(context),
  centerContent: true,
  child: YourWidget(),
)
```

#### ResponsiveText:
```dart
ResponsiveText(
  'Hello World',
  fontSizePercentage: 0.05,
  fontWeight: FontWeight.bold,
  color: Colors.red,
)
```

#### ResponsiveButton:
```dart
ResponsiveButton(
  'Click Me',
  onPressed: () {},
  widthPercentage: 0.8,
  heightPercentage: 0.06,
  fontSizePercentage: 0.04,
)
```

#### ResponsiveImage:
```dart
ResponsiveImage(
  'assets/image.png',
  widthPercentage: 0.8,
  heightPercentage: 0.3,
  fit: BoxFit.cover,
)
```

## Best Practices

### 1. Use Percentages Instead of Fixed Sizes
```dart
// ❌ Bad - Fixed sizes
Container(width: 200, height: 100)

// ✅ Good - Responsive sizes
Container(
  width: ResponsiveUtils.getWidth(context, 0.5),
  height: ResponsiveUtils.getHeight(context, 0.2),
)
```

### 2. Use Responsive Spacing
```dart
// ❌ Bad - Fixed spacing
SizedBox(height: 20)

// ✅ Good - Responsive spacing
SizedBox(height: ResponsiveUtils.getHeight(context, 0.02))
```

### 3. Use Responsive Text Sizes
```dart
// ❌ Bad - Fixed font size
Text('Hello', style: TextStyle(fontSize: 16))

// ✅ Good - Responsive font size
ResponsiveText('Hello', fontSizePercentage: 0.04)
```

### 4. Handle Different Screen Sizes
```dart
Widget build(BuildContext context) {
  if (ResponsiveUtils.isMobile(context)) {
    return MobileLayout();
  } else if (ResponsiveUtils.isTablet(context)) {
    return TabletLayout();
  } else {
    return DesktopLayout();
  }
}
```

## Example Implementation

### Responsive Splash Screen:
```dart
@override
Widget build(BuildContext context) {
  final logoSize = ResponsiveUtils.getImageSize(context, 0.6);
  final titleFontSize = ResponsiveUtils.getFontSize(context, 0.06);
  
  return Scaffold(
    body: ResponsiveWrapper(
      centerContent: true,
      child: Column(
        children: [
          ResponsiveImage(
            'assets/logo.png',
            widthPercentage: 0.6,
            heightPercentage: 0.4,
          ),
          ResponsiveUtils.responsiveSpacing(context, heightPercentage: 0.02),
          ResponsiveText(
            'App Title',
            fontSizePercentage: 0.06,
            fontWeight: FontWeight.bold,
          ),
        ],
      ),
    ),
  );
}
```

### Responsive Home Screen:
```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: ResponsiveText(
        'Home',
        fontSizePercentage: 0.05,
        fontWeight: FontWeight.bold,
      ),
    ),
    body: ResponsiveWrapper(
      padding: ResponsiveUtils.getPadding(context),
      child: Column(
        children: [
          ResponsiveText(
            'Welcome to Entkhabat',
            fontSizePercentage: 0.04,
            textAlign: TextAlign.center,
          ),
          ResponsiveUtils.responsiveSpacing(context, heightPercentage: 0.03),
          ResponsiveButton(
            'Get Started',
            onPressed: () {},
            widthPercentage: 0.8,
          ),
        ],
      ),
    ),
  );
}
```

## Tips for Responsive Design

1. **Test on Multiple Devices**: Always test your app on different screen sizes
2. **Use Flexible Layouts**: Prefer `Flex`, `Expanded`, and `Flexible` widgets
3. **Avoid Fixed Dimensions**: Use percentages and responsive utilities
4. **Consider Orientation**: Handle both portrait and landscape modes
5. **Use SafeArea**: Always wrap content in SafeArea for proper spacing
6. **Test Text Scaling**: Ensure text remains readable at different sizes

## Common Responsive Values

- **Small Text**: 0.03 (3% of screen width)
- **Normal Text**: 0.04 (4% of screen width)
- **Large Text**: 0.06 (6% of screen width)
- **Title Text**: 0.08 (8% of screen width)
- **Button Height**: 0.06 (6% of screen height)
- **Image Width**: 0.8 (80% of screen width)
- **Spacing**: 0.02 (2% of screen height)
- **Padding**: 0.05 (5% of screen width/height) 