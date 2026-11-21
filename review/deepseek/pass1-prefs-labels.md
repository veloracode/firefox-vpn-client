- **File:** `lib/ui/zed/zed_prefs.dart`  
  **Function:** `PixelPrefs.fromJson`  
  **Defect:** The custom color fields and `profileId` are read with unchecked casts instead of the safe helpers used everywhere else.  
  **Failure scenario:** If `app-settings.json` contains a corrupt or legacy value such as `"c_download": 1.5`, `"c_download": "red"`, or `"profile": 123`, the cast throws a `TypeError` while constructing `PixelPrefs`. Since `ZedPrefs.fromJson` constructs both `pixel` and `old` unconditionally, the entire Zed prefs load fails. This contradicts the file comment that every field is independently defaulted and a corrupt value can never break the rest.  
  **Code evidence:**  
  ```dart
  customDownload: j['c_download'] as int?,
  customUpload: j['c_upload'] as int?,
  ...
  profileId: j['profile'] as String? ?? '',
  ```
  Other fields use safe helpers like `_int`, `_bool`, and `_enum`, but these custom fields do not.

TOTAL FINDINGS: 1