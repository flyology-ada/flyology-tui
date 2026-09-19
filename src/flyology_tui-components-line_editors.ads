with Ada.Strings.Wide_Wide_Unbounded;
with Flyology_TUI.Components.Highlights;
with Flyology_TUI.Components.Histories;
with Flyology_TUI.Components.Interactions;
with Flyology_TUI.Components.Text_Areas;
with Flyology_TUI.Events;
with Flyology_TUI.Mouse;
with Flyology_TUI.Styles;
with Flyology_TUI.Surfaces;
with Flyology_TUI.Themes;

--  A rich readline: a prompted, optionally multi-line input buffer with
--  command history, inline hinting, incremental reverse search, readline
--  killing and yanking, and a borrowed syntax-highlighting overlay.
--
--  The editor owns text, history, and interaction state. It never decides
--  what completes, whether an input is syntactically finished, or what a
--  submitted line means: it reports those as actions and the application
--  answers them. Editing delegates to Text_Areas, so grapheme clusters,
--  capacity atomicity, and undo behave exactly as they do there.
package Flyology_TUI.Components.Line_Editors is

   --  Local name for the unbounded wide-string type submissions are
   --  reported in.
   package Text renames Ada.Strings.Wide_Wide_Unbounded;

   --  What the editor is doing with the buffer. Every state carries a
   --  persistent cue in the rendered prompt, not only a color.
   --  @enum Editing The ordinary state
   --  @enum Recalling A history walk has replaced the buffer
   --  @enum Searching Keys extend a reverse-search query
   type Editor_State is (Editing, Recalling, Searching);

   --  What the editor is asking the application to decide.
   --  @enum No_Action Nothing is awaited
   --  @enum Submit_Requested Answer with Accept_Submission or
   --     Insert_Continuation, after inspecting Value
   --  @enum Completion_Requested Answer with Apply_Completion, after
   --     computing candidates for Completion_Span
   --  @enum Cancelled The current input was abandoned
   --  @enum End_Of_Input The end-of-input key was pressed when empty
   type Action_Kind is
     (No_Action,
      Submit_Requested,
      Completion_Requested,
      Cancelled,
      End_Of_Input);

   --  What one event did, and what it now asks of the application.
   --  @field Update Whether the event was handled, and what it changed
   --  @field Action The decision the application must answer
   type Action_Result is record
      Update : Flyology_TUI.Components.Interactions.Update_Result;
      Action : Action_Kind := No_Action;
   end record;

   --  Render-time styles.
   --  @field Prompt Style of the marker on the first line
   --  @field Continuation Style of the marker on wrapped and later lines
   --  @field Recalled Style of the gutter while a history walk is active
   --  @field Content Style of ordinary buffer text
   --  @field Selection Style of selected buffer text
   --  @field Hint Style of the ghost suggestion after the cursor
   --  @field Placeholder Style of the placeholder shown when empty
   --  @field Search_Label Style of the reverse-search label
   --  @field Search_Match Style of the query inside the matched entry
   --  @field Search_Failed Style of the label when nothing matches
   --  @field Disabled Style of buffer text while the editor is disabled
   type Appearance is record
      Prompt       : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Continuation : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Recalled     : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Content      : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Selection    : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Hint         : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Placeholder  : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Search_Label : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Search_Match : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Search_Failed : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default;
      Disabled     : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
   end record;

   --  Map the compact semantic theme onto editor styles.
   --  @param Theme Borrowed semantic theme
   --  @return Styles for this component
   function From_Theme
     (Theme : Flyology_TUI.Themes.Theme) return Appearance;

   --  Map the richer semantic palette onto editor styles.
   --  @param Palette Borrowed semantic palette
   --  @return Styles for this component
   function From_Palette
     (Palette : Flyology_TUI.Themes.Palette) return Appearance;

   --  A model owns its buffer, undo history, command history, and kill
   --  buffer. It is limited so nested ownership remains build-in-place.
   --  @field Max_Code_Points Greatest code points the buffer may hold
   --  @field Max_Lines Greatest number of buffer lines
   --  @field Max_Undo_Entries Greatest number of undo steps
   --  @field Max_Undo_Code_Points Greatest code points kept for undo
   --  @field Max_Recalled_Entries Greatest number of history entries
   --  @field Max_Recalled_Code_Points Greatest code points in history
   type Model
     (Max_Code_Points          : Positive;
      Max_Lines                : Positive;
      Max_Undo_Entries         : Positive;
      Max_Undo_Code_Points     : Positive;
      Max_Recalled_Entries     : Positive;
      Max_Recalled_Code_Points : Positive) is tagged limited private;

   --  Prompt markers, word separators, and the duplicate policy carry no
   --  defaults: each is application policy this component cannot derive.
   --  @param Max_Code_Points Greatest code points the buffer may hold
   --  @param Max_Lines Greatest number of buffer lines
   --  @param Max_Undo_Entries Greatest number of undo steps
   --  @param Max_Undo_Code_Points Greatest code points kept for undo
   --  @param Max_Recalled_Entries Greatest number of history entries
   --  @param Max_Recalled_Code_Points Greatest code points in history
   --  @param Width Cells the editor may use horizontally
   --  @param Height Rows the editor may use
   --  @param Primary Marker drawn on the first line
   --  @param Continuation Marker drawn on wrapped and later lines
   --  @param Word_Separators Code points that end a word
   --  @param Duplicates How history treats a repeated submission
   --  @param Placeholder Text drawn after the prompt while empty
   --  @return An empty, unfocused editor
   function Create
     (Max_Code_Points          : Positive;
      Max_Lines                : Positive;
      Max_Undo_Entries         : Positive;
      Max_Undo_Code_Points     : Positive;
      Max_Recalled_Entries     : Positive;
      Max_Recalled_Code_Points : Positive;
      Width                    : Positive;
      Height                   : Positive;
      Primary                  : Wide_Wide_String;
      Continuation             : Wide_Wide_String;
      Word_Separators          : Wide_Wide_String;
      Duplicates               : Histories.Duplicate_Policy;
      Placeholder              : Wide_Wide_String := "") return Model;

   --------------------------------------------------------------------
   --  Buffer
   --------------------------------------------------------------------

   --  Read the whole buffer.
   --  @param Item Editor to inspect
   --  @return The whole buffer, line feeds included
   function Value (Item : Model) return Wide_Wide_String;

   --  Replace the buffer. Like Text_Areas.Try_Set_Text this discards undo
   --  history, so it loads an input rather than editing one. A read-only or
   --  disabled editor refuses.
   --  @param Item Editor to load into
   --  @param Value Text to load
   --  @param Success Whether the buffer took the value
   procedure Try_Set_Value
     (Item    : in out Model;
      Value   : Wide_Wide_String;
      Success : out Boolean);

   --  Empty the buffer, drop the hint, and leave any walk or search.
   --  @param Item Editor to empty
   procedure Clear (Item : in out Model);

   --  Count the buffer lines.
   --  @param Item Editor to measure
   --  @return Number of buffer lines
   function Line_Count (Item : Model) return Positive;

   --  Report where the cursor sits in the buffer.
   --  @param Item Editor to inspect
   --  @return Code-point offset of the cursor
   function Cursor_Offset (Item : Model) return Natural;

   --  Place the cursor, clamped to the buffer.
   --  @param Item Editor to move within
   --  @param Offset Code-point offset to move to
   procedure Set_Cursor_Offset (Item : in out Model; Offset : Natural);

   --  Report the cursor's line, code point, and cell column.
   --  @param Item Editor to inspect
   --  @return Line, code point, and cell column of the cursor
   function Cursor_Position
     (Item : Model) return Flyology_TUI.Components.Text_Areas.Position;

   --  Report whether a selection exists.
   --  @param Item Editor to inspect
   --  @return True when a non-empty selection exists
   function Has_Selection (Item : Model) return Boolean;

   --  Report the selected range, empty when nothing is selected.
   --  @param Item Editor to inspect
   --  @param First Code-point offset the selection starts at
   --  @param Last Code-point offset after the selection
   procedure Selection_Range (Item : Model; First, Last : out Natural);

   --  Select the whole buffer.
   --  @param Item Editor to select within
   procedure Select_All (Item : in out Model);

   --  Drop the selection, leaving the cursor where it is.
   --  @param Item Editor to deselect within
   procedure Clear_Selection (Item : in out Model);

   --  Report whether an edit can be undone.
   --  @param Item Editor to inspect
   --  @return True when an edit can be undone
   function Can_Undo (Item : Model) return Boolean;

   --  Report whether an undone edit can be redone.
   --  @param Item Editor to inspect
   --  @return True when an undone edit can be redone
   function Can_Redo (Item : Model) return Boolean;

   --  Undo the most recent edit.
   --  @param Item Editor to undo within
   procedure Undo (Item : in out Model);

   --  Redo carries no binding: the readline vocabulary this component
   --  implements gives Ctrl-Y to yanking. An application that wants redo
   --  binds this at its own layer.
   --  @param Item Editor to redo within
   procedure Redo (Item : in out Model);

   --------------------------------------------------------------------
   --  Geometry and presentation
   --------------------------------------------------------------------

   --  Change the cells the editor may use.
   --  @param Item Editor to resize
   --  @param Width Cells the editor may use horizontally
   --  @param Height Rows the editor may use
   procedure Set_Size (Item : in out Model; Width, Height : Positive);

   --  Report the cells the editor may use horizontally.
   --  @param Item Editor to inspect
   --  @return Cells the editor may use horizontally
   function Width (Item : Model) return Positive;

   --  Report the rows the editor may use.
   --  @param Item Editor to inspect
   --  @return Rows the editor may use
   function Height (Item : Model) return Positive;

   --  Choose whether long lines wrap or scroll horizontally.
   --  @param Item Editor to reconfigure
   --  @param Mode Wrapping mode to apply
   procedure Set_Wrap
     (Item : in out Model;
      Mode : Flyology_TUI.Components.Text_Areas.Wrap_Mode);

   --  Set the cell width a tab advances to.
   --  @param Item Editor to reconfigure
   --  @param Width Cells between tab stops
   procedure Set_Tab_Width (Item : in out Model; Width : Positive);

   --  Replace both prompt markers. They are padded to a common gutter so
   --  buffer text stays aligned across lines.
   --  @param Item Editor to reconfigure
   --  @param Primary Marker drawn on the first line
   --  @param Continuation Marker drawn on wrapped and later lines
   procedure Set_Prompt
     (Item         : in out Model;
      Primary      : Wide_Wide_String;
      Continuation : Wide_Wide_String);

   --  Read the marker drawn on the first line.
   --  @param Item Editor to inspect
   --  @return Marker drawn on the first line
   function Primary_Prompt (Item : Model) return Wide_Wide_String;

   --  Read the marker drawn on wrapped and later lines.
   --  @param Item Editor to inspect
   --  @return Marker drawn on wrapped and later lines
   function Continuation_Prompt (Item : Model) return Wide_Wide_String;

   --  Presentation metadata drawn after the prompt while the buffer is
   --  empty. It is not editable text and is outside every capacity bound.
   --  @param Item Editor to reconfigure
   --  @param Placeholder Text to draw while the buffer is empty
   procedure Set_Placeholder
     (Item : in out Model; Placeholder : Wide_Wide_String);

   --  Read the text drawn while the buffer is empty.
   --  @param Item Editor to inspect
   --  @return Text drawn while the buffer is empty
   function Placeholder (Item : Model) return Wide_Wide_String;

   --  Measure the prompt gutter.
   --  @param Item Editor to measure
   --  @return Cells reserved for the prompt gutter
   function Prompt_Columns (Item : Model) return Natural;

   --  Measure the cells left for buffer text.
   --  @param Item Editor to measure
   --  @return Cells left for buffer text; zero publishes no text
   function Text_Columns (Item : Model) return Natural;

   --  Report the terminal cursor's row.
   --  @param Item Editor to inspect
   --  @return Row of the terminal cursor inside the rendered surface
   function Cursor_Row (Item : Model) return Natural;

   --  Report the terminal cursor's column.
   --  @param Item Editor to inspect
   --  @return Column of the terminal cursor inside the rendered surface
   function Cursor_Column (Item : Model) return Natural;

   --  Give the editor keyboard focus.
   --  @param Item Editor to focus
   procedure Focus (Item : in out Model);

   --  Take keyboard focus away.
   --  @param Item Editor to blur
   procedure Blur (Item : in out Model);

   --  Report whether the editor holds focus.
   --  @param Item Editor to inspect
   --  @return True while the editor holds focus
   function Focused (Item : Model) return Boolean;

   --  A disabled editor ignores input and renders with Disabled.
   --  @param Item Editor to reconfigure
   --  @param Enabled Whether the editor accepts input
   procedure Set_Enabled (Item : in out Model; Enabled : Boolean);

   --  Report whether the editor accepts input.
   --  @param Item Editor to inspect
   --  @return True while the editor accepts input
   function Is_Enabled (Item : Model) return Boolean;

   --  A read-only editor still moves and searches but refuses mutation.
   --  @param Item Editor to reconfigure
   --  @param Read_Only Whether mutation is refused
   procedure Set_Read_Only (Item : in out Model; Read_Only : Boolean);

   --  Report whether mutation is refused.
   --  @param Item Editor to inspect
   --  @return True while mutation is refused
   function Is_Read_Only (Item : Model) return Boolean;

   --  Report what the editor is doing with the buffer.
   --  @param Item Editor to inspect
   --  @return What the editor is doing with the buffer
   function State (Item : Model) return Editor_State;

   --------------------------------------------------------------------
   --  Submission
   --------------------------------------------------------------------

   --  Retain the buffer as the newest history entry, empty the buffer, and
   --  report the text that was submitted. This is the application's answer
   --  to Submit_Requested when it judges the input complete. A read-only or
   --  disabled editor refuses, reporting Rejected_Capacity, because an
   --  input it cannot then clear would be submitted twice.
   --  @param Item Editor to submit from
   --  @param Submitted Text that was submitted
   --  @param Recorded Whether history retained the submission
   procedure Accept_Submission
     (Item      : in out Model;
      Submitted : out Text.Unbounded_Wide_Wide_String;
      Recorded  : out Histories.Add_Result);

   --  Insert a line feed at the cursor and keep editing the same input.
   --  This is the answer to Submit_Requested when the input is unfinished.
   --  @param Item Editor to continue within
   --  @param Success Whether the line feed fitted the buffer's bounds
   procedure Insert_Continuation
     (Item : in out Model; Success : out Boolean);

   --  Abandon the current input without retaining it in history.
   --  @param Item Editor to abandon within
   procedure Cancel_Input (Item : in out Model);

   --------------------------------------------------------------------
   --  Completion
   --------------------------------------------------------------------

   --  Half-open code-point range of the word ending at the cursor, found
   --  with the configured word separators. An application offers this range
   --  to a Completions model so an accepted candidate replaces exactly the
   --  text the user was typing.
   --  @param Item Editor to inspect
   --  @param First Code-point offset the word starts at
   --  @param Last Code-point offset after the word
   procedure Completion_Span (Item : Model; First, Last : out Natural);

   --  Replace a half-open code-point range with Value as one undoable edit
   --  and place the cursor after it. This is the application's answer to
   --  Completion_Requested.
   --  @param Item Editor to complete within
   --  @param First Code-point offset the replacement starts at
   --  @param Last Code-point offset after the replaced range
   --  @param Value Text to put in that range
   --  @param Success Whether the replacement fitted the buffer's bounds
   procedure Apply_Completion
     (Item        : in out Model;
      First, Last : Natural;
      Value       : Wide_Wide_String;
      Success     : out Boolean);

   --------------------------------------------------------------------
   --  Hinting
   --------------------------------------------------------------------

   --  Ghost text drawn after the buffer. It is the remainder the editor
   --  would append, not the whole suggested line, and it is drawn only
   --  while the cursor sits at the end of the buffer. Any edit clears it.
   --  A hint is a single-row affordance, so only the text before its first
   --  line break is drawn; Accept_Hint still adopts the whole remainder.
   --  @param Item Editor to hint within
   --  @param Value Remainder to draw after the buffer
   procedure Set_Hint (Item : in out Model; Value : Wide_Wide_String);

   --  Read the remainder drawn as ghost text.
   --  @param Item Editor to inspect
   --  @return The remainder currently drawn as ghost text
   function Hint (Item : Model) return Wide_Wide_String;

   --  Drop the ghost text.
   --  @param Item Editor to clear the hint of
   procedure Clear_Hint (Item : in out Model);

   --  Fill the hint from the newest history entry that extends the buffer.
   --  An application calls this after any change it wants hinted.
   --  @param Item Editor to hint within
   procedure Suggest_From_History (Item : in out Model);

   --  Append the hint to the buffer and clear it.
   --  @param Item Editor to accept within
   --  @param Success Whether the hint fitted the buffer's bounds
   procedure Accept_Hint (Item : in out Model; Success : out Boolean);

   --------------------------------------------------------------------
   --  History
   --------------------------------------------------------------------

   --  Retain a value without submitting it, which is how an application
   --  restores a saved history at startup. Any walk in progress ends.
   --  @param Item Editor to remember within
   --  @param Value Text to retain as the newest entry
   --  @return Whether history retained the value
   function Remember
     (Item  : in out Model;
      Value : Wide_Wide_String) return Histories.Add_Result;

   --  Count the retained history entries.
   --  @param Item Editor to measure
   --  @return Number of retained history entries
   function Recorded_Count (Item : Model) return Natural;

   --  Position 1 is the oldest retained entry.
   --  @param Item Editor to inspect
   --  @param Position Oldest-first position of the wanted entry
   --  @return Text retained at that position
   function Recorded_Entry
     (Item : Model; Position : Positive) return Wide_Wide_String
     with Pre => Position <= Recorded_Count (Item);

   --  Discard every retained history entry.
   --  @param Item Editor to forget within
   procedure Forget_All (Item : in out Model);

   --  Walk toward older entries, holding the caller's own input aside
   --  until the walk returns to it. A walk only begins once an older entry
   --  exists, so a failed first recall leaves the editor Editing.
   --  @param Item Editor to walk within
   --  @param Found Whether an older entry was loaded
   procedure Recall_Older (Item : in out Model; Found : out Boolean);

   --  Walk toward newer entries, restoring the held-aside input past the
   --  newest one.
   --  @param Item Editor to walk within
   --  @param Found Whether the walk moved
   procedure Recall_Newer (Item : in out Model; Found : out Boolean);

   --  Persist the editor's history through the same store contract
   --  Histories.Stores defines, so a prompt can pick up where a previous
   --  run left off from a file, a database, or any other caller store.
   --  The editor still performs no I/O; the store does.
   --  @formal Store Caller-owned handle to the backing store
   --  @formal Write_Entry Appends one entry to the store
   --  @formal Read_Entry Yields the next entry from the store
   generic
      type Store (<>) is limited private;
      --  Append one entry. Save calls this once per retained entry,
      --  oldest first.
      --  @param Target Store being written
      --  @param Value Entry text to append
      with procedure Write_Entry
        (Target : in out Store;
         Value  : Wide_Wide_String);
      --  Yield the next entry, oldest first. Load calls this until
      --  Available is False.
      --  @param Source Store being read
      --  @param Value Entry text that was read
      --  @param Available False once the store is exhausted
      with procedure Read_Entry
        (Source    : in out Store;
         Value     : out Text.Unbounded_Wide_Wide_String;
         Available : out Boolean);
   package History_Stores is

      --  Write every retained entry, oldest first.
      --  @param Item Editor whose history is persisted
      --  @param Target Store to write into
      procedure Save (Item : Model; Target : in out Store);

      --  Read entries until the store is exhausted, adding each as the
      --  newest. Any walk in progress ends.
      --  @param Item Editor to restore history into
      --  @param Source Store to read from
      --  @param Accepted Number of entries the history retained
      --  @param Refused Number of entries the history would not retain
      procedure Load
        (Item     : in out Model;
         Source   : in out Store;
         Accepted : out Natural;
         Refused  : out Natural);

   end History_Stores;

   --------------------------------------------------------------------
   --  Incremental reverse search
   --------------------------------------------------------------------

   --  Begin an incremental reverse search, leaving the buffer untouched.
   --  @param Item Editor to search within
   procedure Begin_Search (Item : in out Model);

   --  Read the query the search is narrowing on.
   --  @param Item Editor to inspect
   --  @return The query the search is narrowing on
   function Search_Query (Item : Model) return Wide_Wide_String;

   --  Report whether the query matches nothing.
   --  @param Item Editor to inspect
   --  @return True while a non-empty query matches no retained entry
   function Search_Failing (Item : Model) return Boolean;

   --  Replace the buffer with the current match and leave the search. The
   --  submit key performs this rather than submitting, so a searched entry
   --  is never executed without being seen first. A match the buffer cannot
   --  hold leaves the search open.
   --  @param Item Editor to accept within
   procedure Accept_Search (Item : in out Model);

   --  Leave the search with the buffer unchanged.
   --  @param Item Editor to leave the search in
   procedure End_Search (Item : in out Model);

   --------------------------------------------------------------------
   --  Killing and yanking
   --------------------------------------------------------------------

   --  The most recently killed text. One kill buffer is retained rather
   --  than a ring, so consecutive kills in the same direction accumulate
   --  and a yank restores the whole run. Any other action ends the run.
   --  @param Item Editor to inspect
   --  @return Text the last kill run removed
   function Kill_Text (Item : Model) return Wide_Wide_String;

   --  Replace the kill buffer, ending any kill run.
   --  @param Item Editor to reconfigure
   --  @param Value Text a later yank restores
   procedure Set_Kill_Text (Item : in out Model; Value : Wide_Wide_String);

   --  Insert the kill buffer at the cursor, replacing any selection.
   --  @param Item Editor to yank within
   --  @param Success Whether the kill buffer fitted the buffer's bounds
   procedure Yank (Item : in out Model; Success : out Boolean);

   --------------------------------------------------------------------
   --  Interaction
   --------------------------------------------------------------------

   --  Fixed readline vocabulary, matching the binding style Text_Areas
   --  already uses. Every action is also a public operation, so an
   --  application that wants a different key layer builds one on those.
   --
   --  Editing    text inserts; Backspace and Delete remove one cluster;
   --             Ctrl-D removes one cluster, or reports End_Of_Input on an
   --             empty buffer; Ctrl-T transposes the clusters at the
   --             cursor; Ctrl-Z undoes.
   --  Movement   Left and Right, or Ctrl-B and Ctrl-F, move one cluster;
   --             Alt-B and Alt-F move one word; Home and Ctrl-A, End and
   --             Ctrl-E, reach the ends of the current line; Up and Down
   --             move between buffer lines and recall history at the first
   --             and last line; Ctrl-P and Ctrl-N always recall history.
   --  Killing    Ctrl-K kills to end of line, Ctrl-U to start of line,
   --             Ctrl-W the previous word, Alt-D the next word, and Ctrl-Y
   --             yanks the kill buffer.
   --  History    Ctrl-R starts and advances a reverse search, Ctrl-S
   --             advances it toward the newest entry, Enter accepts the
   --             match, and Escape abandons the search.
   --  Completion Tab reports Completion_Requested. Right or Ctrl-F at the
   --             end of the buffer accepts a shown hint instead of moving.
   --  Submission Enter reports Submit_Requested, Ctrl-O and Shift-Enter
   --             insert a continuation line directly, and Ctrl-C reports
   --             Cancelled.
   --
   --  Shift-Enter only reaches an application when the terminal is running
   --  the enhanced keyboard protocol, which a View requests through
   --  Enhanced_Keyboard; a legacy terminal reports it as a bare carriage
   --  return that cannot be told apart from Enter. Ctrl-O therefore remains
   --  the binding that works everywhere. Alt-Enter is accepted in both
   --  encodings, as a modified Enter and as the Alt-modified carriage
   --  return a legacy terminal sends.
   --  @param Item Editor receiving the key
   --  @param Event Terminal event to interpret
   --  @return What the key did, and what it now asks of the application
   function Handle
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Terminal_Event) return Action_Result;

   --  Mouse coordinates are relative to the surface Render returns, so the
   --  prompt gutter is already accounted for. The prompt marker is
   --  decoration rather than a text position, so a press on it is ignored;
   --  a drag that crosses it, and a captured release outside the component,
   --  are still routed.
   --  @param Item Editor receiving the event
   --  @param Event Component-local mouse event
   --  @return What the event did
   function Handle
     (Item  : in out Model;
      Event : Flyology_TUI.Mouse.Local_Event) return Action_Result;

   --  Apply a key and discard the result.
   --  @param Item Editor receiving the key
   --  @param Event Terminal event to interpret
   procedure Update
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Terminal_Event);

   --  Apply a mouse event and discard the result.
   --  @param Item Editor receiving the event
   --  @param Event Component-local mouse event
   procedure Update
     (Item  : in out Model;
      Event : Flyology_TUI.Mouse.Local_Event);

   --------------------------------------------------------------------
   --  Rendering
   --------------------------------------------------------------------

   --  Draw the prompt with explicit styles. Spans is a borrowed
   --  syntax-highlighting overlay over Value, in the same code-point
   --  offsets Cursor_Offset uses. It is never retained.
   --  @param Item Editor to draw
   --  @param Look Borrowed styles
   --  @param Spans Borrowed highlighting overlay over Value
   --  @return A surface of the editor's published geometry
   function Render
     (Item  : Model;
      Look  : Appearance;
      Spans : Flyology_TUI.Components.Highlights.Span_Array :=
        Flyology_TUI.Components.Highlights.None)
      return Flyology_TUI.Surfaces.Surface;

   --  Draw the prompt with styles derived from a theme.
   --  @param Item Editor to draw
   --  @param Theme Borrowed semantic theme
   --  @param Spans Borrowed highlighting overlay over Value
   --  @return A surface of the editor's published geometry
   function Render
     (Item  : Model;
      Theme : Flyology_TUI.Themes.Theme;
      Spans : Flyology_TUI.Components.Highlights.Span_Array :=
        Flyology_TUI.Components.Highlights.None)
      return Flyology_TUI.Surfaces.Surface;

private
   --  Direction of the most recent kill, so a repeated kill accumulates at
   --  the correct end of the kill buffer.
   type Kill_Direction is (No_Kill, Kill_Forward, Kill_Backward);

   type Model
     (Max_Code_Points          : Positive;
      Max_Lines                : Positive;
      Max_Undo_Entries         : Positive;
      Max_Undo_Code_Points     : Positive;
      Max_Recalled_Entries     : Positive;
      Max_Recalled_Code_Points : Positive) is
   tagged limited record
      Buffer : Flyology_TUI.Components.Text_Areas.Model
        (Max_Code_Points,
         Max_Lines,
         Max_Undo_Entries,
         Max_Undo_Code_Points);
      Past : Histories.Model
        (Max_Recalled_Entries,
         Max_Recalled_Code_Points);
      Primary      : Text.Unbounded_Wide_Wide_String;
      Continuation : Text.Unbounded_Wide_Wide_String;
      Separators   : Text.Unbounded_Wide_Wide_String;
      Blank        : Text.Unbounded_Wide_Wide_String;
      Ghost        : Text.Unbounded_Wide_Wide_String;
      Killed       : Text.Unbounded_Wide_Wide_String;
      Pending      : Text.Unbounded_Wide_Wide_String;
      Last_Kill    : Kill_Direction := No_Kill;
      Columns      : Positive := 1;
      Rows         : Positive := 1;
      Walking      : Boolean := False;
      Hunting      : Boolean := False;
   end record;
end Flyology_TUI.Components.Line_Editors;
