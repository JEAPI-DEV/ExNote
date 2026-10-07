# ExNote

ExNote is a Flutter study app for handwritten lecture notes, linked PDF exercises,
PDF annotations, graphs, and voice notes. It supports Android tablets and styluses.

## Setup

Use Flutter 3.38.5 / Dart 3.10.4 or a compatible newer SDK. Android requires API 28
or newer; compile SDK 36 and Java 21 are used by the current dependencies.

```sh
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
flutter build apk --release --target-platform android-arm64 --split-per-abi
```

Generated JSON serializers are ignored by Git and must be generated after cloning.
The ARM64 APK is written to `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.
The repository currently signs release builds with its debug signing configuration
for personal testing. Use the same signing identity as an existing installation
when updating it.

## Study assistant

Set your OpenRouter token in a note's Settings drawer. Chat uses GPT-6 Luna by
default, with GPT-6.1 Sol and GPT-6 Astra available for more demanding questions.
Obsolete saved model choices migrate to Luna. Requests cap output at 4096 tokens,
use low reasoning effort, and stream replies. See [official OpenAI model guidance](https://developers.openai.com/api/docs/models)
and [current pricing](https://developers.openai.com/api/docs/pricing).

The assistant automatically receives images of the **complete current canvas**,
including off-screen handwriting, imported images, graphs, and the linked exercise.
Unchanged canvas images are cached during the editor session. Extra screenshots
remain available for highlighting an area; “Submit Last Image Only” applies to
those extra screenshots. Current-note dictated text and recording transcripts are
also included. Up to four relevant library references are selected using titles,
recognized text, and topic keywords; stale handwriting transcripts are excluded.
Chat requests send these materials to OpenRouter. Chat history lasts for the
current editor session and survives closing/reopening the drawer.

Use the microphone in chat to dictate a draft, then send it. Enable **Read replies
aloud**, or use a reply's speaker button. This is turn-based voice input with a
retained text conversation. Dictation uses the device's speech recognition service,
which may require a network connection and may stop after silence. Speech output
uses the device's text-to-speech engine.

## Voice notes

The editor's microphone opens Voice notes. Dictate and save searchable text, or
record and play longer audio clips. Audio is saved locally as mono AAC/M4A and
included in ZIP backups. Dictation and recording are separate modes because the
microphone cannot be shared by both capture services.

For searchable transcripts of recordings, use their transcription button or enable
**Transcribe new recordings with AI**. This opt-in uploads audio using the same
OpenRouter key and incurs API charges. It uses `openai/gpt-transcribe`; the dedicated
[speech-to-text endpoint](https://openrouter.ai/docs/guides/overview/multimodal/stt)
streams the audio upload without holding a base64 copy in memory. Generated text
is stored separately from your description, becomes searchable, and is available
to the assistant. Failed transcription preserves the original audio for retry.
Very long recordings can exceed the provider's processing timeout.

## Handwriting index

Open **Search your notes** from the home screen's search icon. **Scan notes with**
selects Local model or OpenRouter. OpenRouter uses your existing AI Settings token;
its separate scan-model picker defaults to GPT-6 Luna. Provider and scan-model
choices do not change the chat model. Cloud scans upload original page images and
return full transcripts, titles, summaries, and keywords. The app adds no scan
spending limit. **Rescan this note** in a result's menu tests one note; **Scan / resume
library** scans the library with the selected backend.

For local scanning, download the
vision-enabled [Gemma3n E2B INT4 `.task` model](https://huggingface.co/google/gemma-3n-E2B-it-litert-preview)
(`gemma-3n-E2B-it-int4.task`), accepting Google's model terms on Hugging Face,
then choose **Import local vision model**. A text-only Gemma model cannot read
handwriting. Model weights are several gigabytes and live in application support
storage, separate from document backups. They must be imported again on a new device.
The Flutter inference package is pinned to a version compatible with this project's
SDK; migrating to its maintained successor also requires upgrading Flutter.

Installation starts a scan of existing standalone and exercise-linked notes.
Local pages are divided into ink sections and resized into square vision inputs;
transcription and title/topic generation run separately. Completed sections are
checkpointed, and the UI shows section progress. Coverage checks flag very short
or illegible outputs for review. Each processed page gets a title, transcript,
summary, and search keywords. These annotations are stored in `note_index/`, preserving note
names and handwritten sources. Search also works with voice text before a vision
model is installed. Local handwriting analysis makes no cloud inference requests.

Scans checkpoint each page, skip unchanged notes, pause when the app is backgrounded
or an editor opens for local scanning, interrupt active local generation, and release inference memory afterward. Cloud scans continue while notes are viewed. **Scan / resume library**
continues interrupted work. Automatic indexing runs while browsing after notes
change. **Rebuild annotations** forces a new scan. Close the note editor before
starting a library scan, including when opening indexing settings from that editor.

The Gemma3n E2B model misreads some handwritten mathematical symbols on the
OnePlus Pad 3 even with GPU/OpenCL acceleration. Local OCR should be treated as an
approximate search aid. The tested GPT-6 Luna scan reads this math sample more
accurately, but all generated formulas still need checking against the source.
Handwritten mathematics can be misrecognized. Inspect extracted text through a
search result's text button and check formulas against the original handwriting.
The assistant always receives current-note images so it can consult the source.
The index currently uses text and keyword matching, rather than embedding search.
Native GPU compatibility and recognition quality require testing on the tablet.

## Persistence and backups

Catalog and canvas decoding run in worker isolates to keep note navigation responsive.
Opening, viewing, scrolling, selecting, or closing an unchanged note preserves its
source file and index. Only changes to ink, images, or canvas objects trigger a save;
undoing back to the saved content does not invalidate it.
Ink is saved after a brief idle period with the pen lifted. Saves are queued and
replace files atomically after flushing, preventing old snapshots from overwriting
new ones. Ink-only autosaves avoid rewriting the whole folder catalog. Load errors
are surfaced and do not replace unreadable notes with empty canvases.

ZIP compression and extraction use file streams in a worker isolate. Existing
backup ZIPs and unfinished writes are excluded. Already compressed assets are
stored without recompression. Export waits for pending writes; exporting from the
editor also saves its current handwriting first. Restoring a backup merges missing
notes and files, preserves existing notes, and rebases PDF, screenshot, and canvas
image paths. Recordings and derived annotations are included in restores.

Run the synthetic backup benchmark, which uses temporary files:

```sh
flutter pub get
/path/to/flutter/bin/cache/dart-sdk/bin/dart run tool/benchmark_backup.dart
```

An initial desktop run with a 16 MiB PDF and eight synthetic notes measured 690 ms
before and 260 ms afterward. The longest UI timer gap fell from 539 ms to 11 ms;
the faster archive was slightly larger. These are host measurements, not tablet
frame-time results. Use a release build when evaluating tablet responsiveness.

## Code ownership

| Area | Responsibility |
| --- | --- |
| `controllers/note_autosave_controller.dart` | Pen-aware save scheduling |
| `services/note_manager.dart` | Editor snapshots and queued persistence |
| `services/storage_service.dart`, `atomic_file_store.dart` | Catalog/note storage and atomic replacement |
| `services/backup/` | ZIP workers, restoration, and imported path rebasing |
| `models/note_document.dart`, `services/notes/` | Complete canvas snapshots and page rendering |
| `services/indexing/` | Source fingerprints, local inference, index storage, and search |
| `controllers/library_index_controller.dart` | Scan lifecycle, progress, pause/resume, and invalidation |
| `services/ai/`, `ai_service.dart` | Note context, streaming transport, and response decoding |
| `controllers/ai_chat_controller.dart` | Request lifecycle, streamed replies, and retry state |
| `services/voice/`, `providers/voice_note_provider.dart` | Recording, playback metadata, transcription, and speech output |
| `widgets/`, `screens/` | Presentation and user interaction |

Tests cover backup round trips and unsafe ZIP paths, preservation during restores,
save ordering, complete multi-page layouts, resumed indexing, stale annotations,
voice persistence and transcription uploads, model migration, and chat streaming.
Microphone permissions, actual speech services, model inference, and GPU behavior
must additionally be checked on Android hardware.
