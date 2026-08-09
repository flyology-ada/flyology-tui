with Ada.Containers;

package body Flyology_TUI.Components.Panel_Groups is
   use type Flyology_TUI.Events.Key_Kind;
   use type Flyology_TUI.Events.Mouse_Action;
   use type Flyology_TUI.Events.Mouse_Button;
   use type Flyology_TUI.Events.Terminal_Event_Kind;
   use type Flyology_TUI.Layouts.Boxes.Direction;

   Vertical_Line : constant Wide_Wide_String :=
     (1 => Wide_Wide_Character'Val (16#2502#));
   Horizontal_Line : constant Wide_Wide_String :=
     (1 => Wide_Wide_Character'Val (16#2500#));

   package Natural_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Natural,
      Element_Type => Natural);

   function From_Theme
     (Theme : Flyology_TUI.Themes.Theme) return Appearance
   is
     (Pane             => Theme.Primary,
      Divider          => Theme.Border,
      Focused_Divider  => Theme.Focused,
      Hovered_Divider  => Theme.Focused,
      Pressed_Divider  => Theme.Selected,
      Disabled_Divider => Theme.Muted);

   procedure Check_Capacity (Width, Height : Natural) is
   begin
      if Width /= 0 and then Height > Natural'Last / Width then
         raise Flyology_TUI.Components.Capacity_Error with
           "panel group exceeds addressable cell capacity";
      end if;
   end Check_Capacity;

   function Count_Of (Panes : Pane_Vectors.Vector) return Natural is
     (Natural (Panes.Length));

   function Major_Length
     (Flow : Orientation; Width, Height : Natural) return Natural
   is
     (if Flow = Flyology_TUI.Layouts.Boxes.Horizontal then Width else Height);

   function Major_Length (Item : Model) return Natural is
     (Major_Length (Item.Flow_Value, Item.Columns, Item.Rows));

   function Visible_Divider_Count
     (Pane_Count, Major : Natural) return Natural
   is
     (if Pane_Count = 0 then 0
      else Natural'Min (Pane_Count - 1, Major));

   function Pane_Space
     (Pane_Count, Major : Natural) return Natural
   is (Major - Visible_Divider_Count (Pane_Count, Major));

   function Minimums_Fit
     (Panes : Pane_Vectors.Vector;
      Space : Natural) return Boolean
   is
      Remaining : Natural := Space;
   begin
      if Panes.Is_Empty then
         return True;
      end if;
      for Position in Panes.First_Index .. Panes.Last_Index loop
         if Panes (Position).Minimum > Remaining then
            return False;
         end if;
         Remaining := Remaining - Panes (Position).Minimum;
      end loop;
      return True;
   end Minimums_Fit;

   procedure Set_Span
     (Panes    : in out Pane_Vectors.Vector;
      Position : Natural;
      Span     : Natural)
   is
      Value : Pane_State := Panes (Position);
   begin
      Value.Span := Span;
      Panes.Replace_Element (Position, Value);
   end Set_Span;

   procedure Lay_Out
     (Panes       : in out Pane_Vectors.Vector;
      Major       : Natural;
      Use_Initial : Boolean)
   is
      Count     : constant Natural := Count_Of (Panes);
      Space     : constant Natural := Pane_Space (Count, Major);
      Remaining : Natural := Space;
      Fits      : constant Boolean := Minimums_Fit (Panes, Space);
      Total_Weight : Long_Long_Integer := 0;
      Preferences : Natural_Vectors.Vector;
   begin
      if Panes.Is_Empty then
         return;
      end if;

      for Value of Panes loop
         Preferences.Append
           ((if Use_Initial then Value.Initial else Value.Span));
      end loop;

      --  Establish feasible minimums. If the configured set cannot fit,
      --  earlier panes consume their minimum first and there is no movable
      --  slack.
      for Position in Panes.First_Index .. Panes.Last_Index loop
         declare
            Assigned : constant Natural :=
              Natural'Min (Panes (Position).Minimum, Remaining);
         begin
            Set_Span (Panes, Position, Assigned);
            Remaining := Remaining - Assigned;
         end;
      end loop;
      if not Fits then
         return;
      end if;

      --  Fill preferred spans in pane order. Resize supplies the old Span as
      --  the preference; Configure and Create supply Initial.
      for Position in Panes.First_Index .. Panes.Last_Index loop
         declare
            Value : constant Pane_State := Panes (Position);
            Preferred : constant Natural := Preferences (Position);
            Target : constant Natural :=
              Natural'Max (Value.Minimum, Preferred);
            Extra : constant Natural :=
              Natural'Min (Target - Value.Minimum, Remaining);
         begin
            Set_Span (Panes, Position, Value.Minimum + Extra);
            Remaining := Remaining - Extra;
         end;
      end loop;

      if Remaining = 0 then
         return;
      end if;
      for Value of Panes loop
         if Long_Long_Integer (Value.Weight) >
           Long_Long_Integer'Last - Total_Weight
         then
            raise Flyology_TUI.Components.Capacity_Error with
              "panel weights exceed addressable capacity";
         end if;
         Total_Weight := Total_Weight + Long_Long_Integer (Value.Weight);
      end loop;

      --  Sequential proportional allocation avoids a remainder pass and
      --  assigns any rounding residue deterministically to later panes.
      for Position in Panes.First_Index .. Panes.Last_Index loop
         declare
            Value : constant Pane_State := Panes (Position);
            Share : Natural;
         begin
            if Position = Panes.Last_Index then
               Share := Remaining;
            else
               Share := Natural
                 ((Long_Long_Integer (Remaining)
                    * Long_Long_Integer (Value.Weight))
                  / Total_Weight);
            end if;
            Set_Span (Panes, Position, Value.Span + Share);
            Remaining := Remaining - Share;
            Total_Weight :=
              Total_Weight - Long_Long_Integer (Value.Weight);
         end;
      end loop;
   end Lay_Out;

   function Build_Panes
     (Values : Pane_Constraint_Array;
      Major  : Natural) return Pane_Vectors.Vector
   is
      Result : Pane_Vectors.Vector;
   begin
      for Value of Values loop
         Result.Append
           ((Minimum => Value.Minimum_Span,
             Initial => Value.Initial_Span,
             Weight  => Value.Weight,
             Span    => 0));
      end loop;
      Lay_Out (Result, Major, Use_Initial => True);
      return Result;
   end Build_Panes;

   function Create
     (Flow          : Orientation;
      Width, Height : Natural;
      Panes         : Pane_Constraint_Array) return Model
   is
      Result : Model;
   begin
      Check_Capacity (Width, Height);
      Result.Flow_Value := Flow;
      Result.Columns := Width;
      Result.Rows := Height;
      Result.First_Pane_Index := Panes'First;
      Result.Panes := Build_Panes
        (Panes, Major_Length (Flow, Width, Height));
      return Result;
   end Create;

   procedure Resize
     (Item          : in out Model;
      Width, Height : Natural)
   is
      New_Panes : Pane_Vectors.Vector := Item.Panes;
   begin
      Check_Capacity (Width, Height);
      Lay_Out
        (New_Panes,
         Major_Length (Item.Flow_Value, Width, Height),
         Use_Initial => False);
      Item.Columns := Width;
      Item.Rows := Height;
      Item.Panes := New_Panes;
      Item.Dragging := False;
      Item.Has_Hover := False;
   end Resize;

   procedure Configure
     (Item  : in out Model;
      Panes : Pane_Constraint_Array)
   is
   begin
      Configure (Item, Item.Columns, Item.Rows, Panes);
   end Configure;

   procedure Configure
     (Item          : in out Model;
      Width, Height : Natural;
      Panes         : Pane_Constraint_Array)
   is
      New_Panes : Pane_Vectors.Vector;
   begin
      Check_Capacity (Width, Height);
      New_Panes := Build_Panes
        (Panes, Major_Length (Item.Flow_Value, Width, Height));
      Item.Columns := Width;
      Item.Rows := Height;
      Item.First_Pane_Index := Panes'First;
      Item.Panes := New_Panes;
      Item.Focused_Position := 0;
      Item.Has_Hover := False;
      Item.Dragging := False;
   end Configure;

   function Flow (Item : Model) return Orientation is (Item.Flow_Value);
   function Width (Item : Model) return Natural is (Item.Columns);
   function Height (Item : Model) return Natural is (Item.Rows);
   function Bounds (Item : Model) return Flyology_TUI.Geometry.Rectangle is
     ((X => 0, Y => 0, Width => Item.Columns, Height => Item.Rows));
   function Pane_Count (Item : Model) return Natural is
     (Count_Of (Item.Panes));
   function Divider_Count (Item : Model) return Natural is
     (if Pane_Count (Item) = 0 then 0 else Pane_Count (Item) - 1);

   function Position_Of (Item : Model; Index : Integer) return Natural is
     (Natural
        (Long_Long_Integer (Index)
         - Long_Long_Integer (Item.First_Pane_Index)));

   function Index_Of (Item : Model; Position : Natural) return Integer is
     (Item.First_Pane_Index + Integer (Position));

   function Has_Pane (Item : Model; Index : Integer) return Boolean is
      Offset : constant Long_Long_Integer :=
        Long_Long_Integer (Index)
        - Long_Long_Integer (Item.First_Pane_Index);
   begin
      return Offset >= 0
        and then Offset < Long_Long_Integer (Pane_Count (Item));
   end Has_Pane;

   function Has_Divider (Item : Model; Index : Integer) return Boolean is
      Offset : constant Long_Long_Integer :=
        Long_Long_Integer (Index)
        - Long_Long_Integer (Item.First_Pane_Index);
   begin
      return Offset >= 0
        and then Offset < Long_Long_Integer (Divider_Count (Item));
   end Has_Divider;

   function Layout (Item : Model) return Layout_Snapshot is
     (Flow_Value       => Item.Flow_Value,
      Columns          => Item.Columns,
      Rows             => Item.Rows,
      First_Pane_Index => Item.First_Pane_Index,
      Panes            => Item.Panes);

   function Flow (Item : Layout_Snapshot) return Orientation is
     (Item.Flow_Value);
   function Width (Item : Layout_Snapshot) return Natural is (Item.Columns);
   function Height (Item : Layout_Snapshot) return Natural is (Item.Rows);
   function Bounds
     (Item : Layout_Snapshot) return Flyology_TUI.Geometry.Rectangle
   is ((X => 0, Y => 0, Width => Item.Columns, Height => Item.Rows));
   function Pane_Count (Item : Layout_Snapshot) return Natural is
     (Count_Of (Item.Panes));
   function Divider_Count (Item : Layout_Snapshot) return Natural is
     (if Pane_Count (Item) = 0 then 0 else Pane_Count (Item) - 1);

   function Snapshot_Position_Of
     (Item : Layout_Snapshot; Index : Integer) return Natural
   is
     (Natural
        (Long_Long_Integer (Index)
         - Long_Long_Integer (Item.First_Pane_Index)));

   function Has_Pane
     (Item : Layout_Snapshot; Index : Integer) return Boolean
   is
      Offset : constant Long_Long_Integer :=
        Long_Long_Integer (Index)
        - Long_Long_Integer (Item.First_Pane_Index);
   begin
      return Offset >= 0
        and then Offset < Long_Long_Integer (Pane_Count (Item));
   end Has_Pane;

   function Has_Divider
     (Item : Layout_Snapshot; Index : Integer) return Boolean
   is
      Offset : constant Long_Long_Integer :=
        Long_Long_Integer (Index)
        - Long_Long_Integer (Item.First_Pane_Index);
   begin
      return Offset >= 0
        and then Offset < Long_Long_Integer (Divider_Count (Item));
   end Has_Divider;

   function Pane_Span
     (Item : Layout_Snapshot; Index : Integer) return Natural
   is (Item.Panes (Snapshot_Position_Of (Item, Index)).Span);

   function Snapshot_Start_Of
     (Item : Layout_Snapshot; Position : Natural) return Natural
   is
      Result : Natural := 0;
      Visible : constant Natural :=
        Visible_Divider_Count
          (Pane_Count (Item),
           Major_Length (Item.Flow_Value, Item.Columns, Item.Rows));
   begin
      if Position = 0 then
         return 0;
      end if;
      for Previous in 0 .. Position - 1 loop
         Result := Result + Item.Panes (Previous).Span;
         if Previous < Visible then
            Result := Result + 1;
         end if;
      end loop;
      return Result;
   end Snapshot_Start_Of;

   function Pane_Region
     (Item : Layout_Snapshot;
      Index : Integer) return Flyology_TUI.Geometry.Rectangle
   is
      Position : constant Natural := Snapshot_Position_Of (Item, Index);
      Start : constant Natural := Snapshot_Start_Of (Item, Position);
      Span : constant Natural := Item.Panes (Position).Span;
   begin
      if Item.Flow_Value = Flyology_TUI.Layouts.Boxes.Horizontal then
         return (X => Integer (Start), Y => 0,
                 Width => Span, Height => Item.Rows);
      else
         return (X => 0, Y => Integer (Start),
                 Width => Item.Columns, Height => Span);
      end if;
   end Pane_Region;

   function Divider_Region
     (Item : Layout_Snapshot;
      Index : Integer) return Flyology_TUI.Geometry.Rectangle
   is
      Position : constant Natural := Snapshot_Position_Of (Item, Index);
      Start : constant Natural :=
        Snapshot_Start_Of (Item, Position) + Item.Panes (Position).Span;
      Visible : constant Boolean :=
        Position < Visible_Divider_Count
          (Pane_Count (Item),
           Major_Length (Item.Flow_Value, Item.Columns, Item.Rows));
   begin
      if Item.Flow_Value = Flyology_TUI.Layouts.Boxes.Horizontal then
         return (X => Integer (Start), Y => 0,
                 Width => (if Visible then 1 else 0), Height => Item.Rows);
      else
         return (X => 0, Y => Integer (Start), Width => Item.Columns,
                 Height => (if Visible then 1 else 0));
      end if;
   end Divider_Region;

   function Pane_Span (Item : Model; Index : Integer) return Natural is
     (Item.Panes (Position_Of (Item, Index)).Span);

   function Start_Of
     (Item : Model; Position : Natural) return Natural
   is
      Result : Natural := 0;
      Visible : constant Natural :=
        Visible_Divider_Count (Pane_Count (Item), Major_Length (Item));
   begin
      if Position = 0 then
         return 0;
      end if;
      for Previous in 0 .. Position - 1 loop
         Result := Result + Item.Panes (Previous).Span;
         if Previous < Visible then
            Result := Result + 1;
         end if;
      end loop;
      return Result;
   end Start_Of;

   function Pane_Region
     (Item : Model; Index : Integer) return Flyology_TUI.Geometry.Rectangle
   is
      Position : constant Natural := Position_Of (Item, Index);
      Start : constant Natural := Start_Of (Item, Position);
      Span : constant Natural := Item.Panes (Position).Span;
   begin
      if Item.Flow_Value = Flyology_TUI.Layouts.Boxes.Horizontal then
         return (X => Integer (Start), Y => 0,
                 Width => Span, Height => Item.Rows);
      else
         return (X => 0, Y => Integer (Start),
                 Width => Item.Columns, Height => Span);
      end if;
   end Pane_Region;

   function Divider_Region
     (Item : Model; Index : Integer) return Flyology_TUI.Geometry.Rectangle
   is
      Position : constant Natural := Position_Of (Item, Index);
      Start : constant Natural :=
        Start_Of (Item, Position) + Item.Panes (Position).Span;
      Visible : constant Boolean :=
        Position < Visible_Divider_Count
          (Pane_Count (Item), Major_Length (Item));
   begin
      if Item.Flow_Value = Flyology_TUI.Layouts.Boxes.Horizontal then
         return (X => Integer (Start), Y => 0,
                 Width => (if Visible then 1 else 0), Height => Item.Rows);
      else
         return (X => 0, Y => Integer (Start), Width => Item.Columns,
                 Height => (if Visible then 1 else 0));
      end if;
   end Divider_Region;

   procedure Focus (Item : in out Model) is
   begin
      Item.Has_Focus := True;
      if Divider_Count (Item) > 0
        and then Item.Focused_Position >= Divider_Count (Item)
      then
         Item.Focused_Position := 0;
      end if;
   end Focus;

   procedure Blur (Item : in out Model) is
   begin
      Item.Has_Focus := False;
   end Blur;

   function Focused (Item : Model) return Boolean is (Item.Has_Focus);

   procedure Focus_Divider (Item : in out Model; Index : Integer) is
   begin
      Item.Focused_Position := Position_Of (Item, Index);
      Item.Has_Focus := True;
   end Focus_Divider;

   function Has_Focused_Divider (Item : Model) return Boolean is
     (Item.Has_Focus
      and then Item.Focused_Position < Divider_Count (Item));

   function Focused_Divider (Item : Model) return Integer is
     (Index_Of (Item, Item.Focused_Position));

   procedure Set_Enabled (Item : in out Model; Enabled : Boolean) is
   begin
      Item.Enabled := Enabled;
      if not Enabled then
         Item.Dragging := False;
         Item.Has_Hover := False;
      end if;
   end Set_Enabled;

   function Is_Enabled (Item : Model) return Boolean is (Item.Enabled);

   function Divider_At
     (Item     : Model;
      Point    : Flyology_TUI.Geometry.Point;
      Position : out Natural) return Boolean
   is
   begin
      if Divider_Count (Item) = 0 then
         Position := 0;
         return False;
      end if;
      for Candidate in 0 .. Divider_Count (Item) - 1 loop
         if Flyology_TUI.Geometry.Contains
           (Divider_Region (Item, Index_Of (Item, Candidate)), Point)
         then
            Position := Candidate;
            return True;
         end if;
      end loop;
      Position := 0;
      return False;
   end Divider_At;

   function Axis
     (Item : Model; Event : Flyology_TUI.Mouse.Local_Event) return Integer
   is
     (if Item.Flow_Value = Flyology_TUI.Layouts.Boxes.Horizontal
      then Event.X else Event.Y);

   function Shifted
     (Value : Natural; Amount : Integer) return Natural
   is
   begin
      if Amount >= 0 then
         if Natural (Amount) > Natural'Last - Value then
            return Natural'Last;
         else
            return Value + Natural (Amount);
         end if;
      elsif Amount = Integer'First or else Natural (-Amount) >= Value then
         return 0;
      else
         return Value - Natural (-Amount);
      end if;
   end Shifted;

   function Apply_Divider_Move
     (Item     : in out Model;
      Position : Natural;
      Desired_First : Natural) return Boolean
   is
      First_Value : constant Pane_State := Item.Panes (Position);
      Second_Value : constant Pane_State := Item.Panes (Position + 1);
      Combined : constant Natural := First_Value.Span + Second_Value.Span;
      Lower : Natural := 0;
      Upper : Natural := Combined;
      New_First : Natural;
      New_Second : Natural;
   begin
      if not Minimums_Fit
        (Item.Panes,
         Pane_Space (Pane_Count (Item), Major_Length (Item)))
      then
         return False;
      end if;
      Lower := First_Value.Minimum;
      if Second_Value.Minimum > Combined then
         Upper := 0;
      else
         Upper := Combined - Second_Value.Minimum;
      end if;
      if Lower > Upper then
         return False;
      end if;
      New_First := Natural'Max (Lower, Natural'Min (Desired_First, Upper));
      New_Second := Combined - New_First;
      if New_First = First_Value.Span then
         return False;
      end if;
      Set_Span (Item.Panes, Position, New_First);
      Set_Span (Item.Panes, Position + 1, New_Second);
      return True;
   end Apply_Divider_Move;

   function Handle
     (Item  : in out Model;
      Event : Flyology_TUI.Mouse.Local_Event)
      return Flyology_TUI.Components.Interactions.Update_Result
   is
      Result : Flyology_TUI.Components.Interactions.Update_Result;
      Point : constant Flyology_TUI.Geometry.Point := (Event.X, Event.Y);
      Hit_Position : Natural := 0;
      Hit : Boolean;
      Before_Hover : constant Boolean := Item.Has_Hover;
      Before_Hover_Position : constant Natural := Item.Hover_Position;
   begin
      if Event.Action = Flyology_TUI.Events.Mouse_Release
        and then Event.Button = Flyology_TUI.Events.Left_Button
        and then Item.Capturing
      then
         Result.Handled := True;
         Result.Capture :=
           Flyology_TUI.Components.Interactions.Release_Capture;
         Result.Changed := Item.Dragging;
         Item.Capturing := False;
         Item.Dragging := False;
         if Item.Enabled then
            Hit := Divider_At (Item, Point, Hit_Position);
            Item.Has_Hover := Hit;
            if Hit then
               Item.Hover_Position := Hit_Position;
            end if;
         end if;
         Result.Changed :=
           Result.Changed
           or else Before_Hover /= Item.Has_Hover
           or else
             (Item.Has_Hover
              and then Before_Hover_Position /= Item.Hover_Position);
         return Result;
      elsif not Item.Enabled then
         return Result;
      elsif Event.Action = Flyology_TUI.Events.Mouse_Move
        and then not Item.Capturing
      then
         Hit := Divider_At (Item, Point, Hit_Position);
         Result.Changed :=
           Item.Has_Hover /= Hit
           or else (Hit and then Item.Hover_Position /= Hit_Position);
         Item.Has_Hover := Hit;
         if Hit then
            Item.Hover_Position := Hit_Position;
         end if;
         Result.Handled := Result.Changed;
         return Result;
      elsif Event.Action = Flyology_TUI.Events.Mouse_Click
        and then Event.Button = Flyology_TUI.Events.Left_Button
        and then not Item.Capturing
        and then Flyology_TUI.Geometry.Contains (Bounds (Item), Point)
      then
         Hit := Divider_At (Item, Point, Hit_Position);
         Result.Handled := True;
         Result.Focus_Requested := True;
         Result.Changed :=
           not Item.Has_Focus or else Before_Hover;
         Item.Has_Focus := True;
         Item.Has_Hover := False;
         if Hit then
            Result.Changed := True;
            Item.Focused_Position := Hit_Position;
            Item.Has_Hover := False;
            Item.Dragging := True;
            Item.Drag_Position := Hit_Position;
            Item.Capturing := True;
            Item.Press_Coordinate := Axis (Item, Event);
            Item.Press_First_Span := Item.Panes (Hit_Position).Span;
            Item.Press_Second_Span := Item.Panes (Hit_Position + 1).Span;
            Result.Capture :=
              Flyology_TUI.Components.Interactions.Acquire_Capture;
         end if;
         return Result;
      elsif Event.Action = Flyology_TUI.Events.Mouse_Drag
        and then Event.Button = Flyology_TUI.Events.Left_Button
        and then Item.Dragging
      then
         declare
            Before_First : constant Natural :=
              Item.Panes (Item.Drag_Position).Span;
            Before_Second : constant Natural :=
              Item.Panes (Item.Drag_Position + 1).Span;
            Axis_Value : constant Integer := Axis (Item, Event);
            Difference : constant Long_Long_Integer :=
              Long_Long_Integer (Axis_Value)
              - Long_Long_Integer (Item.Press_Coordinate);
            Movement : constant Integer :=
              (if Difference > Long_Long_Integer (Integer'Last)
               then Integer'Last
               elsif Difference < Long_Long_Integer (Integer'First)
               then Integer'First
               else Integer (Difference));
            Desired : constant Natural :=
              Shifted (Item.Press_First_Span, Movement);
         begin
            --  Restore the press-time pair before applying an absolute drag,
            --  so repeated events do not accumulate rounding or clamp error.
            Set_Span
              (Item.Panes, Item.Drag_Position, Item.Press_First_Span);
            Set_Span
              (Item.Panes, Item.Drag_Position + 1,
               Item.Press_Second_Span);
            if Apply_Divider_Move
              (Item, Item.Drag_Position, Desired)
            then
               null;
            end if;
            Result.Changed :=
              Item.Panes (Item.Drag_Position).Span /= Before_First
              or else Item.Panes (Item.Drag_Position + 1).Span /=
                Before_Second;
         end;
         Result.Handled := True;
         return Result;
      end if;
      return Result;
   end Handle;

   function Handle
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Terminal_Event)
      return Flyology_TUI.Components.Interactions.Update_Result
   is
      Result : Flyology_TUI.Components.Interactions.Update_Result;
      Count : constant Natural := Divider_Count (Item);
      Step : constant Natural :=
        (if Event.Kind = Flyology_TUI.Events.Key_Press
         and then Event.Key.Modified.Shift then 5 else 1);
      Forward : Boolean := True;
      Is_Move : Boolean := False;
   begin
      if not Item.Enabled
        or else not Item.Has_Focus
        or else Event.Kind /= Flyology_TUI.Events.Key_Press
        or else Count = 0
      then
         return Result;
      end if;

      case Event.Key.Kind is
         when Flyology_TUI.Events.Tab_Key =>
            declare
               Before : constant Natural := Item.Focused_Position;
            begin
               if Event.Key.Modified.Shift then
                  Item.Focused_Position :=
                    (if Item.Focused_Position = 0
                     then Count - 1 else Item.Focused_Position - 1);
               else
                  Item.Focused_Position :=
                    (if Item.Focused_Position + 1 = Count
                     then 0 else Item.Focused_Position + 1);
               end if;
               Result.Handled := True;
               Result.Changed := Item.Focused_Position /= Before;
               return Result;
            end;
         when Flyology_TUI.Events.Home_Key =>
            Result.Changed := Item.Focused_Position /= 0;
            Item.Focused_Position := 0;
            Result.Handled := True;
            return Result;
         when Flyology_TUI.Events.End_Key =>
            Result.Changed := Item.Focused_Position /= Count - 1;
            Item.Focused_Position := Count - 1;
            Result.Handled := True;
            return Result;
         when Flyology_TUI.Events.Arrow_Left_Key =>
            Is_Move :=
              Item.Flow_Value = Flyology_TUI.Layouts.Boxes.Horizontal;
            Forward := False;
         when Flyology_TUI.Events.Arrow_Right_Key =>
            Is_Move :=
              Item.Flow_Value = Flyology_TUI.Layouts.Boxes.Horizontal;
         when Flyology_TUI.Events.Arrow_Up_Key =>
            Is_Move :=
              Item.Flow_Value = Flyology_TUI.Layouts.Boxes.Vertical;
            Forward := False;
         when Flyology_TUI.Events.Arrow_Down_Key =>
            Is_Move :=
              Item.Flow_Value = Flyology_TUI.Layouts.Boxes.Vertical;
         when others => null;
      end case;
      if not Is_Move then
         return Result;
      end if;

      declare
         Current : constant Natural :=
           Item.Panes (Item.Focused_Position).Span;
         Desired : constant Natural :=
           (if Forward then Shifted (Current, Integer (Step))
            elsif Step >= Current then 0 else Current - Step);
      begin
         Result.Changed := Apply_Divider_Move
           (Item, Item.Focused_Position, Desired);
      end;
      Result.Handled := True;
      return Result;
   end Handle;

   procedure Update
     (Item  : in out Model;
      Event : Flyology_TUI.Mouse.Local_Event)
   is
      Discard : constant Flyology_TUI.Components.Interactions.Update_Result :=
        Handle (Item, Event);
   begin
      null;
   end Update;

   procedure Update
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Terminal_Event)
   is
      Discard : constant Flyology_TUI.Components.Interactions.Update_Result :=
        Handle (Item, Event);
   begin
      null;
   end Update;

   function Divider_Style
     (Item       : Model;
      Position   : Natural;
      Appearance : Panel_Groups.Appearance)
      return Flyology_TUI.Styles.Style
   is
   begin
      if not Item.Enabled then
         return Appearance.Disabled_Divider;
      elsif Item.Dragging and then Item.Drag_Position = Position then
         return Appearance.Pressed_Divider;
      elsif Item.Has_Hover and then Item.Hover_Position = Position then
         return Appearance.Hovered_Divider;
      elsif Has_Focused_Divider (Item)
        and then Item.Focused_Position = Position
      then
         return Appearance.Focused_Divider;
      else
         return Appearance.Divider;
      end if;
   end Divider_Style;

   function Render
     (Item       : Model;
      Children   : Surface_Array;
      Appearance : Panel_Groups.Appearance)
      return Flyology_TUI.Surfaces.Surface
   is (Render (Item, Layout (Item), Children, Appearance));

   function Render
     (Item       : Model;
      Geometry   : Layout_Snapshot;
      Children   : Surface_Array;
      Appearance : Panel_Groups.Appearance)
      return Flyology_TUI.Surfaces.Surface
   is
      Result : Flyology_TUI.Surfaces.Surface;
   begin
      Check_Capacity (Geometry.Columns, Geometry.Rows);
      if Children'First /= Geometry.First_Pane_Index
        or else Children'Length /= Pane_Count (Geometry)
      then
         raise Flyology_TUI.Components.Structure_Error with
           "panel children do not match configured pane bounds";
      end if;
      Result := Flyology_TUI.Surfaces.Create
        (Geometry.Columns, Geometry.Rows, Appearance.Pane);

      for Index in Children'Range loop
         declare
            Region : constant Flyology_TUI.Geometry.Rectangle :=
              Pane_Region (Geometry, Index);
            Layer : Flyology_TUI.Surfaces.Surface :=
              Flyology_TUI.Surfaces.Create
                (Region.Width, Region.Height, Appearance.Pane);
         begin
            Layer.Overlay_Clipped (Children (Index), 0, 0);
            Result.Overlay_Clipped (Layer, Region.X, Region.Y);
         end;
      end loop;

      if Divider_Count (Geometry) > 0 then
         for Position in 0 .. Divider_Count (Geometry) - 1 loop
            declare
               Region : constant Flyology_TUI.Geometry.Rectangle :=
                 Divider_Region
                   (Geometry,
                    Geometry.First_Pane_Index + Integer (Position));
               Style : constant Flyology_TUI.Styles.Style :=
                 Divider_Style (Item, Position, Appearance);
            begin
               if Geometry.Flow_Value =
                 Flyology_TUI.Layouts.Boxes.Horizontal
                 and then Region.Width > 0 and then Region.Height > 0
               then
                  for Y in 0 .. Region.Height - 1 loop
                     Result.Put
                       (Natural (Region.X), Y, Vertical_Line, Style);
                  end loop;
               elsif Region.Width > 0 and then Region.Height > 0 then
                  for X in 0 .. Region.Width - 1 loop
                     Result.Put
                       (X, Natural (Region.Y), Horizontal_Line, Style);
                  end loop;
               end if;
            end;
         end loop;
      end if;
      return Result;
   end Render;

   function Render
     (Item     : Model;
      Children : Surface_Array;
      Theme    : Flyology_TUI.Themes.Theme)
      return Flyology_TUI.Surfaces.Surface
   is (Render (Item, Children, From_Theme (Theme)));

   function Render
     (Item     : Model;
      Geometry : Layout_Snapshot;
      Children : Surface_Array;
      Theme    : Flyology_TUI.Themes.Theme)
      return Flyology_TUI.Surfaces.Surface
   is (Render (Item, Geometry, Children, From_Theme (Theme)));

end Flyology_TUI.Components.Panel_Groups;
