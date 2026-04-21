![emu-icon](assets/emu-icon.png) 

# User Manual
EMU-Script is a programmable MIDI sequencer and music sheet viewer. It proposes an innovative approach to electronic music creation. I hope you will enjoy using it!


## 1. The User Interface
EMU-Script is a document-based application. Upon starting, you will be prompted to either open an existing EMU script document or to create a new one. 

Here is the main view of the application after the creation of a new document:

![main-view](assets/main-view.png)

The user interface has four distinct parts:
- **The sidebar** (on the left) lists the musical sections and instruments of the composition. At the bottom of the sidebar, you can view information about the composition, the current selection, or error messages.
- **The toolbar** (top right) with a button to toggle between the music sheet and the script editor, a play button, a stop button, and scroll buttons.
- **The music sheet** (on the right), which displays the staffs of the selected musical instruments and musical sections.
- **The script editor** is displayed on the right when the document button is pushed:

![script-editor](assets/script-editor.png)


## 2. The Music Sheet
The music sheet is a visual representation of the composition. From left to right, it displays the measures of the compositions. From top to bottom, it displays the following:
- The measure numbers and section names
- The musical staff of the first instrument and its lyrics (if any).
- The musical staffs of the other instruments.
- The chord progression (if any)

![music-sheet](assets/music-sheet.png)


### 2.1 Diatonic Staffs
A diatonic staff has a range of two octaves (+ 2 whole tones). Here are the notes of the C major scale:

![c-major-scale](assets/c-major-scale.png)

The chromatic notes (sharp notes) have an outlined shape. Here are all the chromatic notes of a 6/8 staff in C major:

![chromatic-notes](assets/chromatic-notes.png)


The color used for the horizontal line of the note is an indicator of the note pitch. The color has a gradient ranging from red (low pitches), orange (mid pitches), and yellow (high pitches). Here is the C major scale of a bass instrument:

![c-major-scale-bass](assets/c-major-scale-bass.png)

### 2.2 Drum Staffs
A drum staff has only one line, and it displays the notes as plain text:

![drum-staff](assets/drum-staff.png)

### 2.3 Notes Durations
The duration of a note is proportional to its length on the staff. The shape of the note's head is also an indicator of its duration. Here is an example showing different note durations (4/4 time signature):

![notes-duration](assets/notes-duration.png)

### 2.4 Intervals and Chords

The notes of an interval or chord are linked using a vertical line, and only the lower note has a horizontal line. Here are some chords in C major:

![chords](assets/chords.png)

## 3. Scripts
TODO