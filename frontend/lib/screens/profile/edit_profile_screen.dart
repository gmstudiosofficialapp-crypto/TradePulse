import 'package:flutter/material.dart';

import '../../core/services/app_scope.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../widgets/buttons/primary_button.dart';
import '../../widgets/cards/premium_card.dart';
import '../../widgets/feedback/error_state.dart';
import '../../widgets/forms/app_text_field.dart';
import '../../widgets/layout/atmosphere_background.dart';
import '../../widgets/layout/responsive_body.dart';
import '../../widgets/layout/section_header.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _username;
  late final TextEditingController _phone;
  late final TextEditingController _country;
  late final TextEditingController _division;
  late final TextEditingController _district;
  late final TextEditingController _thana;
  late final TextEditingController _city;
  late final TextEditingController _area;
  late final TextEditingController _address;
  late final TextEditingController _postal;
  DateTime? _dob;
  String _gender = '';
  bool _loading = false;
  String? _error;
  var _seeded = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _username = TextEditingController();
    _phone = TextEditingController();
    _country = TextEditingController();
    _division = TextEditingController();
    _district = TextEditingController();
    _thana = TextEditingController();
    _city = TextEditingController();
    _area = TextEditingController();
    _address = TextEditingController();
    _postal = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    _seeded = true;
    final user = AppScope.auth(context).user;
    _name.text = user?.fullName ?? '';
    _username.text = user?.username ?? '';
    _phone.text = user?.phone ?? '';
    _country.text = user?.country ?? '';
    _division.text = user?.division ?? '';
    _district.text = user?.district ?? '';
    _thana.text = user?.thana ?? '';
    _city.text = user?.city ?? '';
    _area.text = user?.area ?? '';
    _address.text = user?.fullAddress ?? '';
    _postal.text = user?.postalCode ?? '';
    _dob = user?.dateOfBirth;
    _gender = user?.gender ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _phone.dispose();
    _country.dispose();
    _division.dispose();
    _district.dispose();
    _thana.dispose();
    _city.dispose();
    _area.dispose();
    _address.dispose();
    _postal.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await AppScope.auth(context).updateProfile(
        fullName: _name.text,
        username: _username.text.trim(),
        phone: _phone.text.trim(),
        dateOfBirth: _dob,
        clearDateOfBirth: _dob == null,
        gender: _gender,
        country: _country.text.trim(),
        division: _division.text.trim(),
        district: _district.text.trim(),
        thana: _thana.text.trim(),
        city: _city.text.trim(),
        area: _area.text.trim(),
        fullAddress: _address.text.trim(),
        postalCode: _postal.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } on AuthException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tpColors;
    return AtmosphereBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Edit Profile')),
        body: ResponsiveBody(
          maxWidth: 720,
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Only Full Name is required. All other fields are optional.',
                  style: TextStyle(color: colors.mutedText),
                ),
                const SizedBox(height: 16),
                const SectionHeader(title: 'Personal information'),
                const SizedBox(height: 10),
                PremiumCard(
                  child: Column(
                    children: [
                      AppTextField(
                        label: 'Full Name',
                        controller: _name,
                        validator: (value) =>
                            Validators.requiredField(value, 'Full name'),
                      ),
                      const SizedBox(height: 12),
                      AppTextField(label: 'Username (optional)', controller: _username),
                      const SizedBox(height: 12),
                      AppTextField(
                        label: 'Phone number (optional)',
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Date of birth (optional)'),
                        subtitle: Text(
                          _dob == null
                              ? 'Not set'
                              : '${_dob!.year}-${_dob!.month.toString().padLeft(2, '0')}-${_dob!.day.toString().padLeft(2, '0')}',
                        ),
                        trailing: TextButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _dob ?? DateTime(2000, 1, 1),
                              firstDate: DateTime(1920),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) setState(() => _dob = picked);
                          },
                          child: const Text('Choose'),
                        ),
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: _gender,
                        decoration: const InputDecoration(
                          labelText: 'Gender (optional)',
                        ),
                        items: const [
                          DropdownMenuItem(value: '', child: Text('Not set')),
                          DropdownMenuItem(value: 'Female', child: Text('Female')),
                          DropdownMenuItem(value: 'Male', child: Text('Male')),
                          DropdownMenuItem(value: 'Other', child: Text('Other')),
                        ],
                        onChanged: (value) => setState(() => _gender = value ?? ''),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const SectionHeader(title: 'Address'),
                const SizedBox(height: 10),
                PremiumCard(
                  child: Column(
                    children: [
                      AppTextField(label: 'Country (optional)', controller: _country),
                      const SizedBox(height: 12),
                      AppTextField(label: 'Division / State (optional)', controller: _division),
                      const SizedBox(height: 12),
                      AppTextField(label: 'District (optional)', controller: _district),
                      const SizedBox(height: 12),
                      AppTextField(label: 'Thana / Upazila (optional)', controller: _thana),
                      const SizedBox(height: 12),
                      AppTextField(label: 'City (optional)', controller: _city),
                      const SizedBox(height: 12),
                      AppTextField(label: 'Area (optional)', controller: _area),
                      const SizedBox(height: 12),
                      AppTextField(label: 'Full address (optional)', controller: _address),
                      const SizedBox(height: 12),
                      AppTextField(label: 'Postal code (optional)', controller: _postal),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const SectionHeader(title: 'Account / Security / Preferences'),
                const SizedBox(height: 10),
                PremiumCard(
                  child: Text(
                    'Password, theme, and notifications stay in Settings.',
                    style: TextStyle(color: colors.mutedText),
                  ),
                ),
                const SizedBox(height: 16),
                if (_error != null) ...[
                  ErrorState(message: _error!),
                  const SizedBox(height: 12),
                ],
                PrimaryButton(
                  label: 'Save Changes',
                  loading: _loading,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
