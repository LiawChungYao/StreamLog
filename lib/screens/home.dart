import 'package:flutter/material.dart';
import '../services/app_service.dart';
import '../screens/sheet_main.dart';
import '../screens/login.dart';
import '../util/ui_helper.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}


class _HomeScreenState extends State<HomeScreen> {
  bool isLoading = false;
  List<Map<String, dynamic>> spreadsheets = [];


  @override
  void initState() {
    super.initState();
    initialize();
  }

  Future<void> initialize() async {
      debugPrint('INITIALIZING HOME');

      final loaded = await AppService.instance.loadSpreadsheets();

        if (!mounted) return;

      setState(() {
        spreadsheets = loaded;
      });
      debugPrint(spreadsheets.length.toString());
      debugPrint('SPREADSHEETS LOADED');
    }

  @override
  Widget build(BuildContext context) {
    return Stack(
      
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text("StreamLog"),
          ),

          body: Stack(
            children: [
              Column(

                children: [
                  
                  // Log Out
                  ElevatedButton(
                    onPressed: () async {
                  
                      setState(() {
                        isLoading = true;
                      });

                      await AppService.instance.logout(context);
                      
                      if (!mounted) return;

                      setState(() {
                        isLoading = false;
                      });

                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (_) => const LoginScreen(),
                        ),
                        (route) => false,
                      );
                    },

                  child: 
                    const Text("Log Out")
                ),


                  // Sync files
                  ElevatedButton(
                    onPressed: () async {
                  
                      setState(() {
                        isLoading = true;
                      });

                      await AppService.instance.refreshSpreadsheets();
                      final loaded = await AppService.instance.loadSpreadsheets();
                      
                      if (!mounted) return;

                      setState(() {
                        spreadsheets = loaded;
                        isLoading = false;
                      });

                      debugPrint(spreadsheets.length.toString());
                    },

                  child: 
                    const Text("Sync")
                ),

                  // Add New Spreadsheet
                  ElevatedButton(
                    onPressed: () async {
                      
                      setState(() {
                        isLoading = true;
                      });

                      await AppService.instance.createSpreadsheet();
                      
                      final loaded = await AppService.instance.loadSpreadsheets();

                      if (!mounted) return;

                      UIHelper.showSnackBar(context, "Create New Spreadsheet");

                      setState(() {
                        spreadsheets = loaded;
                        isLoading = false;
                      });
                    },

                    child: const Text(
                      "Create Spreadsheet",
                    ),
                  ),

                  // Import spreadsheet
                  ElevatedButton(
                    onPressed: () async {
                      

                      final input = await UIHelper.showTextInput(
                        context,
                        title: "Add Spreadsheet",
                        labelText: "Spreadsheet link",
                        hintText: "Paste Google Sheets link or ID",
                      );

                      debugPrint(input);

                      if (input == null) return;
                      
                      setState(() {
                        isLoading = true;
                      });
                      await AppService.instance.addSpreadsheet(AppService.instance.extractSpreadsheetId(input), context);
                      final loaded = await AppService.instance.loadSpreadsheets();
                      if (!mounted) return;
                      
                      setState(() {
                        isLoading = false;
                        spreadsheets = loaded;
                      });
                    },

                    child: const Text(
                      "Import Spreadsheet",
                    ),
                  ),

                  // List available spreadsheets to use
                  const Divider(),

                  Expanded(

                    child: ListView.builder(

                      itemCount: spreadsheets.length,

                      itemBuilder: (context, index) {

                        final sheet = spreadsheets[index];

                        return ListTile(

                          title: Text(
                            sheet["title"],
                          ),

                          subtitle: Text(
                            sheet["id"],
                          ),

                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SheetMainScreen(
                                  spreadsheetId: sheet['id'],
                                ),
                              ),
                            );
                          },
                        );

                      },

                    ),

                  ),

                ],
              )
            ]
          )
        ),

        // Loading Section
        if (isLoading)
          Container(
            color: Colors.black54,
            child: const Center(
              child: CircularProgressIndicator(),
          ),
        )
      ]
    );
  }
}