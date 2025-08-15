import 'package:flutter/material.dart';

class CustomTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final bool obscureText;
  final IconData? prefixIcon;
  final VoidCallback? onTap;
  final Widget? prefixWidget;
  final String? Function(String?)? validator;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.obscureText = false,
    this.prefixIcon,
    this.onTap,
    this.prefixWidget,
    this.validator,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isFocused = false;
  bool _isObscured = false;

  @override
  void initState() {
    super.initState();
    _isObscured = widget.obscureText;

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // @override
  // Widget build(BuildContext context) {
  //   return Padding(
  //     padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
  //     child: ScaleTransition(
  //       scale: _scaleAnimation,
  //       child: Container(
  //         decoration: BoxDecoration(
  //           borderRadius: BorderRadius.circular(16),
  //           boxShadow: [
  //             BoxShadow(
  //               color: _isFocused
  //                   ? Theme.of(context).primaryColor.withOpacity(0.2)
  //                   : Colors.black.withOpacity(0.05),
  //               blurRadius: _isFocused ? 12 : 8,
  //               offset: const Offset(0, 4),
  //             ),
  //           ],
  //         ),
  //         child: TextField(
  //           controller: widget.controller,
  //           obscureText: _isObscured,
  //           style: const TextStyle(
  //             fontSize: 16,
  //             fontWeight: FontWeight.w500,
  //             color: Color(0xFF1A1A1A),
  //           ),
  //           decoration: InputDecoration(
  //             hintText: widget.hintText,
  //             hintStyle: TextStyle(
  //               color: Colors.grey[500],
  //               fontSize: 16,
  //               fontWeight: FontWeight.w400,
  //             ),

  //             // prefixIcon: widget.prefixIcon != null
  //             //     ? Container(
  //             //         margin: const EdgeInsets.only(left: 12, right: 8),
  //             //         child: Icon(
  //             //           widget.prefixIcon,
  //             //           color: _isFocused
  //             //               ? Theme.of(context).primaryColor
  //             //               : Colors.grey[500],
  //             //           size: 22,
  //             //         ),
  //             //       )
  //             //     : null,
  //             prefixIcon:
  //                 widget.prefixWidget ??
  //                 (widget.prefixIcon != null
  //                     ? Container(
  //                         margin: const EdgeInsets.only(left: 12, right: 8),
  //                         child: Icon(
  //                           widget.prefixIcon,
  //                           color: _isFocused
  //                               ? Theme.of(context).primaryColor
  //                               : Colors.grey[500],
  //                           size: 22,
  //                         ),
  //                       )
  //                     : null),
  //             suffixIcon: widget.obscureText
  //                 ? Container(
  //                     margin: const EdgeInsets.only(right: 12),
  //                     child: IconButton(
  //                       icon: Icon(
  //                         _isObscured
  //                             ? Icons.visibility_off_outlined
  //                             : Icons.visibility_outlined,
  //                         color: _isFocused
  //                             ? Theme.of(context).primaryColor
  //                             : Colors.grey[500],
  //                         size: 22,
  //                       ),
  //                       onPressed: () {
  //                         setState(() {
  //                           _isObscured = !_isObscured;
  //                         });
  //                       },
  //                     ),
  //                   )
  //                 : null,
  //             filled: true,
  //             fillColor: _isFocused
  //                 ? Theme.of(context).primaryColor.withOpacity(0.05)
  //                 : Colors.white,
  //             border: OutlineInputBorder(
  //               borderRadius: BorderRadius.circular(16),
  //               borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
  //             ),
  //             enabledBorder: OutlineInputBorder(
  //               borderRadius: BorderRadius.circular(16),
  //               borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
  //             ),
  //             focusedBorder: OutlineInputBorder(
  //               borderRadius: BorderRadius.circular(16),
  //               borderSide: BorderSide(
  //                 color: Theme.of(context).primaryColor,
  //                 width: 2.0,
  //               ),
  //             ),
  //             errorBorder: OutlineInputBorder(
  //               borderRadius: BorderRadius.circular(16),
  //               borderSide: const BorderSide(color: Colors.red, width: 2.0),
  //             ),
  //             contentPadding: const EdgeInsets.symmetric(
  //               horizontal: 20,
  //               vertical: 18,
  //             ),
  //           ),
  //           onChanged: (value) {
  //             if (value.isNotEmpty && !_animationController.isAnimating) {
  //               _animationController.forward().then((_) {
  //                 _animationController.reverse();
  //               });
  //             }
  //           },
  //           onTapOutside: (_) {
  //             setState(() {
  //               _isFocused = false;
  //             });
  //           },
  //           onTap: () {
  //             setState(() {
  //               _isFocused = true;
  //             });
  //             widget.onTap?.call();
  //           },
  //         ),
  //       ),
  //     ),
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _isFocused
                    ? Theme.of(context).primaryColor.withOpacity(0.2)
                    : Colors.black.withOpacity(0.05),
                blurRadius: _isFocused ? 12 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          // CHANGE 1: Use TextFormField to enable the validator property.
          child: TextFormField(
            controller: widget.controller,
            obscureText: _isObscured,
            validator: widget.validator, // Pass the validator here
            keyboardType: widget.prefixIcon == Icons.phone
                ? TextInputType.phone
                : TextInputType.text,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1A1A1A),
            ),
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: TextStyle(
                color: Colors.grey[500],
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),

              // CHANGE 2: Use the 'prefix' property for custom widgets like the country picker.
              // This provides better alignment and spacing than 'prefixIcon'.
              prefix: widget.prefixWidget,

              // Only show the 'prefixIcon' if 'prefixWidget' is not being used.
              prefixIcon:
                  widget.prefixWidget == null && widget.prefixIcon != null
                  ? Container(
                      margin: const EdgeInsets.only(left: 12, right: 8),
                      child: Icon(
                        widget.prefixIcon,
                        color: _isFocused
                            ? Theme.of(context).primaryColor
                            : Colors.grey[500],
                        size: 22,
                      ),
                    )
                  : null,
              suffixIcon: widget.obscureText
                  ? Container(
                      // ... your existing suffixIcon code is fine
                      margin: const EdgeInsets.only(right: 12),
                      child: IconButton(
                        icon: Icon(
                          _isObscured
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: _isFocused
                              ? Theme.of(context).primaryColor
                              : Colors.grey[500],
                          size: 22,
                        ),
                        onPressed: () {
                          setState(() {
                            _isObscured = !_isObscured;
                          });
                        },
                      ),
                    )
                  : null,
              filled: true,
              // ... the rest of your InputDecoration styling is fine
              fillColor: _isFocused
                  ? Theme.of(context).primaryColor.withOpacity(0.05)
                  : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: Theme.of(context).primaryColor,
                  width: 2.0,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Colors.red, width: 2.0),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 18,
              ),
            ),
            onTap: () {
              setState(() {
                _isFocused = true;
              });
              widget.onTap?.call();
            },
            // Note: TextFormField does not have onTapOutside, but FocusNode can be used
            // for more advanced focus handling if needed.
          ),
        ),
      ),
    );
  }
}
