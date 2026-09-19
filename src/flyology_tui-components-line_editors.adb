with Flyology_TUI.Glyphs;

package body Flyology_TUI.Components.Line_Editors is
   use type Flyology_TUI.Events.Terminal_Event_Kind;
   use type Flyology_TUI.Events.Mouse_Action;

   Line_Feed : constant Wide_Wide_Character := Wide_Wide_Character'Val (10);

   --  Reverse-search chrome. These are structural labels rather than caller
   --  policy, so they stay private to this body.
   Search_Open : constant Wide_Wide_String := "(reverse-i-search)`";
   Search_Close : constant Wide_Wide_String := "': ";
   Search_Failed_Open : constant Wide_Wide_String := "(failed search)`";

   --  Persistent non-color cue for a history walk. It replaces the final
   --  gutter cell so the gutter width, and therefore the text geometry,
   --  never changes with the state.
   Recall_Mark : constant Wide_Wide_String := "^";

   function From_Theme
     (Theme : Flyology_TUI.Themes.Theme) return Appearance
   is (Prompt        => Theme.Primary,
       Continuation  => Theme.Muted,
       Recalled      => Theme.Selected,
       Content       => Theme.Input,
       Selection     => Theme.Selected,
       Hint          => Theme.Placeholder,
       Placeholder   => Theme.Placeholder,
       Search_Label  => Theme.Muted,
       Search_Match  => Theme.Selected,
       Search_Failed => Theme.Error,
       Disabled      => Theme.Muted);

   function From_Palette
     (Palette : Flyology_TUI.Themes.Palette) return Appearance
   is (Prompt        => Palette.Title,
       Continuation  => Palette.Muted,
       Recalled      => Palette.Selected,
       Content       => Palette.Input,
       Selection     => Palette.Selected,
       Hint          => Palette.Placeholder,
       Placeholder   => Palette.Placeholder,
       Search_Label  => Palette.Muted,
       Search_Match  => Palette.Selected,
       Search_Failed => Palette.Error,
       Disabled      => Palette.Disabled);

   ---------------------------------------------------------------------
   --  Geometry
   ---------------------------------------------------------------------

   function Prompt_Columns (Item : Model) return Natural
   is (Natural'Max
         (Flyology_TUI.Glyphs.Width_Of
            (Text.To_Wide_Wide_String (Item.Primary)),
          Flyology_TUI.Glyphs.Width_Of
            (Text.To_Wide_Wide_String (Item.Continuation))));

   function Text_Columns (Item : Model) return Natural is
      Gutter : constant Natural := Prompt_Columns (Item);
   begin
      return (if Item.Columns > Gutter then Item.Columns - Gutter else 0);
   end Text_Columns;

   --  Scroll back up when the buffer would otherwise sit below the top of
   --  a viewport that has room for it. Text_Areas only ever scrolls far
   --  enough to reveal the cursor, so a prompt that grows a row keeps the
   --  earlier lines hidden until something moves the cursor back into
   --  them. Clamping only ever reveals more, never less.
   procedure Ensure_Top (Item : in out Model) is
      Lines : constant Positive := Item.Buffer.Line_Count;
      Last_Start : constant Positive :=
        (if Lines > Item.Rows then Lines - Item.Rows + 1 else 1);
   begin
      if Item.Buffer.Viewport_Line > Last_Start then
         Item.Buffer.Set_Viewport (Last_Start, Item.Buffer.Viewport_Cell);
      end if;
   end Ensure_Top;

   --  Give the inner editor exactly Text_Columns of text width. Its own
   --  line-number gutter is never drawn by this component, so the prompt
   --  gutter replaces it cell for cell.
   procedure Sync_Geometry (Item : in out Model) is
      Reserved : constant Positive := Item.Buffer.Gutter_Columns;
   begin
      Item.Buffer.Set_Size (Text_Columns (Item) + Reserved, Item.Rows);
      Ensure_Top (Item);
   end Sync_Geometry;

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
      Placeholder              : Wide_Wide_String := "") return Model is
   begin
      return Result : Model
        (Max_Code_Points,
         Max_Lines,
         Max_Undo_Entries,
         Max_Undo_Code_Points,
         Max_Recalled_Entries,
         Max_Recalled_Code_Points)
      do
         Result.Primary := Text.To_Unbounded_Wide_Wide_String (Primary);
         Result.Continuation :=
           Text.To_Unbounded_Wide_Wide_String (Continuation);
         Result.Separators :=
           Text.To_Unbounded_Wide_Wide_String (Word_Separators);
         Result.Columns := Width;
         Result.Rows := Height;
         Result.Past.Set_Duplicates (Duplicates);
         Result.Blank := Text.To_Unbounded_Wide_Wide_String (Placeholder);
         Sync_Geometry (Result);
      end return;
   end Create;

   procedure Set_Size (Item : in out Model; Width, Height : Positive) is
   begin
      Item.Columns := Width;
      Item.Rows := Height;
      Sync_Geometry (Item);
   end Set_Size;

   function Width (Item : Model) return Positive is (Item.Columns);
   function Height (Item : Model) return Positive is (Item.Rows);

   procedure Set_Wrap
     (Item : in out Model;
      Mode : Flyology_TUI.Components.Text_Areas.Wrap_Mode) is
   begin
      Item.Buffer.Set_Wrap (Mode);
   end Set_Wrap;

   procedure Set_Tab_Width (Item : in out Model; Width : Positive) is
   begin
      Item.Buffer.Set_Tab_Width (Width);
   end Set_Tab_Width;

   procedure Set_Prompt
     (Item         : in out Model;
      Primary      : Wide_Wide_String;
      Continuation : Wide_Wide_String) is
   begin
      Item.Primary := Text.To_Unbounded_Wide_Wide_String (Primary);
      Item.Continuation :=
        Text.To_Unbounded_Wide_Wide_String (Continuation);
      Sync_Geometry (Item);
   end Set_Prompt;

   function Primary_Prompt (Item : Model) return Wide_Wide_String
   is (Text.To_Wide_Wide_String (Item.Primary));

   function Continuation_Prompt (Item : Model) return Wide_Wide_String
   is (Text.To_Wide_Wide_String (Item.Continuation));

   procedure Set_Placeholder
     (Item : in out Model; Placeholder : Wide_Wide_String) is
   begin
      Item.Blank := Text.To_Unbounded_Wide_Wide_String (Placeholder);
   end Set_Placeholder;

   function Placeholder (Item : Model) return Wide_Wide_String
   is (Text.To_Wide_Wide_String (Item.Blank));

   ---------------------------------------------------------------------
   --  Buffer access
   ---------------------------------------------------------------------

   function Value (Item : Model) return Wide_Wide_String
   is (Item.Buffer.Value);

   function Line_Count (Item : Model) return Positive
   is (Item.Buffer.Line_Count);

   function Cursor_Offset (Item : Model) return Natural
   is (Item.Buffer.Cursor_Offset);

   procedure Set_Cursor_Offset (Item : in out Model; Offset : Natural) is
   begin
      Item.Buffer.Set_Cursor_Offset (Offset);
   end Set_Cursor_Offset;

   function Cursor_Position
     (Item : Model) return Flyology_TUI.Components.Text_Areas.Position
   is (Item.Buffer.Cursor_Position);

   function Has_Selection (Item : Model) return Boolean
   is (Item.Buffer.Has_Selection);

   procedure Selection_Range (Item : Model; First, Last : out Natural) is
   begin
      Item.Buffer.Selection_Range (First, Last);
   end Selection_Range;

   procedure Select_All (Item : in out Model) is
   begin
      Item.Buffer.Select_All;
   end Select_All;

   procedure Clear_Selection (Item : in out Model) is
   begin
      Item.Buffer.Clear_Selection;
   end Clear_Selection;

   function Can_Undo (Item : Model) return Boolean is (Item.Buffer.Can_Undo);
   function Can_Redo (Item : Model) return Boolean is (Item.Buffer.Can_Redo);

   procedure Undo (Item : in out Model) is
   begin
      Item.Buffer.Undo;
   end Undo;

   procedure Redo (Item : in out Model) is
   begin
      Item.Buffer.Redo;
   end Redo;

   procedure Focus (Item : in out Model) is
   begin
      Item.Buffer.Focus;
   end Focus;

   procedure Blur (Item : in out Model) is
   begin
      Item.Buffer.Blur;
   end Blur;

   function Focused (Item : Model) return Boolean is (Item.Buffer.Focused);

   procedure Set_Enabled (Item : in out Model; Enabled : Boolean) is
   begin
      Item.Buffer.Set_Enabled (Enabled);
   end Set_Enabled;

   function Is_Enabled (Item : Model) return Boolean
   is (Item.Buffer.Is_Enabled);

   procedure Set_Read_Only (Item : in out Model; Read_Only : Boolean) is
   begin
      Item.Buffer.Set_Read_Only (Read_Only);
   end Set_Read_Only;

   function Is_Read_Only (Item : Model) return Boolean
   is (Item.Buffer.Is_Read_Only);

   function State (Item : Model) return Editor_State
   is (if Item.Hunting then Searching
       elsif Item.Walking then Recalling
       else Editing);

   --  Leave any history walk or search without touching the buffer.
   procedure Settle (Item : in out Model) is
   begin
      if Item.Walking then
         Item.Past.End_Browse;
         Item.Walking := False;
      end if;
      if Item.Hunting then
         Item.Past.End_Search;
         Item.Hunting := False;
      end if;
      Item.Pending := Text.Null_Unbounded_Wide_Wide_String;
   end Settle;

   procedure Try_Set_Value
     (Item    : in out Model;
      Value   : Wide_Wide_String;
      Success : out Boolean) is
   begin
      if Item.Buffer.Is_Read_Only or else not Item.Buffer.Is_Enabled then
         Success := False;
         return;
      end if;
      Settle (Item);
      Item.Buffer.Try_Set_Text (Value, Success);
      if Success then
         Item.Ghost := Text.Null_Unbounded_Wide_Wide_String;
         Item.Last_Kill := No_Kill;
         Ensure_Top (Item);
   end if;
   end Try_Set_Value;

   procedure Clear (Item : in out Model) is
      Success : Boolean;
   begin
      if Item.Buffer.Is_Read_Only or else not Item.Buffer.Is_Enabled then
         return;
      end if;
      Settle (Item);
      Item.Buffer.Try_Set_Text ("", Success);
      Item.Ghost := Text.Null_Unbounded_Wide_Wide_String;
      Item.Last_Kill := No_Kill;
      Ensure_Top (Item);
   end Clear;

   ---------------------------------------------------------------------
   --  Cluster and word boundaries
   ---------------------------------------------------------------------

   function Next_Boundary
     (Content : Wide_Wide_String; Offset : Natural) return Natural is
   begin
      if Offset >= Content'Length then
         return Content'Length;
      end if;
      return Flyology_TUI.Glyphs.Cluster_Last
        (Content, Content'First + Offset) - Content'First + 1;
   end Next_Boundary;

   function Previous_Boundary
     (Content : Wide_Wide_String; Offset : Natural) return Natural
   is
      Position : Natural := 0;
      Earlier  : Natural := 0;
   begin
      while Position < Offset loop
         Earlier := Position;
         declare
            Step : constant Natural := Next_Boundary (Content, Position);
         begin
            exit when Step <= Position;
            Position := Step;
         end;
      end loop;
      return Earlier;
   end Previous_Boundary;

   function Is_Separator
     (Item : Model; Char : Wide_Wide_Character) return Boolean
   is
      Set : constant Wide_Wide_String :=
        Text.To_Wide_Wide_String (Item.Separators);
   begin
      if Char = Line_Feed then
         return True;
      end if;
      for Candidate of Set loop
         if Candidate = Char then
            return True;
         end if;
      end loop;
      return False;
   end Is_Separator;

   --  Start of the word run ending at Offset, skipping separators first so
   --  a cursor sitting just past a word still finds that word.
   function Word_Start
     (Item : Model; Content : Wide_Wide_String; Offset : Natural)
      return Natural
   is
      Position : Natural := Offset;
   begin
      while Position > 0
        and then Is_Separator (Item, Content (Content'First + Position - 1))
      loop
         Position := Position - 1;
      end loop;
      while Position > 0
        and then not Is_Separator
                       (Item, Content (Content'First + Position - 1))
      loop
         Position := Position - 1;
      end loop;
      return Position;
   end Word_Start;

   function Word_End
     (Item : Model; Content : Wide_Wide_String; Offset : Natural)
      return Natural
   is
      Position : Natural := Offset;
   begin
      while Position < Content'Length
        and then Is_Separator (Item, Content (Content'First + Position))
      loop
         Position := Position + 1;
      end loop;
      while Position < Content'Length
        and then not Is_Separator (Item, Content (Content'First + Position))
      loop
         Position := Position + 1;
      end loop;
      return Position;
   end Word_End;

   procedure Completion_Span (Item : Model; First, Last : out Natural) is
      Content : constant Wide_Wide_String := Value (Item);
      Cursor  : constant Natural := Cursor_Offset (Item);
   begin
      Last := Cursor;
      First := Cursor;
      while First > 0
        and then not Is_Separator (Item, Content (Content'First + First - 1))
      loop
         First := First - 1;
      end loop;
   end Completion_Span;

   procedure Apply_Completion
     (Item        : in out Model;
      First, Last : Natural;
      Value       : Wide_Wide_String;
      Success     : out Boolean) is
   begin
      Item.Buffer.Try_Replace_Range (First, Last, Value, Success);
      if Success then
         Item.Ghost := Text.Null_Unbounded_Wide_Wide_String;
         Item.Last_Kill := No_Kill;
      end if;
   end Apply_Completion;

   ---------------------------------------------------------------------
   --  Killing and yanking
   ---------------------------------------------------------------------

   function Kill_Text (Item : Model) return Wide_Wide_String
   is (Text.To_Wide_Wide_String (Item.Killed));

   procedure Set_Kill_Text (Item : in out Model; Value : Wide_Wide_String) is
   begin
      Item.Killed := Text.To_Unbounded_Wide_Wide_String (Value);
      Item.Last_Kill := No_Kill;
   end Set_Kill_Text;

   procedure Kill_Range
     (Item        : in out Model;
      First, Last : Natural;
      Direction   : Kill_Direction;
      Success     : out Boolean)
   is
      Content : constant Wide_Wide_String := Value (Item);
   begin
      Success := False;
      if Last <= First or else Last > Content'Length then
         return;
      end if;
      declare
         Removed : constant Wide_Wide_String :=
           Content (Content'First + First .. Content'First + Last - 1);
      begin
         Item.Buffer.Try_Replace_Range (First, Last, "", Success);
         if not Success then
            return;
         end if;
         if Item.Last_Kill = Direction then
            case Direction is
               when Kill_Forward =>
                  Text.Append (Item.Killed, Removed);
               when Kill_Backward =>
                  Item.Killed :=
                    Text.To_Unbounded_Wide_Wide_String
                      (Removed & Text.To_Wide_Wide_String (Item.Killed));
               when No_Kill =>
                  null;
            end case;
         else
            Item.Killed := Text.To_Unbounded_Wide_Wide_String (Removed);
         end if;
         Item.Last_Kill := Direction;
         Item.Ghost := Text.Null_Unbounded_Wide_Wide_String;
      end;
   end Kill_Range;

   procedure Yank (Item : in out Model; Success : out Boolean) is
      First, Last : Natural;
   begin
      if Text.Length (Item.Killed) = 0 then
         Success := False;
         return;
      end if;
      Item.Buffer.Selection_Range (First, Last);
      Item.Buffer.Try_Replace_Range
        (First, Last, Text.To_Wide_Wide_String (Item.Killed), Success);
      if Success then
         Item.Ghost := Text.Null_Unbounded_Wide_Wide_String;
      end if;
   end Yank;

   ---------------------------------------------------------------------
   --  Submission
   ---------------------------------------------------------------------

   procedure Accept_Submission
     (Item      : in out Model;
      Submitted : out Text.Unbounded_Wide_Wide_String;
      Recorded  : out Histories.Add_Result)
   is
      Content : constant Wide_Wide_String := Value (Item);
      Success : Boolean;
   begin
      Submitted := Text.To_Unbounded_Wide_Wide_String (Content);
      if Item.Buffer.Is_Read_Only or else not Item.Buffer.Is_Enabled then
         --  Retaining an input this model cannot then clear would leave the
         --  same text submitted twice, so refuse before touching history.
         Recorded := Histories.Rejected_Capacity;
         return;
      end if;
      Settle (Item);
      Recorded := Item.Past.Add (Content);
      Item.Buffer.Try_Set_Text ("", Success);
      Item.Ghost := Text.Null_Unbounded_Wide_Wide_String;
      Item.Last_Kill := No_Kill;
   end Accept_Submission;

   procedure Insert_Continuation
     (Item : in out Model; Success : out Boolean)
   is
      First, Last : Natural;
   begin
      Item.Buffer.Selection_Range (First, Last);
      Item.Buffer.Try_Replace_Range
        (First, Last, (1 => Line_Feed), Success);
      if Success then
         Item.Ghost := Text.Null_Unbounded_Wide_Wide_String;
         Item.Last_Kill := No_Kill;
      end if;
   end Insert_Continuation;

   procedure Cancel_Input (Item : in out Model) is
   begin
      Clear (Item);
   end Cancel_Input;

   ---------------------------------------------------------------------
   --  Hinting
   ---------------------------------------------------------------------

   procedure Set_Hint (Item : in out Model; Value : Wide_Wide_String) is
   begin
      Item.Ghost := Text.To_Unbounded_Wide_Wide_String (Value);
   end Set_Hint;

   function Hint (Item : Model) return Wide_Wide_String
   is (Text.To_Wide_Wide_String (Item.Ghost));

   procedure Clear_Hint (Item : in out Model) is
   begin
      Item.Ghost := Text.Null_Unbounded_Wide_Wide_String;
   end Clear_Hint;

   procedure Suggest_From_History (Item : in out Model) is
      Content : constant Wide_Wide_String := Value (Item);
      Found   : constant Wide_Wide_String := Item.Past.Suggestion (Content);
   begin
      if Found'Length > Content'Length
        and then Next_Boundary (Found, Content'Length) > Content'Length
        and then Content'Length
                 = Previous_Boundary (Found, Next_Boundary
                     (Found, Content'Length))
      then
         Item.Ghost :=
           Text.To_Unbounded_Wide_Wide_String
             (Found (Found'First + Content'Length .. Found'Last));
      else
         Item.Ghost := Text.Null_Unbounded_Wide_Wide_String;
      end if;
   end Suggest_From_History;

   procedure Accept_Hint (Item : in out Model; Success : out Boolean) is
      Content : constant Wide_Wide_String := Value (Item);
      Ghost   : constant Wide_Wide_String :=
        Text.To_Wide_Wide_String (Item.Ghost);
   begin
      if Ghost'Length = 0 then
         Success := False;
         return;
      end if;
      Item.Buffer.Try_Replace_Range
        (Content'Length, Content'Length, Ghost, Success);
      if Success then
         Item.Ghost := Text.Null_Unbounded_Wide_Wide_String;
         Item.Last_Kill := No_Kill;
      end if;
   end Accept_Hint;

   ---------------------------------------------------------------------
   --  History
   ---------------------------------------------------------------------

   --  Histories.Add ends any walk, so the editor's own walk state has to be
   --  released with it or Up and Down would both stop responding.
   function Remember
     (Item  : in out Model;
      Value : Wide_Wide_String) return Histories.Add_Result is
   begin
      Settle (Item);
      return Item.Past.Add (Value);
   end Remember;

   function Recorded_Count (Item : Model) return Natural
   is (Item.Past.Length);

   function Recorded_Entry
     (Item : Model; Position : Positive) return Wide_Wide_String
   is (Item.Past.Entry_At (Position));

   procedure Forget_All (Item : in out Model) is
   begin
      Item.Past.Clear;
      Item.Walking := False;
      Item.Hunting := False;
   end Forget_All;

   --  Put the walk's current entry, or the held-aside input, in the buffer.
   --  Loaded is False when the entry does not fit this buffer's bounds, in
   --  which case the buffer keeps its previous contents.
   procedure Load_Walk (Item : in out Model; Loaded : out Boolean) is
   begin
      if Item.Past.At_Live_Entry then
         Item.Buffer.Try_Set_Text
           (Text.To_Wide_Wide_String (Item.Pending), Loaded);
         Item.Past.End_Browse;
         Item.Walking := False;
         Item.Pending := Text.Null_Unbounded_Wide_Wide_String;
      else
         Item.Buffer.Try_Set_Text (Item.Past.Browse_Value, Loaded);
      end if;
      if not Loaded then
         return;
      end if;
      Item.Buffer.Set_Cursor_Offset (Value (Item)'Length);
      Item.Ghost := Text.Null_Unbounded_Wide_Wide_String;
      Item.Last_Kill := No_Kill;
      Ensure_Top (Item);
   end Load_Walk;

   procedure Recall_Older (Item : in out Model; Found : out Boolean) is
   begin
      if Item.Hunting then
         Item.Past.End_Search;
         Item.Hunting := False;
      end if;
      if Item.Buffer.Is_Read_Only or else not Item.Buffer.Is_Enabled then
         Found := False;
         return;
      end if;
      if Item.Walking then
         Item.Past.Browse_Older (Found);
         if Found then
            Load_Walk (Item, Found);
         end if;
         return;
      end if;
      --  Commit the walk only once an older entry exists, so a failed first
      --  recall cannot strand the editor in Recalling with no way back.
      Item.Past.Begin_Browse;
      Item.Past.Browse_Older (Found);
      if not Found then
         Item.Past.End_Browse;
         return;
      end if;
      Item.Pending := Text.To_Unbounded_Wide_Wide_String (Value (Item));
      Item.Walking := True;
      Load_Walk (Item, Found);
      if not Found then
         --  The entry did not fit the buffer; leave the walk unstarted.
         Item.Past.End_Browse;
         Item.Walking := False;
         Item.Pending := Text.Null_Unbounded_Wide_Wide_String;
      end if;
   end Recall_Older;

   procedure Recall_Newer (Item : in out Model; Found : out Boolean) is
   begin
      Found := False;
      if not Item.Walking
        or else Item.Buffer.Is_Read_Only
        or else not Item.Buffer.Is_Enabled
      then
         return;
      end if;
      Item.Past.Browse_Newer (Found);
      if Found then
         Load_Walk (Item, Found);
      end if;
   end Recall_Newer;

   package body History_Stores is

      package Backing is new Histories.Stores
        (Store       => Store,
         Write_Entry => Write_Entry,
         Read_Entry  => Read_Entry);

      procedure Save (Item : Model; Target : in out Store) is
      begin
         Backing.Save (Item.Past, Target);
      end Save;

      procedure Load
        (Item     : in out Model;
         Source   : in out Store;
         Accepted : out Natural;
         Refused  : out Natural) is
      begin
         Settle (Item);
         Backing.Load (Item.Past, Source, Accepted, Refused);
      end Load;

   end History_Stores;

   ---------------------------------------------------------------------
   --  Incremental reverse search
   ---------------------------------------------------------------------

   procedure Begin_Search (Item : in out Model) is
   begin
      if Item.Walking then
         Item.Past.End_Browse;
         Item.Walking := False;
      end if;
      Item.Pending := Text.To_Unbounded_Wide_Wide_String (Value (Item));
      Item.Past.Begin_Search;
      Item.Hunting := True;
      Item.Ghost := Text.Null_Unbounded_Wide_Wide_String;
      Item.Last_Kill := No_Kill;
   end Begin_Search;

   function Search_Query (Item : Model) return Wide_Wide_String
   is (Item.Past.Query);

   function Search_Failing (Item : Model) return Boolean
   is (Item.Hunting
       and then Item.Past.Query'Length > 0
       and then not Item.Past.Has_Match);

   procedure Accept_Search (Item : in out Model) is
      Success : Boolean;
   begin
      if not Item.Hunting then
         return;
      end if;
      if Item.Past.Has_Match then
         if Item.Buffer.Is_Read_Only or else not Item.Buffer.Is_Enabled then
            return;
         end if;
         Item.Buffer.Try_Set_Text (Item.Past.Match_Value, Success);
         if not Success then
            --  The match does not fit this buffer; keep the search open so
            --  the user can pick another entry rather than losing the state.
            return;
         end if;
         Item.Buffer.Set_Cursor_Offset (Value (Item)'Length);
         Item.Ghost := Text.Null_Unbounded_Wide_Wide_String;
         Item.Last_Kill := No_Kill;
      end if;
      Item.Past.End_Search;
      Item.Hunting := False;
      Item.Pending := Text.Null_Unbounded_Wide_Wide_String;
   end Accept_Search;

   procedure End_Search (Item : in out Model) is
   begin
      if not Item.Hunting then
         return;
      end if;
      Item.Past.End_Search;
      Item.Hunting := False;
      Item.Pending := Text.Null_Unbounded_Wide_Wide_String;
   end End_Search;

   ---------------------------------------------------------------------
   --  Cursor projection
   ---------------------------------------------------------------------

   --  Cells occupied by Content between two code-point offsets.
   function Cell_Span
     (Content : Wide_Wide_String; From, To : Natural) return Natural
   is
      Position : Natural := From;
      Total    : Natural := 0;
   begin
      while Position < To loop
         declare
            Step : constant Natural := Next_Boundary (Content, Position);
         begin
            exit when Step <= Position;
            Total := Total +
              Natural'Max
                (1,
                 Flyology_TUI.Glyphs.Width_Of
                   (Content
                      (Content'First + Position
                       .. Content'First + Step - 1)));
            Position := Step;
         end;
      end loop;
      return Total;
   end Cell_Span;

   procedure Locate_Cursor
     (Item   : Model;
      Row    : out Natural;
      Column : out Natural;
      Found  : out Boolean)
   is
      Content : constant Wide_Wide_String := Value (Item);
      Cursor  : constant Natural := Cursor_Offset (Item);
      Gutter  : constant Natural := Prompt_Columns (Item);
      Scroll  : constant Natural := Item.Buffer.Viewport_Cell;
      Line, Next_Line : Positive;
      First, Last, Next_First, Next_Last : Natural;
      Exists, Next_Exists, Claim : Boolean;
      Cells : Natural;
   begin
      Row := 0;
      Column := Gutter;
      Found := False;
      for Visual in 0 .. Item.Rows - 1 loop
         Item.Buffer.Visible_Segment (Visual, Line, First, Last, Exists);
         exit when not Exists;
         if Cursor >= First and then Cursor <= Last then
            Claim := True;
            if Cursor = Last and then Visual + 1 <= Item.Rows - 1 then
               Item.Buffer.Visible_Segment
                 (Visual + 1, Next_Line, Next_First, Next_Last, Next_Exists);
               --  A soft-wrap continuation begins exactly where this
               --  segment ended, and owns the cursor sitting there.
               if Next_Exists and then Next_First = Last then
                  Claim := False;
               end if;
            end if;
            if Claim then
               Cells := Cell_Span (Content, First, Cursor);
               Row := Visual;
               Column :=
                 Gutter + (if Cells > Scroll then Cells - Scroll else 0);
               Found := True;
               return;
            end if;
         end if;
      end loop;
   end Locate_Cursor;

   --  Cells the reverse-search line draws before the insertion point.
   function Search_Cursor_Cells (Item : Model) return Natural is
      Opening : constant Wide_Wide_String :=
        (if Search_Failing (Item) then Search_Failed_Open else Search_Open);
   begin
      return Flyology_TUI.Glyphs.Width_Of (Opening)
        + Flyology_TUI.Glyphs.Width_Of (Item.Past.Query);
   end Search_Cursor_Cells;

   function Cursor_Row (Item : Model) return Natural is
      Row, Column : Natural;
      Found : Boolean;
   begin
      if Item.Hunting then
         --  Render draws only the search line, so the cursor belongs on it.
         return 0;
      end if;
      Locate_Cursor (Item, Row, Column, Found);
      return Row;
   end Cursor_Row;

   function Cursor_Column (Item : Model) return Natural is
      Row, Column : Natural;
      Found : Boolean;
   begin
      if Item.Hunting then
         return Natural'Min
           (Search_Cursor_Cells (Item), Natural'Max (0, Item.Columns - 1));
      end if;
      Locate_Cursor (Item, Row, Column, Found);
      return Natural'Min (Column, Natural'Max (0, Item.Columns - 1));
   end Cursor_Column;

   ---------------------------------------------------------------------
   --  Interaction
   ---------------------------------------------------------------------

   function Control_Letter
     (Event : Flyology_TUI.Events.Terminal_Event) return Wide_Wide_Character
   is
      Value : Wide_Wide_Character := Wide_Wide_Character'Val (0);
   begin
      if Text.Length (Event.Key.Value) = 1 then
         Value := Text.Element (Event.Key.Value, 1);
         if Value in 'A' .. 'Z' then
            Value :=
              Wide_Wide_Character'Val
                (Wide_Wide_Character'Pos (Value) + 32);
         end if;
      end if;
      return Value;
   end Control_Letter;

   procedure Delegate
     (Item   : in out Model;
      Event  : Flyology_TUI.Events.Terminal_Event;
      Result : in out Action_Result) is
   begin
      Result.Update := Item.Buffer.Handle (Event);
   end Delegate;

   --  Extend or shorten the incremental query while searching.
   function Handle_Search
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Terminal_Event) return Action_Result
   is
      Result : Action_Result;
      Query : constant Wide_Wide_String := Item.Past.Query;
      Found : Boolean;
   begin
      Result.Update.Handled := True;
      case Event.Key.Kind is
         when Flyology_TUI.Events.Text_Key =>
            if Event.Key.Modified.Control then
               case Control_Letter (Event) is
                  when 'r' =>
                     Item.Past.Search_Older (Found);
                     Result.Update.Changed := Found;
                  when 's' =>
                     Item.Past.Search_Newer (Found);
                     Result.Update.Changed := Found;
                  when 'g' | 'c' =>
                     End_Search (Item);
                     Result.Update.Changed := True;
                  when others =>
                     Result.Update.Handled := False;
               end case;
            elsif Event.Key.Modified.Super or else Event.Key.Modified.Alt
            then
               Result.Update.Handled := False;
            else
               Item.Past.Set_Query
                 (Query & Text.To_Wide_Wide_String (Event.Key.Value));
               Result.Update.Changed := True;
            end if;
         when Flyology_TUI.Events.Backspace_Key =>
            if Query'Length = 0 then
               End_Search (Item);
            else
               Item.Past.Set_Query
                 (Query
                    (Query'First
                     .. Query'First
                        + Previous_Boundary (Query, Query'Length) - 1));
            end if;
            Result.Update.Changed := True;
         when Flyology_TUI.Events.Enter_Key =>
            Accept_Search (Item);
            Result.Update.Changed := True;
         when Flyology_TUI.Events.Escape_Key =>
            End_Search (Item);
            Result.Update.Changed := True;
         when others =>
            Result.Update.Handled := False;
      end case;
      return Result;
   end Handle_Search;

   function Handle
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Terminal_Event) return Action_Result
   is
      Result : Action_Result;
      Content : constant Wide_Wide_String := Value (Item);
      Cursor : constant Natural := Cursor_Offset (Item);
      Success, Found : Boolean;
      Here : Flyology_TUI.Components.Text_Areas.Position;
      Start, Stop : Natural;
      Killing : Boolean := False;
      --  True while the key being handled is itself a history walk step.
      Stepping : Boolean := False;
   begin
      if not Item.Buffer.Is_Enabled or else not Item.Buffer.Focused then
         return Result;
      end if;

      if Event.Kind = Flyology_TUI.Events.Paste then
         Settle (Item);
         Delegate (Item, Event, Result);
         Item.Ghost := Text.Null_Unbounded_Wide_Wide_String;
         Item.Last_Kill := No_Kill;
         return Result;
      elsif Event.Kind /= Flyology_TUI.Events.Key_Press then
         return Result;
      end if;

      if Item.Hunting then
         return Handle_Search (Item, Event);
      end if;

      Result.Update.Handled := True;
      case Event.Key.Kind is
         when Flyology_TUI.Events.Text_Key =>
            if Event.Key.Modified.Control then
               case Control_Letter (Event) is
                  when 'a' =>
                     Item.Buffer.Set_Cursor_Offset
                       (Item.Buffer.Line_Start_Offset
                          (Item.Buffer.Cursor_Position.Line));
                  when 'e' =>
                     Here := Item.Buffer.Cursor_Position;
                     Item.Buffer.Set_Cursor_Offset
                       (Item.Buffer.Line_End_Offset (Here.Line));
                  when 'b' =>
                     Item.Buffer.Set_Cursor_Offset
                       (Previous_Boundary (Content, Cursor));
                  when 'f' =>
                     if Cursor = Content'Length
                       and then Text.Length (Item.Ghost) > 0
                     then
                        Accept_Hint (Item, Success);
                        Result.Update.Changed := Success;
                     else
                        Item.Buffer.Set_Cursor_Offset
                          (Next_Boundary (Content, Cursor));
                     end if;
                  when 'k' =>
                     Here := Item.Buffer.Cursor_Position;
                     Kill_Range
                       (Item,
                        Cursor,
                        Item.Buffer.Line_End_Offset (Here.Line),
                        Kill_Forward,
                        Success);
                     Result.Update.Changed := Success;
                     Killing := True;
                  when 'u' =>
                     Here := Item.Buffer.Cursor_Position;
                     Kill_Range
                       (Item,
                        Item.Buffer.Line_Start_Offset (Here.Line),
                        Cursor,
                        Kill_Backward,
                        Success);
                     Result.Update.Changed := Success;
                     Killing := True;
                  when 'w' =>
                     Kill_Range
                       (Item,
                        Word_Start (Item, Content, Cursor),
                        Cursor,
                        Kill_Backward,
                        Success);
                     Result.Update.Changed := Success;
                     Killing := True;
                  when 'y' =>
                     Yank (Item, Success);
                     Result.Update.Changed := Success;
                     Result.Update.Rejected := not Success;
                  when 'd' =>
                     if Content'Length = 0 then
                        Result.Action := End_Of_Input;
                     else
                        Stop := Next_Boundary (Content, Cursor);
                        if Stop > Cursor then
                           Item.Buffer.Try_Replace_Range
                             (Cursor, Stop, "", Success);
                           Result.Update.Changed := Success;
                        end if;
                     end if;
                  when 'c' =>
                     Cancel_Input (Item);
                     Result.Update.Changed := True;
                     Result.Action := Cancelled;
                  when 'p' =>
                     Stepping := True;
                     Recall_Older (Item, Found);
                     Result.Update.Changed := Found;
                  when 'n' =>
                     Stepping := True;
                     Recall_Newer (Item, Found);
                     Result.Update.Changed := Found;
                  when 'r' =>
                     Begin_Search (Item);
                     Result.Update.Changed := True;
                  when 't' =>
                     Start := Previous_Boundary (Content, Cursor);
                     if Start > 0 then
                        Stop := Previous_Boundary (Content, Start);
                        Item.Buffer.Try_Replace_Range
                          (Stop,
                           Cursor,
                           Content
                             (Content'First + Start
                              .. Content'First + Cursor - 1)
                           & Content
                             (Content'First + Stop
                              .. Content'First + Start - 1),
                           Success);
                        Result.Update.Changed := Success;
                     end if;
                  when 'o' =>
                     Insert_Continuation (Item, Success);
                     Result.Update.Changed := Success;
                     Result.Update.Rejected := not Success;
                  when 'z' =>
                     if Item.Buffer.Can_Undo then
                        Item.Buffer.Undo;
                        Result.Update.Changed := True;
                     end if;
                  when others =>
                     Result.Update.Handled := False;
               end case;
            elsif Event.Key.Modified.Alt then
               case Control_Letter (Event) is
                  when Wide_Wide_Character'Val (13)
                     | Wide_Wide_Character'Val (10) =>
                     --  A terminal encodes Alt-Enter as ESC CR, which this
                     --  parser reports as an Alt-modified text key rather
                     --  than a modified Enter_Key.
                     Insert_Continuation (Item, Success);
                     Result.Update.Changed := Success;
                     Result.Update.Rejected := not Success;
                  when 'b' =>
                     Item.Buffer.Set_Cursor_Offset
                       (Word_Start (Item, Content, Cursor));
                  when 'f' =>
                     Item.Buffer.Set_Cursor_Offset
                       (Word_End (Item, Content, Cursor));
                  when 'd' =>
                     Kill_Range
                       (Item,
                        Cursor,
                        Word_End (Item, Content, Cursor),
                        Kill_Forward,
                        Success);
                     Result.Update.Changed := Success;
                     Killing := True;
                  when others =>
                     Result.Update.Handled := False;
               end case;
            elsif Event.Key.Modified.Super then
               Result.Update.Handled := False;
            else
               Settle (Item);
               Delegate (Item, Event, Result);
               if Result.Update.Changed then
                  Item.Ghost := Text.Null_Unbounded_Wide_Wide_String;
               end if;
            end if;

         when Flyology_TUI.Events.Enter_Key =>
            --  A terminal running the enhanced keyboard protocol reports a
            --  modified Enter, so Shift-Enter continues the input there.
            --  Without that protocol a modified Enter is indistinguishable
            --  from a bare one, which is why Ctrl-O exists as well.
            if Event.Key.Modified.Shift
              or else Event.Key.Modified.Alt
            then
               Insert_Continuation (Item, Success);
               Result.Update.Changed := Success;
               Result.Update.Rejected := not Success;
            else
               Result.Action := Submit_Requested;
            end if;

         when Flyology_TUI.Events.Tab_Key =>
            Result.Action := Completion_Requested;

         when Flyology_TUI.Events.Escape_Key =>
            if Text.Length (Item.Ghost) > 0 then
               Item.Ghost := Text.Null_Unbounded_Wide_Wide_String;
               Result.Update.Changed := True;
            else
               Result.Update.Handled := False;
            end if;

         when Flyology_TUI.Events.Arrow_Right_Key =>
            if Cursor = Content'Length
              and then Text.Length (Item.Ghost) > 0
              and then not Event.Key.Modified.Shift
            then
               Accept_Hint (Item, Success);
               Result.Update.Changed := Success;
            else
               Delegate (Item, Event, Result);
            end if;

         when Flyology_TUI.Events.Arrow_Up_Key =>
            if Item.Buffer.Cursor_Position.Line = 1 then
               Stepping := True;
               Recall_Older (Item, Found);
               Result.Update.Changed := Found;
            else
               Delegate (Item, Event, Result);
            end if;

         when Flyology_TUI.Events.Arrow_Down_Key =>
            if Item.Buffer.Cursor_Position.Line = Item.Buffer.Line_Count then
               Stepping := True;
               Recall_Newer (Item, Found);
               Result.Update.Changed := Found;
            else
               Delegate (Item, Event, Result);
            end if;

         when others =>
            Delegate (Item, Event, Result);
            if Result.Update.Changed then
               Item.Ghost := Text.Null_Unbounded_Wide_Wide_String;
            end if;
      end case;

      if not Killing then
         Item.Last_Kill := No_Kill;
      end if;
      --  Editing a recalled entry detaches it from the walk, so the held
      --  aside input is released rather than silently overwriting the edit.
      if Result.Update.Changed and then not Stepping and then Item.Walking
      then
         Settle (Item);
      end if;
      Ensure_Top (Item);
      return Result;
   end Handle;

   function Handle
     (Item  : in out Model;
      Event : Flyology_TUI.Mouse.Local_Event) return Action_Result
   is
      Result : Action_Result;
      Gutter : constant Natural := Prompt_Columns (Item);
      Local  : Flyology_TUI.Mouse.Local_Event := Event;
   begin
      if Item.Hunting then
         return Result;
      end if;
      --  The prompt marker is decoration, so a press on it is not a text
      --  position. Swallowing only the press keeps a drag that crosses the
      --  marker, and a captured release outside the component, routed.
      if Event.Action = Flyology_TUI.Events.Mouse_Click
        and then Event.X >= 0
        and then Event.X < Gutter
      then
         return Result;
      end if;
      --  The inner editor still reserves its own gutter, so a click lands
      --  on the same text cell after the prompt gutter is removed.
      Local.X := Event.X - Gutter + Item.Buffer.Gutter_Columns;
      Result.Update := Item.Buffer.Handle (Local);
      --  A pointer move breaks kill adjacency exactly as a cursor key does.
      Item.Last_Kill := No_Kill;
      if Result.Update.Changed then
         Item.Ghost := Text.Null_Unbounded_Wide_Wide_String;
      end if;
      return Result;
   end Handle;

   procedure Update
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Terminal_Event)
   is
      Discard : constant Action_Result := Handle (Item, Event);
      pragma Unreferenced (Discard);
   begin
      null;
   end Update;

   procedure Update
     (Item  : in out Model;
      Event : Flyology_TUI.Mouse.Local_Event)
   is
      Discard : constant Action_Result := Handle (Item, Event);
      pragma Unreferenced (Discard);
   begin
      null;
   end Update;

   ---------------------------------------------------------------------
   --  Rendering
   ---------------------------------------------------------------------

   procedure Render_Search
     (Item   : Model;
      Look   : Appearance;
      Result : in out Flyology_TUI.Surfaces.Surface)
   is
      Failing : constant Boolean := Search_Failing (Item);
      Query : constant Wide_Wide_String := Item.Past.Query;
      Opening : constant Wide_Wide_String :=
        (if Failing then Search_Failed_Open else Search_Open);
      Label : constant Wide_Wide_String := Opening & Query & Search_Close;
      Label_Style : constant Flyology_TUI.Styles.Style :=
        (if Failing then Look.Search_Failed else Look.Search_Label);
      Column : Natural := 0;
      Position : Natural := 0;
   begin
      while Position < Label'Length and then Column < Item.Columns loop
         declare
            Step : constant Natural := Next_Boundary (Label, Position);
            Glyph : constant Wide_Wide_String :=
              Label (Label'First + Position .. Label'First + Step - 1);
         begin
            exit when Step <= Position;
            Result.Put (Column, 0, Glyph, Label_Style);
            Column := Column +
              Natural'Max (1, Flyology_TUI.Glyphs.Width_Of (Glyph));
            Position := Step;
         end;
      end loop;

      if not Item.Past.Has_Match then
         return;
      end if;

      declare
         Matched : constant Wide_Wide_String := Item.Past.Match_Value;
         First, Last : Natural;
      begin
         Item.Past.Match_Range (First, Last);
         Position := 0;
         while Position < Matched'Length and then Column < Item.Columns loop
            declare
               Step : constant Natural := Next_Boundary (Matched, Position);
               Glyph : constant Wide_Wide_String :=
                 Matched
                   (Matched'First + Position .. Matched'First + Step - 1);
               Inside : constant Boolean :=
                 Last > First
                 and then Position >= First
                 and then Position < Last;
            begin
               exit when Step <= Position;
               Result.Put
                 (Column,
                  0,
                  Glyph,
                  (if Inside then Look.Search_Match else Look.Content));
               Column := Column +
                 Natural'Max (1, Flyology_TUI.Glyphs.Width_Of (Glyph));
               Position := Step;
            end;
         end loop;
      end;
   end Render_Search;

   procedure Render_Buffer
     (Item   : Model;
      Look   : Appearance;
      Spans  : Flyology_TUI.Components.Highlights.Span_Array;
      Result : in out Flyology_TUI.Surfaces.Surface)
   is
      Content : constant Wide_Wide_String := Value (Item);
      Gutter : constant Natural := Prompt_Columns (Item);
      Scroll : constant Natural := Item.Buffer.Viewport_Cell;
      Ghost : constant Wide_Wide_String :=
        Text.To_Wide_Wide_String (Item.Ghost);
      Blank : constant Wide_Wide_String :=
        Text.To_Wide_Wide_String (Item.Blank);
      Cursor : constant Natural := Cursor_Offset (Item);
      Base : constant Flyology_TUI.Styles.Style :=
        (if not Item.Buffer.Is_Enabled then Look.Disabled
         else Look.Content);
      Selected : constant Boolean := Item.Buffer.Has_Selection;
      Selection_First, Selection_Last : Natural;
      Line : Positive;
      First, Last : Natural;
      Exists : Boolean;

      --  Draw borrowed presentation text after the buffer text of a row.
      --  A ghost hint or placeholder is a single-row affordance, so drawing
      --  stops at the first line break rather than putting a control
      --  character on the row.
      procedure Write_Trailing
        (Value  : Wide_Wide_String;
         Style  : Flyology_TUI.Styles.Style;
         Row    : Natural;
         Column : in out Natural)
      is
         Offset : Natural := 0;
      begin
         while Offset < Value'Length and then Column < Item.Columns loop
            declare
               Step : constant Natural := Next_Boundary (Value, Offset);
               Glyph : constant Wide_Wide_String :=
                 Value (Value'First + Offset .. Value'First + Step - 1);
            begin
               exit when Step <= Offset;
               exit when Glyph (Glyph'First) = Line_Feed;
               Result.Put (Column, Row, Glyph, Style);
               Column := Column +
                 Natural'Max (1, Flyology_TUI.Glyphs.Width_Of (Glyph));
               Offset := Step;
            end;
         end loop;
      end Write_Trailing;

   begin
      Item.Buffer.Selection_Range (Selection_First, Selection_Last);

      for Row in 0 .. Item.Rows - 1 loop
         Item.Buffer.Visible_Segment (Row, Line, First, Last, Exists);
         exit when not Exists;

         declare
            Leading : constant Boolean := Line = 1 and then First = 0;
            Marker : constant Wide_Wide_String :=
              (if Leading then Primary_Prompt (Item)
               else Continuation_Prompt (Item));
            Marker_Style : constant Flyology_TUI.Styles.Style :=
              (if Leading then Look.Prompt else Look.Continuation);
            Column : Natural := 0;
            Position : Natural := 0;
            Cells : Natural := 0;
         begin
            --  Prompt gutter. Markers narrower than the gutter leave the
            --  remaining cells blank so buffer text stays aligned.
            while Position < Marker'Length and then Column < Gutter loop
               declare
                  Step : constant Natural :=
                    Next_Boundary (Marker, Position);
                  Glyph : constant Wide_Wide_String :=
                    Marker (Marker'First + Position
                            .. Marker'First + Step - 1);
               begin
                  exit when Step <= Position;
                  Result.Put (Column, Row, Glyph, Marker_Style);
                  Column := Column +
                    Natural'Max (1, Flyology_TUI.Glyphs.Width_Of (Glyph));
                  Position := Step;
               end;
            end loop;
            --  A history walk replaces the final gutter cell so the state
            --  is visible without changing the text geometry.
            if Item.Walking and then Leading and then Gutter > 0 then
               Result.Put (Gutter - 1, Row, Recall_Mark, Look.Recalled);
            end if;
            Column := Gutter;
            Position := First;

            --  Buffer text for this visual row.
            while Position < Last and then Column < Item.Columns loop
               declare
                  Step : constant Natural :=
                    Next_Boundary (Content, Position);
                  Glyph : constant Wide_Wide_String :=
                    Content (Content'First + Position
                             .. Content'First + Step - 1);
                  Span : constant Natural :=
                    Natural'Max
                      (1, Flyology_TUI.Glyphs.Width_Of (Glyph));
                  In_Selection : constant Boolean :=
                    Selected
                    and then Position >= Selection_First
                    and then Position < Selection_Last;
                  Style : constant Flyology_TUI.Styles.Style :=
                    (if In_Selection then Look.Selection
                     else Flyology_TUI.Components.Highlights.Style_At
                       (Spans, Position, Base));
               begin
                  exit when Step <= Position;
                  if Cells >= Scroll then
                     if Glyph (Glyph'First) /= Line_Feed then
                        Result.Put (Column, Row, Glyph, Style);
                     end if;
                     Column := Column + Span;
                  end if;
                  Cells := Cells + Span;
                  Position := Step;
               end;
            end loop;

            --  A ghost hint follows the buffer end; an empty buffer shows
            --  the placeholder in its place.
            if Ghost'Length > 0
              and then Last = Content'Length
              and then Cursor = Content'Length
            then
               Write_Trailing (Ghost, Look.Hint, Row, Column);
            elsif Content'Length = 0 and then Blank'Length > 0 then
               Write_Trailing (Blank, Look.Placeholder, Row, Column);
            end if;
         end;
      end loop;
   end Render_Buffer;

   function Render
     (Item  : Model;
      Look  : Appearance;
      Spans : Flyology_TUI.Components.Highlights.Span_Array :=
        Flyology_TUI.Components.Highlights.None)
      return Flyology_TUI.Surfaces.Surface
   is
      Result : Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.Create (Item.Columns, Item.Rows, Look.Content);
   begin
      if Item.Hunting then
         Render_Search (Item, Look, Result);
      else
         Render_Buffer (Item, Look, Spans, Result);
      end if;
      return Result;
   end Render;

   function Render
     (Item  : Model;
      Theme : Flyology_TUI.Themes.Theme;
      Spans : Flyology_TUI.Components.Highlights.Span_Array :=
        Flyology_TUI.Components.Highlights.None)
      return Flyology_TUI.Surfaces.Surface
   is (Render (Item, From_Theme (Theme), Spans));

end Flyology_TUI.Components.Line_Editors;
