import 'package:flutter/material.dart';
import '../utils/responsive_utils.dart';

class ResponsiveWrapper extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final bool useSafeArea;
  final bool centerContent;
  final Color? backgroundColor;

  const ResponsiveWrapper({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.useSafeArea = true,
    this.centerContent = false,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = child;

    if (centerContent) {
      content = Center(child: content);
    }

    if (padding != null) {
      content = Padding(
        padding: padding!,
        child: content,
      );
    }

    if (margin != null) {
      content = Container(
        margin: margin!,
        child: content,
      );
    }

    if (useSafeArea) {
      content = SafeArea(child: content);
    }

    if (backgroundColor != null) {
      content = Container(
        color: backgroundColor,
        child: content,
      );
    }

    return content;
  }
}

class ResponsiveText extends StatelessWidget {
  final String text;
  final double fontSizePercentage;
  final FontWeight fontWeight;
  final Color? color;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const ResponsiveText(
    this.text, {
    super.key,
    this.fontSizePercentage = 0.04,
    this.fontWeight = FontWeight.normal,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: ResponsiveUtils.getResponsiveTextStyle(
        context,
        fontSizePercentage: fontSizePercentage,
        fontWeight: fontWeight,
        color: color,
      ),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

class ResponsiveButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final double widthPercentage;
  final double heightPercentage;
  final double fontSizePercentage;
  final Color? backgroundColor;
  final Color? textColor;
  final BorderRadius? borderRadius;

  const ResponsiveButton(
    this.text, {
    super.key,
    this.onPressed,
    this.widthPercentage = 0.8,
    this.heightPercentage = 0.06,
    this.fontSizePercentage = 0.04,
    this.backgroundColor,
    this.textColor,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: ResponsiveUtils.getWidth(context, widthPercentage),
      height: ResponsiveUtils.getHeight(context, heightPercentage),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          shape: RoundedRectangleBorder(
            borderRadius: borderRadius ?? BorderRadius.circular(8),
          ),
        ),
        child: ResponsiveText(
          text,
          fontSizePercentage: fontSizePercentage,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class ResponsiveImage extends StatelessWidget {
  final String imagePath;
  final double widthPercentage;
  final double heightPercentage;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const ResponsiveImage(
    this.imagePath, {
    super.key,
    this.widthPercentage = 0.8,
    this.heightPercentage = 0.3,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    Widget image = Image.asset(
      imagePath,
      fit: fit,
    );

    if (borderRadius != null) {
      image = ClipRRect(
        borderRadius: borderRadius!,
        child: image,
      );
    }

    return SizedBox(
      width: ResponsiveUtils.getWidth(context, widthPercentage),
      height: ResponsiveUtils.getHeight(context, heightPercentage),
      child: image,
    );
  }
} 