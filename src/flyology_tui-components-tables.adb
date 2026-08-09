with Flyology_TUI.Glyphs;

package body Flyology_TUI.Components.Tables is
   package Text_Impl renames Ada.Strings.Wide_Wide_Unbounded;
   use type Flyology_TUI.Events.Key_Kind;
   use type Flyology_TUI.Events.Mouse_Action;
   use type Flyology_TUI.Events.Mouse_Button;
   use type Flyology_TUI.Events.Terminal_Event_Kind;

   function From_Theme
     (Theme : Flyology_TUI.Themes.Theme) return Appearance is
     (Header   => Theme.Border,
      Normal   => Theme.Primary,
      Selected => Theme.Selected,
      Focused  => Theme.Focused,
      Muted    => Theme.Muted,
      Divider  => Theme.Border);

   function Effective_Width
     (Value : Column_Definition) return Natural is
     (Natural'Max (Value.Width, Value.Minimum_Width));

   procedure Validate_Dimensions
     (Columns : Column_Definitions; Rows : Natural)
   is
      Remaining : Natural;
   begin
      if Rows = Natural'Last then
         raise Flyology_TUI.Components.Capacity_Error;
      end if;
      if Natural'Last < 2 then
         raise Flyology_TUI.Components.Capacity_Error;
      end if;
      Remaining := Natural'Last - 2;
      for Column in Column_Id loop
         if Effective_Width (Columns (Column)) > Remaining then
            raise Flyology_TUI.Components.Capacity_Error;
         end if;
         Remaining := Remaining - Effective_Width (Columns (Column));
         if Column /= Column_Id'Last then
            if Remaining = 0 then
               raise Flyology_TUI.Components.Capacity_Error;
            end if;
            Remaining := Remaining - 1;
         end if;
      end loop;
   end Validate_Dimensions;

   procedure Validate (Values : Item_Array) is
   begin
      if Values'Length > Capacity then
         raise Flyology_TUI.Components.Capacity_Error;
      end if;
      for Left in Values'Range loop
         for Right in Values'Range loop
            if Right > Left
              and then Id_Of (Values (Left)) = Id_Of (Values (Right))
            then
               raise Flyology_TUI.Components.Structure_Error;
            end if;
         end loop;
      end loop;
   end Validate;

   function Length (Item : Model) return Natural is
     (Natural (Item.Values.Length));
   function Is_Empty (Item : Model) return Boolean is (Item.Values.Is_Empty);
   function Is_Enabled (Item : Model) return Boolean is (Item.Enabled);
   function Viewport_Rows (Item : Model) return Natural is (Item.Rows);

   function Source_At
     (Item : Model; Display_Position : Positive) return Natural is
     (Item.Order.Element (Display_Position - 1));

   function Display_Of_Source
     (Item : Model; Source : Natural) return Natural is
   begin
      if not Item.Order.Is_Empty then
         for Position in 0 .. Natural (Item.Order.Length) - 1 loop
            if Item.Order.Element (Position) = Source then
               return Position + 1;
            end if;
         end loop;
      end if;
      return 0;
   end Display_Of_Source;

   procedure Rebuild_Order (Item : in out Model) is
      New_Order : Index_Vectors.Vector;
   begin
      if not Item.Values.Is_Empty then
         for Source in 0 .. Natural (Item.Values.Length) - 1 loop
            New_Order.Append (Source);
         end loop;
      end if;

      if Item.Sorting.Direction /= Unsorted
        and then Natural (New_Order.Length) > 1
      then
         for Position in 1 .. Natural (New_Order.Length) - 1 loop
            declare
               Moving : constant Natural := New_Order.Element (Position);
               Insert : Natural := Position;
            begin
               while Insert > 0 loop
                  declare
                     Previous : constant Natural :=
                       New_Order.Element (Insert - 1);
                     Before : constant Boolean :=
                       (if Item.Sorting.Direction = Ascending
                        then Less
                          (Item.Values.Element (Moving),
                           Item.Values.Element (Previous),
                           Item.Sorting.Column)
                        else Less
                          (Item.Values.Element (Previous),
                           Item.Values.Element (Moving),
                           Item.Sorting.Column));
                  begin
                     exit when not Before;
                     New_Order.Replace_Element
                       (Insert, New_Order.Element (Insert - 1));
                     Insert := Insert - 1;
                  end;
               end loop;
               New_Order.Replace_Element (Insert, Moving);
            end;
         end loop;
      end if;
      Item.Order := New_Order;
   end Rebuild_Order;

   procedure Ensure_Visible (Item : in out Model) is
      Last_First : Natural;
   begin
      if Item.Values.Is_Empty then
         Item.First := 0;
         Item.Focused := 0;
         return;
      end if;
      if Item.Focused = 0 then
         Item.Focused := 1;
      elsif Item.Focused > Length (Item) then
         Item.Focused := Length (Item);
      end if;
      if Item.First = 0 then
         Item.First := 1;
      end if;
      if Item.Rows > 0 then
         if Item.Focused < Item.First then
            Item.First := Item.Focused;
         elsif Item.Focused >= Item.First
           and then Item.Focused - Item.First >= Item.Rows
         then
            Item.First := Item.Focused - Item.Rows + 1;
         end if;
         Last_First :=
           (if Length (Item) > Item.Rows
            then Length (Item) - Item.Rows + 1 else 1);
         Item.First := Natural'Min (Item.First, Last_First);
      else
         Item.First := Item.Focused;
      end if;
   end Ensure_Visible;

   procedure Set_Rows (Item : in out Model; Values : Item_Array) is
      New_Values : Item_Vectors.Vector;
      New_Selected_Source : Natural := 0;
      New_Focused_Source  : Natural := 0;
      Old_Focused_Source  : Natural := 0;
   begin
      Validate (Values);
      for Value of Values loop
         New_Values.Append (Value);
      end loop;

      if Item.Focused > 0 and then Item.Focused <= Length (Item) then
         Old_Focused_Source := Source_At (Item, Item.Focused);
      end if;
      if not New_Values.Is_Empty then
         for Source in 0 .. Natural (New_Values.Length) - 1 loop
            if Item.Selected > 0
              and then Id_Of (New_Values.Element (Source)) =
                Id_Of (Item.Values.Element (Item.Selected - 1))
            then
               New_Selected_Source := Source + 1;
            end if;
            if Old_Focused_Source < Natural (Item.Values.Length)
              and then Item.Focused > 0
              and then Id_Of (New_Values.Element (Source)) =
                Id_Of (Item.Values.Element (Old_Focused_Source))
            then
               New_Focused_Source := Source + 1;
            end if;
         end loop;
      end if;

      Item.Values := New_Values;
      Item.Selected := New_Selected_Source;
      Rebuild_Order (Item);
      if New_Focused_Source > 0 then
         Item.Focused := Display_Of_Source (Item, New_Focused_Source - 1);
      elsif New_Selected_Source > 0 then
         Item.Focused := Display_Of_Source (Item, New_Selected_Source - 1);
      elsif not Item.Values.Is_Empty then
         Item.Focused := 1;
      else
         Item.Focused := 0;
         Item.Focus_Zone_Value := Header_Area;
      end if;
      Ensure_Visible (Item);
   end Set_Rows;

   function Create
     (Values        : Item_Array;
      Columns       : Column_Definitions;
      Viewport_Rows : Natural := 8;
      Enabled       : Boolean := True) return Model
   is
      Result : Model;
   begin
      Validate_Dimensions (Columns, Viewport_Rows);
      Result.Definitions := Columns;
      Result.Rows := Viewport_Rows;
      Result.Enabled := Enabled;
      Set_Rows (Result, Values);
      if Result.Values.Is_Empty then
         Result.Focus_Zone_Value := Header_Area;
      end if;
      return Result;
   end Create;

   procedure Set_Columns
     (Item : in out Model; Columns : Column_Definitions) is
   begin
      Validate_Dimensions (Columns, Item.Rows);
      Item.Definitions := Columns;
   end Set_Columns;

   procedure Set_Viewport_Rows (Item : in out Model; Rows : Natural) is
   begin
      Validate_Dimensions (Item.Definitions, Rows);
      Item.Rows := Rows;
      Ensure_Visible (Item);
   end Set_Viewport_Rows;

   procedure Set_Enabled (Item : in out Model; Enabled : Boolean) is
   begin
      Item.Enabled := Enabled;
   end Set_Enabled;

   procedure Sort_By
     (Item      : in out Model;
      Column    : Column_Id;
      Direction : Sort_Direction)
   is
      Focused_Source : Natural := 0;
   begin
      if Item.Focused > 0 then
         Focused_Source := Source_At (Item, Item.Focused);
      end if;
      Item.Sorting := (Direction => Direction, Column => Column);
      Rebuild_Order (Item);
      if Item.Focused > 0 then
         Item.Focused := Display_Of_Source (Item, Focused_Source);
      end if;
      Ensure_Visible (Item);
   end Sort_By;

   function Sort (Item : Model) return Sort_Description is (Item.Sorting);
   function Focus_Zone (Item : Model) return Focus_Area is
     (Item.Focus_Zone_Value);
   function Focused_Column (Item : Model) return Column_Id is
     (Item.Header_Column);

   procedure Select_Id (Item : in out Model; Id : Id_Type) is
   begin
      if not Item.Values.Is_Empty then
         for Source in 0 .. Natural (Item.Values.Length) - 1 loop
            if Id_Of (Item.Values.Element (Source)) = Id then
               Item.Selected := Source + 1;
               Item.Focused := Display_Of_Source (Item, Source);
               Item.Focus_Zone_Value := Row_Area;
               Ensure_Visible (Item);
               return;
            end if;
         end loop;
      end if;
      raise Flyology_TUI.Components.Structure_Error;
   end Select_Id;

   procedure Clear_Selection (Item : in out Model) is
   begin
      Item.Selected := 0;
   end Clear_Selection;

   function Has_Selection (Item : Model) return Boolean is
     (Item.Selected > 0);
   function Selected_Id (Item : Model) return Id_Type is
     (Id_Of (Item.Values.Element (Item.Selected - 1)));
   function Focused_Id (Item : Model) return Id_Type is
     (Id_Of (Item.Values.Element (Source_At (Item, Item.Focused))));

   function First_Visible_Row (Item : Model) return Natural is
     (if Item.Rows = 0 then 0 else Item.First);

   function Visible_Row_Count (Item : Model) return Natural is
     (if Item.Rows = 0 or else Item.First = 0 then 0
      else Natural'Min (Item.Rows, Length (Item) - Item.First + 1));

   function Row_Id
     (Item : Model; Display_Position : Positive) return Id_Type is
     (Id_Of (Item.Values.Element (Source_At (Item, Display_Position))));

   function Visible_Row_Id
     (Item : Model; Visible_Position : Positive) return Id_Type is
     (Row_Id (Item, Item.First + (Visible_Position - 1)));

   function Width (Item : Model) return Natural is
      Result : Natural := 2;
   begin
      for Column in Column_Id loop
         Result := Result + Effective_Width (Item.Definitions (Column));
         if Column /= Column_Id'Last then
            Result := Result + 1;
         end if;
      end loop;
      return Result;
   end Width;

   function Height (Item : Model) return Natural is (Item.Rows + 1);

   function Header_Region (Item : Model)
      return Flyology_TUI.Geometry.Rectangle is
     ((X => 0, Y => 0, Width => Width (Item), Height => 1));

   function Column_X (Item : Model; Wanted : Column_Id) return Natural is
      Result : Natural := 2;
   begin
      for Column in Column_Id loop
         exit when Column = Wanted;
         Result := Result + Effective_Width (Item.Definitions (Column)) + 1;
      end loop;
      return Result;
   end Column_X;

   function Column_Region
     (Item : Model; Column : Column_Id)
      return Flyology_TUI.Geometry.Rectangle is
     ((X      => Integer (Column_X (Item, Column)),
       Y      => 0,
       Width  => Effective_Width (Item.Definitions (Column)),
       Height => Height (Item)));

   function Visible_Row_Region
     (Item : Model; Visible_Position : Positive)
      return Flyology_TUI.Geometry.Rectangle is
     ((X => 0, Y => Integer (Visible_Position),
       Width => Width (Item), Height => 1));

   type Move_Direction is (Toward_Start, Toward_End);

   function Magnitude (Value : Integer) return Natural is
     (if Value = Integer'First then Natural'Last else Natural (abs Value));

   procedure Move_Focus
     (Item      : in out Model;
      Direction : Move_Direction;
      Steps     : Natural;
      Changed   : out Boolean)
   is
      Before_Focus : constant Natural := Item.Focused;
      Before_Selected : constant Natural := Item.Selected;
   begin
      if Item.Values.Is_Empty then
         Changed := False;
         return;
      end if;
      if Direction = Toward_Start then
         Item.Focused := Item.Focused -
           Natural'Min (Steps, Item.Focused - 1);
      else
         Item.Focused := Item.Focused +
           Natural'Min (Steps, Length (Item) - Item.Focused);
      end if;
      Item.Selected := Source_At (Item, Item.Focused) + 1;
      Ensure_Visible (Item);
      Changed := Item.Focused /= Before_Focus
        or else Item.Selected /= Before_Selected;
   end Move_Focus;

   function Is_Activation_Key
     (Event : Flyology_TUI.Events.Terminal_Event) return Boolean is
   begin
      return Event.Key.Kind = Flyology_TUI.Events.Enter_Key
        or else
          (Event.Key.Kind = Flyology_TUI.Events.Text_Key
           and then Text_Impl.To_Wide_Wide_String (Event.Key.Value) = " ");
   end Is_Activation_Key;

   function Next_Sort
     (Item : Model; Column : Column_Id) return Sort_Direction is
     (if Item.Sorting.Column /= Column
        or else Item.Sorting.Direction = Unsorted
      then Ascending
      elsif Item.Sorting.Direction = Ascending then Descending
      else Unsorted);

   procedure Move_Header
     (Item      : in out Model;
      Direction : Move_Direction;
      Changed   : out Boolean)
   is
      Before : constant Column_Id := Item.Header_Column;
   begin
      if Direction = Toward_Start
        and then Item.Header_Column /= Column_Id'First
      then
         Item.Header_Column := Column_Id'Pred (Item.Header_Column);
      elsif Direction = Toward_End
        and then Item.Header_Column /= Column_Id'Last
      then
         Item.Header_Column := Column_Id'Succ (Item.Header_Column);
      end if;
      Changed := Before /= Item.Header_Column;
   end Move_Header;

   function Handle
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Terminal_Event)
      return Flyology_TUI.Components.Interactions.Update_Result
   is
      Changed : Boolean := False;
   begin
      if not Item.Enabled
        or else Event.Kind /= Flyology_TUI.Events.Key_Press
      then
         return Flyology_TUI.Components.Interactions.Ignored;
      end if;
      if Item.Focus_Zone_Value = Header_Area then
         case Event.Key.Kind is
            when Flyology_TUI.Events.Arrow_Left_Key =>
               Move_Header (Item, Toward_Start, Changed);
            when Flyology_TUI.Events.Arrow_Right_Key =>
               Move_Header (Item, Toward_End, Changed);
            when Flyology_TUI.Events.Arrow_Down_Key =>
               if not Item.Values.Is_Empty then
                  Item.Focus_Zone_Value := Row_Area;
                  Changed := True;
               end if;
            when Flyology_TUI.Events.Arrow_Up_Key => null;
            when others =>
               if Is_Activation_Key (Event)
                 and then Item.Definitions (Item.Header_Column).Sortable
               then
                  Sort_By
                    (Item, Item.Header_Column,
                     Next_Sort (Item, Item.Header_Column));
                  return
                    (Handled => True, Changed => True, Activated => True,
                     others => <>);
               end if;
               return Flyology_TUI.Components.Interactions.Ignored;
         end case;
         return (Handled => True, Changed => Changed, others => <>);
      elsif Item.Values.Is_Empty then
         Item.Focus_Zone_Value := Header_Area;
         return (Handled => True, Changed => True, others => <>);
      end if;

      case Event.Key.Kind is
         when Flyology_TUI.Events.Arrow_Up_Key =>
            if Item.Focused = 1 then
               Item.Focus_Zone_Value := Header_Area;
               Changed := True;
            else
               Move_Focus (Item, Toward_Start, 1, Changed);
            end if;
         when Flyology_TUI.Events.Arrow_Down_Key =>
            Move_Focus (Item, Toward_End, 1, Changed);
         when Flyology_TUI.Events.Page_Up_Key =>
            Move_Focus
              (Item, Toward_Start, Natural'Max (1, Item.Rows), Changed);
         when Flyology_TUI.Events.Page_Down_Key =>
            Move_Focus
              (Item, Toward_End, Natural'Max (1, Item.Rows), Changed);
         when Flyology_TUI.Events.Home_Key =>
            Move_Focus (Item, Toward_Start, Natural'Last, Changed);
         when Flyology_TUI.Events.End_Key =>
            Move_Focus (Item, Toward_End, Natural'Last, Changed);
         when others =>
            if Is_Activation_Key (Event) then
               return (Handled => True, Activated => True, others => <>);
            end if;
            return Flyology_TUI.Components.Interactions.Ignored;
      end case;
      return (Handled => True, Changed => Changed, others => <>);
   end Handle;

   function Hit_Column (Item : Model; X : Integer) return Column_Id is
      Last : Column_Id := Column_Id'First;
   begin
      for Column in Column_Id loop
         Last := Column;
         declare
            Region : constant Flyology_TUI.Geometry.Rectangle :=
              Column_Region (Item, Column);
         begin
            if Flyology_TUI.Geometry.Contains (Region, X, 0) then
               return Column;
            end if;
         end;
      end loop;
      return Last;
   end Hit_Column;

   function Handle
     (Item  : in out Model;
      Event : Flyology_TUI.Mouse.Local_Event)
      return Flyology_TUI.Components.Interactions.Update_Result
   is
      Changed : Boolean := False;
   begin
      if not Item.Enabled then
         return Flyology_TUI.Components.Interactions.Ignored;
      elsif Event.Action = Flyology_TUI.Events.Mouse_Wheel
        and then Event.X >= 0 and then Event.X < Integer (Width (Item))
        and then Event.Y >= 0 and then Event.Y < Integer (Height (Item))
        and then Event.Wheel_Y /= 0 and then not Item.Values.Is_Empty
      then
         Item.Focus_Zone_Value := Row_Area;
         if Event.Wheel_Y > 0 then
            Move_Focus
              (Item, Toward_Start, Magnitude (Event.Wheel_Y), Changed);
         else
            Move_Focus
              (Item, Toward_End, Magnitude (Event.Wheel_Y), Changed);
         end if;
         return
           (Handled => True, Changed => Changed, Focus_Requested => True,
            others => <>);
      elsif Event.Action /= Flyology_TUI.Events.Mouse_Click
        or else Event.Button /= Flyology_TUI.Events.Left_Button
        or else Event.X < 0 or else Event.X >= Integer (Width (Item))
        or else Event.Y < 0 or else Event.Y >= Integer (Height (Item))
      then
         return Flyology_TUI.Components.Interactions.Ignored;
      elsif Event.Y = 0 then
         if Event.X >= 2 then
            declare
               Column : constant Column_Id := Hit_Column (Item, Event.X);
            begin
               Changed := Item.Focus_Zone_Value /= Header_Area
                 or else Item.Header_Column /= Column;
               Item.Focus_Zone_Value := Header_Area;
               Item.Header_Column := Column;
               if Item.Definitions (Column).Sortable
                 and then Flyology_TUI.Geometry.Contains
                   (Column_Region (Item, Column), Event.X, 0)
               then
                  Sort_By
                    (Item, Column, Next_Sort (Item, Column));
                  return
                    (Handled => True, Changed => True,
                     Focus_Requested => True, others => <>);
               end if;
            end;
         end if;
         if Item.Focus_Zone_Value /= Header_Area then
            Item.Focus_Zone_Value := Header_Area;
            Changed := True;
         end if;
         return
           (Handled => True,
            Changed => Changed,
            Focus_Requested => True,
            others => <>);
      else
         declare
            Visible : constant Natural := Natural (Event.Y);
         begin
            if Visible <= Visible_Row_Count (Item) then
               declare
                  Display : constant Natural :=
                    Item.First + (Visible - 1);
                  Source  : constant Natural := Source_At (Item, Display);
               begin
                  Changed := Item.Selected /= Source + 1
                    or else Item.Focused /= Display
                    or else Item.Focus_Zone_Value /= Row_Area;
                  Item.Selected := Source + 1;
                  Item.Focused := Display;
                  Item.Focus_Zone_Value := Row_Area;
                  return
                    (Handled => True, Changed => Changed, Activated => True,
                     Focus_Requested => True, others => <>);
               end;
            end if;
         end;
      end if;
      return Flyology_TUI.Components.Interactions.Ignored;
   end Handle;

   procedure Update
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Terminal_Event)
   is
      Discard : constant Flyology_TUI.Components.Interactions.Update_Result :=
        Handle (Item, Event);
      pragma Unreferenced (Discard);
   begin null; end Update;

   procedure Update
     (Item  : in out Model;
      Event : Flyology_TUI.Mouse.Local_Event)
   is
      Discard : constant Flyology_TUI.Components.Interactions.Update_Result :=
        Handle (Item, Event);
      pragma Unreferenced (Discard);
   begin null; end Update;

   procedure Write_Aligned
     (Target : in out Flyology_TUI.Surfaces.Surface;
      X, Y, Columns : Natural;
      Value : Wide_Wide_String;
      Align : Alignment;
      Style : Flyology_TUI.Styles.Style)
   is
      Used : constant Natural := Flyology_TUI.Glyphs.Width_Of (Value);
      Offset : Natural := 0;
   begin
      if Columns = 0 then
         return;
      elsif Used < Columns then
         case Align is
            when Align_Left => Offset := 0;
            when Align_Center => Offset := (Columns - Used) / 2;
            when Align_Right => Offset := Columns - Used;
         end case;
      end if;
      Target.Write (X + Offset, Y, Value, Style);
   end Write_Aligned;

   function Render_Cell
     (Columns : Natural;
      Value   : Wide_Wide_String;
      Align   : Alignment;
      Style   : Flyology_TUI.Styles.Style)
      return Flyology_TUI.Surfaces.Surface
   is
      Result : Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.Create (Columns, 1, Style);
   begin
      Write_Aligned (Result, 0, 0, Columns, Value, Align, Style);
      return Result;
   end Render_Cell;

   function Render
     (Item      : Model;
      Look      : Appearance;
      Has_Focus : Boolean := False) return Flyology_TUI.Surfaces.Surface
   is
      Result : Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.Create (Width (Item), Height (Item));
   begin
      if Width (Item) >= 2 then
         Result.Write (0, 0, "  ", Look.Header);
      end if;
      for Column in Column_Id loop
         declare
            X : constant Natural := Column_X (Item, Column);
            W : constant Natural :=
              Effective_Width (Item.Definitions (Column));
            Header_Style : constant Flyology_TUI.Styles.Style :=
              (if Has_Focus
                 and then Item.Focus_Zone_Value = Header_Area
                 and then Item.Header_Column = Column
               then Look.Focused else Look.Header);
            Marker : constant Wide_Wide_String :=
              (if W = 0 then ""
               elsif Item.Sorting.Direction = Ascending
                 and then Item.Sorting.Column = Column then "▲"
               elsif Item.Sorting.Direction = Descending
                 and then Item.Sorting.Column = Column then "▼"
               else "");
         begin
            declare
               Header_Cell : Flyology_TUI.Surfaces.Surface :=
                 Render_Cell
                   (W,
                    Text_Impl.To_Wide_Wide_String
                      (Item.Definitions (Column).Heading),
                    Item.Definitions (Column).Align, Header_Style);
            begin
               if Marker'Length > 0 and then W > 0 then
                  Header_Cell.Write (W - 1, 0, Marker, Header_Style);
               end if;
               Result.Overlay (Header_Cell, X, 0);
            end;
            if Column /= Column_Id'Last and then X + W < Width (Item) then
               Result.Write (X + W, 0, "│", Look.Divider);
            end if;
         end;
      end loop;

      for Visible in 1 .. Visible_Row_Count (Item) loop
         declare
            Display : constant Natural := Item.First + (Visible - 1);
            Source  : constant Natural := Source_At (Item, Display);
            Selected : constant Boolean := Item.Selected = Source + 1;
            Focused : constant Boolean :=
              Has_Focus and then Item.Focused = Display;
            Style : constant Flyology_TUI.Styles.Style :=
              (if not Item.Enabled then Look.Muted
               elsif Focused then Look.Focused
               elsif Selected then Look.Selected
               else Look.Normal);
         begin
            Result.Write
              (0, Visible, (if Selected then "› " else "  "), Style);
            for Column in Column_Id loop
               declare
                  X : constant Natural := Column_X (Item, Column);
                  W : constant Natural :=
                    Effective_Width (Item.Definitions (Column));
               begin
                  Result.Overlay
                    (Render_Cell
                       (W,
                        Cell (Item.Values.Element (Source), Column),
                        Item.Definitions (Column).Align, Style),
                     X, Visible);
                  if Column /= Column_Id'Last
                    and then X + W < Width (Item)
                  then
                     Result.Write (X + W, Visible, "│", Look.Divider);
                  end if;
               end;
            end loop;
         end;
      end loop;
      return Result;
   end Render;

   function Render
     (Item      : Model;
      Theme     : Flyology_TUI.Themes.Theme;
      Has_Focus : Boolean := False) return Flyology_TUI.Surfaces.Surface is
     (Render (Item, From_Theme (Theme), Has_Focus));

end Flyology_TUI.Components.Tables;
