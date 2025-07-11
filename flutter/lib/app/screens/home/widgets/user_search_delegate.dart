import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:chat_app/app/models/user_model.dart';

class UserSearchDelegate extends SearchDelegate {
  final List<UserModel> users;
  UserSearchDelegate(this.users);

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) => buildSuggestions(context);

  @override
  Widget buildSuggestions(BuildContext context) {
    final results =
        users
            .where(
              (u) => u.fullName.toLowerCase().contains(query.toLowerCase()),
            )
            .toList();

    if (results.isEmpty) {
      return const Center(child: Text("No users found"));
    }

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final user = results[index];
        return ListTile(
          title: Text(user.fullName),
          subtitle: Text(user.email),
          onTap: () {
            Get.toNamed(
              '/ChatScreen',
              arguments: {'userId': user.id, 'userName': user.fullName},
            );
          },
        );
      },
    );
  }
}
