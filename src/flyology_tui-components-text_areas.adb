with Flyology_TUI.Glyphs;

package body Flyology_TUI.Components.Text_Areas is
   use type Flyology_TUI.Events.Key_Kind;
   use type Flyology_TUI.Events.Mouse_Action;
   use type Flyology_TUI.Events.Mouse_Button;
   use type Flyology_TUI.Events.Terminal_Event_Kind;

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
      Result.Columns := Width;
      Result.Rows := Height;
      Result.Placeholder := Text.To_Unbounded_Wide_Wide_String (Placeholder);
      return Result;
   end Create;

   function Normalize (Value : Wide_Wide_String) return Wide_Wide_String is
      Result : Text.Unbounded_Wide_Wide_String;
      Index  : Natural := Value'First;
   begin
      while Index <= Value'Last loop
         if Value (Index) = Wide_Wide_Character'Val (13) then
            Text.Append (Result, Wide_Wide_Character'Val (10));
            if Index < Value'Last
              and then Value (Index + 1) = Wide_Wide_Character'Val (10)
            then
               Index := Index + 1;
            end if;
         else
            Text.Append (Result, Value (Index));
         end if;
         Index := Index + 1;
      end loop;
      return Text.To_Wide_Wide_String (Result);
   end Normalize;

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
      Clean : constant Wide_Wide_String := Normalize (Value);
   begin
      Success :=
        Clean'Length <= Item.Max_Code_Points
        and then Count_Lines (Clean) <= Item.Max_Lines;
      if Success then
         Item.Content := Text.To_Unbounded_Wide_Wide_String (Clean);
         Item.Cursor := Clean'Length;
         Item.Anchor := Item.Cursor;
         Item.First_Line := 1;
         Item.First_Cell := 0;
         Item.Has_Preferred := False;
         for Index in Item.Undo_Items'Range loop
            Item.Undo_Items (Index) := (others => <>);
            Item.Redo_Items (Index) := (others => <>);
         end loop;
         Item.Undo_Count := 0;
         Item.Redo_Count := 0;
      end if;
   end Try_Set_Text;

   procedure Set_Size (Item : in out Model; Width, Height : Positive) is
   begin
      Item.Columns := Width;
      Item.Rows := Height;
   end Set_Size;

   function Width (Item : Model) return Positive is (Item.Columns);
   function Height (Item : Model) return Positive is (Item.Rows);

   procedure Set_Wrap (Item : in out Model; Mode : Wrap_Mode) is
   begin
      Item.Wrap := Mode;
      if Mode = Soft_Wrap then
         Item.First_Cell := 0;
      end if;
   end Set_Wrap;

   function Wrapping (Item : Model) return Wrap_Mode is (Item.Wrap);

   procedure Set_Tab_Width (Item : in out Model; Width : Positive) is
   begin
      Item.Tabs := Width;
      Item.Has_Preferred := False;
   end Set_Tab_Width;

   function Tab_Width (Item : Model) return Positive is (Item.Tabs);

   procedure Focus (Item : in out Model) is
   begin
      Item.Has_Focus := True;
   end Focus;

   procedure Blur (Item : in out Model) is
   begin
      Item.Has_Focus := False;
   end Blur;

   function Focused (Item : Model) return Boolean is (Item.Has_Focus);

   procedure Set_Enabled (Item : in out Model; Enabled : Boolean) is
   begin
      Item.Enabled := Enabled;
   end Set_Enabled;

   function Is_Enabled (Item : Model) return Boolean is (Item.Enabled);

   procedure Set_Read_Only (Item : in out Model; Read_Only : Boolean) is
   begin
      Item.Read_Only := Read_Only;
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
            Result := Result + Cluster_Width (Item, Value, Pos, Stop, Result);
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
   end Select_All;

   procedure Clear_Selection (Item : in out Model) is
   begin
      Item.Anchor := Item.Cursor;
   end Clear_Selection;

   procedure Set_Viewport
     (Item : in out Model; First_Line : Positive; First_Cell : Natural := 0)
   is
   begin
      Item.First_Line := Positive'Min (First_Line, Line_Count (Item));
      Item.First_Cell := (if Item.Wrap = Soft_Wrap then 0 else First_Cell);
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
      Inserted : Wide_Wide_String) return Boolean
   is
      Current : constant Wide_Wide_String := Value (Item);
      Clean   : constant Wide_Wide_String := Normalize (Inserted);
      Result  : Text.Unbounded_Wide_Wide_String;
      New_Length : constant Natural := Current'Length - (Last - First)
        + Clean'Length;
   begin
      if First > Last or else Last > Current'Length
        or else New_Length > Item.Max_Code_Points
      then
         return False;
      end if;
      if First > 0 then
         Text.Append
           (Result, Current (Current'First .. Current'First + First - 1));
      end if;
      Text.Append (Result, Clean);
      if Last < Current'Length then
         Text.Append
           (Result, Current (Current'First + Last .. Current'Last));
      end if;
      if Count_Lines (Text.To_Wide_Wide_String (Result)) > Item.Max_Lines then
         return False;
      end if;
      Push_Undo (Item);
      Item.Content := Result;
      Item.Cursor := First + Clean'Length;
      Item.Anchor := Item.Cursor;
      Item.Has_Preferred := False;
      return True;
   end Try_Replace;

   function Insert_Text
     (Item : in out Model; Inserted : Wide_Wide_String) return Boolean
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
      Start, Stop, Cell : Natural;
      Initial_Cell : Natural := 0)
      return Natural
   is
      Pos : Natural := Start;
      Cell_At : Natural := Initial_Cell;
   begin
      while Pos < Stop loop
         declare
            Last : constant Natural := Next_Boundary (Value, Pos) - 1;
            Span : constant Natural :=
              Cluster_Width (Item, Value, Pos, Last, Cell_At);
         begin
            if Cell < Cell_At + Span then
               return
                 (if Cell - Cell_At < (Span + 1) / 2
                  then Pos else Last + 1);
            end if;
            Cell_At := Cell_At + Span;
            Pos := Last + 1;
         end;
      end loop;
      return Stop;
   end Offset_For_Cell;

   procedure Move_Vertical
     (Item : in out Model; Line_Delta : Integer; Selecting : Boolean)
   is
      Current : constant Wide_Wide_String := Value (Item);
      Here    : constant Position := Cursor_Position (Item);
      Target_Line : Positive;
      Start, Stop : Natural;
   begin
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
      if Here.Line < Item.First_Line then
         Item.First_Line := Here.Line;
      elsif Here.Line - Item.First_Line >= Item.Rows then
         Item.First_Line := Here.Line - Item.Rows + 1;
      end if;
      if Item.Wrap = No_Wrap then
         if Here.Cell_Column < Item.First_Cell then
            Item.First_Cell := Here.Cell_Column;
         elsif Here.Cell_Column - Item.First_Cell >= Content_Width then
            Item.First_Cell := Here.Cell_Column - Content_Width + 1;
         end if;
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
      if Event.Kind = Flyology_TUI.Events.Paste then
         Result.Handled := True;
         if Item.Read_Only then
            return Result;
         end if;
         Changed := Insert_Text
           (Item, Text.To_Wide_Wide_String (Event.Pasted_Text));
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
                  Key_Value : constant Wide_Wide_String :=
                    Text.To_Wide_Wide_String (Event.Key.Value);
               begin
                  if Key_Value = "a" or else Key_Value = "A" then
                     Select_All (Item);
                  elsif (Key_Value = "z" or else Key_Value = "Z")
                    and then not Item.Read_Only
                  then
                     if Event.Key.Modified.Shift then
                        Changed := Can_Redo (Item);
                        Redo (Item);
                     else
                        Changed := Can_Undo (Item);
                        Undo (Item);
                     end if;
                     Result.Changed := Changed;
                  elsif (Key_Value = "y" or else Key_Value = "Y")
                    and then not Item.Read_Only
                  then
                     Changed := Can_Redo (Item);
                     Redo (Item);
                     Result.Changed := Changed;
                  else
                     Result.Handled := False;
                  end if;
               end;
            elsif not Event.Key.Modified.Super and then not Item.Read_Only then
               Changed := Insert_Text
                 (Item, Text.To_Wide_Wide_String (Event.Key.Value));
               Result.Changed := Changed;
               Result.Rejected := not Changed;
            else
               Result.Handled := False;
            end if;
         when Flyology_TUI.Events.Enter_Key =>
            if not Item.Read_Only then
               Changed := Insert_Text
                 (Item, (1 => Wide_Wide_Character'Val (10)));
               Result.Changed := Changed;
               Result.Rejected := not Changed;
            end if;
         when Flyology_TUI.Events.Tab_Key =>
            if not Item.Read_Only then
               Changed := Insert_Text
                 (Item, (1 => Wide_Wide_Character'Val (9)));
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
                  Result.Changed := Try_Replace (Item, First, Last, "");
               end if;
            end if;
         when Flyology_TUI.Events.Delete_Key =>
            if not Item.Read_Only then
               Selection_Range (Item, First, Last);
               if First = Last and then Last < Current'Length then
                  Last := Next_Boundary (Current, Last);
               end if;
               if First < Last then
                  Result.Changed := Try_Replace (Item, First, Last, "");
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
            exit when Used > 0 and then Used + Span > Available;
            Logical_Cell := Logical_Cell + Span;
            Used := Used + Span;
            Position := Cluster_Last + 1;
            exit when Used >= Available;
         end;
      end loop;
      return Position;
   end Wrapped_End;

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
      First : Natural := Line_Start (Current, Current_Line);
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
      Cell : Natural;
   begin
      Visible_Segment (Item, Y, Line, Start, Stop, Exists);
      if not Exists then
         return Current'Length;
      end if;
      Segment_Cell :=
        Cell_Between
          (Item, Current, Line_Start (Current, Line), Start);
      Cell :=
        (if X < Gutter then Segment_Cell
         elsif Item.Wrap = Soft_Wrap then Segment_Cell + X - Gutter
         else X - Gutter + Item.First_Cell);
      return Offset_For_Cell
        (Item, Current, Start, Stop, Cell, Segment_Cell);
   end Offset_At_Mouse;

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
      then
         if Inside then
            Item.Cursor := Offset_At_Mouse
              (Item, Natural (Event.X), Natural (Event.Y));
         end if;
         Item.Capturing := False;
         Ensure_Visible (Item);
         return
           (Handled => True,
            Changed => True,
            Capture => Flyology_TUI.Components.Interactions.Release_Capture,
            others => <>);
      elsif not Item.Enabled then
         return Result;
      elsif Event.Action = Flyology_TUI.Events.Mouse_Wheel and then Inside then
         if Event.Wheel_Y < 0 then
            declare
               Amount : constant Natural := Magnitude (Event.Wheel_Y);
            begin
               if Amount >= Line_Count (Item) - Item.First_Line then
                  Item.First_Line := Line_Count (Item);
               else
                  Item.First_Line := Item.First_Line + Amount;
               end if;
            end;
         elsif Event.Wheel_Y > 0 then
            Item.First_Line := Positive'Max
              (1,
               Item.First_Line
               - Natural'Min
                   (Item.First_Line - 1, Natural (Event.Wheel_Y)));
         end if;
         if Item.Wrap = No_Wrap then
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
         end if;
         return (Handled => True, Changed => True, others => <>);
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
         Item.Has_Preferred := False;
         return
           (Handled => True,
            Changed => True,
            Focus_Requested => True,
            Capture => Flyology_TUI.Components.Interactions.Acquire_Capture,
            others => <>);
      elsif Event.Action = Flyology_TUI.Events.Mouse_Drag
        and then Item.Capturing
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
                     Visible_Cell : constant Integer := Integer (Cell) -
                       (if Item.Wrap = Soft_Wrap then Integer (Segment_Cell)
                        else Integer (Item.First_Cell));
                     Style : constant Flyology_TUI.Styles.Style :=
                       (if not Item.Enabled then Look.Disabled
                        elsif Pos < Sel_Last and then Last + 1 > Sel_First
                        then Look.Selection else Base);
                  begin
                     if Visible_Cell >= 0
                       and then Natural (Visible_Cell) < Content_Width
                     then
                        if Current (Current'First + Pos) =
                          Wide_Wide_Character'Val (9)
                        then
                           for Index in 0 .. Natural'Min
                             (Span, Content_Width - Natural (Visible_Cell)) - 1
                           loop
                              Result.Put
                                (Gutter + Natural (Visible_Cell) + Index,
                                 Row, " ", Style);
                           end loop;
                        elsif Natural (Visible_Cell) + Span <=
                          Content_Width
                        then
                           Result.Put
                             (Gutter + Natural (Visible_Cell),
                              Row,
                              Current
                                (Current'First + Pos .. Current'First + Last),
                              Style);
                        end if;
                     end if;
                     Cell := Cell + Span;
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
            Cursor_Row : Integer := -1;
            Cursor_X : Integer := -1;
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
                    and then Item.Cursor <= Stop
                  then
                     Cursor_Row := Integer (Candidate_Row);
                     Cursor_X := Integer (Gutter)
                       + Integer (Here.Cell_Column)
                       - Integer
                           (Position_At_Offset (Item, Start).Cell_Column);
                     exit;
                  end if;
               end;
            end loop;
            if Cursor_Row >= 0
              and then Cursor_X >= Integer (Gutter)
              and then Cursor_X < Integer (Item.Columns)
            then
               declare
                  Existing : constant Flyology_TUI.Surfaces.Cell :=
                    Result.Element
                      (Natural (Cursor_X), Natural (Cursor_Row));
                  Glyph : constant Wide_Wide_String :=
                    Text.To_Wide_Wide_String (Existing.Glyph);
               begin
                  if not Existing.Continuation then
                     Result.Put
                       (Natural (Cursor_X),
                        Natural (Cursor_Row),
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
