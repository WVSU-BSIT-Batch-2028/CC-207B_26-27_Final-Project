import 'package:flutter/material.dart';

import '../models/food.dart';
import '../services/supabase_service.dart';
import '../services/strapi_service.dart';

class BackendTestScreen extends StatefulWidget {
  const BackendTestScreen({super.key});

  @override
  State<BackendTestScreen> createState() => _BackendTestScreenState();
}

class _BackendTestScreenState extends State<BackendTestScreen> {
  String supabaseStatus = 'Not tested';
  String strapiStatus = 'Not tested';

  bool loadingSupabase = false;
  bool loadingStrapi = false;

  List<Food> foodItems = [];

  Future<void> testSupabase() async {
    setState(() {
      loadingSupabase = true;
      supabaseStatus = 'Connecting...';
    });

    try {
      final connected = await SupabaseService.testConnection();

      setState(() {
        supabaseStatus = connected
            ? 'Connected successfully!'
            : 'Unexpected response';
      });
    } catch (e) {
      setState(() {
        supabaseStatus = 'Connection failed: $e';
      });
    } finally {
      setState(() {
        loadingSupabase = false;
      });
    }
  }

  Future<void> testStrapi() async {
    setState(() {
      loadingStrapi = true;
      strapiStatus = 'Connecting...';
      foodItems = [];
    });

    try {
      final result = await StrapiService.fetchFoodItems();

      setState(() {
        foodItems = result;

        strapiStatus = 'Connected! Found ${result.length} food item(s).';
      });
    } catch (e) {
      setState(() {
        strapiStatus = 'Connection failed: $e';
      });
    } finally {
      setState(() {
        loadingStrapi = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FoodWise Backend Test')),

      body: Padding(
        padding: const EdgeInsets.all(20),

        child: ListView(
          children: [
            const Text(
              'Backend Connections',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 25),

            const Text(
              'Supabase Database',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            FilledButton(
              onPressed: loadingSupabase ? null : testSupabase,
              child: loadingSupabase
                  ? const CircularProgressIndicator()
                  : const Text('Test Supabase'),
            ),

            const SizedBox(height: 10),

            Text(supabaseStatus),

            const Divider(height: 35),

            const Text(
              'Strapi CMS',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            FilledButton(
              onPressed: loadingStrapi ? null : testStrapi,
              child: loadingStrapi
                  ? const CircularProgressIndicator()
                  : const Text('Test Strapi API'),
            ),

            const SizedBox(height: 10),

            Text(strapiStatus),

            const SizedBox(height: 20),

            ...foodItems.map((item) {
  return ListTile(
    leading: const Icon(
      Icons.restaurant,
      color: Color.fromARGB(255, 232, 105, 14),
    ),
    title: Text(item.name),
    subtitle: Text(
      'Price: ₱${item.price.toStringAsFixed(2)}',
    ),
    trailing: Text(
      item.isAvailable ? 'Available' : 'Unavailable',
    ),
  );
}),
          ],
        ),
      ),
    );
  }
}
