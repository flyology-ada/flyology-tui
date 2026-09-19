with Ada.Strings.Wide_Wide_Unbounded;
with Ada.Text_IO;
with Flyology_TUI.Components;
with Flyology_TUI.Components.Completions;
with Flyology_TUI.Components.Interactions;
with Flyology_TUI.Components.Highlights;
with Flyology_TUI.Components.Histories;
with Flyology_TUI.Components.Line_Editors;
with Flyology_TUI.Components.Text_Areas;
with Flyology_TUI.Events;
with Flyology_TUI.Input;
with Flyology_TUI.Mouse;
with Flyology_TUI.Styles;
with Flyology_TUI.Surfaces;
with Flyology_TUI.Themes;

procedure Line_Editor_Tests is
   package Text renames Ada.Strings.Wide_Wide_Unbounded;
   package Editors renames Flyology_TUI.Components.Line_Editors;
   package Past renames Flyology_TUI.Components.Histories;
   package Marks renames Flyology_TUI.Components.Highlights;

   use type Flyology_TUI.Styles.Style;
   use type Past.Add_Result;
   use type Editors.Action_Kind;
   use type Editors.Editor_State;
   use type Flyology_TUI.Events.Terminal_Event_Kind;
   use type Flyology_TUI.Events.Key_Kind;

   Line_Feed : constant Wide_Wide_Character := Wide_Wide_Character'Val (10);

   procedure Assert (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         raise Program_Error with Message;
      end if;
   end Assert;

   function Key
     (Kind    : Flyology_TUI.Events.Key_Kind;
      Shift   : Boolean := False;
      Control : Boolean := False;
      Alt     : Boolean := False)
      return Flyology_TUI.Events.Terminal_Event
   is
      Value : Flyology_TUI.Events.Key_Event (Kind);
   begin
      Value.Modified :=
        (Shift => Shift, Control => Control, Alt => Alt, Super => False);
      return Flyology_TUI.Events.Pressed (Value);
   end Key;

   function Character_Key
     (Value   : Wide_Wide_String;
      Control : Boolean := False;
      Alt     : Boolean := False)
      return Flyology_TUI.Events.Terminal_Event is
     (Flyology_TUI.Events.Pressed
        ((Kind     => Flyology_TUI.Events.Text_Key,
          Modified =>
            (Shift => False, Control => Control, Alt => Alt, Super => False),
          Repeated => False,
          Value    => Text.To_Unbounded_Wide_Wide_String (Value))));

   function Cell_Text
     (Item : Flyology_TUI.Surfaces.Surface;
      X, Y : Natural) return Wide_Wide_String
   is (Text.To_Wide_Wide_String (Item.Element (X, Y).Glyph));

   --  Read Count cells of a row as text, which is how the rendered prompt
   --  line is compared against an expected layout. Passing the expected
   --  string's own length keeps each comparison self-checking.
   function Row_Text
     (Item  : Flyology_TUI.Surfaces.Surface;
      Y     : Natural;
      First : Natural;
      Count : Natural) return Wide_Wide_String
   is
      Result : Text.Unbounded_Wide_Wide_String;
   begin
      for X in First .. First + Count - 1 loop
         exit when X >= Item.Width;
         if not Item.Element (X, Y).Continuation then
            Text.Append (Result, Cell_Text (Item, X, Y));
         end if;
      end loop;
      return Text.To_Wide_Wide_String (Result);
   end Row_Text;

   ------------------------------------------------------------------
   --  Highlights
   ------------------------------------------------------------------

   type Token is (Word, Number, Comment);
   type Lexer_State is record
      Inside : Boolean := False;
   end record;

   Initial : constant Lexer_State := (Inside => False);

   type Lexer_Behavior is (Normal, Overlapping, Exploding);
   Behavior : Lexer_Behavior := Normal;

   --  Split a line into runs of digits and runs of anything else. A line
   --  beginning with '#' is one comment token and turns the carried state
   --  on so the following line is a comment too.
   procedure Lex
     (Line        : Wide_Wide_String;
      Initial     : Lexer_State;
      From        : Natural;
      Kind        : out Token;
      First, Last : out Natural;
      Final       : out Lexer_State;
      Has_Token   : out Boolean)
   is
      Position : Natural := From;
   begin
      Final := Initial;
      Kind := Word;
      First := From;
      Last := From;
      Has_Token := False;

      if Behavior = Exploding then
         raise Constraint_Error with "lexer failure";
      end if;

      if Position >= Line'Length then
         return;
      end if;

      if Initial.Inside
        or else (Position = 0
                 and then Line (Line'First) = '#')
      then
         Kind := Comment;
         First := 0;
         Last := Line'Length;
         Final := (Inside => True);
         Has_Token := Position = 0;
         return;
      end if;

      declare
         Digits_Run : constant Boolean :=
           Line (Line'First + Position) in '0' .. '9';
      begin
         while Position < Line'Length
           and then (Line (Line'First + Position) in '0' .. '9')
                    = Digits_Run
         loop
            Position := Position + 1;
         end loop;
         Kind := (if Digits_Run then Number else Word);
         First := (if Behavior = Overlapping and then From > 0
                   then From - 1 else From);
         Last := Position;
         Has_Token := True;
      end;
   end Lex;

   package Scanners is new Marks.Lexers
     (Token_Kind    => Token,
      Lexer_State   => Lexer_State,
      Initial_State => Initial,
      Next_Token    => Lex);

   use type Scanners.Scan_State;

   Number_Style : constant Flyology_TUI.Styles.Style :=
     (Bold => True, others => <>);
   Comment_Style : constant Flyology_TUI.Styles.Style :=
     (Italic => True, others => <>);

   Palette : constant Scanners.Token_Appearance :=
     (Word    => Flyology_TUI.Styles.Default,
      Number  => Number_Style,
      Comment => Comment_Style);

   procedure Test_Highlights is
      Base : constant Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default;
      Left : constant Flyology_TUI.Styles.Style :=
        (Bold => True, others => <>);
      Right : constant Flyology_TUI.Styles.Style :=
        (Underline => True, others => <>);
      Overlapped : constant Marks.Span_Array :=
        ((First => 0, Last => 4, Look => Left),
         (First => 2, Last => 6, Look => Right));
      Spans : Marks.Span_Array (1 .. 8);
      Count : Natural;
      Status : Scanners.Scan_State;
   begin
      Assert
        (Marks.Style_At (Marks.None, 0, Base) = Base,
         "an empty overlay changed the base style");
      Assert
        (Marks.Style_At (Overlapped, 1, Base) = Left,
         "a non-overlapped offset did not take its own span");
      Assert
        (Marks.Style_At (Overlapped, 3, Base) = Right,
         "a later span did not win on overlap");
      Assert
        (Marks.Style_At (Overlapped, 6, Base) = Base,
         "an uncovered offset did not keep the base style");
      Assert
        (not Marks.Is_Ordered (Overlapped),
         "overlapping spans were reported as ordered");
      Assert
        (Marks.Is_Ordered (Marks.None),
         "an empty overlay was not reported as ordered");

      --  The fixture lexer emits one token per run of digits and one per
      --  run of anything else, so "ab 12" is two tokens.
      Behavior := Normal;
      Scanners.Scan ("ab 12", Palette, Spans, Count, Status);
      Assert
        (Status = Scanners.Scan_Complete and then Count = 2,
         "scanning one line did not produce a token per run");
      Assert
        (Spans (1).First = 0 and then Spans (1).Last = 3,
         "the leading word run did not cover its own span");
      Assert
        (Spans (2).First = 3
         and then Spans (2).Last = 5
         and then Spans (2).Look = Number_Style,
         "the digit run did not take the number style");

      --  State carries across the line feed, so the second line stays a
      --  comment without repeating the marker.
      Scanners.Scan
        ("#x" & Line_Feed & "yz", Palette, Spans, Count, Status);
      Assert
        (Status = Scanners.Scan_Complete and then Count = 2,
         "carried lexer state did not produce a token per line");
      Assert
        (Spans (1).Look = Comment_Style
         and then Spans (2).Look = Comment_Style,
         "carried comment state did not style the following line");
      Assert
        (Spans (2).First = 3 and then Spans (2).Last = 5,
         "the second line's span was not rebased onto the whole buffer");

      declare
         Tight : Marks.Span_Array (1 .. 1);
      begin
         Scanners.Scan ("ab 12", Palette, Tight, Count, Status);
         Assert
           (Status = Scanners.Scan_Capacity_Limited and then Count = 1,
            "a full overlay did not report a capacity limit");
      end;

      Behavior := Overlapping;
      Scanners.Scan ("ab 12", Palette, Spans, Count, Status);
      Assert
        (Status = Scanners.Scan_Structure_Invalid,
         "an out-of-order token was not reported as invalid");

      Behavior := Exploding;
      Scanners.Scan ("ab", Palette, Spans, Count, Status);
      Assert
        (Status = Scanners.Scan_Lexer_Failed and then Count = 0,
         "a raising lexer was not contained");
      Behavior := Normal;
   end Test_Highlights;

   ------------------------------------------------------------------
   --  Histories
   ------------------------------------------------------------------

   procedure Test_Histories is
      Item : Past.Model := Past.Create (3, 40, Past.Ignore_Consecutive);
      Found : Boolean;
      First, Last : Natural;
   begin
      Assert (Item.Add ("") = Past.Ignored_Empty, "an empty add was kept");
      Assert (Item.Add ("alpha") = Past.Added, "the first add was refused");
      Assert
        (Item.Add ("alpha") = Past.Ignored_Duplicate,
         "a consecutive duplicate was retained");
      Assert (Item.Add ("beta") = Past.Added, "the second add was refused");
      Assert (Item.Add ("gamma") = Past.Added, "the third add was refused");
      Assert
        (Item.Add ("delta") = Past.Added_After_Eviction,
         "exceeding the entry bound did not evict");
      Assert (Item.Length = 3, "eviction did not hold the entry bound");
      Assert
        (Item.Entry_At (1) = "beta" and then Item.Entry_At (3) = "delta",
         "eviction did not remove the oldest entry");

      declare
         Before : constant Natural := Item.Length;
      begin
         Assert
           (Item.Add ((1 .. 41 => 'x')) = Past.Rejected_Capacity,
            "an oversized entry was accepted");
         Assert
           (Item.Length = Before and then Item.Entry_At (3) = "delta",
            "a rejected add mutated the history");
      end;

      --  Browsing walks newest first and returns to the live entry.
      Item.Begin_Browse;
      Item.Browse_Older (Found);
      Assert
        (Found and then Item.Browse_Value = "delta",
         "browsing did not start at the newest entry");
      Item.Browse_Older (Found);
      Item.Browse_Older (Found);
      Assert
        (Found and then Item.Browse_Value = "beta",
         "browsing did not reach the oldest entry");
      Item.Browse_Older (Found);
      Assert (not Found, "browsing walked past the oldest entry");
      Item.Browse_Newer (Found);
      Item.Browse_Newer (Found);
      Item.Browse_Newer (Found);
      Assert
        (Found and then Item.At_Live_Entry,
         "browsing did not return to the live entry");
      Item.End_Browse;

      --  A prefix restricts the walk.
      Item.Begin_Browse ("d");
      Item.Browse_Older (Found);
      Assert
        (Found and then Item.Browse_Value = "delta",
         "a prefixed walk skipped its only match");
      Item.Browse_Older (Found);
      Assert (not Found, "a prefixed walk matched an unrelated entry");
      Item.End_Browse;

      --  Incremental search narrows as the query grows.
      Item.Begin_Search;
      Item.Set_Query ("a");
      Assert
        (Item.Has_Match and then Item.Match_Value = "delta",
         "searching did not start at the newest match");
      Item.Set_Query ("am");
      Assert
        (Item.Has_Match and then Item.Match_Value = "gamma",
         "a narrowed query did not move to an older match");
      Item.Match_Range (First, Last);
      Assert
        (First = 1 and then Last = 3,
         "the reported match range did not cover the query");
      Item.Set_Query ("zz");
      Assert (not Item.Has_Match, "an unmatched query kept a match");
      Item.End_Search;
      Assert (not Item.Searching, "ending the search left it active");

      Assert
        (Item.Suggestion ("del") = "delta",
         "a prefix suggestion did not find the newest extension");
      Assert
        (Item.Suggestion ("delta") = "",
         "an exact prefix was suggested as its own extension");
      Assert (Item.Suggestion ("") = "", "an empty prefix was suggested");

      --  Earlier duplicates are removed rather than ignored.
      declare
         Erasing : Past.Model := Past.Create (4, 40, Past.Ignore_Earlier);
      begin
         Assert (Erasing.Add ("one") = Past.Added, "add one failed");
         Assert (Erasing.Add ("two") = Past.Added, "add two failed");
         Assert (Erasing.Add ("one") = Past.Added, "re-add one failed");
         Assert
           (Erasing.Length = 2
            and then Erasing.Entry_At (1) = "two"
            and then Erasing.Entry_At (2) = "one",
            "erasing duplicates did not keep only the newest copy");
      end;
   end Test_Histories;

   ------------------------------------------------------------------
   --  Completions
   ------------------------------------------------------------------

   type Candidate_Kind is (Plain, Keyword);

   package Menus is new Flyology_TUI.Components.Completions
     (Category => Candidate_Kind, Capacity => 8);

   use type Menus.Offer_Result;

   Menu_Click : constant Flyology_TUI.Mouse.Local_Event :=
     (X        => 0,
      Y        => 1,
      Button   => Flyology_TUI.Events.Left_Button,
      Action   => Flyology_TUI.Events.Mouse_Click,
      Modified => (others => False),
      Wheel_X  => 0,
      Wheel_Y  => 0);

   procedure Test_Completions is
      Look : Menus.Appearance :=
        Menus.From_Theme (Flyology_TUI.Themes.Charm);
      Item : Menus.Model :=
        Menus.Create (Menus.Tabulated_Grid, 20, 3);
      Values : constant Menus.Candidate_Array :=
        (Menus.Candidate_Of ("print", Detail => "builtin"),
         Menus.Candidate_Of ("printf", Kind => Keyword),
         Menus.Candidate_Of ("println"),
         Menus.Candidate_Of ("prime"));
      Shape : Menus.Presentation;
      Result : Flyology_TUI.Components.Interactions.Update_Result;
   begin
      Assert
        (Item.Offer (Values, 4, 2) = Menus.Rejected_Span,
         "an inverted replacement span was accepted");
      Assert (not Item.Is_Open, "a rejected offer opened the popup");

      Assert
        (Item.Offer (Values, 2, 4) = Menus.Offered,
         "a valid offer was refused");
      Assert
        (Item.Is_Open and then Item.Length = 4 and then Item.Selected_Index = 1,
         "an offer did not open with the first candidate selected");
      Assert
        (Item.Replacement_First = 2 and then Item.Replacement_Last = 4,
         "the replacement span was not retained");
      Assert
        (Item.Common_Prefix = "pri",
         "the longest common prefix was not computed");

      --  A two-cell selection mark, seven display cells and a two-cell
      --  gutter make eleven-cell columns, so twenty cells fit two columns
      --  and four candidates need two rows with no counter.
      Shape := Item.Layout;
      Assert
        (Menus.Columns (Shape) = 2 and then Menus.Content_Rows (Shape) = 2,
         "the tabulated grid did not fill the available width");
      Assert
        (Menus.Visible_Count (Shape) = 4
         and then Menus.Hidden_Count (Shape) = 0
         and then not Menus.Has_Counter_Row (Shape),
         "a grid that fits reported clipped candidates");
      Assert
        (Menus.Position_At_Cell (Shape, 0, 0) = 1
         and then Menus.Position_At_Cell (Shape, 0, 1) = 2
         and then Menus.Position_At_Cell (Shape, 11, 0) = 3,
         "the grid was not filled column-major");
      Assert
        (Menus.Position_At_Cell (Shape, 9, 0) = 0,
         "a click on the inter-column gutter reported a candidate");
      Assert
        (Menus.Position_At_Cell (Shape, 0, 2) = 0,
         "a cell outside the grid reported a candidate");

      --  Selection wraps and a column step moves by whole columns.
      Item.Select_Last;
      Item.Select_Next;
      Assert
        (Item.Selected_Index = 1, "the selection did not wrap forward");
      Item.Select_Previous;
      Assert (Item.Selected_Index = 4, "the selection did not wrap back");
      Item.Select_First;
      Item.Select_Next_Column;
      Assert
        (Item.Selected_Index = 3,
         "a column step did not move a whole column");

      --  A narrow popup clips and reserves the counter row.
      Item.Set_Size (8, 2);
      Shape := Item.Layout;
      Assert
        (Menus.Columns (Shape) = 1
         and then Menus.Content_Rows (Shape) = 1
         and then Menus.Has_Counter_Row (Shape)
         and then Menus.Hidden_Count (Shape) = 3,
         "a clipped grid did not reserve a counter row");
      Assert
        (Menus.Height (Shape) = 2,
         "the counter row was not included in the published height");

      declare
         Frame : constant Flyology_TUI.Surfaces.Surface :=
           Item.Render (Look);
      begin
         Assert
           (Frame.Width = 8 and then Frame.Height = 2,
            "the popup did not render its published geometry");
         Assert
           (Row_Text (Frame, 1, 0, 7) = "+3 more",
            "the counter row did not report the clipped candidates");
      end;

      --  Zero rows publish no geometry at all.
      Item.Set_Size (20, 0);
      Shape := Item.Layout;
      Assert
        (Menus.Height (Shape) = 0
         and then Menus.Visible_Count (Shape) = 0
         and then Menus.Position_At_Cell (Shape, 0, 0) = 0,
         "a zero-height popup published clickable geometry");

      Item.Set_Size (20, 3);
      Assert
        (Item.Offer ((1 .. 0 => Menus.Candidate_Of ("")), 0, 0)
         = Menus.Closed_Empty,
         "an empty offer did not close the popup");
      Assert (not Item.Is_Open, "an empty offer left the popup open");

      --  Escape closes, and a click both selects and activates.
      Assert
        (Item.Offer (Values, 0, 0) = Menus.Offered, "re-offer failed");
      Result := Item.Handle (Menu_Click);
      Assert
        (Result.Handled and then Result.Activated
         and then Item.Selected_Index = 2,
         "a click did not select and activate its candidate");
      Result := Item.Handle (Key (Flyology_TUI.Events.Escape_Key));
      Assert
        (Result.Handled and then not Item.Is_Open,
         "escape did not close the popup");
   end Test_Completions;

   ------------------------------------------------------------------
   --  Line editors
   ------------------------------------------------------------------

   Separators : constant Wide_Wide_String := " " & Line_Feed;

   function New_Editor
     (Width : Positive := 24; Height : Positive := 3) return Editors.Model
   is (Editors.Create
         (Max_Code_Points          => 64,
          Max_Lines                => 8,
          Max_Undo_Entries         => 8,
          Max_Undo_Code_Points     => 256,
          Max_Recalled_Entries     => 8,
          Max_Recalled_Code_Points => 256,
          Width                    => Width,
          Height                   => Height,
          Primary                  => "> ",
          Continuation             => ". ",
          Word_Separators          => Separators,
          Duplicates               => Past.Ignore_Consecutive,
          Placeholder              => "type here"));

   procedure Type_Text (Item : in out Editors.Model; Value : Wide_Wide_String)
   is
      Ignored : Editors.Action_Result;
   begin
      for Char of Value loop
         Ignored := Item.Handle (Character_Key ((1 => Char)));
      end loop;
   end Type_Text;

   procedure Test_Editing_And_Prompt is
      Item : Editors.Model := New_Editor;
      Look : constant Editors.Appearance :=
        Editors.From_Theme (Flyology_TUI.Themes.Charm);
      Result : Editors.Action_Result;
      Success : Boolean;
   begin
      Assert
        (Item.Prompt_Columns = 2 and then Item.Text_Columns = 22,
         "the prompt gutter did not reserve the wider marker");

      --  An unfocused editor ignores input.
      Result := Item.Handle (Character_Key ("x"));
      Assert
        (not Result.Update.Handled and then Item.Value = "",
         "an unfocused editor accepted a key");

      Item.Focus;
      declare
         Frame : constant Flyology_TUI.Surfaces.Surface :=
           Item.Render (Look);
      begin
         Assert
           (Row_Text (Frame, 0, 0, 11) = "> type here",
            "the empty prompt did not draw its placeholder");
      end;

      Type_Text (Item, "echo hi");
      Assert (Item.Value = "echo hi", "typed text did not reach the buffer");

      declare
         Frame : constant Flyology_TUI.Surfaces.Surface :=
           Item.Render (Look);
      begin
         Assert
           (Row_Text (Frame, 0, 0, 9) = "> echo hi",
            "the prompt marker did not precede the buffer text");
         Assert
           (Frame.Element (0, 0).Appearance = Look.Prompt,
            "the prompt marker did not take the prompt style");
         Assert
           (Item.Cursor_Row = 0 and then Item.Cursor_Column = 9,
            "the cursor was not projected past the prompt gutter");
      end;

      --  Ctrl-A and Ctrl-E reach the ends of the line.
      Result := Item.Handle (Character_Key ("a", Control => True));
      Assert
        (Item.Cursor_Offset = 0, "Ctrl-A did not reach the line start");
      Result := Item.Handle (Character_Key ("e", Control => True));
      Assert
        (Item.Cursor_Offset = 7, "Ctrl-E did not reach the line end");

      --  Word movement honors the configured separators.
      Result := Item.Handle (Character_Key ("b", Alt => True));
      Assert
        (Item.Cursor_Offset = 5, "Alt-B did not move one word back");

      --  Transposition swaps the two clusters before the cursor.
      Item.Set_Cursor_Offset (4);
      Result := Item.Handle (Character_Key ("t", Control => True));
      Assert
        (Item.Value = "ecoh hi",
         "Ctrl-T did not transpose the clusters at the cursor");
      Result := Item.Handle (Character_Key ("z", Control => True));
      Assert (Item.Value = "echo hi", "Ctrl-Z did not undo the transposition");

      --  A submit key reports intent rather than acting on its own.
      Result := Item.Handle (Key (Flyology_TUI.Events.Enter_Key));
      Assert
        (Result.Action = Editors.Submit_Requested
         and then Item.Value = "echo hi",
         "the submit key changed the buffer instead of reporting intent");

      --  The application answers with a continuation line.
      Item.Insert_Continuation (Success);
      Assert
        (Success and then Item.Line_Count = 2,
         "a continuation did not open a second line");
      Type_Text (Item, "there");
      declare
         Frame : constant Flyology_TUI.Surfaces.Surface :=
           Item.Render (Look);
      begin
         Assert
           (Row_Text (Frame, 1, 0, 7) = ". there",
            "the second line did not draw the continuation marker");
         Assert
           (Frame.Element (0, 1).Appearance = Look.Continuation,
            "the continuation marker did not take its own style");
      end;

      --  Ctrl-O inserts a continuation without asking the application.
      Result := Item.Handle (Character_Key ("o", Control => True));
      Assert
        (Result.Action = Editors.No_Action and then Item.Line_Count = 3,
         "Ctrl-O did not insert a continuation line directly");

      --  A terminal running the enhanced keyboard protocol can report a
      --  modified Enter, which continues instead of submitting.
      Result := Item.Handle
        (Key (Flyology_TUI.Events.Enter_Key, Shift => True));
      Assert
        (Result.Action = Editors.No_Action and then Item.Line_Count = 4,
         "Shift-Enter did not insert a continuation line");

      --  A bare Enter still submits, which is what a legacy terminal sends
      --  for every form of Enter.
      Result := Item.Handle (Key (Flyology_TUI.Events.Enter_Key));
      Assert
        (Result.Action = Editors.Submit_Requested
         and then Item.Line_Count = 4,
         "a bare Enter did not report a submission");
   end Test_Editing_And_Prompt;

   procedure Test_Killing_And_Yanking is
      Item : Editors.Model := New_Editor;
      Result : Editors.Action_Result;
      Success : Boolean;
   begin
      Item.Focus;
      Type_Text (Item, "one two three");

      --  Ctrl-W kills the previous word, and consecutive kills accumulate
      --  at the leading end of the kill buffer.
      Result := Item.Handle (Character_Key ("w", Control => True));
      Assert
        (Item.Value = "one two " and then Item.Kill_Text = "three",
         "Ctrl-W did not kill the previous word");
      Result := Item.Handle (Character_Key ("w", Control => True));
      Assert
        (Item.Value = "one " and then Item.Kill_Text = "two three",
         "consecutive backward kills did not accumulate in order");

      --  Any other action ends the run, so the next kill starts fresh.
      Result := Item.Handle (Key (Flyology_TUI.Events.Arrow_Left_Key));
      Result := Item.Handle (Character_Key ("u", Control => True));
      Assert
        (Item.Kill_Text = "one",
         "a kill after an intervening action still accumulated");

      Item.Set_Cursor_Offset (0);
      Item.Yank (Success);
      Assert
        (Success and then Item.Value = "one ",
         "yanking did not restore the killed text");

      --  Ctrl-K kills to the end of the line.
      Item.Set_Cursor_Offset (3);
      Result := Item.Handle (Character_Key ("k", Control => True));
      Assert
        (Item.Value = "one" and then Item.Kill_Text = " ",
         "Ctrl-K did not kill to the end of the line");
   end Test_Killing_And_Yanking;

   procedure Test_History_And_Hinting is
      Item : Editors.Model := New_Editor;
      Look : constant Editors.Appearance :=
        Editors.From_Theme (Flyology_TUI.Themes.Charm);
      Result : Editors.Action_Result;
      Submitted : Text.Unbounded_Wide_Wide_String;
      Recorded : Past.Add_Result;
      Found, Success : Boolean;
   begin
      Item.Focus;
      Type_Text (Item, "list files");
      Item.Accept_Submission (Submitted, Recorded);
      Assert
        (Text.To_Wide_Wide_String (Submitted) = "list files"
         and then Recorded = Past.Added
         and then Item.Value = "",
         "accepting a submission did not retain and clear the input");
      Assert
        (Item.Recorded_Count = 1 and then Item.Recorded_Entry (1)
         = "list files",
         "the submitted input did not reach the history");

      Type_Text (Item, "show status");
      Item.Accept_Submission (Submitted, Recorded);

      --  An Up arrow on the first line recalls, holding the live input.
      Type_Text (Item, "draft");
      Result := Item.Handle (Key (Flyology_TUI.Events.Arrow_Up_Key));
      Assert
        (Item.Value = "show status" and then Item.State = Editors.Recalling,
         "the first recall did not load the newest entry");
      Result := Item.Handle (Key (Flyology_TUI.Events.Arrow_Up_Key));
      Assert
        (Item.Value = "list files", "the second recall did not step older");
      Result := Item.Handle (Key (Flyology_TUI.Events.Arrow_Down_Key));
      Result := Item.Handle (Key (Flyology_TUI.Events.Arrow_Down_Key));
      Assert
        (Item.Value = "draft" and then Item.State = Editors.Editing,
         "returning past the newest entry did not restore the live input");

      --  Hinting completes from the history as ghost text.
      Item.Clear;
      Type_Text (Item, "li");
      Item.Suggest_From_History;
      Assert
        (Item.Hint = "st files", "the hint did not extend the typed prefix");
      declare
         Frame : constant Flyology_TUI.Surfaces.Surface :=
           Item.Render (Look);
      begin
         Assert
           (Row_Text (Frame, 0, 0, 12) = "> list files",
            "the ghost hint was not drawn after the buffer");
         Assert
           (Frame.Element (4, 0).Appearance = Look.Hint,
            "the ghost hint did not take the hint style");
         Assert
           (Frame.Element (2, 0).Appearance /= Look.Hint,
            "typed text was drawn as a hint");
      end;

      Result := Item.Handle (Key (Flyology_TUI.Events.Arrow_Right_Key));
      Assert
        (Item.Value = "list files" and then Item.Hint = "",
         "the right arrow did not accept the shown hint");

      --  A hint carrying a line break is drawn only up to that break, so a
      --  multi-line suggestion never puts a control character on the row.
      Item.Clear;
      Type_Text (Item, "ab");
      Item.Set_Hint ("cd" & Line_Feed & "ef");
      declare
         Frame : constant Flyology_TUI.Surfaces.Surface :=
           Item.Render (Look);
      begin
         Assert
           (Row_Text (Frame, 0, 0, 7) = "> abcd ",
            "a hint with a line break was not cut at the break");
      end;
      Item.Accept_Hint (Success);
      Assert
        (Success and then Item.Line_Count = 2
         and then Item.Value = "abcd" & Line_Feed & "ef",
         "accepting a cut hint did not adopt the whole remainder");

      --  Reverse search narrows without touching the buffer until accepted.
      Item.Clear;
      Type_Text (Item, "keep");
      Result := Item.Handle (Character_Key ("r", Control => True));
      Assert
        (Item.State = Editors.Searching and then Item.Value = "keep",
         "starting a search disturbed the buffer");
      Type_Text (Item, "stat");
      Assert
        (Item.Search_Query = "stat" and then not Item.Search_Failing,
         "the search query did not narrow onto a match");
      declare
         Frame : constant Flyology_TUI.Surfaces.Surface :=
           Item.Render (Look);
      begin
         Assert
           (Row_Text (Frame, 0, 0, 18) = "(reverse-i-search)",
            "the search line did not draw its label");
      end;
      Result := Item.Handle (Key (Flyology_TUI.Events.Enter_Key));
      Assert
        (Item.Value = "show status" and then Item.State = Editors.Editing
         and then Result.Action = Editors.No_Action,
         "accepting a search did not load the match without submitting");

      --  A failing query is reported rather than silently ignored.
      Item.Clear;
      Result := Item.Handle (Character_Key ("r", Control => True));
      Type_Text (Item, "zzz");
      Assert (Item.Search_Failing, "an unmatched query was not reported");
      Result := Item.Handle (Key (Flyology_TUI.Events.Escape_Key));
      Assert
        (Item.State = Editors.Editing,
         "escape did not leave the search");

      --  Loading a saved history uses the same bound as submission.
      Item.Forget_All;
      Assert (Item.Recorded_Count = 0, "forgetting did not empty history");
      Assert
        (Item.Remember ("restored") = Past.Added,
         "a restored entry was refused");
      Item.Suggest_From_History;
      Item.Clear;
      Type_Text (Item, "res");
      Item.Suggest_From_History;
      Assert
        (Item.Hint = "tored", "a restored entry did not become a hint");
      Item.Accept_Hint (Success);
      Assert
        (Success and then Item.Value = "restored",
         "accepting the hint did not adopt it");
   end Test_History_And_Hinting;

   procedure Test_Completion_And_Highlighting is
      Item : Editors.Model := New_Editor;
      Look : constant Editors.Appearance :=
        Editors.From_Theme (Flyology_TUI.Themes.Charm);
      Result : Editors.Action_Result;
      Spans : Marks.Span_Array (1 .. 8);
      Count : Natural;
      Status : Scanners.Scan_State;
      First, Last : Natural;
      Success : Boolean;
   begin
      Item.Focus;
      Type_Text (Item, "git pu");

      --  The completion key reports intent and names the span to replace.
      Result := Item.Handle (Key (Flyology_TUI.Events.Tab_Key));
      Assert
        (Result.Action = Editors.Completion_Requested,
         "the completion key did not report intent");
      Item.Completion_Span (First, Last);
      Assert
        (First = 4 and then Last = 6,
         "the completion span did not cover the word at the cursor");

      Item.Apply_Completion (First, Last, "push", Success);
      Assert
        (Success and then Item.Value = "git push"
         and then Item.Cursor_Offset = 8,
         "applying a completion did not replace the span");
      Assert
        (Item.Can_Undo, "applying a completion discarded undo history");

      --  A borrowed overlay styles the rendered buffer without being kept.
      Behavior := Normal;
      Scanners.Scan (Item.Value, Palette, Spans, Count, Status);
      Assert (Status = Scanners.Scan_Complete, "scanning the buffer failed");

      Item.Clear;
      Type_Text (Item, "add 42");
      Scanners.Scan (Item.Value, Palette, Spans, Count, Status);
      declare
         Frame : constant Flyology_TUI.Surfaces.Surface :=
           Item.Render (Look, Spans (1 .. Count));
         Plain : constant Flyology_TUI.Surfaces.Surface :=
           Item.Render (Look);
      begin
         --  "add 42" sits two cells past the prompt gutter, so the digits
         --  begin at column six.
         Assert
           (Frame.Element (6, 0).Appearance = Number_Style,
            "the highlight overlay did not style the digit run");
         Assert
           (Frame.Element (2, 0).Appearance /= Number_Style,
            "the highlight overlay leaked onto the word run");
         Assert
           (Plain.Element (6, 0).Appearance /= Number_Style,
            "the overlay was retained between renders");
      end;
   end Test_Completion_And_Highlighting;

   procedure Test_Geometry_And_Guards is
      Item : Editors.Model := New_Editor (Width => 12, Height => 2);
      Look : constant Editors.Appearance :=
        Editors.From_Theme (Flyology_TUI.Themes.Charm);
      Result : Editors.Action_Result;
      Success : Boolean;
   begin
      Item.Focus;
      Item.Set_Wrap (Flyology_TUI.Components.Text_Areas.Soft_Wrap);
      Type_Text (Item, "abcdefghijklmno");
      declare
         Frame : constant Flyology_TUI.Surfaces.Surface :=
           Item.Render (Look);
      begin
         Assert
           (Frame.Width = 12 and then Frame.Height = 2,
            "the editor did not render its assigned geometry");
         Assert
           (Row_Text (Frame, 0, 0, 12) = "> abcdefghij",
            "soft wrapping did not break at the text width");
         Assert
           (Row_Text (Frame, 1, 0, 7) = ". klmno",
            "the wrapped row did not draw the continuation marker");
      end;

      --  A prompt wider than the frame leaves no text cells but stays safe.
      Item.Set_Prompt ("very-long-prompt> ", "... ");
      Assert
        (Item.Text_Columns = 0,
         "an oversized prompt still published text cells");
      declare
         Frame : constant Flyology_TUI.Surfaces.Surface :=
           Item.Render (Look);
      begin
         Assert
           (Frame.Width = 12 and then Frame.Height = 2,
            "a zero-width text area changed the published geometry");
      end;

      Item.Set_Prompt ("> ", ". ");

      --  Capacity is refused atomically.
      Item.Clear;
      Type_Text (Item, (1 .. 64 => 'x'));
      Assert
        (Item.Value'Length = 64, "the editor did not fill to its bound");
      Result := Item.Handle (Character_Key ("y"));
      Assert
        (Result.Update.Rejected and then Item.Value'Length = 64,
         "an over-capacity key was not rejected atomically");

      --  Read-only and disabled editors refuse mutation.
      Item.Clear;
      Item.Set_Read_Only (True);
      Result := Item.Handle (Character_Key ("x"));
      Assert (Item.Value = "", "a read-only editor accepted text");
      Item.Apply_Completion (0, 0, "no", Success);
      Assert (not Success, "a read-only editor accepted a completion");
      Item.Set_Read_Only (False);
      Item.Set_Enabled (False);
      Result := Item.Handle (Character_Key ("x"));
      Assert
        (not Result.Update.Handled, "a disabled editor handled a key");
      Item.Set_Enabled (True);

      --  Ctrl-D on an empty buffer reports end of input, not a deletion.
      Item.Clear;
      Result := Item.Handle (Character_Key ("d", Control => True));
      Assert
        (Result.Action = Editors.End_Of_Input,
         "Ctrl-D on an empty buffer did not report end of input");
      Type_Text (Item, "ab");
      Item.Set_Cursor_Offset (0);
      Result := Item.Handle (Character_Key ("d", Control => True));
      Assert
        (Item.Value = "b" and then Result.Action = Editors.No_Action,
         "Ctrl-D on a filled buffer did not delete forward");

      --  Ctrl-C abandons the input.
      Type_Text (Item, "cde");
      Result := Item.Handle (Character_Key ("c", Control => True));
      Assert
        (Result.Action = Editors.Cancelled and then Item.Value = "",
         "Ctrl-C did not abandon the input");
   end Test_Geometry_And_Guards;

   --  A prompt that grows a row must reveal the lines it scrolled past,
   --  not keep showing only the line the cursor happens to sit on.
   procedure Test_Growing_Viewport is
      Item : Editors.Model := New_Editor (Width => 24, Height => 1);
      Look : constant Editors.Appearance :=
        Editors.From_Theme (Flyology_TUI.Themes.Charm);
      Success : Boolean;
   begin
      Item.Focus;
      Type_Text (Item, "one");
      Item.Insert_Continuation (Success);
      Type_Text (Item, "two");
      Assert
        (Success and then Item.Line_Count = 2,
         "the continuation did not open a second line");

      --  One row can only show the line the cursor is on.
      declare
         Frame : constant Flyology_TUI.Surfaces.Surface :=
           Item.Render (Look);
      begin
         Assert
           (Frame.Height = 1 and then Row_Text (Frame, 0, 0, 5) = ". two",
            "a one-row prompt did not follow the cursor");
      end;

      --  Given a second row, the first line must come back into view.
      Item.Set_Size (24, 2);
      declare
         Frame : constant Flyology_TUI.Surfaces.Surface :=
           Item.Render (Look);
      begin
         Assert
           (Row_Text (Frame, 0, 0, 5) = "> one",
            "growing the prompt did not reveal the scrolled-past line");
         Assert
           (Row_Text (Frame, 1, 0, 5) = ". two",
            "growing the prompt lost the line the cursor is on");
         Assert
           (Item.Cursor_Row = 1,
            "the cursor was not projected onto its own row");
      end;

      --  Deleting the continuation must not leave the viewport below the
      --  buffer either.
      Item.Set_Cursor_Offset (Item.Value'Length);
      for Step in 1 .. 4 loop
         Result_Discard : declare
            Ignored : constant Editors.Action_Result :=
              Item.Handle (Key (Flyology_TUI.Events.Backspace_Key));
         begin
            null;
         end Result_Discard;
      end loop;
      declare
         Frame : constant Flyology_TUI.Surfaces.Surface :=
           Item.Render (Look);
      begin
         Assert
           (Item.Line_Count = 1
            and then Row_Text (Frame, 0, 0, 5) = "> one",
            "collapsing to one line left the viewport scrolled away");
      end;
   end Test_Growing_Viewport;

   --  The enhanced keyboard protocol reports modified keys a legacy
   --  encoding cannot express. Only those keys take the new path.
   procedure Test_Enhanced_Keyboard is
      Parser : Flyology_TUI.Input.Parser;
      Event  : Flyology_TUI.Events.Terminal_Event;
      Ready  : Boolean;
      Escape : constant Character := Character'Val (27);

      procedure Take (Data : String) is
      begin
         Parser.Feed (Data);
         Parser.Next_Event (Event, Ready);
      end Take;
   begin
      Parser.Initialize;

      --  Shift-Enter, the key a legacy terminal cannot distinguish.
      Take (Escape & "[13;2u");
      Assert
        (Ready
         and then Event.Kind = Flyology_TUI.Events.Key_Press
         and then Event.Key.Kind = Flyology_TUI.Events.Enter_Key
         and then Event.Key.Modified.Shift
         and then not Event.Key.Modified.Control,
         "a reported Shift-Enter did not decode as a modified Enter");

      --  Ctrl-A arrives as its code point with a control modifier, which
      --  is the same event the legacy encoding produces.
      Take (Escape & "[97;5u");
      Assert
        (Ready
         and then Event.Key.Kind = Flyology_TUI.Events.Text_Key
         and then Text.To_Wide_Wide_String (Event.Key.Value) = "a"
         and then Event.Key.Modified.Control
         and then not Event.Key.Modified.Shift,
         "a reported Ctrl-A did not decode as the legacy encoding does");

      --  Ctrl-Shift-Tab combines both bits, which is 1 + 1 + 4.
      Take (Escape & "[9;6u");
      Assert
        (Ready
         and then Event.Key.Kind = Flyology_TUI.Events.Tab_Key
         and then Event.Key.Modified.Shift
         and then Event.Key.Modified.Control,
         "a combined modifier set did not decode both bits");

      --  The terminal's own flag report is not a key.
      Parser.Feed (Escape & "[?1u");
      Assert
        (not Parser.Has_Event,
         "the protocol flag report was decoded as a key press");

      --  With the protocol enabled a terminal reports F1 to F4 in the CSI
      --  form, because the legacy SS3 form cannot carry a modifier.
      Take (Escape & "[1;1Q");
      Assert
        (Ready
         and then Event.Key.Kind = Flyology_TUI.Events.Function_Key
         and then Event.Key.Number = 2,
         "the CSI form of F2 was not decoded");
      Take (Escape & "[1;5P");
      Assert
        (Ready
         and then Event.Key.Number = 1
         and then Event.Key.Modified.Control,
         "a modified function key lost its modifier");

      --  The legacy SS3 form still works, so a terminal without the
      --  protocol is unaffected.
      Take (Escape & "OQ");
      Assert
        (Ready
         and then Event.Key.Kind = Flyology_TUI.Events.Function_Key
         and then Event.Key.Number = 2,
         "the legacy SS3 form of F2 stopped decoding");

      --  A cursor position report shares the final byte of F3 but carries
      --  a row as its first parameter, so it must not become a key.
      Parser.Reset;
      Parser.Feed (Escape & "[24;80R");
      Assert
        (not Parser.Has_Event,
         "a cursor position report was decoded as a function key");

      --  A bare carriage return still reports an unmodified Enter, so a
      --  legacy terminal keeps working unchanged.
      Take (Character'Val (13) & "");
      Assert
        (Ready
         and then Event.Key.Kind = Flyology_TUI.Events.Enter_Key
         and then not Event.Key.Modified.Shift,
         "a bare carriage return stopped reporting a plain Enter");
   end Test_Enhanced_Keyboard;

   --  Boundary conditions that the ordinary flows never reach.
   procedure Test_Edge_Cases is
      Wide : constant Wide_Wide_String :=
        (1 => Wide_Wide_Character'Val (16#4E2D#));
      Item : Editors.Model := New_Editor;
      Result : Editors.Action_Result;
      Spans : Marks.Span_Array (1 .. 4);
      Count : Natural;
      Status : Scanners.Scan_State;
   begin
      --  A one-entry history evicts on every later add.
      declare
         Single : Past.Model := Past.Create (1, 40, Past.Keep_Duplicates);
      begin
         Assert (Single.Add ("a") = Past.Added, "single-entry add failed");
         Assert
           (Single.Add ("b") = Past.Added_After_Eviction
            and then Single.Length = 1
            and then Single.Entry_At (1) = "b",
            "a one-entry history did not replace its only entry");
      end;

      --  The code-point budget evicts even when entry slots remain.
      declare
         Tight : Past.Model := Past.Create (8, 10, Past.Keep_Duplicates);
      begin
         Assert (Tight.Add ("abcde") = Past.Added, "first tight add failed");
         Assert (Tight.Add ("fghij") = Past.Added, "second tight add failed");
         Assert
           (Tight.Add ("k") = Past.Added_After_Eviction
            and then Tight.Length = 2
            and then Tight.Entry_At (1) = "fghij"
            and then Tight.Code_Point_Count = 6,
            "the code-point budget did not evict the oldest entry");
      end;

      --  Scanning an empty buffer completes without writing a span.
      Behavior := Normal;
      Scanners.Scan ("", Palette, Spans, Count, Status);
      Assert
        (Status = Scanners.Scan_Complete and then Count = 0,
         "scanning an empty buffer did not complete cleanly");

      --  One candidate makes the whole insert text the common prefix, and a
      --  popup narrower than its widest candidate still publishes one column.
      declare
         Only : Menus.Model := Menus.Create (Menus.Tabulated_Grid, 5, 3);
         Shape : Menus.Presentation;
      begin
         Assert
           (Only.Offer ((1 => Menus.Candidate_Of ("procedure")), 0, 0)
            = Menus.Offered,
            "a single-candidate offer was refused");
         Assert
           (Only.Common_Prefix = "procedure",
            "one candidate did not yield its own text as the prefix");
         Shape := Only.Layout;
         Assert
           (Menus.Columns (Shape) = 1,
            "a popup narrower than its candidate published extra columns");
         declare
            Frame : constant Flyology_TUI.Surfaces.Surface :=
              Only.Render (Menus.From_Theme (Flyology_TUI.Themes.Charm));
         begin
            Assert
              (Frame.Width = 5 and then Row_Text (Frame, 0, 0, 5) = "> pro",
               "a clipped candidate was not truncated to the popup width");
         end;
      end;

      --  A two-cell glyph advances the cursor by two columns.
      Item.Focus;
      Type_Text (Item, Wide);
      Assert
        (Item.Value = Wide and then Item.Cursor_Column = 4,
         "a two-cell glyph did not advance the cursor by two columns");

      --  Transposition at the start of the buffer is a no-op.
      Item.Clear;
      Type_Text (Item, "a");
      Item.Set_Cursor_Offset (0);
      Result := Item.Handle (Character_Key ("t", Control => True));
      Assert
        (Item.Value = "a", "Ctrl-T at the buffer start changed the buffer");

      --  A click lands on the text cell under the prompt gutter, and a click
      --  on the gutter itself moves nothing.
      Item.Clear;
      Type_Text (Item, "hello");
      Item.Set_Cursor_Offset (0);
      Result := Item.Handle
        (Flyology_TUI.Mouse.Local_Event'
           (X        => 5,
            Y        => 0,
            Button   => Flyology_TUI.Events.Left_Button,
            Action   => Flyology_TUI.Events.Mouse_Click,
            Modified => (others => False),
            Wheel_X  => 0,
            Wheel_Y  => 0));
      Assert
        (Item.Cursor_Offset = 3,
         "a click did not land on the cell under the prompt gutter");
      Result := Item.Handle
        (Flyology_TUI.Mouse.Local_Event'
           (X        => 0,
            Y        => 0,
            Button   => Flyology_TUI.Events.Left_Button,
            Action   => Flyology_TUI.Events.Mouse_Click,
            Modified => (others => False),
            Wheel_X  => 0,
            Wheel_Y  => 0));
      Assert
        (Item.Cursor_Offset = 3,
         "a click on the prompt gutter moved the cursor");
   end Test_Edge_Cases;

   ------------------------------------------------------------------
   --  A store standing in for a file or a database
   ------------------------------------------------------------------

   type Entry_Buffer is
     array (1 .. 16) of Text.Unbounded_Wide_Wide_String;

   type Memory_Store is limited record
      Items  : Entry_Buffer;
      Count  : Natural := 0;
      Cursor : Natural := 0;
   end record;

   procedure Write_Entry
     (Target : in out Memory_Store; Value : Wide_Wide_String) is
   begin
      Target.Count := Target.Count + 1;
      Target.Items (Target.Count) :=
        Text.To_Unbounded_Wide_Wide_String (Value);
   end Write_Entry;

   procedure Read_Entry
     (Source    : in out Memory_Store;
      Value     : out Text.Unbounded_Wide_Wide_String;
      Available : out Boolean) is
   begin
      Available := Source.Cursor < Source.Count;
      if Available then
         Source.Cursor := Source.Cursor + 1;
         Value := Source.Items (Source.Cursor);
      else
         Value := Text.Null_Unbounded_Wide_Wide_String;
      end if;
   end Read_Entry;

   package History_Store is new Past.Stores
     (Store => Memory_Store, Write_Entry => Write_Entry,
      Read_Entry => Read_Entry);

   package Editor_Store is new Editors.History_Stores
     (Store => Memory_Store, Write_Entry => Write_Entry,
      Read_Entry => Read_Entry);

   procedure Test_Stores is
      Item : Past.Model := Past.Create (8, 256, Past.Keep_Duplicates);
      Store : Memory_Store;
      Accepted, Refused : Natural;
      Multiline : constant Wide_Wide_String :=
        "first" & Line_Feed & "second";
   begin
      Assert (Item.Add ("alpha") = Past.Added, "store seed one failed");
      Assert (Item.Add (Multiline) = Past.Added, "store seed two failed");
      Assert (Item.Add ("omega") = Past.Added, "store seed three failed");

      History_Store.Save (Item, Store);
      Assert
        (Store.Count = 3
         and then Text.To_Wide_Wide_String (Store.Items (1)) = "alpha"
         and then Text.To_Wide_Wide_String (Store.Items (3)) = "omega",
         "saving did not write entries oldest first");

      --  A restored history reproduces the saved order exactly, including
      --  an entry that spans lines.
      Item.Clear;
      Assert (Item.Length = 0, "clearing before a load left entries");
      History_Store.Load (Item, Store, Accepted, Refused);
      Assert
        (Accepted = 3 and then Refused = 0 and then Item.Length = 3,
         "loading did not restore every saved entry");
      Assert
        (Item.Entry_At (1) = "alpha"
         and then Item.Entry_At (2) = Multiline
         and then Item.Entry_At (3) = "omega",
         "a restored history did not reproduce the saved order");

      --  A store written by a larger model is refused entry by entry
      --  rather than raising.
      declare
         --  Five code points admits the two short entries but not the
         --  twelve-code-point multi-line one.
         Narrow : Past.Model := Past.Create (8, 5, Past.Keep_Duplicates);
         Replay : Memory_Store := (Items => Store.Items,
                                   Count => Store.Count,
                                   Cursor => 0);
      begin
         History_Store.Load (Narrow, Replay, Accepted, Refused);
         Assert
           (Accepted = 2 and then Refused = 1 and then Narrow.Length = 1,
            "an oversized entry was not refused on its own");
      end;

      --  The editor persists the same way through the same contract.
      declare
         Prompt : Editors.Model := New_Editor;
         Round  : Memory_Store;
      begin
         Assert
           (Prompt.Remember ("one") = Past.Added, "editor seed one failed");
         Assert
           (Prompt.Remember ("two") = Past.Added, "editor seed two failed");
         Editor_Store.Save (Prompt, Round);
         Prompt.Forget_All;
         Assert (Prompt.Recorded_Count = 0, "forgetting left entries");
         Editor_Store.Load (Prompt, Round, Accepted, Refused);
         Assert
           (Accepted = 2
            and then Prompt.Recorded_Entry (1) = "one"
            and then Prompt.Recorded_Entry (2) = "two",
            "an editor history did not survive a store round trip");
      end;
   end Test_Stores;

begin
   Test_Highlights;
   Test_Histories;
   Test_Completions;
   Test_Editing_And_Prompt;
   Test_Killing_And_Yanking;
   Test_History_And_Hinting;
   Test_Completion_And_Highlighting;
   Test_Geometry_And_Guards;
   Test_Growing_Viewport;
   Test_Enhanced_Keyboard;
   Test_Edge_Cases;
   Test_Stores;
   Ada.Text_IO.Put_Line ("line editor tests passed");
end Line_Editor_Tests;
