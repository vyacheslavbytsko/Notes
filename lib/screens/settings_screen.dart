import 'package:beshence_vault/beshence_vault.dart';
import 'package:flutter/material.dart';

import '../boxes/servers_box_v1.dart';
import '../main.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<StatefulWidget> createState() => _SettingsScreenState();
}


class _SettingsScreenState extends State<SettingsScreen> {
  final addressController = TextEditingController();
  final tokenController = TextEditingController();
  ServerV1? server = serversBox.getServer();

  @override
  void dispose() {
    addressController.dispose();
    tokenController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    addressController.text = server != null ? server!.address : '';
    tokenController.text = server != null ? server!.token : '';

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text("Server settings"),
      ),
      body: Column(
        children: [
          TextField(
            controller: addressController,
            maxLines: 1,
            decoration: InputDecoration(
                hintText: "Address"
            ),
          ),
          TextField(
            controller: tokenController,
            maxLines: 1,
            decoration: InputDecoration(
                hintText: "Token"
            ),
          ),
          MaterialButton(child: Text("Save"), onPressed: () async {
            BeshenceVault vault = BeshenceVault(address: addressController.text, token: tokenController.text);
            BeshenceVaultInfo vaultInfo = await vault.vaultInfo;
            String chainName = await vault.initChain("notes", ignoreAlreadyInitialized: true);

            if(server == null) {
              server = ServerV1(address: addressController.text, token: tokenController.text, order: 0, lastEventId: null);
            } else {
              server!.address = addressController.text;
              server!.token = tokenController.text;
            }

            serversBox.setServer(server!);
          })
        ],
      ),
    );
  }
}