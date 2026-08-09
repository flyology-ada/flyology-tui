with Flyology_TUI.Glyphs;

package body Flyology_TUI.Components.Text_Areas is
   use type Flyology_TUI.Events.Key_Kind;
   use type Flyology_TUI.Events.Mouse_Action;
   use type Flyology_TUI.Events.Mouse_Button;
   use type Flyology_TUI.Events.Terminal_Event_Kind;

   function Saturating_Add (Left, Right : Natural) return Natural is
     (if Right > Natural'Last - Left then Natural'Last else Left + Right);

   procedure Validate_Size (Width, Height : Positive) is
   begin
      if Height > Natural'Last / Width then
         raise Flyology_TUI.Components.Capacity_Error;
      end if;
   end Validate_Size;

   function From_Theme
     (Theme : Flyology_TUI.Themes.Theme) return Appearance is
     (Text         => Theme.Input,
      Selection    => Theme.Selected,
      Current_Line => Theme.Primary,
      Gutter       => Theme.Muted,
      Placeholder  => Theme.Placeholder,
      Cursor       => Theme.Focused,
      Read_Only    => Theme.Muted,
      Disabled     => Theme.Muted);

   function Create
     (Max_Code_Points        : Positive;
      Max_Lines              : Positive;
      Max_Undo_Entries       : Positive;
      Max_History_Codepoints : Positive;
      Width                  : Positive := 40;
      Height                 : Positive := 8;
      Placeholder            : Wide_Wide_String := "") return Model
   is
      Result : Model
        (Max_Code_Points,
         Max_Lines,
         Max_Undo_Entries,
         Max_History_Codepoints);
   begin
      Validate_Size (Width, Height);
      Result.Columns := Width;
      Result.Rows := Height;
      Result.Placeholder := Text.To_Unbounded_Wide_Wide_String (Placeholder);
      return Result;
   end Create;

   procedure Normalize_Bounded
     (Value           : Wide_Wide_String;
      Max_Code_Points : Natural;
      Max_Lines       : Positive;
      Result          : out Text.Unbounded_Wide_Wide_String;
      Success         : out Boolean)
   is
      Index : Natural := Value'First;
      Count : Natural := 0;
      Lines : Positive := 1;
   begin
      Result := Text.Null_Unbounded_Wide_Wide_String;
      Success := True;
      while Index <= Value'Last loop
         if Count >= Max_Code_Points then
            Success := False;
            return;
         end if;
         if Value (Index) = Wide_Wide_Character'Val (13) then
            if Lines >= Max_Lines then
               Success := False;
               return;
            end if;
            Text.Append (Result, Wide_Wide_Character'Val (10));
            Lines := Lines + 1;
            if Index < Value'Last
              and then Value (Index + 1) = Wide_Wide_Character'Val (10)
            then
               Index := Index + 1;
            end if;
         else
            if Value (Index) = Wide_Wide_Character'Val (10) then
               if Lines >= Max_Lines then
                  Success := False;
                  return;
               end if;
               Lines := Lines + 1;
            end if;
            Text.Append (Result, Value (Index));
         end if;
         Count := Count + 1;
         Index := Index + 1;
      end loop;
   end Normalize_Bounded;

   procedure Normalize_Bounded
     (Value           : Text.Unbounded_Wide_Wide_String;
      Max_Code_Points : Natural;
      Max_Lines       : Positive;
      Result          : out Text.Unbounded_Wide_Wide_String;
      Success         : out Boolean)
   is
      Index : Positive := 1;
      Length : constant Natural := Text.Length (Value);
      Count : Natural := 0;
      Lines : Positive := 1;
      Char : Wide_Wide_Character;
   begin
      Result := Text.Null_Unbounded_Wide_Wide_String;
      Success := True;
      while Index <= Length loop
         if Count >= Max_Code_Points then
            Success := False;
            return;
         end if;
         Char := Text.Element (Value, Index);
         if Char = Wide_Wide_Character'Val (13) then
            if Lines >= Max_Lines then
               Success := False;
               return;
            end if;
            Text.Append (Result, Wide_Wide_Character'Val (10));
            Lines := Lines + 1;
            if Index < Length
              and then Text.Element (Value, Index + 1) =
                Wide_Wide_Character'Val (10)
            then
               Index := Index + 1;
            end if;
         else
            if Char = Wide_Wide_Character'Val (10) then
               if Lines >= Max_Lines then
                  Success := False;
                  return;
               end if;
               Lines := Lines + 1;
            end if;
            Text.Append (Result, Char);
         end if;
         Count := Count + 1;
         exit when Index = Length;
         Index := Index + 1;
      end loop;
   end Normalize_Bounded;

   function Count_Lines (Value : Wide_Wide_String) return Positive is
      Result : Positive := 1;
   begin
      for Char of Value loop
         if Char = Wide_Wide_Character'Val (10) then
            Result := Result + 1;
         end if;
      end loop;
      return Result;
   end Count_Lines;

   function Value (Item : Model) return Wide_Wide_String is
     (Text.To_Wide_Wide_String (Item.Content));

   function Line_Count (Item : Model) return Positive is
     (Count_Lines (Value (Item)));

   function Boundary_At_Or_Before
     (Value : Wide_Wide_String; Offset : Natural) return Natural
   is
      Limit : constant Natural := Natural'Min (Offset, Value'Length);
      Pos   : Natural := Value'First;
      Last  : Natural := 0;
   begin
      while Pos <= Value'Last and then Pos - Value'First <= Limit loop
         Last := Pos - Value'First;
         Pos := Flyology_TUI.Glyphs.Cluster_Last (Value, Pos) + 1;
      end loop;
      return (if Limit = Value'Length then Limit else Last);
   end Boundary_At_Or_Before;

   procedure Try_Set_Text
     (Item    : in out Model;
      Value   : Wide_Wide_String;
      Success : out Boolean)
   is
      Clean : Text.Unbounded_Wide_Wide_String;
   begin
      Normalize_Bounded
        (Value,
         Item.Max_Code_Points,
         Item.Max_Lines,
         Clean,
         Success);
      if Success then
         Item.Content := Clean;
         Item.Cursor := Text.Length (Clean);
         Item.Anchor := Item.Cursor;
         Item.First_Line := 1;
         Item.First_Segment := 0;
         Item.First_Cell := 0;
         Item.Has_Preferred := False;
         Item.Drag_Active := False;
         for Index in Item.Undo_Items'Range loop
            Item.Undo_Items (Index) := (others => <>);
            Item.Redo_Items (Index) := (others => <>);
         end loop;
         Item.Undo_Count := 0;
         Item.Redo_Count := 0;
      end if;
   end Try_Set_Text;

   function Line_Start
     (Value : Wide_Wide_String; Line : Positive) return Natural;

   procedure Ensure_Visible (Item : in out Model);

   procedure Set_Size (Item : in out Model; Width, Height : Positive) is
   begin
      Validate_Size (Width, Height);
      Item.Columns := Width;
      Item.Rows := Height;
      Item.Drag_Active := False;
      Ensure_Visible (Item);
   end Set_Size;

   function Width (Item : Model) return Positive is (Item.Columns);
   function Height (Item : Model) return Positive is (Item.Rows);

   procedure Set_Wrap (Item : in out Model; Mode : Wrap_Mode) is
   begin
      Item.Wrap := Mode;
      Item.Drag_Active := False;
      if Mode = Soft_Wrap then
         Item.First_Cell := 0;
         Item.First_Segment := Line_Start
           (Value (Item), Item.First_Line);
      else
         Item.First_Segment := Line_Start
           (Value (Item), Item.First_Line);
      end if;
      Ensure_Visible (Item);
   end Set_Wrap;

   function Wrapping (Item : Model) return Wrap_Mode is (Item.Wrap);

   procedure Set_Tab_Width (Item : in out Model; Width : Positive) is
   begin
      Item.Tabs := Width;
      Item.Has_Preferred := False;
      Item.Drag_Active := False;
      Ensure_Visible (Item);
   end Set_Tab_Width;

   function Tab_Width (Item : Model) return Positive is (Item.Tabs);

   procedure Focus (Item : in out Model) is
   begin
      Item.Has_Focus := True;
   end Focus;

   procedure Blur (Item : in out Model) is
   begin
      Item.Has_Focus := False;
      Item.Drag_Active := False;
   end Blur;

   function Focused (Item : Model) return Boolean is (Item.Has_Focus);

   procedure Set_Enabled (Item : in out Model; Enabled : Boolean) is
   begin
      Item.Enabled := Enabled;
      if not Enabled then
         Item.Drag_Active := False;
      end if;
   end Set_Enabled;

   function Is_Enabled (Item : Model) return Boolean is (Item.Enabled);

   procedure Set_Read_Only (Item : in out Model; Read_Only : Boolean) is
   begin
      Item.Read_Only := Read_Only;
      Item.Drag_Active := False;
   end Set_Read_Only;

   function Is_Read_Only (Item : Model) return Boolean is (Item.Read_Only);

   function Line_Start
     (Value : Wide_Wide_String; Line : Positive) return Natural
   is
      Current : Positive := 1;
   begin
      if Line = 1 then
         return 0;
      end if;
      for Offset in 0 .. Value'Length - 1 loop
         if Value (Value'First + Offset) = Wide_Wide_Character'Val (10) then
            Current := Current + 1;
            if Current = Line then
               return Offset + 1;
            end if;
         end if;
      end loop;
      return Value'Length;
   end Line_Start;

   function Line_End
     (Value : Wide_Wide_String; Start : Natural) return Natural
   is
   begin
      for Offset in Start .. Value'Length - 1 loop
         if Value (Value'First + Offset) = Wide_Wide_Character'Val (10) then
            return Offset;
         end if;
      end loop;
      return Value'Length;
   end Line_End;

   function Line_Of
     (Value : Wide_Wide_String; Offset : Natural) return Positive
   is
      Result : Positive := 1;
   begin
      if Value'Length = 0 then
         return Result;
      end if;
      for Pos in 0 .. Natural'Min (Offset, Value'Length) - 1 loop
         if Value (Value'First + Pos) = Wide_Wide_Character'Val (10) then
            Result := Result + 1;
         end if;
      end loop;
      return Result;
   end Line_Of;

   function Cluster_Width
     (Item  : Model;
      Value : Wide_Wide_String;
      First, Last : Natural;
      At_Cell : Natural) return Natural
   is
   begin
      if Value (Value'First + First) = Wide_Wide_Character'Val (9) then
         return Item.Tabs - (At_Cell mod Item.Tabs);
      else
         return Natural'Max
           (1,
            Flyology_TUI.Glyphs.Width_Of
              (Value
                 (Value'First + First .. Value'First + Last)));
      end if;
   end Cluster_Width;

   function Cell_Between
     (Item  : Model;
      Value : Wide_Wide_String;
      First, Last : Natural) return Natural
   is
      Result : Natural := 0;
      Pos    : Natural := First;
   begin
      while Pos < Last loop
         declare
            Stop : constant Natural :=
              Flyology_TUI.Glyphs.Cluster_Last
                (Value, Value'First + Pos) - Value'First;
         begin
            Result := Saturating_Add
              (Result, Cluster_Width (Item, Value, Pos, Stop, Result));
            Pos := Stop + 1;
         end;
      end loop;
      return Result;
   end Cell_Between;

   function Position_At_Offset (Item : Model; Offset : Natural)
      return Position
   is
      Current : constant Wide_Wide_String := Value (Item);
      Safe    : constant Natural := Boundary_At_Or_Before (Current, Offset);
      Line    : constant Positive := Line_Of (Current, Safe);
      Start   : constant Natural := Line_Start (Current, Line);
   begin
      return
        (Line        => Line,
         Code_Point  => Safe - Start,
         Cell_Column => Cell_Between (Item, Current, Start, Safe));
   end Position_At_Offset;

   function Cursor_Position (Item : Model) return Position is
     (Position_At_Offset (Item, Item.Cursor));

   function Cursor_Offset (Item : Model) return Natural is (Item.Cursor);

   procedure Set_Cursor_Offset (Item : in out Model; Offset : Natural) is
      Current : constant Wide_Wide_String := Value (Item);
   begin
      Item.Cursor := Boundary_At_Or_Before (Current, Offset);
      Item.Anchor := Item.Cursor;
      Item.Has_Preferred := False;
      Item.Drag_Active := False;
      Ensure_Visible (Item);
   end Set_Cursor_Offset;

   function Has_Selection (Item : Model) return Boolean is
     (Item.Cursor /= Item.Anchor);

   procedure Selection_Range
     (Item : Model; First, Last : out Natural) is
   begin
      First := Natural'Min (Item.Cursor, Item.Anchor);
      Last := Natural'Max (Item.Cursor, Item.Anchor);
   end Selection_Range;

   procedure Select_All (Item : in out Model) is
   begin
      Item.Anchor := 0;
      Item.Cursor := Text.Length (Item.Content);
      Item.Has_Preferred := False;
      Item.Drag_Active := False;
      Ensure_Visible (Item);
   end Select_All;

   procedure Clear_Selection (Item : in out Model) is
   begin
      Item.Anchor := Item.Cursor;
      Item.Drag_Active := False;
   end Clear_Selection;

   procedure Set_Viewport
     (Item : in out Model; First_Line : Positive; First_Cell : Natural := 0)
   is
   begin
      Item.First_Line := Positive'Min (First_Line, Line_Count (Item));
      Item.First_Segment := Line_Start (Value (Item), Item.First_Line);
      Item.First_Cell := (if Item.Wrap = Soft_Wrap then 0 else First_Cell);
      Item.Drag_Active := False;
   end Set_Viewport;

   function Viewport_Line (Item : Model) return Positive is (Item.First_Line);
   function Viewport_Cell (Item : Model) return Natural is (Item.First_Cell);

   function Line_Start_Offset (Item : Model; Line : Positive) return Natural is
     (Line_Start (Value (Item), Positive'Min (Line, Line_Count (Item))));

   function Line_End_Offset (Item : Model; Line : Positive) return Natural is
     (Line_End
        (Value (Item),
         Line_Start (Value (Item), Positive'Min (Line, Line_Count (Item)))));

   function History_Length
     (Items : Snapshot_Array; Count : Natural) return Natural
   is
      Result : Natural := 0;
   begin
      for Index in 1 .. Count loop
         Result := Result + Text.Length (Items (Index).Content);
      end loop;
      return Result;
   end History_Length;

   function Total_History_Length (Item : Model) return Natural is
     (History_Length (Item.Undo_Items, Item.Undo_Count)
      + History_Length (Item.Redo_Items, Item.Redo_Count));

   procedure Drop_Oldest
     (Items : in out Snapshot_Array; Count : in out Natural) is
   begin
      if Count = 0 then
         return;
      end if;
      for Index in 1 .. Count - 1 loop
         Items (Index) := Items (Index + 1);
      end loop;
      Items (Count) := (others => <>);
      Count := Count - 1;
   end Drop_Oldest;

   procedure Push
     (Item  : Model;
      Items : in out Snapshot_Array;
      Count : in out Natural;
      Value : Snapshot)
   is
      Needed : constant Natural := Text.Length (Value.Content);
   begin
      if Needed > Item.Max_History_Codepoints then
         return;
      end if;
      while Count >= Item.Max_Undo_Entries
        or else History_Length (Items, Count) + Needed >
          Item.Max_History_Codepoints
      loop
         Drop_Oldest (Items, Count);
      end loop;
      Count := Count + 1;
      Items (Count) := Value;
   end Push;

   function Current_Snapshot (Item : Model) return Snapshot is
     (Content => Item.Content, Cursor => Item.Cursor, Anchor => Item.Anchor);

   procedure Push_Undo (Item : in out Model) is
      State : constant Snapshot := Current_Snapshot (Item);
   begin
      Push (Item, Item.Undo_Items, Item.Undo_Count, State);
      for Index in 1 .. Item.Redo_Count loop
         Item.Redo_Items (Index) := (others => <>);
      end loop;
      Item.Redo_Count := 0;
   end Push_Undo;

   function Can_Undo (Item : Model) return Boolean is (Item.Undo_Count > 0);
   function Can_Redo (Item : Model) return Boolean is (Item.Redo_Count > 0);

   procedure Restore (Item : in out Model; State : Snapshot) is
   begin
      Item.Content := State.Content;
      Item.Cursor := State.Cursor;
      Item.Anchor := State.Anchor;
      Item.Has_Preferred := False;
   end Restore;

   procedure Undo (Item : in out Model) is
      Previous : Snapshot;
      State    : constant Snapshot := Current_Snapshot (Item);
   begin
      if Item.Undo_Count = 0 then
         return;
      end if;
      Previous := Item.Undo_Items (Item.Undo_Count);
      Item.Undo_Items (Item.Undo_Count) := (others => <>);
      Item.Undo_Count := Item.Undo_Count - 1;
      Push (Item, Item.Redo_Items, Item.Redo_Count, State);
      while Total_History_Length (Item) > Item.Max_History_Codepoints
        and then Item.Undo_Count > 0
      loop
         Drop_Oldest (Item.Undo_Items, Item.Undo_Count);
      end loop;
      while Total_History_Length (Item) > Item.Max_History_Codepoints
        and then Item.Redo_Count > 0
      loop
         Drop_Oldest (Item.Redo_Items, Item.Redo_Count);
      end loop;
      Restore (Item, Previous);
      Item.Drag_Active := False;
      Ensure_Visible (Item);
   end Undo;

   procedure Redo (Item : in out Model) is
      Following : Snapshot;
      State     : constant Snapshot := Current_Snapshot (Item);
   begin
      if Item.Redo_Count = 0 then
         return;
      end if;
      Following := Item.Redo_Items (Item.Redo_Count);
      Item.Redo_Items (Item.Redo_Count) := (others => <>);
      Item.Redo_Count := Item.Redo_Count - 1;
      Push (Item, Item.Undo_Items, Item.Undo_Count, State);
      while Total_History_Length (Item) > Item.Max_History_Codepoints
        and then Item.Undo_Count > 0
      loop
         Drop_Oldest (Item.Undo_Items, Item.Undo_Count);
      end loop;
      while Total_History_Length (Item) > Item.Max_History_Codepoints
        and then Item.Redo_Count > 0
      loop
         Drop_Oldest (Item.Redo_Items, Item.Redo_Count);
      end loop;
      Restore (Item, Following);
      Item.Drag_Active := False;
      Ensure_Visible (Item);
   end Redo;

   function Next_Boundary
     (Value : Wide_Wide_String; Offset : Natural) return Natural is
   begin
      if Offset >= Value'Length then
         return Value'Length;
      end if;
      return
        Flyology_TUI.Glyphs.Cluster_Last (Value, Value'First + Offset)
        - Value'First + 1;
   end Next_Boundary;

   function Previous_Boundary
     (Value : Wide_Wide_String; Offset : Natural) return Natural
   is
      Pos  : Natural := 0;
      Last : Natural := 0;
   begin
      while Pos < Offset loop
         Last := Pos;
         Pos := Next_Boundary (Value, Pos);
      end loop;
      return Last;
   end Previous_Boundary;

   function Try_Replace
     (Item : in out Model;
      First, Last : Natural;
      Inserted : Text.Unbounded_Wide_Wide_String) return Boolean
   is
      Current : constant Wide_Wide_String := Value (Item);
      function Newline_Count (Value : Wide_Wide_String) return Natural is
         Result : Natural := 0;
      begin
         for Char of Value loop
            if Char = Wide_Wide_Character'Val (10) then
               Result := Result + 1;
            end if;
         end loop;
         return Result;
      end Newline_Count;
   begin
      if First > Last or else Last > Current'Length then
         return False;
      end if;
      declare
         Retained : constant Natural :=
           Current'Length - (Last - First);
         Allowed : constant Natural := Item.Max_Code_Points - Retained;
         Clean : Text.Unbounded_Wide_Wide_String;
         Clean_OK : Boolean;
      begin
         Normalize_Bounded
           (Inserted, Allowed, Item.Max_Lines, Clean, Clean_OK);
         if not Clean_OK then
            return False;
         end if;
         declare
            Clean_Value : constant Wide_Wide_String :=
              Text.To_Wide_Wide_String (Clean);
            Removed_Newlines : constant Natural :=
              (if First = Last then 0
               else Newline_Count
                 (Current
                    (Current'First + First .. Current'First + Last - 1)));
            Base_Lines : constant Positive :=
              Line_Count (Item) - Removed_Newlines;
            Added_Newlines : constant Natural := Newline_Count (Clean_Value);
            Result : Text.Unbounded_Wide_Wide_String;
         begin
            if Added_Newlines > Item.Max_Lines - Base_Lines then
               return False;
            end if;
            if First > 0 then
               Text.Append
                 (Result,
                  Current (Current'First .. Current'First + First - 1));
            end if;
            Text.Append (Result, Clean_Value);
            if Last < Current'Length then
               Text.Append
                 (Result, Current (Current'First + Last .. Current'Last));
            end if;
            Push_Undo (Item);
            Item.Content := Result;
            Item.Cursor := First + Clean_Value'Length;
            Item.Anchor := Item.Cursor;
            Item.Has_Preferred := False;
            Item.Drag_Active := False;
            return True;
         end;
      end;
   end Try_Replace;

   function Insert_Text
     (Item : in out Model;
      Inserted : Text.Unbounded_Wide_Wide_String) return Boolean
   is
      First, Last : Natural;
   begin
      Selection_Range (Item, First, Last);
      return Try_Replace (Item, First, Last, Inserted);
   end Insert_Text;

   procedure Move_To
     (Item : in out Model; Offset : Natural; Selecting : Boolean) is
   begin
      if not Selecting then
         Item.Anchor := Offset;
      end if;
      Item.Cursor := Offset;
   end Move_To;

   function Offset_For_Cell
     (Item : Model;
      Value : Wide_Wide_String;
      Start, Stop, Relative_Cell : Natural;
      Initial_Cell : Natural := 0)
      return Natural
   is
      Pos : Natural := Start;
      Logical_Cell : Natural := Initial_Cell;
      Used : Natural := 0;
   begin
      while Pos < Stop loop
         declare
            Last : constant Natural := Next_Boundary (Value, Pos) - 1;
            Span : constant Natural :=
              Cluster_Width (Item, Value, Pos, Last, Logical_Cell);
         begin
            if Relative_Cell < Saturating_Add (Used, Span) then
               return
                 (if Relative_Cell - Used < Span / 2 + Span mod 2
                  then Pos else Last + 1);
            end if;
            Logical_Cell := Saturating_Add (Logical_Cell, Span);
            Used := Saturating_Add (Used, Span);
            Pos := Last + 1;
         end;
      end loop;
      return Stop;
   end Offset_For_Cell;

   procedure Move_Wrapped
     (Item : in out Model; Row_Delta : Integer; Selecting : Boolean);

   procedure Segment_Containing
     (Item          : Model;
      Line          : Positive;
      Offset        : Natural;
      Segment_First : out Natural;
      Segment_Last  : out Natural);

   procedure Move_Vertical
     (Item : in out Model; Line_Delta : Integer; Selecting : Boolean)
   is
      Current : constant Wide_Wide_String := Value (Item);
      Here    : constant Position := Cursor_Position (Item);
      Target_Line : Positive;
      Start, Stop : Natural;
   begin
      if Item.Wrap = Soft_Wrap then
         Move_Wrapped (Item, Line_Delta, Selecting);
         return;
      end if;
      if not Item.Has_Preferred then
         Item.Preferred_Cell := Here.Cell_Column;
         Item.Has_Preferred := True;
      end if;
      if Line_Delta < 0 then
         declare
            Amount : constant Natural := Natural (-Line_Delta);
         begin
            Target_Line :=
              (if Amount >= Here.Line then 1 else Here.Line - Amount);
         end;
      else
         declare
            Amount : constant Natural := Natural (Line_Delta);
         begin
            Target_Line :=
              (if Amount >= Line_Count (Item) - Here.Line
               then Line_Count (Item) else Here.Line + Amount);
         end;
      end if;
      Start := Line_Start (Current, Target_Line);
      Stop := Line_End (Current, Start);
      Move_To
        (Item,
         Offset_For_Cell (Item, Current, Start, Stop, Item.Preferred_Cell),
         Selecting);
   end Move_Vertical;

   function Gutter_Width (Item : Model) return Positive;

   procedure Ensure_Visible (Item : in out Model) is
      Here : constant Position := Cursor_Position (Item);
      Gutter : constant Positive := Gutter_Width (Item);
      Content_Width : constant Positive :=
        (if Item.Columns > Gutter then Item.Columns - Gutter else 1);
   begin
      if Item.Wrap = Soft_Wrap then
         declare
            First, Last : Natural;
         begin
            Segment_Containing
              (Item,
               Item.First_Line,
               Item.First_Segment,
               First,
               Last);
            Item.First_Segment := First;
         end;
         for Row in 0 .. Item.Rows - 1 loop
            declare
               Line : Positive;
               First, Last : Natural;
               Exists : Boolean;
            begin
               Visible_Segment (Item, Row, Line, First, Last, Exists);
               exit when not Exists;
               if Line = Here.Line
                 and then Item.Cursor >= First
                 and then
                   (Item.Cursor < Last
                    or else
                      (Item.Cursor = Last
                       and then Last = Line_End (Value (Item), First)))
               then
                  return;
               end if;
            end;
         end loop;
         Item.First_Line := Here.Line;
         declare
            Segment_Last : Natural;
         begin
            Segment_Containing
              (Item,
               Here.Line,
               Item.Cursor,
               Item.First_Segment,
               Segment_Last);
         end;
         Item.First_Cell := 0;
         return;
      end if;
      if Here.Line < Item.First_Line then
         Item.First_Line := Here.Line;
      elsif Here.Line - Item.First_Line >= Item.Rows then
         Item.First_Line := Here.Line - Item.Rows + 1;
      end if;
      Item.First_Segment := Line_Start (Value (Item), Item.First_Line);
      if Here.Cell_Column < Item.First_Cell then
         Item.First_Cell := Here.Cell_Column;
      elsif Here.Cell_Column - Item.First_Cell >= Content_Width then
         Item.First_Cell := Here.Cell_Column - Content_Width + 1;
      end if;
   end Ensure_Visible;

   function Handle
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Terminal_Event)
      return Flyology_TUI.Components.Interactions.Update_Result
   is
      Result : Flyology_TUI.Components.Interactions.Update_Result;
      Changed : Boolean := False;
      Current : constant Wide_Wide_String := Value (Item);
      First, Last : Natural;
      Selecting : Boolean := False;
   begin
      if not Item.Enabled or else not Item.Has_Focus then
         return Result;
      end if;
      if Event.Kind = Flyology_TUI.Events.Paste
        or else Event.Kind = Flyology_TUI.Events.Key_Press
      then
         Item.Drag_Active := False;
      end if;
      if Event.Kind = Flyology_TUI.Events.Paste then
         Result.Handled := True;
         if Item.Read_Only then
            return Result;
         end if;
         Changed := Insert_Text
           (Item, Event.Pasted_Text);
         Result.Changed := Changed;
         Result.Rejected := not Changed;
         Ensure_Visible (Item);
         return Result;
      elsif Event.Kind /= Flyology_TUI.Events.Key_Press then
         return Result;
      end if;

      Selecting := Event.Key.Modified.Shift;
      Result.Handled := True;
      case Event.Key.Kind is
         when Flyology_TUI.Events.Text_Key =>
            if Event.Key.Modified.Control then
               declare
                  Key_Length : constant Natural :=
                    Text.Length (Event.Key.Value);
                  Key_Value : Wide_Wide_Character :=
                    Wide_Wide_Character'Val (0);
               begin
                  if Key_Length = 1 then
                     Key_Value := Text.Element (Event.Key.Value, 1);
                  end if;
                  if Key_Length = 1
                    and then (Key_Value = 'a' or else Key_Value = 'A')
                  then
                     Select_All (Item);
                  elsif Key_Length = 1
                    and then (Key_Value = 'z' or else Key_Value = 'Z')
                  then
                     if not Item.Read_Only then
                        if Event.Key.Modified.Shift then
                           Changed := Can_Redo (Item);
                           Redo (Item);
                        else
                           Changed := Can_Undo (Item);
                           Undo (Item);
                        end if;
                        Result.Changed := Changed;
                     end if;
                  elsif Key_Length = 1
                    and then (Key_Value = 'y' or else Key_Value = 'Y')
                  then
                     if not Item.Read_Only then
                        Changed := Can_Redo (Item);
                        Redo (Item);
                        Result.Changed := Changed;
                     end if;
                  else
                     Result.Handled := False;
                  end if;
               end;
            elsif not Event.Key.Modified.Super then
               if not Item.Read_Only then
                  Changed := Insert_Text
                    (Item, Event.Key.Value);
                  Result.Changed := Changed;
                  Result.Rejected := not Changed;
               end if;
            else
               Result.Handled := False;
            end if;
         when Flyology_TUI.Events.Enter_Key =>
            if not Item.Read_Only then
               Changed := Insert_Text
                 (Item,
                  Text.To_Unbounded_Wide_Wide_String
                    ((1 => Wide_Wide_Character'Val (10))));
               Result.Changed := Changed;
               Result.Rejected := not Changed;
            end if;
         when Flyology_TUI.Events.Tab_Key =>
            if not Item.Read_Only then
               Changed := Insert_Text
                 (Item,
                  Text.To_Unbounded_Wide_Wide_String
                    ((1 => Wide_Wide_Character'Val (9))));
               Result.Changed := Changed;
               Result.Rejected := not Changed;
            end if;
         when Flyology_TUI.Events.Backspace_Key =>
            if not Item.Read_Only then
               Selection_Range (Item, First, Last);
               if First = Last and then First > 0 then
                  First := Previous_Boundary (Current, First);
               end if;
               if First < Last then
                  Result.Changed := Try_Replace
                    (Item, First, Last, Text.Null_Unbounded_Wide_Wide_String);
               end if;
            end if;
         when Flyology_TUI.Events.Delete_Key =>
            if not Item.Read_Only then
               Selection_Range (Item, First, Last);
               if First = Last and then Last < Current'Length then
                  Last := Next_Boundary (Current, Last);
               end if;
               if First < Last then
                  Result.Changed := Try_Replace
                    (Item, First, Last, Text.Null_Unbounded_Wide_Wide_String);
               end if;
            end if;
         when Flyology_TUI.Events.Arrow_Left_Key =>
            if Has_Selection (Item) and then not Selecting then
               Selection_Range (Item, First, Last);
               Move_To (Item, First, False);
            else
               Move_To
                 (Item,
                  Previous_Boundary (Current, Item.Cursor),
                  Selecting);
            end if;
            Item.Has_Preferred := False;
         when Flyology_TUI.Events.Arrow_Right_Key =>
            if Has_Selection (Item) and then not Selecting then
               Selection_Range (Item, First, Last);
               Move_To (Item, Last, False);
            else
               Move_To (Item, Next_Boundary (Current, Item.Cursor), Selecting);
            end if;
            Item.Has_Preferred := False;
         when Flyology_TUI.Events.Arrow_Up_Key =>
            Move_Vertical (Item, -1, Selecting);
         when Flyology_TUI.Events.Arrow_Down_Key =>
            Move_Vertical (Item, 1, Selecting);
         when Flyology_TUI.Events.Page_Up_Key =>
            Move_Vertical (Item, -Integer (Item.Rows), Selecting);
         when Flyology_TUI.Events.Page_Down_Key =>
            Move_Vertical (Item, Integer (Item.Rows), Selecting);
         when Flyology_TUI.Events.Home_Key =>
            Move_To
              (Item,
               Line_Start (Current, Cursor_Position (Item).Line),
               Selecting);
            Item.Has_Preferred := False;
         when Flyology_TUI.Events.End_Key =>
            declare
               Start : constant Natural :=
                 Line_Start (Current, Cursor_Position (Item).Line);
            begin
               Move_To (Item, Line_End (Current, Start), Selecting);
            end;
            Item.Has_Preferred := False;
         when others =>
            Result.Handled := False;
      end case;
      Ensure_Visible (Item);
      return Result;
   end Handle;

   function Gutter_Width (Item : Model) return Positive is
      Value : Natural := Item.Max_Lines;
      Digit_Count : Positive := 1;
   begin
      while Value >= 10 loop
         Value := Value / 10;
         Digit_Count := Digit_Count + 1;
      end loop;
      return Digit_Count + 1;
   end Gutter_Width;

   function Gutter_Columns (Item : Model) return Positive is
     (Gutter_Width (Item));

   function Wrapped_End
     (Item  : Model;
      Value : Wide_Wide_String;
      First, Last, Available : Natural) return Natural
   is
      Position : Natural := First;
      Logical_Cell : Natural :=
        Cell_Between
          (Item,
           Value,
           Line_Start (Value, Line_Of (Value, First)),
           First);
      Used : Natural := 0;
   begin
      if First = Last or else Available = 0 then
         return Last;
      end if;
      while Position < Last loop
         declare
            Cluster_Last : constant Natural :=
              Next_Boundary (Value, Position) - 1;
            Span : constant Natural :=
              Cluster_Width
                (Item, Value, Position, Cluster_Last, Logical_Cell);
         begin
            exit when Used > 0
              and then Span > Available - Natural'Min (Used, Available);
            Logical_Cell := Saturating_Add (Logical_Cell, Span);
            Used := Saturating_Add (Used, Span);
            Position := Cluster_Last + 1;
            exit when Used >= Available;
         end;
      end loop;
      return Position;
   end Wrapped_End;

   procedure Segment_Containing
     (Item          : Model;
      Line          : Positive;
      Offset        : Natural;
      Segment_First : out Natural;
      Segment_Last  : out Natural)
   is
      Current : constant Wide_Wide_String := Value (Item);
      Gutter : constant Positive := Gutter_Width (Item);
      Available : constant Natural :=
        (if Item.Columns > Gutter then Item.Columns - Gutter else 0);
      Line_Last : constant Natural :=
        Line_End (Current, Line_Start (Current, Line));
      First : Natural := Line_Start (Current, Line);
      Last  : Natural;
   begin
      loop
         Last := Wrapped_End
           (Item, Current, First, Line_Last, Available);
         if Offset < Last or else Last = Line_Last then
            Segment_First := First;
            Segment_Last := Last;
            return;
         end if;
         First := Last;
      end loop;
   end Segment_Containing;

   function Previous_Segment_First
     (Item : Model; Line : Positive; Before : Natural) return Natural
   is
      Current : constant Wide_Wide_String := Value (Item);
      Gutter : constant Positive := Gutter_Width (Item);
      Available : constant Natural :=
        (if Item.Columns > Gutter then Item.Columns - Gutter else 0);
      First : Natural := Line_Start (Current, Line);
      Previous : Natural := First;
      Last : Natural;
      Line_Last : constant Natural := Line_End (Current, First);
   begin
      while First < Before loop
         Previous := First;
         Last := Wrapped_End (Item, Current, First, Line_Last, Available);
         exit when Last >= Before or else Last = First;
         First := Last;
      end loop;
      return Previous;
   end Previous_Segment_First;

   procedure Move_Wrapped
     (Item : in out Model; Row_Delta : Integer; Selecting : Boolean)
   is
      Current : constant Wide_Wide_String := Value (Item);
      Here : constant Position := Cursor_Position (Item);
      Target_Line : Positive := Here.Line;
      First, Last : Natural;
      Amount : Natural :=
        (if Row_Delta < 0 then Natural (-Row_Delta)
         else Natural (Row_Delta));
      Moving_Up : constant Boolean := Row_Delta < 0;
   begin
      Segment_Containing
        (Item, Here.Line, Item.Cursor, First, Last);
      if not Item.Has_Preferred then
         Item.Preferred_Cell :=
           Here.Cell_Column
           - Position_At_Offset (Item, First).Cell_Column;
         Item.Has_Preferred := True;
      end if;
      while Amount > 0 loop
         if Moving_Up then
            if First > Line_Start (Current, Target_Line) then
               First := Previous_Segment_First (Item, Target_Line, First);
               Last := Wrapped_End
                 (Item,
                  Current,
                  First,
                  Line_End (Current, First),
                  (if Item.Columns > Gutter_Width (Item)
                   then Item.Columns - Gutter_Width (Item) else 0));
            elsif Target_Line > 1 then
               Target_Line := Target_Line - 1;
               First := Previous_Segment_First
                 (Item,
                  Target_Line,
                  Line_End
                    (Current, Line_Start (Current, Target_Line)));
               Last := Wrapped_End
                 (Item,
                  Current,
                  First,
                  Line_End (Current, First),
                  (if Item.Columns > Gutter_Width (Item)
                   then Item.Columns - Gutter_Width (Item) else 0));
            else
               exit;
            end if;
         else
            if Last < Line_End (Current, First) then
               First := Last;
               Last := Wrapped_End
                 (Item,
                  Current,
                  First,
                  Line_End (Current, First),
                  (if Item.Columns > Gutter_Width (Item)
                   then Item.Columns - Gutter_Width (Item) else 0));
            elsif Target_Line < Line_Count (Item) then
               Target_Line := Target_Line + 1;
               First := Line_Start (Current, Target_Line);
               Last := Wrapped_End
                 (Item,
                  Current,
                  First,
                  Line_End (Current, First),
                  (if Item.Columns > Gutter_Width (Item)
                   then Item.Columns - Gutter_Width (Item) else 0));
            else
               exit;
            end if;
         end if;
         Amount := Amount - 1;
      end loop;
      declare
         Initial_Cell : constant Natural :=
           Position_At_Offset (Item, First).Cell_Column;
      begin
         Move_To
           (Item,
            Offset_For_Cell
              (Item,
               Current,
               First,
               Last,
               Item.Preferred_Cell,
               Initial_Cell),
            Selecting);
      end;
   end Move_Wrapped;

   procedure Visible_Segment
     (Item          : Model;
      Row           : Natural;
      Line          : out Positive;
      Segment_First : out Natural;
      Segment_Last  : out Natural;
      Exists        : out Boolean)
   is
      Current : constant Wide_Wide_String := Value (Item);
      Gutter : constant Positive := Gutter_Width (Item);
      Available : constant Natural :=
        (if Item.Columns > Gutter then Item.Columns - Gutter else 0);
      Current_Line : Positive := Item.First_Line;
      First : Natural :=
        (if Item.Wrap = Soft_Wrap
         then Natural'Max
           (Line_Start (Current, Current_Line),
            Natural'Min
              (Line_End
                 (Current, Line_Start (Current, Current_Line)),
               Boundary_At_Or_Before (Current, Item.First_Segment)))
         else Line_Start (Current, Current_Line));
      Last  : Natural;
   begin
      for Visual_Row in 0 .. Row loop
         if Current_Line > Line_Count (Item) then
            Exists := False;
            Line := Line_Count (Item);
            Segment_First := Current'Length;
            Segment_Last := Current'Length;
            return;
         end if;
         Last := Line_End (Current, First);
         if Item.Wrap = Soft_Wrap then
            Last := Wrapped_End
              (Item,
               Current,
               First,
               Line_End (Current, First),
               Available);
         end if;
         if Visual_Row = Row then
            Exists := True;
            Line := Current_Line;
            Segment_First := First;
            Segment_Last := Last;
            return;
         end if;
         if Last < Line_End (Current, First) then
            First := Last;
         else
            Current_Line := Current_Line + 1;
            if Current_Line <= Line_Count (Item) then
               First := Line_Start (Current, Current_Line);
            end if;
         end if;
      end loop;
      Exists := False;
      Line := Line_Count (Item);
      Segment_First := Current'Length;
      Segment_Last := Current'Length;
   end Visible_Segment;

   function Offset_At_Mouse
     (Item : Model; X, Y : Natural) return Natural
   is
      Current : constant Wide_Wide_String := Value (Item);
      Line : Positive;
      Start, Stop : Natural;
      Exists : Boolean;
      Gutter : constant Positive := Gutter_Width (Item);
      Segment_Cell : Natural;
      Relative_Cell : Natural;
   begin
      Visible_Segment (Item, Y, Line, Start, Stop, Exists);
      if not Exists then
         return Current'Length;
      end if;
      Segment_Cell :=
        Cell_Between
          (Item, Current, Line_Start (Current, Line), Start);
      Relative_Cell :=
        (if X < Gutter then 0
         elsif Item.Wrap = Soft_Wrap
         then X - Gutter
         else Saturating_Add (X - Gutter, Item.First_Cell));
      return Offset_For_Cell
        (Item, Current, Start, Stop, Relative_Cell, Segment_Cell);
   end Offset_At_Mouse;

   procedure Scroll_Viewport
     (Item       : in out Model;
      Direction  : Integer;
      Amount     : Natural;
      Did_Change : out Boolean)
   is
      Current : constant Wide_Wide_String := Value (Item);
      Before_Line : constant Positive := Item.First_Line;
      Before_Segment : constant Natural := Item.First_Segment;
      Remaining : Natural := Amount;
      Available : constant Natural :=
        (if Item.Columns > Gutter_Width (Item)
         then Item.Columns - Gutter_Width (Item) else 0);
   begin
      if Item.Wrap = No_Wrap then
         if Direction > 0 then
            if Amount >= Line_Count (Item) - Item.First_Line then
               Item.First_Line := Line_Count (Item);
            else
               Item.First_Line := Item.First_Line + Amount;
            end if;
         else
            Item.First_Line := Item.First_Line -
              Natural'Min (Item.First_Line - 1, Amount);
         end if;
         Item.First_Segment := Line_Start (Current, Item.First_Line);
      else
         while Remaining > 0 loop
            declare
               Line_First : constant Natural :=
                 Line_Start (Current, Item.First_Line);
               Line_Last : constant Natural :=
                 Line_End (Current, Line_First);
               Segment_Last : constant Natural :=
                 Wrapped_End
                   (Item,
                    Current,
                    Item.First_Segment,
                    Line_Last,
                    Available);
            begin
               if Direction > 0 then
                  if Segment_Last < Line_Last then
                     Item.First_Segment := Segment_Last;
                  elsif Item.First_Line < Line_Count (Item) then
                     Item.First_Line := Item.First_Line + 1;
                     Item.First_Segment :=
                       Line_Start (Current, Item.First_Line);
                  else
                     exit;
                  end if;
               elsif Item.First_Segment > Line_First then
                  Item.First_Segment := Previous_Segment_First
                    (Item, Item.First_Line, Item.First_Segment);
               elsif Item.First_Line > 1 then
                  Item.First_Line := Item.First_Line - 1;
                  Item.First_Segment := Previous_Segment_First
                    (Item,
                     Item.First_Line,
                     Line_End
                       (Current, Line_Start (Current, Item.First_Line)));
               else
                  exit;
               end if;
               Remaining := Remaining - 1;
            end;
         end loop;
      end if;
      Did_Change :=
        Item.First_Line /= Before_Line
        or else Item.First_Segment /= Before_Segment;
   end Scroll_Viewport;

   function Handle
     (Item  : in out Model;
      Event : Flyology_TUI.Mouse.Local_Event)
      return Flyology_TUI.Components.Interactions.Update_Result
   is
      Result : Flyology_TUI.Components.Interactions.Update_Result;
      Inside : constant Boolean :=
        Event.X >= 0 and then Event.Y >= 0
        and then Event.X < Integer (Item.Columns)
        and then Event.Y < Integer (Item.Rows);
      function Magnitude (Value : Integer) return Natural is
        (if Value = Integer'First then Natural (Integer'Last)
         else Natural (abs Value));
   begin
      if Event.Action = Flyology_TUI.Events.Mouse_Release
        and then Item.Capturing
        and then Event.Button = Flyology_TUI.Events.Left_Button
      then
         declare
            Before : constant Natural := Item.Cursor;
         begin
            if Inside and then Item.Drag_Active and then Item.Enabled then
               Item.Cursor := Offset_At_Mouse
                 (Item, Natural (Event.X), Natural (Event.Y));
            end if;
            Item.Capturing := False;
            Item.Drag_Active := False;
            Ensure_Visible (Item);
            return
              (Handled => True,
               Changed => Item.Cursor /= Before,
               Capture =>
                 Flyology_TUI.Components.Interactions.Release_Capture,
               others => <>);
         end;
      elsif not Item.Enabled then
         return Result;
      elsif Event.Action = Flyology_TUI.Events.Mouse_Wheel and then Inside then
         if Event.Wheel_X = 0 and then Event.Wheel_Y = 0 then
            return Result;
         end if;
         Result.Handled := True;
         if Event.Wheel_Y /= 0 then
            declare
               Changed : Boolean;
            begin
               Scroll_Viewport
                 (Item,
                  (if Event.Wheel_Y < 0 then 1 else -1),
                  Magnitude (Event.Wheel_Y),
                  Changed);
               Result.Changed := Result.Changed or else Changed;
            end;
         end if;
         if Item.Wrap = No_Wrap and then Event.Wheel_X /= 0 then
            declare
               Before : constant Natural := Item.First_Cell;
            begin
               if Event.Wheel_X < 0 then
                  declare
                     Amount : constant Natural := Magnitude (Event.Wheel_X);
                  begin
                     if Amount > Natural'Last - Item.First_Cell then
                        Item.First_Cell := Natural'Last;
                     else
                        Item.First_Cell := Item.First_Cell + Amount;
                     end if;
                  end;
               elsif Event.Wheel_X > 0 then
                  Item.First_Cell :=
                    Item.First_Cell
                    - Natural'Min
                        (Item.First_Cell, Natural (Event.Wheel_X));
               end if;
               Result.Changed :=
                 Result.Changed or else Item.First_Cell /= Before;
            end;
         elsif Item.Wrap = Soft_Wrap
           and then Event.Wheel_Y = 0
           and then Event.Wheel_X /= 0
         then
            Result.Handled := False;
         end if;
         return Result;
      elsif Event.Button = Flyology_TUI.Events.Left_Button
        and then Event.Action = Flyology_TUI.Events.Mouse_Click
        and then Inside
      then
         Item.Has_Focus := True;
         Item.Cursor := Offset_At_Mouse
           (Item, Natural (Event.X), Natural (Event.Y));
         if not Event.Modified.Shift then
            Item.Anchor := Item.Cursor;
         end if;
         Item.Capturing := True;
         Item.Drag_Active := True;
         Item.Has_Preferred := False;
         return
           (Handled => True,
            Changed => True,
            Focus_Requested => True,
            Capture => Flyology_TUI.Components.Interactions.Acquire_Capture,
            others => <>);
      elsif Event.Action = Flyology_TUI.Events.Mouse_Drag
        and then Item.Capturing
        and then Item.Drag_Active
        and then Event.Button = Flyology_TUI.Events.Left_Button
      then
         declare
            Clamped_X : constant Natural := Natural
              (Integer'Max
                 (0, Integer'Min (Integer (Item.Columns) - 1, Event.X)));
            Clamped_Y : constant Natural := Natural
              (Integer'Max
                 (0, Integer'Min (Integer (Item.Rows) - 1, Event.Y)));
         begin
            Item.Cursor := Offset_At_Mouse (Item, Clamped_X, Clamped_Y);
         end;
         Ensure_Visible (Item);
         return (Handled => True, Changed => True, others => <>);
      end if;
      return Result;
   end Handle;

   procedure Update
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Terminal_Event)
   is
      Discard : constant Flyology_TUI.Components.Interactions.Update_Result :=
        Handle (Item, Event);
      pragma Unreferenced (Discard);
   begin
      null;
   end Update;

   procedure Update
     (Item  : in out Model;
      Event : Flyology_TUI.Mouse.Local_Event)
   is
      Discard : constant Flyology_TUI.Components.Interactions.Update_Result :=
        Handle (Item, Event);
      pragma Unreferenced (Discard);
   begin
      null;
   end Update;

   function Image (Value : Positive) return Wide_Wide_String is
      Narrow : constant String := Positive'Image (Value);
      Result : Wide_Wide_String (1 .. Narrow'Length - 1);
   begin
      for Index in Result'Range loop
         Result (Index) := Wide_Wide_Character'Val
           (Character'Pos (Narrow (Narrow'First + Index)));
      end loop;
      return Result;
   end Image;

   function Render
     (Item : Model; Look : Appearance)
      return Flyology_TUI.Surfaces.Surface
   is
      Result : Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.Create (Item.Columns, Item.Rows);
      Current : constant Wide_Wide_String := Value (Item);
      Gutter : constant Positive := Gutter_Width (Item);
      Content_Width : constant Natural :=
        (if Item.Columns > Gutter then Item.Columns - Gutter else 0);
      Cursor_Line : constant Positive := Cursor_Position (Item).Line;
      Sel_First, Sel_Last : Natural;
      Base : constant Flyology_TUI.Styles.Style :=
        (if not Item.Enabled then Look.Disabled
         elsif Item.Read_Only then Look.Read_Only
         else Look.Text);
   begin
      Selection_Range (Item, Sel_First, Sel_Last);
      for Row in 0 .. Item.Rows - 1 loop
         declare
            Line : Positive;
            Start, Stop : Natural;
            Exists : Boolean;
         begin
            Visible_Segment (Item, Row, Line, Start, Stop, Exists);
            exit when not Exists;
            if Line = Cursor_Line and then Item.Enabled then
               for X in 0 .. Item.Columns - 1 loop
                  Result.Put (X, Row, " ", Look.Current_Line);
               end loop;
            end if;
            declare
               Number : constant Wide_Wide_String := Image (Line);
               Number_X : constant Natural :=
                 (if Gutter - 1 > Number'Length
                  then Gutter - 1 - Number'Length else 0);
               Pos   : Natural := Start;
               Segment_Cell : constant Natural :=
                 Cell_Between
                   (Item, Current, Line_Start (Current, Line), Start);
               Cell  : Natural := Segment_Cell;
            begin
               if Start = Line_Start (Current, Line)
                 and then Number_X < Item.Columns
               then
                  Result.Write
                    (Number_X,
                     Row,
                     Number,
                     (if Item.Enabled then Look.Gutter else Look.Disabled));
               end if;
               while Pos < Stop and then Content_Width > 0 loop
                  declare
                     Last : constant Natural :=
                       Next_Boundary (Current, Pos) - 1;
                     Span : constant Natural :=
                       Cluster_Width (Item, Current, Pos, Last, Cell);
                     Origin : constant Natural :=
                       (if Item.Wrap = Soft_Wrap
                        then Segment_Cell else Item.First_Cell);
                     Is_Visible : constant Boolean := Cell >= Origin;
                     Visible_Cell : constant Natural :=
                       (if Is_Visible then Cell - Origin else 0);
                     Style : constant Flyology_TUI.Styles.Style :=
                       (if not Item.Enabled then Look.Disabled
                        elsif Pos < Sel_Last and then Last + 1 > Sel_First
                        then Look.Selection else Base);
                  begin
                     if Is_Visible and then Visible_Cell < Content_Width
                     then
                        if Current (Current'First + Pos) =
                          Wide_Wide_Character'Val (9)
                        then
                           for Index in 0 .. Natural'Min
                             (Span, Content_Width - Visible_Cell) - 1
                           loop
                              Result.Put
                                (Gutter + Visible_Cell + Index,
                                 Row, " ", Style);
                           end loop;
                        elsif Span <= Content_Width - Visible_Cell
                        then
                           Result.Put
                             (Gutter + Visible_Cell,
                              Row,
                              Current
                                (Current'First + Pos .. Current'First + Last),
                              Style);
                        end if;
                     end if;
                     Cell := Saturating_Add (Cell, Span);
                     Pos := Last + 1;
                  end;
               end loop;
            end;
         end;
      end loop;
      if Current'Length = 0 and then Content_Width > 0 then
         Result.Write
           (Gutter, 0, Text.To_Wide_Wide_String (Item.Placeholder),
            (if not Item.Enabled then Look.Disabled
             elsif Item.Read_Only then Look.Read_Only
             else Look.Placeholder));
      end if;
      if Item.Enabled and then Item.Has_Focus then
         declare
            Here : constant Position := Cursor_Position (Item);
            Cursor_Row : Natural := 0;
            Cursor_X : Natural := 0;
            Cursor_Visible : Boolean := False;
         begin
            for Candidate_Row in 0 .. Item.Rows - 1 loop
               declare
                  Line : Positive;
                  Start, Stop : Natural;
                  Exists : Boolean;
               begin
                  Visible_Segment
                    (Item,
                     Candidate_Row,
                     Line,
                     Start,
                     Stop,
                     Exists);
                  exit when not Exists;
                  if Line = Here.Line
                    and then Item.Cursor >= Start
                    and then
                      (Item.Cursor < Stop
                       or else
                         (Item.Cursor = Stop
                          and then Stop = Line_End (Current, Start)))
                  then
                     declare
                        Start_Cell : constant Natural :=
                          Position_At_Offset (Item, Start).Cell_Column;
                        Origin : constant Natural :=
                          (if Item.Wrap = Soft_Wrap
                           then Start_Cell else Item.First_Cell);
                        Relative_Cell : constant Natural :=
                          (if Here.Cell_Column >= Origin
                           then Here.Cell_Column - Origin else 0);
                     begin
                        Cursor_Row := Candidate_Row;
                        if Here.Cell_Column >= Origin
                          and then Relative_Cell <= Natural'Last - Gutter
                        then
                           Cursor_X := Gutter + Relative_Cell;
                           Cursor_Visible := Cursor_X < Item.Columns;
                        end if;
                     end;
                     exit;
                  end if;
               end;
            end loop;
            if Cursor_Visible then
               declare
                  Existing : constant Flyology_TUI.Surfaces.Cell :=
                    Result.Element
                      (Cursor_X, Cursor_Row);
                  Glyph : constant Wide_Wide_String :=
                    Text.To_Wide_Wide_String (Existing.Glyph);
               begin
                  if not Existing.Continuation then
                     Result.Put
                       (Cursor_X,
                        Cursor_Row,
                        (if Glyph'Length = 0 then " " else Glyph),
                        Look.Cursor);
                  end if;
               end;
            end if;
         end;
      end if;
      return Result;
   end Render;

   function Render
     (Item : Model; Theme : Flyology_TUI.Themes.Theme)
      return Flyology_TUI.Surfaces.Surface is
     (Render (Item, From_Theme (Theme)));

end Flyology_TUI.Components.Text_Areas;
