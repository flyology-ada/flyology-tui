with Flyology_TUI.Glyphs;

package body Flyology_TUI.Components.Streaming_Texts is
   use type Flyology_TUI.Events.Key_Kind;
   use type Flyology_TUI.Events.Mouse_Action;
   use type Flyology_TUI.Events.Mouse_Button;
   use type Flyology_TUI.Events.Terminal_Event_Kind;

   subtype Wide_Count is Long_Long_Integer range 0 .. Long_Long_Integer'Last;

   function From_Theme
     (Theme : Flyology_TUI.Themes.Theme) return Appearance
   is (Streaming_Text => Theme.Input,
       Finished_Text  => Theme.Success,
       Failed_Text    => Theme.Error,
       Cancelled_Text => Theme.Muted,
       Focused_Text   => Theme.Focused,
       Background     => Flyology_TUI.Styles.Default);

   function Fits_Viewport (Width, Height : Natural) return Boolean is
     (Width = 0
      or else Height = 0
      or else Height <= Max_Viewport_Cells / Width);

   function Create
     (Width       : Natural;
      Height      : Natural;
      Overflow    : Overflow_Policy := Reject;
      Tab_Stop    : Tab_Stop_Width := 4;
      Follow_Tail : Boolean := True) return Model
   is
      Result : Model;
   begin
      if not Fits_Viewport (Width, Height) then
         raise Flyology_TUI.Components.Capacity_Error;
      end if;
      Result.Columns := Width;
      Result.Rows := Height;
      Result.Policy := Overflow;
      Result.Tab_Columns := Tab_Stop;
      Result.Follow := Follow_Tail;
      return Result;
   end Create;

   function Saturating_Add (Left, Right : Natural) return Natural is
   begin
      if Right > Natural'Last - Left then
         return Natural'Last;
      else
         return Left + Right;
      end if;
   end Saturating_Add;

   function Is_Boundary_Control
     (Value : Wide_Wide_Character) return Boolean
   is (Value = Wide_Wide_Character'Val (9)
       or else Value = Wide_Wide_Character'Val (10));

   function Stored_Cluster_Last
     (Item  : Model;
      First : Positive) return Natural
   is
      Last      : Natural := First;
      Join_Next : Boolean := False;
   begin
      if Is_Boundary_Control (Item.Buffer (First)) then
         return First;
      end if;
      while Last < Item.Used loop
         declare
            Next_Value : constant Wide_Wide_Character :=
              Item.Buffer (Last + 1);
            Next_Code  : constant Natural :=
              Wide_Wide_Character'Pos (Next_Value);
         begin
            if Is_Boundary_Control (Next_Value) then
               exit;
            elsif Flyology_TUI.Glyphs.Is_Extender (Next_Value) then
               Last := Last + 1;
               Join_Next := Next_Code = 16#200D#;
            elsif Join_Next then
               Last := Last + 1;
               Join_Next := False;
            else
               exit;
            end if;
         end;
      end loop;
      return Last;
   end Stored_Cluster_Last;

   function Stored_Cluster_Width
     (Item : Model;
      First, Last : Positive) return Flyology_TUI.Glyphs.Cell_Width
   is
      Result : Flyology_TUI.Glyphs.Cell_Width := 0;
   begin
      for Position in First .. Last loop
         Result := Flyology_TUI.Glyphs.Cell_Width'Max
           (Result, Flyology_TUI.Glyphs.Width_Of (Item.Buffer (Position)));
      end loop;
      return Result;
   end Stored_Cluster_Width;

   function Measured_Rows
     (Item  : Model;
      Limit : Natural) return Natural
   is
      Row      : Natural := 0;
      Column   : Natural := 0;
      Position : Natural := 1;

      procedure Next_Cell is
      begin
         if Column = Item.Columns then
            Row := Saturating_Add (Row, 1);
            Column := 0;
         end if;
         Column := Column + 1;
      end Next_Cell;
   begin
      if Item.Columns = 0 then
         return 0;
      end if;
      while Position <= Limit loop
         if Item.Buffer (Position) = Wide_Wide_Character'Val (10) then
            Row := Saturating_Add (Row, 1);
            Column := 0;
            Position := Position + 1;
         elsif Item.Buffer (Position) = Wide_Wide_Character'Val (9) then
            if Column = Item.Columns then
               Row := Saturating_Add (Row, 1);
               Column := 0;
            end if;
            declare
               Spaces : constant Natural :=
                 Item.Tab_Columns - (Column mod Item.Tab_Columns);
            begin
               for Count in 1 .. Spaces loop
                  Next_Cell;
               end loop;
            end;
            Position := Position + 1;
         else
            declare
               Last : constant Natural := Stored_Cluster_Last (Item, Position);
               Width : constant Natural :=
                 Natural (Stored_Cluster_Width (Item, Position, Last));
               Display_Width : constant Natural :=
                 (if Width > Item.Columns then 1 else Width);
            begin
               if Display_Width > 0 then
                  if Column > Item.Columns - Display_Width then
                     Row := Saturating_Add (Row, 1);
                     Column := 0;
                  end if;
                  Column := Column + Display_Width;
               end if;
               Position := Last + 1;
            end;
         end if;
      end loop;
      return Saturating_Add (Row, 1);
   end Measured_Rows;

   function Visual_Row_Count (Item : Model) return Natural is
     (Measured_Rows (Item, Item.Used));

   function Maximum_First (Item : Model) return Natural is
      Total : constant Natural := Visual_Row_Count (Item);
   begin
      return Total - Natural'Min (Total, Item.Rows);
   end Maximum_First;

   procedure Recompute_Unseen_Rows (Item : in out Model) is
      Total : constant Natural := Visual_Row_Count (Item);
      Visible_End : constant Natural :=
        Saturating_Add (Item.First_Row, Item.Rows);
   begin
      if Total > Visible_End then
         Item.Unseen_Rows := Total - Visible_End;
      else
         Item.Unseen_Rows := 0;
      end if;
   end Recompute_Unseen_Rows;

   procedure Follow_Current_Tail (Item : in out Model) is
   begin
      Item.First_Row := Maximum_First (Item);
      Item.Follow := True;
      Item.Unseen_Rows := 0;
      Item.Unseen_Chunks := 0;
   end Follow_Current_Tail;

   function Resize
     (Item : in out Model;
      Width, Height : Natural) return Operation_Result
   is
   begin
      if not Fits_Viewport (Width, Height) then
         return Rejected_Geometry;
      elsif Width = Item.Columns and then Height = Item.Rows then
         return Unchanged;
      end if;
      Item.Columns := Width;
      Item.Rows := Height;
      if Item.Follow then
         Follow_Current_Tail (Item);
      else
         Item.First_Row := Natural'Min (Item.First_Row, Maximum_First (Item));
         Recompute_Unseen_Rows (Item);
         if Item.Unseen_Rows = 0 then
            Item.Unseen_Chunks := 0;
         end if;
      end if;
      return Applied;
   end Resize;

   function Mutate
     (Item        : in out Model;
      Value       : Wide_Wide_String;
      Append_Mode : Boolean) return Operation_Result
   is
      Old_Length : constant Natural := (if Append_Mode then Item.Used else 0);
      Total      : constant Wide_Count :=
        Wide_Count (Old_Length) + Wide_Count (Value'Length);

      function Virtual_Character
        (Position : Wide_Count) return Wide_Wide_Character
      is
      begin
         if Position <= Wide_Count (Old_Length) then
            return Item.Buffer (Natural (Position));
         else
            declare
               Offset : constant Natural :=
                 Natural (Position - Wide_Count (Old_Length));
            begin
               return Value (Value'First + (Offset - 1));
            end;
         end if;
      end Virtual_Character;

      function Virtual_Cluster_Last (First : Wide_Count) return Wide_Count is
         Last      : Wide_Count := First;
         Join_Next : Boolean := False;
      begin
         if Is_Boundary_Control (Virtual_Character (First)) then
            return First;
         end if;
         while Last < Total loop
            declare
               Next_Value : constant Wide_Wide_Character :=
                 Virtual_Character (Last + 1);
               Next_Code : constant Natural :=
                 Wide_Wide_Character'Pos (Next_Value);
            begin
               if Is_Boundary_Control (Next_Value) then
                  exit;
               elsif Flyology_TUI.Glyphs.Is_Extender (Next_Value) then
                  Last := Last + 1;
                  Join_Next := Next_Code = 16#200D#;
               elsif Join_Next then
                  Last := Last + 1;
                  Join_Next := False;
               else
                  exit;
               end if;
            end;
         end loop;
         return Last;
      end Virtual_Cluster_Last;

      Lines       : Wide_Count := 1;
      Start       : Wide_Count := 1;
      New_Length  : Natural;
      Same        : Boolean;
      Was_Following : constant Boolean := Item.Follow;
   begin
      if Item.Current_State /= Streaming then
         return Rejected_State;
      elsif Append_Mode and then Value'Length = 0 then
         return Unchanged;
      end if;

      --  This scan is the capacity preflight. No input-sized object is made.
      for Position in Wide_Count range 1 .. Total loop
         if Virtual_Character (Position) = Wide_Wide_Character'Val (10) then
            Lines := Lines + 1;
         end if;
      end loop;

      if Item.Policy = Reject then
         if Total > Wide_Count (Max_Code_Points)
           or else Lines > Wide_Count (Max_Lines)
         then
            return Rejected_Capacity;
         end if;
      else
         declare
            Lines_To_Remove : Wide_Count :=
              Wide_Count'Max (0, Lines - Wide_Count (Max_Lines));
         begin
            while Lines_To_Remove > 0 loop
               if Virtual_Character (Start) = Wide_Wide_Character'Val (10) then
                  Lines_To_Remove := Lines_To_Remove - 1;
               end if;
               Start := Start + 1;
            end loop;
         end;

         while Start <= Total
           and then Total - Start + 1 > Wide_Count (Max_Code_Points)
         loop
            Start := Virtual_Cluster_Last (Start) + 1;
         end loop;
      end if;

      New_Length :=
        (if Start > Total then 0 else Natural (Total - Start + 1));
      Same := New_Length = Item.Used;
      if Same then
         for Position in 1 .. New_Length loop
            if Item.Buffer (Position) /=
              Virtual_Character (Start + Wide_Count (Position) - 1)
            then
               Same := False;
               exit;
            end if;
         end loop;
      end if;
      if Same and then not Append_Mode then
         return Unchanged;
      end if;

      if not Same then
         for Position in 1 .. New_Length loop
            Item.Buffer (Position) :=
              Virtual_Character (Start + Wide_Count (Position) - 1);
         end loop;
         Item.Used := New_Length;
      end if;
      Item.First_Row := Natural'Min (Item.First_Row, Maximum_First (Item));

      if Append_Mode and then not Was_Following then
         Item.Follow := False;
         Recompute_Unseen_Rows (Item);
         Item.Unseen_Chunks := Saturating_Add (Item.Unseen_Chunks, 1);
      elsif Append_Mode then
         Follow_Current_Tail (Item);
      else
         Item.Unseen_Rows := 0;
         Item.Unseen_Chunks := 0;
         if Was_Following then
            Follow_Current_Tail (Item);
         else
            Item.Follow := False;
         end if;
      end if;
      return Applied;
   end Mutate;

   function Append
     (Item  : in out Model;
      Chunk : Wide_Wide_String) return Operation_Result
   is (Mutate (Item, Chunk, True));

   function Replace
     (Item    : in out Model;
      Content : Wide_Wide_String) return Operation_Result
   is (Mutate (Item, Content, False));

   function Transition_To
     (Item   : in out Model;
      Target : Stream_State) return Operation_Result
   is
   begin
      if Item.Current_State /= Streaming then
         return Rejected_State;
      end if;
      Item.Current_State := Target;
      return Applied;
   end Transition_To;

   function Finish (Item : in out Model) return Operation_Result is
     (Transition_To (Item, Finished));

   function Fail (Item : in out Model) return Operation_Result is
     (Transition_To (Item, Failed));

   function Cancel (Item : in out Model) return Operation_Result is
     (Transition_To (Item, Cancelled));

   function Content (Item : Model) return Wide_Wide_String is
     (if Item.Used = 0 then "" else Item.Buffer (1 .. Item.Used));

   function Code_Point_Count (Item : Model) return Natural is (Item.Used);

   function Logical_Line_Count (Item : Model) return Positive is
      Result : Positive := 1;
   begin
      for Position in 1 .. Item.Used loop
         if Item.Buffer (Position) = Wide_Wide_Character'Val (10) then
            Result := Result + 1;
         end if;
      end loop;
      return Result;
   end Logical_Line_Count;

   function State (Item : Model) return Stream_State is (Item.Current_State);
   function Overflow_Mode (Item : Model) return Overflow_Policy is
     (Item.Policy);
   function Viewport_Width (Item : Model) return Natural is (Item.Columns);
   function Viewport_Height (Item : Model) return Natural is (Item.Rows);
   function First_Visible_Row (Item : Model) return Natural is
     (Item.First_Row);
   function Is_Following_Tail (Item : Model) return Boolean is (Item.Follow);
   function Unseen_Row_Count (Item : Model) return Natural is
     (Item.Unseen_Rows);
   function Unseen_Chunk_Count (Item : Model) return Natural is
     (Item.Unseen_Chunks);

   procedure Set_Follow_Tail (Item : in out Model; Enabled : Boolean) is
   begin
      if Enabled then
         Follow_Current_Tail (Item);
      else
         Item.Follow := False;
      end if;
   end Set_Follow_Tail;

   function Scroll_Wide
     (Item  : in out Model;
      Amount : Long_Long_Integer)
      return Flyology_TUI.Components.Interactions.Update_Result
   is
      Before_First  : constant Natural := Item.First_Row;
      Before_Follow : constant Boolean := Item.Follow;
      Before_Rows   : constant Natural := Item.Unseen_Rows;
      Before_Chunks : constant Natural := Item.Unseen_Chunks;
      Maximum       : constant Natural := Maximum_First (Item);
      Candidate     : Long_Long_Integer :=
        Long_Long_Integer (Item.First_Row) + Amount;
   begin
      Candidate := Long_Long_Integer'Max
        (0, Long_Long_Integer'Min (Candidate, Long_Long_Integer (Maximum)));
      Item.First_Row := Natural (Candidate);
      if Item.First_Row = Maximum then
         Item.Follow := True;
         Item.Unseen_Rows := 0;
         Item.Unseen_Chunks := 0;
      else
         Item.Follow := False;
         Recompute_Unseen_Rows (Item);
      end if;
      return
        (Handled => True,
         Changed =>
           Item.First_Row /= Before_First
           or else Item.Follow /= Before_Follow
           or else Item.Unseen_Rows /= Before_Rows
           or else Item.Unseen_Chunks /= Before_Chunks,
         others => <>);
   end Scroll_Wide;

   function Scroll
     (Item  : in out Model;
      Amount : Integer)
      return Flyology_TUI.Components.Interactions.Update_Result
   is (Scroll_Wide (Item, Long_Long_Integer (Amount)));

   function Handle
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Terminal_Event)
      return Flyology_TUI.Components.Interactions.Update_Result
   is
   begin
      if Event.Kind /= Flyology_TUI.Events.Key_Press then
         return Flyology_TUI.Components.Interactions.Ignored;
      end if;
      case Event.Key.Kind is
         when Flyology_TUI.Events.Arrow_Up_Key =>
            return Scroll_Wide (Item, -1);
         when Flyology_TUI.Events.Arrow_Down_Key =>
            return Scroll_Wide (Item, 1);
         when Flyology_TUI.Events.Page_Up_Key =>
            return Scroll_Wide (Item, -Long_Long_Integer (Item.Rows));
         when Flyology_TUI.Events.Page_Down_Key =>
            return Scroll_Wide (Item, Long_Long_Integer (Item.Rows));
         when Flyology_TUI.Events.Home_Key =>
            return Scroll_Wide
              (Item, -Long_Long_Integer (Natural'Last));
         when Flyology_TUI.Events.End_Key =>
            return Scroll_Wide (Item, Long_Long_Integer (Natural'Last));
         when others =>
            return Flyology_TUI.Components.Interactions.Ignored;
      end case;
   end Handle;

   function Inside (Item : Model; Event : Flyology_TUI.Mouse.Local_Event)
      return Boolean
   is
     (Event.X >= 0
      and then Event.Y >= 0
      and then Long_Long_Integer (Event.X) < Long_Long_Integer (Item.Columns)
      and then Long_Long_Integer (Event.Y) < Long_Long_Integer (Item.Rows));

   function Handle
     (Item  : in out Model;
      Event : Flyology_TUI.Mouse.Local_Event)
      return Flyology_TUI.Components.Interactions.Update_Result
   is
      Result : Flyology_TUI.Components.Interactions.Update_Result;
   begin
      if not Inside (Item, Event) then
         return Result;
      elsif Event.Action = Flyology_TUI.Events.Mouse_Wheel
        and then Event.Wheel_Y /= 0
      then
         Result := Scroll_Wide
           (Item, -3 * Long_Long_Integer (Event.Wheel_Y));
         Result.Focus_Requested := True;
         return Result;
      elsif Event.Action = Flyology_TUI.Events.Mouse_Click
        and then Event.Button = Flyology_TUI.Events.Left_Button
      then
         return
           (Handled => True, Focus_Requested => True, others => <>);
      else
         return Result;
      end if;
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

   function Render
     (Item       : Model;
      Appearance : Streaming_Texts.Appearance := (others => <>);
      Has_Focus  : Boolean := False)
      return Flyology_TUI.Surfaces.Surface
   is
      Result : Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.Create
          (Item.Columns, Item.Rows, Appearance.Background);
      Text_Style : constant Flyology_TUI.Styles.Style :=
        (if Has_Focus then Appearance.Focused_Text
         else
           (case Item.Current_State is
               when Streaming => Appearance.Streaming_Text,
               when Finished  => Appearance.Finished_Text,
               when Failed    => Appearance.Failed_Text,
               when Cancelled => Appearance.Cancelled_Text));
      Row      : Natural := 0;
      Column   : Natural := 0;
      Position : Natural := 1;

      function Visible (Source_Row : Natural) return Boolean is
        (Source_Row >= Item.First_Row
         and then Long_Long_Integer (Source_Row - Item.First_Row) <
           Long_Long_Integer (Item.Rows));

      procedure Put_Cell (Glyph : Wide_Wide_String) is
      begin
         if Column = Item.Columns then
            Row := Saturating_Add (Row, 1);
            Column := 0;
         end if;
         if Visible (Row) then
            Result.Put (Column, Row - Item.First_Row, Glyph, Text_Style);
         end if;
         Column := Column + 1;
      end Put_Cell;
   begin
      if Item.Columns = 0 or else Item.Rows = 0 then
         return Result;
      end if;
      while Position <= Item.Used loop
         exit when Row > Saturating_Add (Item.First_Row, Item.Rows);
         if Item.Buffer (Position) = Wide_Wide_Character'Val (10) then
            Row := Saturating_Add (Row, 1);
            Column := 0;
            Position := Position + 1;
         elsif Item.Buffer (Position) = Wide_Wide_Character'Val (9) then
            if Column = Item.Columns then
               Row := Saturating_Add (Row, 1);
               Column := 0;
            end if;
            declare
               Spaces : constant Natural :=
                 Item.Tab_Columns - (Column mod Item.Tab_Columns);
            begin
               for Count in 1 .. Spaces loop
                  Put_Cell (" ");
               end loop;
            end;
            Position := Position + 1;
         else
            declare
               Last : constant Natural := Stored_Cluster_Last (Item, Position);
               Width : constant Natural :=
                 Natural (Stored_Cluster_Width (Item, Position, Last));
               Display_Width : constant Natural :=
                 (if Width > Item.Columns then 1 else Width);
            begin
               if Display_Width > 0 then
                  if Column > Item.Columns - Display_Width then
                     Row := Saturating_Add (Row, 1);
                     Column := 0;
                  end if;
                  if Visible (Row) then
                     Result.Put
                       (Column,
                        Row - Item.First_Row,
                        (if Width > Item.Columns
                         then "?" else Item.Buffer (Position .. Last)),
                        Text_Style);
                  end if;
                  Column := Column + Display_Width;
               end if;
               Position := Last + 1;
            end;
         end if;
      end loop;
      return Result;
   end Render;

   function Render
     (Item      : Model;
      Theme     : Flyology_TUI.Themes.Theme;
      Has_Focus : Boolean := False)
      return Flyology_TUI.Surfaces.Surface
   is (Render (Item, From_Theme (Theme), Has_Focus));

end Flyology_TUI.Components.Streaming_Texts;
