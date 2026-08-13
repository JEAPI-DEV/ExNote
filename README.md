# ExNote

A note-taking app with a nice way to link exercises with notes, by allowing the user to select a section in a PDF, screenshotting that section automatically and opening a page with the screenshot in the top left corner of the notes page.
Some other features also followed, like folders. A seperate Notes section, allows users to create their own notes without linking them to a PDF file. An AI review functionality was added as well, to allow users to let an AI review their work inside the app, though it requires your own OpenRouter key. Chats are deleted upon exiting the notes page.
There are also a lot of other features including shape snapping, though that feature is still a little bit buggy, grid support, light and dark themes.
The PDF viewer also supports an annotate mode that lets you draw and erase ink directly on the PDF pages (stored per page) without creating a separate note page.
The app also allows the user to export their notes as PDFs or export the whole library of notes and exercises, or import notes.

## Getting Started

Download the source code, compile it and run it. You need flutter :D.

## Folder Structure
```
lib
├── controllers
│   ├── ai_chat_controller.dart
│   ├── drawing
│   │   ├── eraser_handler.dart
│   │   ├── pen_handler.dart
│   │   ├── resize_handler.dart
│   │   ├── selection_handler.dart
│   │   └── shape_snap_handler.dart
│   ├── drawing_canvas_controller.dart
│   ├── note_settings_controller.dart
│   └── pdf_annotation_controller.dart
├── main.dart
├── models
│   ├── canvas_image.dart
│   ├── chat_message.dart
│   ├── drawing_tool.dart
│   ├── exercise_list.dart
│   ├── exercise_list.g.dart
│   ├── folder.dart
│   ├── folder.g.dart
│   ├── grid_type.dart
│   ├── note.dart
│   ├── note.g.dart
│   ├── note_settings.dart
│   ├── pdf_annotation.dart
│   ├── right_drawer_content.dart
│   ├── selection.dart
│   ├── selection.g.dart
│   └── undo_action.dart
├── providers
│   ├── folder_provider.dart
│   └── theme_provider.dart
├── screens
│   ├── exercise_folder_screen.dart
│   ├── folder_screen.dart
│   ├── note_folder_screen.dart
│   ├── note_screen.dart
│   ├── page_selection_screen.dart
│   ├── pdf_viewer_screen.dart
│   └── subject_screen.dart
├── services
│   ├── ai_service.dart
│   ├── backup_service.dart
│   ├── export
│   │   ├── canvas_capture_service.dart
│   │   ├── export_service.dart
│   │   ├── png_export_service.dart
│   │   └── zip_backup_service.dart
│   ├── llm_parser
│   │   ├── latex_block_syntax.dart
│   │   ├── latex_element_builder.dart
│   │   └── latex_inline_syntax.dart
│   ├── note_manager.dart
│   ├── pdf
│   │   ├── a4_note_pdf_renderer.dart
│   │   ├── pdf_note_export_service.dart
│   │   ├── pdf_page_extractor.dart
│   │   └── pdf_screenshot_service.dart
│   ├── settings_service.dart
│   ├── sketch_renderer.dart
│   ├── storage_service.dart
│   └── stylus_shortcut_manager.dart
├── theme
│   └── app_theme.dart
├── utils
│   ├── app_config.dart
│   ├── clipboard_manager.dart
│   ├── context_extensions.dart
│   ├── export_directory.dart
│   ├── folder_colors.dart
│   ├── line_hit_test.dart
│   ├── page_layout.dart
│   ├── pdf_coordinate_mapper.dart
│   ├── pdf_page_geometry.dart
│   ├── pdf_split_calculator.dart
│   ├── shape_recognizer.dart
│   ├── sketch_bounds.dart
│   ├── sketch_serializer.dart
│   ├── theme_extensions.dart
│   └── undo_redo_manager.dart
└── widgets
    ├── ai_chat_drawer.dart
    ├── chat
    │   ├── chat_bubble.dart
    │   ├── chat_header.dart
    │   ├── chat_input_area.dart
    │   └── chat_markdown_style.dart
    ├── color_swatch_button.dart
    ├── dialogs
    │   ├── app_dialogs.dart
    │   ├── create_folder_dialog.dart
    │   └── move_item_dialog.dart
    ├── edit_selection_controls.dart
    ├── fast_drawing_canvas.dart
    ├── fast_sketch_painter.dart
    ├── folder_color_picker.dart
    ├── folder_grid.dart
    ├── grid_painter.dart
    ├── link_overlay_painter.dart
    ├── modals
    │   └── folder_selection_tree.dart
    ├── note_app_bar.dart
    ├── note_canvas.dart
    ├── note_card.dart
    ├── note_toolbar.dart
    ├── pdf_annotation_overlay.dart
    ├── pdf_annotation_painter.dart
    ├── pdf_annotation_toolbar.dart
    ├── selection_overlay.dart
    ├── settings_drawer.dart
    └── zoomable_canvas_wrapper.dart

16 directories, 90 files
```