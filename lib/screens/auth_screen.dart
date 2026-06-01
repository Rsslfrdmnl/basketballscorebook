import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../main.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool isLoading = false;
  bool isLogin = true;

  Future<void> _authenticate() async {
    String loginInput = _emailController.text.trim();
    
    if (isLogin) {
      // Login - username or email
      if (loginInput.isEmpty || _passwordController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill in all fields')),
        );
        return;
      }
    } else {
      // Sign up - email, password, and username
      if (_emailController.text.trim().isEmpty || 
          _passwordController.text.trim().isEmpty ||
          _usernameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill in all fields')),
        );
        return;
      }
    }

    setState(() => isLoading = true);

    try {
      UserCredential cred;
      String emailToUse = loginInput;
      
      // Check if input contains @ (it's an email)
      bool isEmail = loginInput.contains('@');
      
      // If it's not an email, look up the email from Firestore
      if (isLogin && !isEmail) {
        
        // Query Firestore for the username
        final querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('username', isEqualTo: loginInput)
            .get();
        
        if (querySnapshot.docs.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Username not found')),
          );
          setState(() => isLoading = false);
          return;
        }
        
        // Get the email from the user document
        emailToUse = querySnapshot.docs.first['email'];
      }
      
      if (isLogin) {
        // Login with email
        cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: emailToUse,
          password: _passwordController.text.trim(),
        );
      } else {
        // Sign up with email and password
        cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        
        // Store user data including username
        await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
          'email': _emailController.text.trim(),
          'username': _usernameController.text.trim(),
          'role': 'sub_admin',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ScorebookHome()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryDark,
              AppTheme.secondaryDark,
              AppTheme.surfaceDark,
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card(
              color: AppTheme.surfaceDark,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Colors.white10),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.accentGold.withOpacity(0.1),
                        border: Border.all(color: AppTheme.accentGold.withOpacity(0.3)),
                      ),
                      child: const Icon(
                        Icons.sports_basketball,
                        size: 48,
                        color: AppTheme.accentGold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Scorebook Pro',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textPrimary,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isLogin ? 'Sign in with email or username' : 'Create your account',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Username (only for sign up)
                    if (!isLogin)
                      TextField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          prefixIcon: Icon(Icons.person),
                        ),
                      ),
                    if (!isLogin) const SizedBox(height: 16),
                    
                    // Email or Username (for login) / Email (for sign up)
                    TextField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: isLogin ? 'Email or Username' : 'Email',
                        prefixIcon: const Icon(Icons.email),
                      ),
                      keyboardType: isLogin ? TextInputType.text : TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    
                    // Password
                    TextField(
                      controller: _passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock),
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 24),
                    
                    // Action button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _authenticate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentBlue,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(
                                isLogin ? 'Sign In' : 'Create Account',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Toggle
                    TextButton(
                      onPressed: () {
                        setState(() {
                          isLogin = !isLogin;
                        });
                      },
                      child: Text(
                        isLogin ? 'Don\'t have an account? Sign up' : 'Already have an account? Sign in',
                        style: const TextStyle(color: AppTheme.textMuted),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}