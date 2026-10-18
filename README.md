# StreamLog

A customizable logging app built with Flutter that uses Google Sheets as its data store and Google Drive to manage media files. Create spreadsheets, configure your own columns, and keep track of information through a flexible logging interface.

## Demo
<video src="docs/main_demo.mp4" controls width="600">
  Your browser does not support the video tag.
</video>


## Features

### Google Drive & Google Sheets Integration
- **User-owned data** — Work with spreadsheets and files accessible to your signed-in Google account.
- **Google Sign-In** — Connect your Google account to access your spreadsheets and Drive files.
- **Spreadsheet management** — Create new spreadsheets, import existing spreadsheets using a link or ID, and synchronize your spreadsheet list.
- **Direct Google API integration** — Read and update spreadsheet data using the Google Sheets API, with media files stored in Google Drive.
- **Spreadsheet settings** — View spreadsheet details and rename spreadsheets.


### Configurable Columns

StreamLog uses a column-based architecture, allowing each log to have its own structure instead of relying on a fixed set of fields.

Supported column types include:

| Column type | Description |
|---|---|
| Text | Store general text information. |
| Number | Record numeric values. |
| Timestamp | Record date and time information. |
| Metadata | Configure additional values, including free-text and selection-based inputs. |
| Media | Attach files or URLs to log entries. |

Column configuration supports options such as required fields and type-specific settings. Metadata columns can be configured for free-text, single-select, or multi-select input, with selectable options where applicable.

### Media Support

StreamLog's Media column supports attaching files and linking to existing media.

- **File uploads** — Select files from your device and upload them to Google Drive when the log entry is confirmed.
- **External links** — Attach existing HTTP or HTTPS URLs.

Features of media
- **Image previews** — Display image previews in the app and open larger previews for viewing.
- **Multiple attachments** — Associate multiple files or links with a log entry.
- **Persistent references** — Store media URLs in Google Sheets so they can be retrieved when records are loaded again.
- **Configurable display** — Control whether images are displayed automatically or whether links must be loaded manually.

Google Sheets stores references to media files rather than the underlying binary file contents. The original files remain in Google Drive or at their external URLs.

### Log Management

- Create log entries using the configured column types.
- Edit existing records.
- Validate required fields and column-specific input.
- Load records and column definitions from Google Sheets.
- Keep spreadsheet data and the app's logging interface synchronized.

## How It Works

StreamLog connects Flutter directly to Google's APIs without requiring a separate application backend.

```text
┌──────────────────────┐
│      StreamLog       │
│     Flutter App      │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│    Google Sign-In    │
│   User Authorization │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│    Google APIs       │
├──────────────────────┤
│ Google Sheets API    │──► Schemas & Records
│ Google Drive API     │──► Uploaded Media
└──────────────────────┘
```

### Data Organization

StreamLog uses dedicated worksheets for application data:

- `_schema` — Stores column definitions and configuration.
- `_record` — Stores log records.

These are the default worksheet names. The app uses the schema to determine how records should be displayed and edited.

Media attachments are represented by URLs in the record data, while the corresponding files are stored separately.

## Technology Stack

- **Framework:** Flutter
- **Language:** Dart
- **Authentication:** Google Sign-In
- **Data storage:** Google Sheets API
- **File storage:** Google Drive API
- **Development tools:** Visual Studio Code

## Project Structure

The project separates UI screens, data models, helper services, and reusable utilities.

```text
lib/
├── models/
│   ├── column_type.dart
│   ├── log_column.dart
│   ├── log_schema.dart
│   └── ...
├── screens/
│   ├── home_screen.dart
│   ├── login.dart
│   ├── sheet_main.dart
│   ├── sheet_overview.dart
│   └── ...
├── services/
│   ├── app_service.dart
│   ├── sheets_service.dart
│   ├── schema_service.dart
│   ├── record_service.dart
│   └── ...
└── util/
    ├── ui_helper.dart
    └── ...
```