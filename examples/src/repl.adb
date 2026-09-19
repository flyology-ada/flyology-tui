with Ada.Exceptions;
with Ada.Strings.Wide_Wide_Unbounded;
with Ada.Text_IO;
with Ada.Wide_Wide_Text_IO;
with Flyology_TUI.Application_Events;
with Flyology_TUI.Backends;
with Flyology_TUI.Backends.POSIX;
with Flyology_TUI.Components.Completions;
with Flyology_TUI.Components.Help;
with Flyology_TUI.Components.Highlights;
with Flyology_TUI.Components.Histories;
with Flyology_TUI.Components.Interactions;
with Flyology_TUI.Components.Line_Editors;
with Flyology_TUI.Components.Panel_Groups;
with Flyology_TUI.Components.Text_Areas;
with Flyology_TUI.Components.Windows;
with Flyology_TUI.Events;
with Flyology_TUI.Geometry;
with Flyology_TUI.Glyphs;
with Flyology_TUI.Layouts;
with Flyology_TUI.Layouts.Boxes;
with Flyology_TUI.Mouse;
with Flyology_TUI.Runners;
with Flyology_TUI.Styles;
with Flyology_TUI.Surfaces;
with Flyology_TUI.Themes;
with Flyology_TUI.Transitions;
with Flyology_TUI.Views;

--  A read-eval-print loop built from the readline primitives, arranged as a
--  reference rather than a toy.
--
--  Several independent sessions can run at once. Each owns its prompt, its
--  completion popup, and its own scrollback, so hosting one in a window, in
--  a panel, or directly on the frame changes only the measurements handed
--  to it. The scrollback keeps the language colouring that the prompt shows
--  while an input is being typed, because it re-scans the visible rows with
--  the same lexer.
procedure REPL is
   package Text renames Ada.Strings.Wide_Wide_Unbounded;
   package Editors renames Flyology_TUI.Components.Line_Editors;
   package Marks renames Flyology_TUI.Components.Highlights;
   package Histories renames Flyology_TUI.Components.Histories;
   package Panels renames Flyology_TUI.Components.Panel_Groups;
   package Frames renames Flyology_TUI.Components.Windows;
   package Wide_IO renames Ada.Wide_Wide_Text_IO;

   use type Flyology_TUI.Events.Terminal_Event_Kind;
   use type Flyology_TUI.Events.Key_Kind;
   use type Flyology_TUI.Events.Mouse_Action;

   Line_Feed : constant Wide_Wide_Character := Wide_Wide_Character'Val (10);

   type Message is (Unused_Message);
   type Command is (No_Command);

   ------------------------------------------------------------------
   --  Languages
   ------------------------------------------------------------------

   --  The prompt highlights whichever language is selected. One token
   --  vocabulary serves all three, so the palette stays in one place.
   type Language is (Arithmetic, Ada_Source, JSON);

   type Token_Kind is
     (Plain, Keyword, Literal, Numeral, Operator, Bracket, Comment,
      Directive);

   type Lexer_State is record
      Started : Boolean := False;
   end record;

   Fresh : constant Lexer_State := (Started => False);

   --  Read by the lexer while Present scans the buffer. The overlay is
   --  recomputed every frame, so switching languages needs no cache.
   Active : Language := Arithmetic;

   function Is_Digit (Item : Wide_Wide_Character) return Boolean
   is (Item in '0' .. '9');

   function Is_Name (Item : Wide_Wide_Character) return Boolean
   is (Item in 'a' .. 'z' or else Item in 'A' .. 'Z'
       or else Is_Digit (Item) or else Item = '_');

   function Is_Bracket (Item : Wide_Wide_Character) return Boolean
   is (Item = '(' or else Item = ')' or else Item = '['
       or else Item = ']' or else Item = '{' or else Item = '}');

   function Is_Operator (Item : Wide_Wide_Character) return Boolean
   is (Item = '+' or else Item = '-' or else Item = '*' or else Item = '/'
       or else Item = ':' or else Item = ',' or else Item = ';'
       or else Item = '=' or else Item = '.');

   Ada_Words : constant Wide_Wide_String :=
     " procedure function is begin end if then else elsif loop while for "
     & "return declare package body type record null and or not new when "
     & "case with use constant out in of exit ";

   JSON_Words : constant Wide_Wide_String := " true false null ";

   --  Whether a space-delimited word appears in a space-delimited list.
   function Listed
     (Words : Wide_Wide_String; Word : Wide_Wide_String) return Boolean
   is
      Target : constant Wide_Wide_String := " " & Word & " ";
   begin
      if Word'Length = 0 or else Target'Length > Words'Length then
         return False;
      end if;
      for Start in Words'First .. Words'Last - Target'Length + 1 loop
         if Words (Start .. Start + Target'Length - 1) = Target then
            return True;
         end if;
      end loop;
      return False;
   end Listed;

   --  Emit one token per run. Every branch advances Position, so the scan
   --  always terminates.
   procedure Next_Token
     (Line        : Wide_Wide_String;
      Initial     : Lexer_State;
      From        : Natural;
      Kind        : out Token_Kind;
      First, Last : out Natural;
      Final       : out Lexer_State;
      Has_Token   : out Boolean)
   is
      Position : Natural := From;

      function At_Char (Offset : Natural) return Wide_Wide_Character
      is (Line (Line'First + Offset));
   begin
      Final := (Started => True);
      Kind := Plain;
      First := From;
      Last := From;
      Has_Token := False;
      if Position >= Line'Length then
         return;
      end if;

      First := Position;
      Has_Token := True;

      --  A colon directive is recognized in every language, because the
      --  loop's own commands are not part of the language being edited.
      if not Initial.Started and then Position = 0
        and then At_Char (0) = ':'
      then
         Kind := Directive;
         while Position < Line'Length
           and then At_Char (Position) /= ' '
         loop
            Position := Position + 1;
         end loop;
         Last := Position;
         return;
      end if;

      if Active /= Arithmetic
        and then At_Char (Position) = '"'
      then
         Kind := Literal;
         Position := Position + 1;
         while Position < Line'Length loop
            exit when At_Char (Position) = '"';
            Position := Position + 1;
         end loop;
         if Position < Line'Length then
            Position := Position + 1;
         end if;
         Last := Position;
         return;
      end if;

      if Active = Ada_Source
        and then At_Char (Position) = '-'
        and then Position + 1 < Line'Length
        and then At_Char (Position + 1) = '-'
      then
         Kind := Comment;
         Last := Line'Length;
         return;
      end if;

      if Is_Digit (At_Char (Position)) then
         Kind := Numeral;
         while Position < Line'Length
           and then (Is_Digit (At_Char (Position))
                     or else At_Char (Position) = '.')
         loop
            Position := Position + 1;
         end loop;
         Last := Position;
         return;
      end if;

      if Is_Bracket (At_Char (Position)) then
         Kind := Bracket;
         Last := Position + 1;
         return;
      end if;

      if Is_Operator (At_Char (Position)) then
         Kind := Operator;
         Last := Position + 1;
         return;
      end if;

      if Is_Name (At_Char (Position)) then
         while Position < Line'Length
           and then Is_Name (At_Char (Position))
         loop
            Position := Position + 1;
         end loop;
         Last := Position;
         declare
            Word : constant Wide_Wide_String :=
              Line (Line'First + First .. Line'First + Last - 1);
         begin
            case Active is
               when Ada_Source =>
                  Kind := (if Listed (Ada_Words, Word) then Keyword
                           else Plain);
               when JSON =>
                  Kind := (if Listed (JSON_Words, Word) then Keyword
                           else Plain);
               when Arithmetic =>
                  Kind := Plain;
            end case;
         end;
         return;
      end if;

      --  Anything else, including spaces, is one plain run.
      while Position < Line'Length
        and then not Is_Digit (At_Char (Position))
        and then not Is_Name (At_Char (Position))
        and then not Is_Bracket (At_Char (Position))
        and then not Is_Operator (At_Char (Position))
        and then At_Char (Position) /= '"'
      loop
         Position := Position + 1;
      end loop;
      Last := Position;
   end Next_Token;

   package Scanner is new Marks.Lexers
     (Token_Kind    => Token_Kind,
      Lexer_State   => Lexer_State,
      Initial_State => Fresh,
      Next_Token    => Next_Token);
   ------------------------------------------------------------------
   --  Scrollback
   ------------------------------------------------------------------

   --  A transcript row keeps its text and what the row is, never a style.
   --  Colour is decided at render time: an echoed input is re-scanned with
   --  the active lexer, so the scrollback keeps the same colouring the
   --  prompt showed while it was being typed.
   type Line_Kind is (Echo_Line, Result_Line, Notice_Line, Problem_Line);

   Max_Log_Lines : constant := 400;

   type Log_Line is record
      Content : Text.Unbounded_Wide_Wide_String;
      Kind    : Line_Kind := Notice_Line;
   end record;

   type Log_Array is array (1 .. Max_Log_Lines) of Log_Line;

   type Scrollback is record
      Items : Log_Array;
      First : Positive := 1;
      Count : Natural := 0;
   end record;

   procedure Append
     (Log : in out Scrollback;
      Value : Wide_Wide_String;
      Kind : Line_Kind)
   is
      Slot : constant Positive :=
        (((Log.First - 1) + Log.Count) mod Max_Log_Lines) + 1;
   begin
      if Log.Count = Max_Log_Lines then
         Log.Items (Log.First) :=
           (Content => Text.To_Unbounded_Wide_Wide_String (Value),
            Kind => Kind);
         Log.First := (Log.First mod Max_Log_Lines) + 1;
      else
         Log.Items (Slot) :=
           (Content => Text.To_Unbounded_Wide_Wide_String (Value),
            Kind => Kind);
         Log.Count := Log.Count + 1;
      end if;
   end Append;

   function Log_Entry
     (Log : Scrollback; Position : Positive) return Log_Line
   is (Log.Items ((((Log.First - 1) + (Position - 1)) mod Max_Log_Lines) + 1));

   ------------------------------------------------------------------
   --  Completion
   ------------------------------------------------------------------

   type Candidate_Kind is
     (Directive_Candidate, Keyword_Candidate, Recalled_Candidate);

   package Menus is new Flyology_TUI.Components.Completions
     (Category => Candidate_Kind, Capacity => 64);

   use type Menus.Offer_Result;

   Directives : constant Menus.Candidate_Array :=
     [Menus.Candidate_Of
        (":help", Detail => "bindings", Kind => Directive_Candidate),
      Menus.Candidate_Of
        (":history", Detail => "list entries", Kind => Directive_Candidate),
      Menus.Candidate_Of
        (":clear", Detail => "empty transcript", Kind => Directive_Candidate),
      Menus.Candidate_Of
        (":demo", Detail => "load a multi-line input",
         Kind => Directive_Candidate),
      Menus.Candidate_Of
        (":mode", Detail => "cycle placement", Kind => Directive_Candidate),
      Menus.Candidate_Of
        (":new", Detail => "open another session",
         Kind => Directive_Candidate),
      Menus.Candidate_Of
        (":close", Detail => "close this session",
         Kind => Directive_Candidate),
      Menus.Candidate_Of
        (":next", Detail => "focus the next session",
         Kind => Directive_Candidate),
      Menus.Candidate_Of
        (":lang", Detail => "arithmetic, ada, json",
         Kind => Directive_Candidate),
      Menus.Candidate_Of
        (":quit", Detail => "leave the loop", Kind => Directive_Candidate)];

   ------------------------------------------------------------------
   --  Sessions
   ------------------------------------------------------------------

   Max_Sessions : constant := 4;
   Footer_Rows : constant := 1;
   Max_Prompt_Rows : constant := 8;

   --  Every session owns a complete loop. Nothing here knows where it is
   --  drawn, which is what lets the same value be hosted on the frame, in
   --  a window, or in a panel.
   type Session is limited record
      Prompt : Editors.Model (1_024, 32, 64, 8_192, 256, 16_384) :=
        Editors.Create
          (Max_Code_Points          => 1_024,
           Max_Lines                => 32,
           Max_Undo_Entries         => 64,
           Max_Undo_Code_Points     => 8_192,
           Max_Recalled_Entries     => 256,
           Max_Recalled_Code_Points => 16_384,
           Width                    => 40,
           Height                   => 1,
           Primary                  => ">>> ",
           Continuation             => "... ",
           --  A colon stays inside a word so a directive completes as one.
           Word_Separators          => " ()[]{}+-*/,;=" & Line_Feed,
           Duplicates               => Histories.Ignore_Consecutive,
           Placeholder              => "an expression, or :help");
      Menu  : Menus.Model := Menus.Create (Menus.Detailed_Menu, 40, 6);
      Log   : Scrollback;
      Frame : Frames.Model :=
        Frames.Create
          (X => 2, Y => 1, Width => 48, Height => 12,
           Minimum_Width => 24, Minimum_Height => 6, Closable => False);
      Live  : Boolean := False;
   end record;

   type Session_Array is array (1 .. Max_Sessions) of Session;
   type Order_Array is array (1 .. Max_Sessions) of Natural;

   --  Where the sessions are drawn. Inline and docked show the focused
   --  session alone. Windowed and paneled host every live session at once.
   type Prompt_Placement is
     (Inline_Prompt, Docked_Prompt, Windowed_Prompt, Paneled_Prompt);

   type Model is limited record
      Sessions  : Session_Array;
      --  Front-most last, so a later window draws over an earlier one.
      Order     : Order_Array := [others => 0];
      Live      : Natural := 0;
      Panes     : Panels.Model :=
        Panels.Create
          (Flow => Flyology_TUI.Layouts.Boxes.Horizontal,
           Width => 78, Height => 20,
           Panes => [1 .. 1 => (Minimum_Span => 12, Initial_Span => 0,
                                Weight => 1)]);
      Placement : Prompt_Placement := Inline_Prompt;
      Width     : Natural := 80;
      Height    : Natural := 24;
   end record;

   package Events is new Flyology_TUI.Application_Events (Message);
   package Transitions is new Flyology_TUI.Transitions (Command);

   --  Cells the loop may use, with the footer removed.
   function Workspace (Item : Model) return Flyology_TUI.Geometry.Rectangle
   is (X      => 0,
       Y      => 0,
       Width  => Item.Width,
       Height =>
         (if Item.Height > Footer_Rows then Item.Height - Footer_Rows
          else 1));

   --  The focused session is the front-most one.
   function Focused_Session (Item : Model) return Positive
   is (if Item.Live = 0 then 1
       else Positive'Max (1, Item.Order (Item.Live)));

   procedure Say
     (Item : in out Model;
      Index : Positive;
      Value : Wide_Wide_String;
      Kind : Line_Kind := Notice_Line) is
   begin
      Append (Item.Sessions (Index).Log, Value, Kind);
   end Say;

   ------------------------------------------------------------------
   --  A history file store
   ------------------------------------------------------------------

   --  Entries may contain line feeds, so each is written as one escaped
   --  line. This is the store's concern, not the component's.
   History_Path : constant String := ".flyology_repl_history";

   type File_Store is limited record
      Handle : Wide_IO.File_Type;
   end record;

   function Escaped (Value : Wide_Wide_String) return Wide_Wide_String is
      Result : Text.Unbounded_Wide_Wide_String;
   begin
      for Char of Value loop
         if Char = '\' then
            Text.Append (Result, "\\");
         elsif Char = Line_Feed then
            Text.Append (Result, "\n");
         else
            Text.Append (Result, Char);
         end if;
      end loop;
      return Text.To_Wide_Wide_String (Result);
   end Escaped;

   function Unescaped (Value : Wide_Wide_String) return Wide_Wide_String is
      Result : Text.Unbounded_Wide_Wide_String;
      Index  : Natural := Value'First;
   begin
      while Index <= Value'Last loop
         if Value (Index) = '\' and then Index < Value'Last then
            case Value (Index + 1) is
               when 'n' => Text.Append (Result, Line_Feed);
               when others => Text.Append (Result, Value (Index + 1));
            end case;
            Index := Index + 2;
         else
            Text.Append (Result, Value (Index));
            Index := Index + 1;
         end if;
      end loop;
      return Text.To_Wide_Wide_String (Result);
   end Unescaped;

   --  A one-row presentation of a possibly multi-line entry. The store's
   --  backslash encoding is a file format, not something to show a reader,
   --  so a visible return glyph stands in for each line feed.
   function Flattened (Value : Wide_Wide_String) return Wide_Wide_String is
      Result : Text.Unbounded_Wide_Wide_String;
   begin
      for Char of Value loop
         if Char = Line_Feed then
            Text.Append
              (Result, " " & Wide_Wide_Character'Val (16#23CE#) & " ");
         else
            Text.Append (Result, Char);
         end if;
      end loop;
      return Text.To_Wide_Wide_String (Result);
   end Flattened;

   procedure Write_Entry
     (Target : in out File_Store; Value : Wide_Wide_String) is
   begin
      Wide_IO.Put_Line (Target.Handle, Escaped (Value));
   end Write_Entry;

   procedure Read_Entry
     (Source    : in out File_Store;
      Value     : out Text.Unbounded_Wide_Wide_String;
      Available : out Boolean) is
   begin
      Value := Text.Null_Unbounded_Wide_Wide_String;
      Available := not Wide_IO.End_Of_File (Source.Handle);
      if Available then
         Value :=
           Text.To_Unbounded_Wide_Wide_String
             (Unescaped (Wide_IO.Get_Line (Source.Handle)));
      end if;
   end Read_Entry;

   package History_Files is new Editors.History_Stores
     (Store       => File_Store,
      Write_Entry => Write_Entry,
      Read_Entry  => Read_Entry);

   --  History is read before the loop starts and written after it ends, so
   --  Update never performs I/O. The store holds one history; it belongs to
   --  the first session, and a session opened later starts empty.
   procedure Restore_History (Item : in out Model) is
      Store : File_Store;
      Accepted, Refused : Natural;
   begin
      Wide_IO.Open (Store.Handle, Wide_IO.In_File, History_Path, "WCEM=8");
      History_Files.Load
        (Item.Sessions (1).Prompt, Store, Accepted, Refused);
      Wide_IO.Close (Store.Handle);
      if Accepted > 0 then
         Say (Item, 1,
              "Restored" & Natural'Wide_Wide_Image (Accepted)
              & " history entries.");
      end if;
   exception
      when Wide_IO.Name_Error =>
         null;
      when others =>
         if Wide_IO.Is_Open (Store.Handle) then
            Wide_IO.Close (Store.Handle);
         end if;
         Say (Item, 1, "  ! the history store could not be read",
              Problem_Line);
   end Restore_History;

   procedure Persist_History (Item : in out Model) is
      Store : File_Store;
   begin
      Wide_IO.Create (Store.Handle, Wide_IO.Out_File, History_Path, "WCEM=8");
      History_Files.Save (Item.Sessions (1).Prompt, Store);
      Wide_IO.Close (Store.Handle);
   exception
      when others =>
         if Wide_IO.Is_Open (Store.Handle) then
            Wide_IO.Close (Store.Handle);
         end if;
   end Persist_History;

   --  Depth of unclosed brackets. A negative result means the input is
   --  already malformed rather than merely unfinished.
   function Bracket_Depth (Value : Wide_Wide_String) return Integer is
      Depth : Integer := 0;
   begin
      for Char of Value loop
         if Char = '(' or else Char = '[' or else Char = '{' then
            Depth := Depth + 1;
         elsif Char = ')' or else Char = ']' or else Char = '}' then
            Depth := Depth - 1;
         end if;
      end loop;
      return Depth;
   end Bracket_Depth;

   --  Whether the application judges the input unfinished. A bracket left
   --  open and a dangling arithmetic operator both mean more is coming, so
   --  Enter opens a continuation line instead of evaluating. This is the
   --  decision the component deliberately refuses to make.
   function Needs_More (Value : Wide_Wide_String) return Boolean is
      Last : Natural := 0;
   begin
      if Bracket_Depth (Value) > 0 then
         return True;
      end if;
      for Index in Value'Range loop
         if Value (Index) /= ' ' and then Value (Index) /= Line_Feed then
            Last := Index;
         end if;
      end loop;
      return Last > 0
        and then (Value (Last) = '+' or else Value (Last) = '-'
                  or else Value (Last) = '*' or else Value (Last) = '/');
   end Needs_More;

   function Number_Image (Value : Integer) return Wide_Wide_String is
      Narrow : constant String := Integer'Image (Value);
      Trimmed : constant String :=
        (if Value < 0 then Narrow
         else Narrow (Narrow'First + 1 .. Narrow'Last));
      Result : Wide_Wide_String (Trimmed'Range);
   begin
      for Index in Trimmed'Range loop
         Result (Index) :=
           Wide_Wide_Character'Val (Character'Pos (Trimmed (Index)));
      end loop;
      return Result;
   end Number_Image;

   procedure Evaluate
     (Value   : Wide_Wide_String;
      Result  : out Integer;
      Success : out Boolean)
   is
      Position : Natural := Value'First;

      --  A continued input carries the line feeds the editor inserted, so
      --  they separate tokens exactly as spaces do.
      procedure Skip_Spaces is
      begin
         while Position <= Value'Last
           and then (Value (Position) = ' '
                     or else Value (Position) = Line_Feed)
         loop
            Position := Position + 1;
         end loop;
      end Skip_Spaces;

      function Expression return Integer;

      function Primary return Integer is
         Total : Integer := 0;
         Seen  : Boolean := False;
      begin
         Skip_Spaces;
         if Position <= Value'Last and then Value (Position) = '(' then
            Position := Position + 1;
            Total := Expression;
            Skip_Spaces;
            if Position <= Value'Last and then Value (Position) = ')' then
               Position := Position + 1;
            else
               Success := False;
            end if;
            return Total;
         elsif Position <= Value'Last and then Value (Position) = '-' then
            Position := Position + 1;
            return -Primary;
         end if;
         while Position <= Value'Last and then Is_Digit (Value (Position))
         loop
            Total :=
              Total * 10
              + (Wide_Wide_Character'Pos (Value (Position))
                 - Wide_Wide_Character'Pos ('0'));
            Position := Position + 1;
            Seen := True;
         end loop;
         if not Seen then
            Success := False;
         end if;
         return Total;
      end Primary;

      function Term return Integer is
         Total : Integer := Primary;
      begin
         loop
            Skip_Spaces;
            exit when Position > Value'Last;
            if Value (Position) = '*' then
               Position := Position + 1;
               Total := Total * Primary;
            elsif Value (Position) = '/' then
               Position := Position + 1;
               declare
                  Divisor : constant Integer := Primary;
               begin
                  if Divisor = 0 then
                     Success := False;
                     return 0;
                  end if;
                  Total := Total / Divisor;
               end;
            else
               exit;
            end if;
         end loop;
         return Total;
      end Term;

      function Expression return Integer is
         Total : Integer := Term;
      begin
         loop
            Skip_Spaces;
            exit when Position > Value'Last;
            if Value (Position) = '+' then
               Position := Position + 1;
               Total := Total + Term;
            elsif Value (Position) = '-' then
               Position := Position + 1;
               Total := Total - Term;
            else
               exit;
            end if;
         end loop;
         return Total;
      end Expression;

   begin
      Success := True;
      Result := 0;
      if Value'Length = 0 then
         Success := False;
         return;
      end if;
      Result := Expression;
      Skip_Spaces;
      if Position <= Value'Last then
         Success := False;
      end if;
   exception
      when others =>
         Success := False;
   end Evaluate;
   ------------------------------------------------------------------
   --  Rendering one session
   ------------------------------------------------------------------

   --  Colour for a transcript row that is not an echoed input.
   function Kind_Style
     (Kind : Line_Kind;
      Palette : Flyology_TUI.Themes.Palette)
      return Flyology_TUI.Styles.Style
   is (case Kind is
          when Echo_Line => Palette.Content,
          when Result_Line => Palette.Success,
          when Notice_Line => Palette.Muted,
          when Problem_Line => Palette.Error);

   --  Draw the last rows of a scrollback. An echoed input is re-scanned
   --  with the active lexer, so the transcript keeps the colouring the
   --  prompt showed. Only the visible rows are scanned.
   function Render_Log
     (Log : Scrollback;
      Cells, Rows : Positive;
      Palette : Flyology_TUI.Themes.Palette;
      Tones : Scanner.Token_Appearance)
      return Flyology_TUI.Surfaces.Surface
   is
      Result : Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.Create (Cells, Rows, Palette.Content);
      Shown : constant Natural := Natural'Min (Rows, Log.Count);
      Skip : constant Natural := Log.Count - Shown;
      Spans : Marks.Span_Array (1 .. 128);
      Count : Natural;
      Status : Scanner.Scan_State;
   begin
      for Row in 0 .. Shown - 1 loop
         declare
            Item : constant Log_Line := Log_Entry (Log, Skip + Row + 1);
            Value : constant Wide_Wide_String :=
              Text.To_Wide_Wide_String (Item.Content);
            Base : constant Flyology_TUI.Styles.Style :=
              Kind_Style (Item.Kind, Palette);
            Column : Natural := 0;
            Offset : Natural := 0;
         begin
            Count := 0;
            if Item.Kind = Echo_Line then
               Scanner.Scan (Value, Tones, Spans, Count, Status);
            end if;
            while Offset < Value'Length and then Column < Cells loop
               declare
                  Stop : constant Natural :=
                    Flyology_TUI.Glyphs.Cluster_Last
                      (Value, Value'First + Offset) - Value'First + 1;
                  Glyph : constant Wide_Wide_String :=
                    Value (Value'First + Offset .. Value'First + Stop - 1);
               begin
                  exit when Stop <= Offset;
                  Result.Put
                    (Column, Row, Glyph,
                     Marks.Style_At (Spans (1 .. Count), Offset, Base));
                  Column := Column +
                    Natural'Max (1, Flyology_TUI.Glyphs.Width_Of (Glyph));
                  Offset := Stop;
               end;
            end loop;
         end;
      end loop;
      return Result;
   end Render_Log;

   --  One session as a surface of exactly the cells it was given.
   function Session_Surface
     (Item : Model;
      Index : Positive;
      Cells, Rows : Positive;
      Palette : Flyology_TUI.Themes.Palette;
      Tones : Scanner.Token_Appearance;
      Focused : Boolean;
      --  Hug shrinks the transcript to its own content, which puts the
      --  prompt directly under the last output instead of at the bottom
      --  of the frame. That is the difference between the inline and the
      --  docked placement.
      Hug : Boolean := False)
      return Flyology_TUI.Surfaces.Surface
   is
      Visual : constant Flyology_TUI.Themes.Theme :=
        Flyology_TUI.Themes.To_Theme (Palette);
      Look : constant Editors.Appearance := Editors.From_Palette (Palette);
      Session_Item : Session renames Item.Sessions (Index);
      Menu_Rows : constant Natural :=
        (if Session_Item.Menu.Is_Open
         then Menus.Height (Session_Item.Menu.Layout) else 0);
      Prompt_Rows : constant Natural := Session_Item.Prompt.Height;
      Spare : constant Natural :=
        (if Rows > Prompt_Rows + Menu_Rows
         then Rows - Prompt_Rows - Menu_Rows else 1);
      Log_Rows : constant Positive :=
        (if Hug
         then Positive'Max
                (1, Natural'Min (Spare, Item.Sessions (Index).Log.Count))
         else Positive'Max (1, Spare));
      Spans : Marks.Span_Array (1 .. 512);
      Count : Natural;
      Status : Scanner.Scan_State;
   begin
      Scanner.Scan (Session_Item.Prompt.Value, Tones, Spans, Count, Status);
      declare
         Body_Surface : constant Flyology_TUI.Surfaces.Surface :=
           Render_Log (Session_Item.Log, Cells, Log_Rows, Palette, Tones);
         Prompt_Surface : constant Flyology_TUI.Surfaces.Surface :=
           Session_Item.Prompt.Render (Look, Spans (1 .. Count));
         Lower : Flyology_TUI.Surfaces.Surface := Prompt_Surface;
      begin
         if Session_Item.Menu.Is_Open then
            declare
               Popup : constant Flyology_TUI.Surfaces.Surface :=
                 Session_Item.Menu.Render (Menus.From_Palette (Palette));
               Word_Cells : constant Natural :=
                 Session_Item.Menu.Replacement_Last
                 - Session_Item.Menu.Replacement_First;
               Anchor : constant Natural :=
                 (if Session_Item.Prompt.Cursor_Column > Word_Cells
                  then Session_Item.Prompt.Cursor_Column - Word_Cells
                  else 0);
               Origin : constant Natural :=
                 Natural'Min
                   (Anchor,
                    (if Cells > Popup.Width then Cells - Popup.Width else 0));
               Row : Flyology_TUI.Surfaces.Surface :=
                 Flyology_TUI.Surfaces.Create
                   (Cells, Popup.Height, Palette.Content);
            begin
               Row.Overlay_Clipped (Popup, Integer (Origin), 0);
               Lower := Flyology_TUI.Layouts.Join_Vertically
                 (Row, Prompt_Surface, Gap => 0);
            end;
         end if;
         if not Focused and then Item.Live > 1 then
            return Flyology_TUI.Layouts.Join_Vertically
              (Body_Surface, Lower, Gap => 0).Inherit_Colors (Visual.Muted);
         end if;
         return Flyology_TUI.Layouts.Join_Vertically
           (Body_Surface, Lower, Gap => 0);
      end;
   end Session_Surface;

   --  Rows the prompt of one session wants, given the cells it has.
   function Prompt_Rows_For
     (Item : Model; Index : Positive; Available : Positive) return Positive
   is
      Wanted : constant Natural :=
        Natural'Min (Max_Prompt_Rows, Item.Sessions (Index).Prompt.Line_Count);
   begin
      return Positive'Max
        (1, Natural'Min (Wanted, Natural'Max (1, Available - 1)));
   end Prompt_Rows_For;

   --  Only the prompt is sized here. The transcript takes whatever rows
   --  remain when the session surface is built.
   procedure Size_Session
     (Item : in out Model;
      Index : Positive;
      Cells, Rows : Positive)
   is
      Prompt_Rows : constant Positive :=
        Prompt_Rows_For (Item, Index, Rows);
   begin
      Item.Sessions (Index).Prompt.Set_Size (Cells, Prompt_Rows);
   end Size_Session;

   ------------------------------------------------------------------
   --  Layout
   ------------------------------------------------------------------

   procedure Sync_Layout (Item : in out Model) is
      Area : constant Flyology_TUI.Geometry.Rectangle := Workspace (Item);
      Cells : constant Positive :=
        Positive'Max (20, Area.Width - Natural'Min (2, Area.Width));
      Rows : constant Positive := Positive'Max (1, Area.Height);
   begin
      case Item.Placement is
         when Inline_Prompt | Docked_Prompt =>
            Size_Session (Item, Focused_Session (Item), Cells, Rows);
         when Windowed_Prompt =>
            for Index in 1 .. Max_Sessions loop
               if Item.Sessions (Index).Live then
                  declare
                     Client : constant Flyology_TUI.Geometry.Rectangle :=
                       Item.Sessions (Index).Frame.Client_Region;
                  begin
                     Size_Session
                       (Item, Index,
                        Positive'Max (8, Client.Width),
                        Positive'Max (1, Client.Height));
                  end;
               end if;
            end loop;
         when Paneled_Prompt =>
            Item.Panes.Resize (Area.Width, Area.Height);
            declare
               Seen : Natural := 0;
            begin
               for Index in 1 .. Max_Sessions loop
                  if Item.Sessions (Index).Live then
                     Seen := Seen + 1;
                     if Item.Panes.Has_Pane (Seen) then
                        declare
                           Region : constant
                             Flyology_TUI.Geometry.Rectangle :=
                               Item.Panes.Pane_Region (Seen);
                        begin
                           Size_Session
                             (Item, Index,
                              Positive'Max (8, Region.Width),
                              Positive'Max (1, Region.Height));
                        end;
                     end if;
                  end if;
               end loop;
            end;
      end case;
   end Sync_Layout;

   --  Give the panel group one pane per live session.
   procedure Reconfigure_Panes (Item : in out Model) is
      Wanted : constant Positive := Positive'Max (1, Item.Live);
      Shape : constant Panels.Pane_Constraint_Array :=
        [1 .. Wanted => (Minimum_Span => 12, Initial_Span => 0, Weight => 1)];
   begin
      Item.Panes.Configure (Shape);
      Item.Panes.Resize (Workspace (Item).Width, Workspace (Item).Height);
   end Reconfigure_Panes;

   ------------------------------------------------------------------
   --  Session lifecycle
   ------------------------------------------------------------------

   procedure Raise_Session (Item : in out Model; Index : Positive) is
      Found : Natural := 0;
   begin
      for Slot in 1 .. Item.Live loop
         if Item.Order (Slot) = Index then
            Found := Slot;
         end if;
      end loop;
      if Found = 0 or else Found = Item.Live then
         return;
      end if;
      for Slot in Found .. Item.Live - 1 loop
         Item.Order (Slot) := Item.Order (Slot + 1);
      end loop;
      Item.Order (Item.Live) := Index;
   end Raise_Session;

   procedure Focus_Only (Item : in out Model; Index : Positive) is
   begin
      for Slot in 1 .. Max_Sessions loop
         if Item.Sessions (Slot).Live then
            if Slot = Index then
               Item.Sessions (Slot).Prompt.Focus;
               Item.Sessions (Slot).Frame.Focus;
            else
               Item.Sessions (Slot).Prompt.Blur;
               Item.Sessions (Slot).Frame.Blur;
            end if;
         end if;
      end loop;
   end Focus_Only;

   procedure Open_Session (Item : in out Model; Opened : out Natural) is
   begin
      Opened := 0;
      for Index in 1 .. Max_Sessions loop
         if not Item.Sessions (Index).Live then
            Item.Sessions (Index).Live := True;
            Item.Sessions (Index).Prompt.Set_Wrap
              (Flyology_TUI.Components.Text_Areas.Soft_Wrap);
            --  Offset each window so a new one is visibly its own.
            Item.Sessions (Index).Frame.Constrain_To (Workspace (Item));
            Item.Live := Item.Live + 1;
            Item.Order (Item.Live) := Index;
            Opened := Index;
            Focus_Only (Item, Index);
            Reconfigure_Panes (Item);
            return;
         end if;
      end loop;
   end Open_Session;

   procedure Close_Session (Item : in out Model; Index : Positive) is
      Found : Natural := 0;
   begin
      if Item.Live <= 1 then
         return;
      end if;
      Item.Sessions (Index).Live := False;
      for Slot in 1 .. Item.Live loop
         if Item.Order (Slot) = Index then
            Found := Slot;
         end if;
      end loop;
      if Found /= 0 then
         for Slot in Found .. Item.Live - 1 loop
            Item.Order (Slot) := Item.Order (Slot + 1);
         end loop;
         Item.Order (Item.Live) := 0;
         Item.Live := Item.Live - 1;
      end if;
      Focus_Only (Item, Focused_Session (Item));
      Reconfigure_Panes (Item);
   end Close_Session;

   procedure Focus_Next (Item : in out Model) is
   begin
      if Item.Live <= 1 then
         return;
      end if;
      Raise_Session (Item, Item.Order (1));
      Focus_Only (Item, Focused_Session (Item));
   end Focus_Next;

   ------------------------------------------------------------------
   --  Directives
   ------------------------------------------------------------------

   function Word_After
     (Value : Wide_Wide_String; Head : Wide_Wide_String)
      return Wide_Wide_String
   is
     (if Value'Length > Head'Length
        and then Value (Value'First .. Value'First + Head'Length - 1) = Head
      then Value (Value'First + Head'Length .. Value'Last)
      else "");

   Demo_Input : constant Wide_Wide_String :=
     "(1 + 2) * (" & Line_Feed & "  3 + 4" & Line_Feed & ")";

   function Placement_Name (Item : Model) return Wide_Wide_String
   is (case Item.Placement is
          when Inline_Prompt => "inline",
          when Docked_Prompt => "docked",
          when Windowed_Prompt => "windowed",
          when Paneled_Prompt => "paneled");

   procedure Run_Directive
     (Item  : in out Model;
      Index : Positive;
      Value : Wide_Wide_String;
      Next  : in out Transitions.Transition)
   is
      Loaded : Boolean;
      Opened : Natural;
   begin
      if Value = ":quit" then
         Transitions.Quit (Next);
      elsif Value = ":clear" then
         Item.Sessions (Index).Log := (Items => <>, First => 1, Count => 0);
      elsif Value = ":history" then
         for Position in 1 .. Item.Sessions (Index).Prompt.Recorded_Count loop
            Say (Item, Index,
                 "  " & Number_Image (Position) & "  "
                 & Flattened
                     (Item.Sessions (Index).Prompt.Recorded_Entry (Position)));
         end loop;
      elsif Value = ":demo" then
         Item.Sessions (Index).Prompt.Try_Set_Value (Demo_Input, Loaded);
         if Loaded then
            Item.Sessions (Index).Prompt.Set_Cursor_Offset (0);
            Say (Item, Index,
                 "Loaded a three-line input. Up and Down move between");
            Say (Item, Index,
                 "its lines; Ctrl-O opens another; Enter evaluates it.");
         end if;
      elsif Value = ":new" then
         Open_Session (Item, Opened);
         if Opened = 0 then
            Say (Item, Index, "  ! no free session slot", Problem_Line);
         else
            Say (Item, Opened, "Session" & Natural'Wide_Wide_Image (Opened)
                 & ". Try :mode to see it beside the others.");
         end if;
      elsif Value = ":close" then
         if Item.Live <= 1 then
            Say (Item, Index, "  ! the last session stays open",
                 Problem_Line);
         else
            Close_Session (Item, Index);
         end if;
      elsif Value = ":next" then
         Focus_Next (Item);
      elsif Value = ":mode" then
         Item.Placement :=
           (if Item.Placement = Prompt_Placement'Last then Inline_Prompt
            else Prompt_Placement'Succ (Item.Placement));
         Say (Item, Index,
              "Placement is now " & Placement_Name (Item) & ".");
         if Item.Placement = Windowed_Prompt then
            Say (Item, Index,
                 "Drag a header to move, a border to resize, a body to focus.");
         elsif Item.Placement = Paneled_Prompt then
            Say (Item, Index, "Drag a divider to rebalance the panes.");
         end if;
      elsif Word_After (Value, ":lang ") /= "" then
         declare
            Choice : constant Wide_Wide_String := Word_After (Value, ":lang ");
         begin
            if Choice = "ada" then
               Active := Ada_Source;
            elsif Choice = "json" then
               Active := JSON;
            elsif Choice = "arithmetic" then
               Active := Arithmetic;
            else
               Say (Item, Index, "  unknown language " & Choice,
                    Problem_Line);
               return;
            end if;
            Say (Item, Index,
                 "Highlighting " & Choice
                 & ". The transcript recolours with it.");
         end;
      elsif Value = ":lang" then
         Say (Item, Index, "  :lang arithmetic | ada | json");
      elsif Value = ":help" then
         Say (Item, Index,
              "  Tab      completion     Ctrl-R  reverse search");
         Say (Item, Index,
              "  Up/Down  line, history  Ctrl-O  continue line");
         Say (Item, Index,
              "  F2 placement  F3 new session  F4 focus next");
         Say (Item, Index,
              "  :demo multi-line   :new :close :next   :lang");
      else
         Say (Item, Index, "  unknown directive " & Value, Problem_Line);
      end if;
   end Run_Directive;

   --  The application, not the component, decides whether input is
   --  finished. Unbalanced brackets and a dangling operator both continue.
   procedure Submit
     (Item : in out Model;
      Index : Positive;
      Next : in out Transitions.Transition)
   is
      Pending : constant Wide_Wide_String :=
        Item.Sessions (Index).Prompt.Value;
      Submitted : Text.Unbounded_Wide_Wide_String;
      Recorded : Histories.Add_Result;
      Continued : Boolean;
      Answer : Integer;
      Success : Boolean;
   begin
      if Pending'Length = 0 then
         return;
      elsif Needs_More (Pending) then
         Item.Sessions (Index).Prompt.Insert_Continuation (Continued);
         if not Continued then
            Say (Item, Index, "  ! the input reached this prompt's bounds",
                 Problem_Line);
         end if;
         return;
      end if;

      Item.Sessions (Index).Prompt.Accept_Submission (Submitted, Recorded);
      declare
         Entered : constant Wide_Wide_String :=
           Text.To_Wide_Wide_String (Submitted);
         First : Natural := Entered'First;
      begin
         for Position in Entered'Range loop
            if Entered (Position) = Line_Feed then
               Say (Item, Index,
                    (if First = Entered'First then ">>> " else "... ")
                    & Entered (First .. Position - 1), Echo_Line);
               First := Position + 1;
            end if;
         end loop;
         Say (Item, Index,
              (if First = Entered'First then ">>> " else "... ")
              & Entered (First .. Entered'Last), Echo_Line);

         if Entered (Entered'First) = ':' then
            Run_Directive (Item, Index, Entered, Next);
         else
            Evaluate (Entered, Answer, Success);
            if Success then
               Say (Item, Index, "  = " & Number_Image (Answer),
                    Result_Line);
            else
               Say (Item, Index, "  ? not an arithmetic expression",
                    Problem_Line);
            end if;
         end if;
      end;
   end Submit;

   ------------------------------------------------------------------
   --  Completion
   ------------------------------------------------------------------

   function Matches
     (Value : Wide_Wide_String; Prefix : Wide_Wide_String) return Boolean
   is (Prefix'Length <= Value'Length
       and then Value (Value'First .. Value'First + Prefix'Length - 1)
                = Prefix);

   procedure Offer_Completions (Item : in out Model; Index : Positive) is
      First, Last : Natural;
      Buffer : constant Wide_Wide_String :=
        Item.Sessions (Index).Prompt.Value;
      Chosen : Menus.Candidate_Array (1 .. 64);
      Count : Natural := 0;
      Offered : Menus.Offer_Result;

      procedure Add_Word (Value : Wide_Wide_String; Word : Wide_Wide_String)
      is
      begin
         if Count < Chosen'Length and then Matches (Value, Word) then
            Count := Count + 1;
            Chosen (Count) :=
              Menus.Candidate_Of
                (Value, Detail => "keyword", Kind => Keyword_Candidate);
         end if;
      end Add_Word;

      procedure Offer_Words
        (Words : Wide_Wide_String; Word : Wide_Wide_String)
      is
         Start : Natural := Words'First;
      begin
         for Position in Words'Range loop
            if Words (Position) = ' ' then
               if Position > Start then
                  Add_Word (Words (Start .. Position - 1), Word);
               end if;
               Start := Position + 1;
            end if;
         end loop;
      end Offer_Words;

      --  The word before the one being completed decides what may follow
      --  it. After a declaration keyword the cursor is at a name, so the
      --  language's own keywords are not offered there.
      function Preceding_Word (Upto : Natural) return Wide_Wide_String is
         Stop : Natural := Upto;
         Start : Natural;
      begin
         while Stop > 0
           and then (Buffer (Buffer'First + Stop - 1) = ' '
                     or else Buffer (Buffer'First + Stop - 1) = Line_Feed)
         loop
            Stop := Stop - 1;
         end loop;
         Start := Stop;
         while Start > 0
           and then Is_Name (Buffer (Buffer'First + Start - 1))
         loop
            Start := Start - 1;
         end loop;
         return Buffer (Buffer'First + Start .. Buffer'First + Stop - 1);
      end Preceding_Word;
   begin
      Item.Sessions (Index).Prompt.Completion_Span (First, Last);
      declare
         Word : constant Wide_Wide_String :=
           Buffer (Buffer'First + First .. Buffer'First + Last - 1);
      begin
         if Word'Length > 0 and then Word (Word'First) = ':' then
            for Position in Directives'Range loop
               exit when Count = Chosen'Length;
               if Matches
                    (Text.To_Wide_Wide_String (Directives (Position).Insert),
                     Word)
               then
                  Count := Count + 1;
                  Chosen (Count) := Directives (Position);
               end if;
            end loop;
         elsif Listed (" procedure function package type ",
                       Preceding_Word (First))
         then
            null;
         else
            case Active is
               when Ada_Source => Offer_Words (Ada_Words, Word);
               when JSON => Offer_Words (JSON_Words, Word);
               when Arithmetic => null;
            end case;
            for Position in reverse
              1 .. Item.Sessions (Index).Prompt.Recorded_Count
            loop
               exit when Count = Chosen'Length;
               declare
                  Recalled : constant Wide_Wide_String :=
                    Item.Sessions (Index).Prompt.Recorded_Entry (Position);
               begin
                  if Word'Length > 0 and then Matches (Recalled, Word) then
                     Count := Count + 1;
                     Chosen (Count) :=
                       Menus.Candidate_Of
                         (Recalled,
                          Display => Flattened (Recalled),
                          Detail  => "history",
                          Kind    => Recalled_Candidate);
                  end if;
               end;
            end loop;
         end if;

         declare
            Cells : constant Natural :=
              Item.Sessions (Index).Prompt.Width;
            Widest : Natural := 12;
         begin
            for Position in 1 .. Count loop
               Widest :=
                 Natural'Max
                   (Widest,
                    Flyology_TUI.Glyphs.Width_Of
                      (Text.To_Wide_Wide_String (Chosen (Position).Display))
                    + Flyology_TUI.Glyphs.Width_Of
                        (Text.To_Wide_Wide_String (Chosen (Position).Detail))
                    + 6);
            end loop;
            Item.Sessions (Index).Menu.Set_Size
              (Natural'Min (Cells, Widest),
               Natural'Min (8, Natural'Max (1, Item.Height / 3)));
         end;
         Offered :=
           Item.Sessions (Index).Menu.Offer (Chosen (1 .. Count), First, Last);
         if Offered = Menus.Rejected_Span then
            Item.Sessions (Index).Menu.Close;
         end if;
      end;
   end Offer_Completions;

   procedure Apply_Selected (Item : in out Model; Index : Positive) is
      Success : Boolean;
   begin
      if Item.Sessions (Index).Menu.Is_Empty then
         return;
      end if;
      Item.Sessions (Index).Prompt.Apply_Completion
        (Item.Sessions (Index).Menu.Replacement_First,
         Item.Sessions (Index).Menu.Replacement_Last,
         Text.To_Wide_Wide_String
           (Item.Sessions (Index).Menu.Selected_Candidate.Insert),
         Success);
      Item.Sessions (Index).Menu.Close;
   end Apply_Selected;

   ------------------------------------------------------------------
   --  Application loop
   ------------------------------------------------------------------

   procedure Initialize
     (Item : in out Model;
      Next : in out Transitions.Transition)
   is
      pragma Unreferenced (Next);
      Opened : Natural;
   begin
      --  Stagger the windows so a second session is visibly its own.
      for Index in 1 .. Max_Sessions loop
         Item.Sessions (Index).Frame :=
           Frames.Create
             (X => 2 + 4 * (Index - 1),
              Y => 1 + 2 * (Index - 1),
              Width => 48, Height => 12,
              Minimum_Width => 24, Minimum_Height => 6, Closable => False);
      end loop;
      Open_Session (Item, Opened);
      Say (Item, 1, "Flyology TUI readline reference.");
      Say (Item, 1, "Evaluate integer arithmetic, or type :help.");
      Sync_Layout (Item);
   end Initialize;

   --  Which session a workspace cell belongs to, front-most first.
   function Session_At
     (Item : Model; X, Y : Integer) return Natural is
   begin
      case Item.Placement is
         when Inline_Prompt | Docked_Prompt =>
            return Focused_Session (Item);
         when Windowed_Prompt =>
            for Slot in reverse 1 .. Item.Live loop
               declare
                  Index : constant Positive := Item.Order (Slot);
                  Bounds : constant Flyology_TUI.Geometry.Rectangle :=
                    Item.Sessions (Index).Frame.Bounds;
               begin
                  if X >= Bounds.X and then Y >= Bounds.Y
                    and then X < Bounds.X + Bounds.Width
                    and then Y < Bounds.Y + Bounds.Height
                  then
                     return Index;
                  end if;
               end;
            end loop;
            return 0;
         when Paneled_Prompt =>
            declare
               Seen : Natural := 0;
            begin
               for Index in 1 .. Max_Sessions loop
                  if Item.Sessions (Index).Live then
                     Seen := Seen + 1;
                     if Item.Panes.Has_Pane (Seen) then
                        declare
                           Region : constant
                             Flyology_TUI.Geometry.Rectangle :=
                               Item.Panes.Pane_Region (Seen);
                        begin
                           if X >= Region.X and then Y >= Region.Y
                             and then X < Region.X + Region.Width
                             and then Y < Region.Y + Region.Height
                           then
                              return Index;
                           end if;
                        end;
                     end if;
                  end if;
               end loop;
               return 0;
            end;
      end case;
   end Session_At;

   procedure Handle_Mouse
     (Item : in out Model;
      Event : Flyology_TUI.Events.Terminal_Event)
   is
      Area : constant Flyology_TUI.Geometry.Rectangle := Workspace (Item);
      Local : Flyology_TUI.Mouse.Local_Event :=
        (X        => Event.Mouse.X,
         Y        => Event.Mouse.Y,
         Button   => Event.Mouse.Button,
         Action   => Event.Mouse.Action,
         Modified => Event.Mouse.Modified,
         Wheel_X  => Event.Mouse.Wheel_X,
         Wheel_Y  => Event.Mouse.Wheel_Y);
      Target : constant Natural := Session_At (Item, Local.X, Local.Y);
      Taken : Flyology_TUI.Components.Interactions.Update_Result;
      Index : Positive := Focused_Session (Item);
      Menu_Rows : Natural;
   begin
      --  A press inside a session focuses it and raises it above the rest.
      if Target /= 0
        and then Event.Mouse.Action = Flyology_TUI.Events.Mouse_Click
      then
         Raise_Session (Item, Target);
         Focus_Only (Item, Target);
      end if;
      if Target /= 0 then
         Index := Target;
      end if;

      case Item.Placement is
         when Windowed_Prompt =>
            Taken := Item.Sessions (Index).Frame.Handle (Local, Area);
            if Taken.Handled then
               Sync_Layout (Item);
               return;
            end if;
            declare
               Client : constant Flyology_TUI.Geometry.Rectangle :=
                 Item.Sessions (Index).Frame.Client_Region;
            begin
               Local.X := Local.X - Client.X;
               Local.Y := Local.Y - Client.Y;
            end;
         when Paneled_Prompt =>
            Taken := Item.Panes.Handle (Local);
            if Taken.Handled then
               Sync_Layout (Item);
               return;
            end if;
            declare
               Seen : Natural := 0;
            begin
               for Slot in 1 .. Max_Sessions loop
                  if Item.Sessions (Slot).Live then
                     Seen := Seen + 1;
                     exit when Slot = Index;
                  end if;
               end loop;
               if Item.Panes.Has_Pane (Seen) then
                  declare
                     Region : constant Flyology_TUI.Geometry.Rectangle :=
                       Item.Panes.Pane_Region (Seen);
                  begin
                     Local.X := Local.X - Region.X;
                     Local.Y := Local.Y - Region.Y;
                  end;
               end if;
            end;
         when Inline_Prompt | Docked_Prompt =>
            null;
      end case;

      Menu_Rows :=
        (if Item.Sessions (Index).Menu.Is_Open
         then Menus.Height (Item.Sessions (Index).Menu.Layout) else 0);
      Local.Y :=
        Local.Y - Item.Sessions (Index).Prompt.Height - Menu_Rows;
      declare
         Ignored : constant Editors.Action_Result :=
           Item.Sessions (Index).Prompt.Handle (Local);
      begin
         null;
      end;
   end Handle_Mouse;

   procedure Update
     (Item  : in out Model;
      Event : Events.Event;
      Next  : in out Transitions.Transition)
   is
      Menu_Result : Flyology_TUI.Components.Interactions.Update_Result;
      Action : Editors.Action_Result;
      Index : Positive;
      Opened : Natural;
   begin
      case Event.Kind is
         when Events.Application_Message =>
            null;
         when Events.Terminal_Input =>
            case Event.Terminal.Kind is
               when Flyology_TUI.Events.Resize =>
                  Item.Width := Event.Terminal.Width;
                  Item.Height := Event.Terminal.Height;
                  for Slot in 1 .. Max_Sessions loop
                     if Item.Sessions (Slot).Live then
                        Item.Sessions (Slot).Frame.Constrain_To
                          (Workspace (Item));
                     end if;
                  end loop;
                  Reconfigure_Panes (Item);
                  Sync_Layout (Item);
               when Flyology_TUI.Events.Interrupt =>
                  Transitions.Quit (Next);
               when others =>
                  Index := Focused_Session (Item);

                  if Event.Terminal.Kind = Flyology_TUI.Events.Key_Press
                    and then Event.Terminal.Key.Kind
                             = Flyology_TUI.Events.Function_Key
                  then
                     case Event.Terminal.Key.Number is
                        when 2 =>
                           Item.Placement :=
                             (if Item.Placement = Prompt_Placement'Last
                              then Inline_Prompt
                              else Prompt_Placement'Succ (Item.Placement));
                           Sync_Layout (Item);
                           return;
                        when 3 =>
                           Open_Session (Item, Opened);
                           Sync_Layout (Item);
                           return;
                        when 4 =>
                           Focus_Next (Item);
                           Sync_Layout (Item);
                           return;
                        when others =>
                           null;
                     end case;
                  end if;

                  if Event.Terminal.Kind = Flyology_TUI.Events.Mouse_Input
                  then
                     Handle_Mouse (Item, Event.Terminal);
                     Sync_Layout (Item);
                     return;
                  end if;

                  --  A window or a panel group takes its own arrow keys.
                  if Item.Placement = Windowed_Prompt then
                     Menu_Result :=
                       Item.Sessions (Index).Frame.Handle
                         (Event.Terminal, Workspace (Item));
                     if Menu_Result.Handled then
                        Sync_Layout (Item);
                        return;
                     end if;
                  end if;

                  if Item.Sessions (Index).Menu.Is_Open then
                     Menu_Result :=
                       Item.Sessions (Index).Menu.Handle (Event.Terminal);
                     if Menu_Result.Activated then
                        Apply_Selected (Item, Index);
                        Sync_Layout (Item);
                        return;
                     elsif Menu_Result.Handled then
                        Sync_Layout (Item);
                        return;
                     end if;
                  end if;

                  Action :=
                    Item.Sessions (Index).Prompt.Handle (Event.Terminal);
                  case Action.Action is
                     when Editors.Submit_Requested =>
                        Item.Sessions (Index).Menu.Close;
                        Submit (Item, Index, Next);
                     when Editors.Completion_Requested =>
                        Offer_Completions (Item, Index);
                     when Editors.Cancelled =>
                        Item.Sessions (Index).Menu.Close;
                        Say (Item, Index, ">>> (cancelled)");
                     when Editors.End_Of_Input =>
                        Transitions.Quit (Next);
                     when Editors.No_Action =>
                        null;
                  end case;

                  if Action.Update.Changed then
                     Item.Sessions (Index).Menu.Close;
                  end if;
                  Item.Sessions (Index).Prompt.Suggest_From_History;
                  Sync_Layout (Item);
            end case;
      end case;
   end Update;

   function Present (Item : Model) return Flyology_TUI.Views.View is
      Palette : constant Flyology_TUI.Themes.Palette :=
        Flyology_TUI.Themes.Charm_Palette;
      Visual : constant Flyology_TUI.Themes.Theme :=
        Flyology_TUI.Themes.To_Theme (Palette);
      Area : constant Flyology_TUI.Geometry.Rectangle := Workspace (Item);
      Focus : constant Positive := Focused_Session (Item);
      Tones : Scanner.Token_Appearance := [others => Palette.Content];
      Bindings : constant Flyology_TUI.Components.Help.Binding_Array :=
        [(Key         => Text.To_Unbounded_Wide_Wide_String ("tab"),
          Description => Text.To_Unbounded_Wide_Wide_String ("complete"),
          Enabled     => True),
         (Key         => Text.To_Unbounded_Wide_Wide_String ("ctrl-o"),
          Description => Text.To_Unbounded_Wide_Wide_String ("continue"),
          Enabled     => True),
         (Key         => Text.To_Unbounded_Wide_Wide_String ("f2"),
          Description => Text.To_Unbounded_Wide_Wide_String ("placement"),
          Enabled     => True),
         (Key         => Text.To_Unbounded_Wide_Wide_String ("f3/f4"),
          Description => Text.To_Unbounded_Wide_Wide_String ("new/next"),
          Enabled     => True),
         (Key         => Text.To_Unbounded_Wide_Wide_String ("ctrl-d"),
          Description => Text.To_Unbounded_Wide_Wide_String ("quit"),
          Enabled     => True)];
      Canvas : Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.Create
          (Positive'Max (1, Area.Width), Positive'Max (1, Area.Height),
           Palette.Content);
      Origin_X : Integer := 0;
      Origin_Y : Integer := 0;
      Result : Flyology_TUI.Views.View;
   begin
      Tones (Numeral) := Palette.Success;
      Tones (Operator) := Palette.Interaction;
      Tones (Bracket) := Palette.Muted;
      Tones (Directive) := Palette.Title;
      Tones (Keyword) := Palette.Title;
      Tones (Literal) := Palette.Success;
      Tones (Comment) := Palette.Muted;

      case Item.Placement is
         when Inline_Prompt | Docked_Prompt =>
            declare
               Cells : constant Positive :=
                 Positive'Max (1, Item.Sessions (Focus).Prompt.Width);
               Body_Rows : constant Positive :=
                 Positive'Max (1, Area.Height);
               Panel : constant Flyology_TUI.Surfaces.Surface :=
                 Session_Surface
                   (Item, Focus, Cells, Body_Rows, Palette, Tones, True,
                    Hug => Item.Placement = Inline_Prompt);
            begin
               if Item.Placement = Inline_Prompt then
                  Canvas.Overlay_Clipped (Panel, 0, 0);
                  Origin_Y := 0;
               else
                  Origin_Y := Area.Height - Panel.Height;
                  Canvas.Overlay_Clipped (Panel, 0, Origin_Y);
               end if;
               Origin_Y := Origin_Y + Panel.Height
                 - Item.Sessions (Focus).Prompt.Height;
            end;

         when Windowed_Prompt =>
            for Slot in 1 .. Item.Live loop
               declare
                  Index : constant Positive := Item.Order (Slot);
                  Bounds : constant Flyology_TUI.Geometry.Rectangle :=
                    Item.Sessions (Index).Frame.Bounds;
                  Client : constant Flyology_TUI.Geometry.Rectangle :=
                    Item.Sessions (Index).Frame.Client_Region;
                  Inner : constant Flyology_TUI.Surfaces.Surface :=
                    Session_Surface
                      (Item, Index,
                       Positive'Max (1, Client.Width),
                       Positive'Max (1, Client.Height),
                       Palette, Tones, Index = Focus);
                  Whole : constant Flyology_TUI.Surfaces.Surface :=
                    Item.Sessions (Index).Frame.Render
                      ((if Index = Focus then "readline" else "readline ~"),
                       Inner, Area, Frames.From_Theme (Visual));
                  --  Crop to this window's own rectangle so a lower window
                  --  keeps the cells this one does not occupy.
                  Piece : Flyology_TUI.Surfaces.Surface :=
                    Flyology_TUI.Surfaces.Create
                      (Positive'Max (1, Bounds.Width),
                       Positive'Max (1, Bounds.Height), Palette.Content);
               begin
                  Piece.Overlay_Clipped (Whole, -Bounds.X, -Bounds.Y);
                  Canvas.Overlay_Clipped (Piece, Bounds.X, Bounds.Y);
                  if Index = Focus then
                     Origin_X := Client.X;
                     Origin_Y := Client.Y + Client.Height
                       - Item.Sessions (Index).Prompt.Height;
                  end if;
               end;
            end loop;

         when Paneled_Prompt =>
            declare
               Count : constant Positive :=
                 Positive'Max (1, Item.Panes.Pane_Count);
               Children : Panels.Surface_Array (1 .. Count) :=
                 [others =>
                    Flyology_TUI.Surfaces.Create (1, 1, Palette.Content)];
               Seen : Natural := 0;
            begin
               for Index in 1 .. Max_Sessions loop
                  if Item.Sessions (Index).Live then
                     Seen := Seen + 1;
                     if Seen <= Count and then Item.Panes.Has_Pane (Seen) then
                        declare
                           Region : constant
                             Flyology_TUI.Geometry.Rectangle :=
                               Item.Panes.Pane_Region (Seen);
                        begin
                           Children (Seen) :=
                             Session_Surface
                               (Item, Index,
                                Positive'Max (1, Region.Width),
                                Positive'Max (1, Region.Height),
                                Palette, Tones, Index = Focus);
                           if Index = Focus then
                              Origin_X := Region.X;
                              Origin_Y := Region.Y + Region.Height
                                - Item.Sessions (Index).Prompt.Height;
                           end if;
                        end;
                     end if;
                  end if;
               end loop;
               Canvas.Overlay_Clipped
                 (Item.Panes.Render
                    (Children, Panels.From_Theme (Visual)), 0, 0);
            end;
      end case;

      Result := Flyology_TUI.Views.From_Surface
        (Flyology_TUI.Layouts.Join_Vertically
           (Canvas,
            Flyology_TUI.Components.Help.Render
              (Bindings,
               Positive'Max (20, Item.Width - Natural'Min (2, Item.Width)),
               Visual, Vertical => False),
            Gap => 0));
      Result.Alternate_Screen := True;
      --  Moving and resizing are drags, so the view must ask for motion
      --  reporting and not only button events.
      Result.Mouse := Flyology_TUI.Views.Cell_Motion;
      Result.Enhanced_Keyboard := True;
      Result.Window_Title :=
        Text.To_Unbounded_Wide_Wide_String ("Flyology TUI readline");
      declare
         Cursor_X : constant Integer :=
           Origin_X + Item.Sessions (Focus).Prompt.Cursor_Column;
         Cursor_Y : constant Integer :=
           Origin_Y + Item.Sessions (Focus).Prompt.Cursor_Row;
      begin
         Result.Cursor :=
           (Visible => Cursor_X >= 0 and then Cursor_Y >= 0,
            X       => Natural'Max (0, Cursor_X),
            Y       => Natural'Max (0, Cursor_Y),
            Shape   => Flyology_TUI.Views.Cursor_Bar,
            Blink   => True);
      end;
      return Result;
   end Present;

   procedure Execute
     (Item     : Command;
      Result   : out Message;
      Produced : out Boolean)
   is
      pragma Unreferenced (Item);
   begin
      Result := Unused_Message;
      Produced := False;
   end Execute;

   package Runtime is new Flyology_TUI.Runners
     (Events      => Events,
      Transitions => Transitions,
      Model_Type  => Model,
      Initialize  => Initialize,
      Update      => Update,
      Present     => Present,
      Execute     => Execute);

   State : Model;
   Terminal : Flyology_TUI.Backends.POSIX.POSIX_Backend;
begin
   Restore_History (State);
   Runtime.Run (State, Terminal);
   Persist_History (State);
exception
   when Error : Flyology_TUI.Backends.Backend_Error =>
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "repl: " & Ada.Exceptions.Exception_Message (Error));
end REPL;
