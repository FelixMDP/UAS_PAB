import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'userprofilescreen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<DocumentSnapshot> _searchResults = [];
  bool _isLoading = false;

  // Custom color palette to match the app theme
  static const Color _background = Color(0xFF293133);
  static const Color _cream = Color(0xFFF1E9D2);
  static const Color _textDark = Color(0xFF293133);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Get all users and filter them locally for case-insensitive search
      final QuerySnapshot result =
          await FirebaseFirestore.instance.collection('users').get();

      final filteredDocs =
          result.docs.where((doc) {
            final fullName =
                (doc.data() as Map<String, dynamic>)['fullName'] as String? ??
                '';
            return fullName.toLowerCase().contains(query.toLowerCase());
          }).toList();

      setState(() {
        _searchResults = filteredDocs;
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error searching users: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: const Text('Search', style: TextStyle(color: _cream)),
        backgroundColor: _background,
        iconTheme: const IconThemeData(color: _cream),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              style: const TextStyle(color: _cream),
              cursorColor: _cream,
              decoration: InputDecoration(
                hintText: 'Search for users...',
                hintStyle: TextStyle(color: _cream.withOpacity(0.5)),
                prefixIcon: const Icon(Icons.search, color: _cream),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: const BorderSide(color: _cream),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: const BorderSide(color: _cream),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: const BorderSide(color: _cream, width: 2),
                ),
                filled: true,
                fillColor: _background,
              ),
              onChanged: _searchUsers,
            ),
            const SizedBox(height: 16),
            Expanded(
              child:
                  _isLoading
                      ? const Center(
                        child: CircularProgressIndicator(color: _cream),
                      )
                      : _searchResults.isEmpty
                      ? Center(
                        child: Text(
                          _searchController.text.isEmpty
                              ? 'Search for users by name'
                              : 'No users found',
                          style: TextStyle(color: _cream.withOpacity(0.7)),
                        ),
                      )
                      : ListView.builder(
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final userData =
                              _searchResults[index].data()
                                  as Map<String, dynamic>;
                          return ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: _cream,
                              child: Icon(Icons.person, color: _textDark),
                            ),
                            title: Text(
                              userData['fullName'] ?? 'Unknown User',
                              style: const TextStyle(
                                color: _cream,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle:
                                userData['bio'] != null &&
                                        userData['bio'].toString().isNotEmpty
                                    ? Text(
                                      userData['bio'],
                                      style: TextStyle(
                                        color: _cream.withOpacity(0.7),
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    )
                                    : null,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => UserProfileScreen(
                                        userId: _searchResults[index].id,
                                      ),
                                ),
                              );
                            },
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
