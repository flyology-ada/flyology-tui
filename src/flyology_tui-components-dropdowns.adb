with Ada.Strings.Wide_Wide_Unbounded;
with Flyology_TUI.Glyphs;

package body Flyology_TUI.Components.Dropdowns is
   package Text renames Ada.Strings.Wide_Wide_Unbounded;
   use type Flyology_TUI.Events.Key_Kind;
   use type Flyology_TUI.Events.Mouse_Action;
   use type Flyology_TUI.Events.Mouse_Button;
   use type Flyology_TUI.Events.Terminal_Event_Kind;

   function From_Theme
     (Theme : Flyology_TUI.Themes.Theme) return Appearance is
     (Normal      => Theme.Primary,
      Selected    => Theme.Selected,
      Highlighted => Theme.Focused,
      Focused     => Theme.Focused,
      Disabled    => Theme.Muted);

   function From_Palette
     (Palette : Flyology_TUI.Themes.Palette) return Appearance is
     (Normal      => Palette.Content,
      Selected    => Palette.Selected,
      Highlighted => Palette.Button_Focused,
      Focused     => Palette.Interaction,
      Disabled    => Palette.Disabled);

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

   function Find
     (Values : Item_Vectors.Vector;
      Id     : Id_Type) return Natural is
   begin
      if Values.Is_Empty then
         return 0;
      end if;
      for Index in 0 .. Natural (Values.Length) - 1 loop
         if Id_Of (Values.Element (Index)) = Id then
            return Index + 1;
         end if;
      end loop;
      return 0;
   end Find;

   procedure Set_Items (Item : in out Model; Values : Item_Array) is
      New_Values   : Item_Vectors.Vector;
      New_Selected : Natural := 0;
   begin
      Validate (Values);
      for Value of Values loop
         New_Values.Append (Value);
      end loop;
      if not New_Values.Is_Empty then
         if Item.Selected > 0 then
            New_Selected := Find
              (New_Values, Id_Of (Item.Values.Element (Item.Selected - 1)));
         end if;
         if New_Selected = 0 then
            New_Selected := 1;
         end if;
      end if;
      Item.Values := New_Values;
      Item.Selected := New_Selected;
      Item.Highlighted := New_Selected;
      Item.Armed_Row := 0;
      Item.Opened := False;
   end Set_Items;

   function Create
     (Values  : Item_Array;
      Enabled : Boolean := True) return Model
   is
      Result : Model;
   begin
      Result.Enabled := Enabled;
      Set_Items (Result, Values);
      return Result;
   end Create;

   procedure Select_Id (Item : in out Model; Id : Id_Type) is
      Index : constant Natural := Find (Item.Values, Id);
   begin
      if Index = 0 then
         raise Flyology_TUI.Components.Structure_Error;
      end if;
      Item.Selected := Index;
      Item.Highlighted := Index;
      Item.Armed_Row := 0;
   end Select_Id;

   function Length (Item : Model) return Natural is
     (Natural (Item.Values.Length));
   function Is_Empty (Item : Model) return Boolean is (Item.Values.Is_Empty);
   function Selected_Id (Item : Model) return Id_Type is
     (Id_Of (Item.Values.Element (Item.Selected - 1)));

   function Is_Open (Item : Model) return Boolean is (Item.Opened);

   procedure Open (Item : in out Model) is
   begin
      if Item.Enabled and then not Item.Values.Is_Empty then
         Item.Opened := True;
         Item.Highlighted := Item.Selected;
         Item.Armed_Row := 0;
      end if;
   end Open;

   procedure Close (Item : in out Model) is
   begin
      Item.Opened := False;
      Item.Highlighted := Item.Selected;
      Item.Armed_Row := 0;
   end Close;

   function Dismiss
     (Item : in out Model)
      return Flyology_TUI.Components.Interactions.Update_Result
   is
      Was_Open : constant Boolean := Item.Opened;
      Was_Capturing : constant Boolean := Item.Capturing;
   begin
      Close (Item);
      Item.Capturing := False;
      return
        (Handled => Was_Open or else Was_Capturing,
         Changed => Was_Open,
         Capture =>
           (if Was_Capturing
            then Flyology_TUI.Components.Interactions.Release_Capture
            else Flyology_TUI.Components.Interactions.No_Capture_Change),
         others => <>);
   end Dismiss;

   procedure Set_Enabled (Item : in out Model; Enabled : Boolean) is
   begin
      Item.Enabled := Enabled;
      if not Enabled then
         Close (Item);
      end if;
   end Set_Enabled;
   function Is_Enabled (Item : Model) return Boolean is (Item.Enabled);

   function Width (Item : Model) return Natural is
      Result : Natural := 5;
   begin
      for Value of Item.Values loop
         Result := Natural'Max
           (Result, Flyology_TUI.Glyphs.Width_Of (Label (Value)) + 5);
      end loop;
      return Result;
   end Width;

   function Height (Item : Model) return Natural is
     (if Item.Opened then Length (Item) + 1 else 1);

   procedure Move
     (Item : in out Model;
      Amount : Integer;
      Changed : out Boolean)
   is
      Position : Natural :=
        (if Item.Opened then Item.Highlighted else Item.Selected);
      Last : constant Integer := Integer (Item.Values.Length);
      Before : constant Natural := Position;
   begin
      if Amount < 0 then
         if Amount = Integer'First
           or else Natural (-Amount) >= Position - 1
         then
            Position := 1;
         else
            Position := Position - Natural (-Amount);
         end if;
      elsif Amount > 0 then
         if Natural (Amount) >= Natural (Last) - Position then
            Position := Natural (Last);
         else
            Position := Position + Natural (Amount);
         end if;
      end if;
      if Item.Opened then
         Item.Highlighted := Position;
      else
         Item.Selected := Position;
         Item.Highlighted := Position;
      end if;
      Changed := Position /= Before;
   end Move;

   function Is_Activation_Key
     (Event : Flyology_TUI.Events.Terminal_Event) return Boolean is
   begin
      return Event.Key.Kind = Flyology_TUI.Events.Enter_Key
        or else
          (Event.Key.Kind = Flyology_TUI.Events.Text_Key
           and then Text.To_Wide_Wide_String (Event.Key.Value) = " ");
   end Is_Activation_Key;

   function Handle
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Terminal_Event)
      return Flyology_TUI.Components.Interactions.Update_Result
   is
      Changed : Boolean := False;
   begin
      if not Item.Enabled or else Item.Values.Is_Empty
        or else Event.Kind /= Flyology_TUI.Events.Key_Press
      then
         return Flyology_TUI.Components.Interactions.Ignored;
      elsif Event.Key.Kind = Flyology_TUI.Events.Escape_Key
        and then Item.Opened
      then
         return Dismiss (Item);
      elsif Is_Activation_Key (Event) then
         if Item.Opened then
            Changed := Item.Selected /= Item.Highlighted;
            Item.Selected := Item.Highlighted;
            Close (Item);
            return
              (Handled => True, Activated => True, Changed => Changed,
               others => <>);
         else
            Open (Item);
            return (Handled => True, Changed => True, others => <>);
         end if;
      end if;

      case Event.Key.Kind is
         when Flyology_TUI.Events.Arrow_Up_Key =>
            Move (Item, -1, Changed);
         when Flyology_TUI.Events.Arrow_Down_Key =>
            Move (Item, 1, Changed);
         when Flyology_TUI.Events.Home_Key =>
            if Item.Opened then
               Changed := Item.Highlighted /= 1;
               Item.Highlighted := 1;
            else
               Changed := Item.Selected /= 1;
               Item.Selected := 1;
               Item.Highlighted := 1;
            end if;
         when Flyology_TUI.Events.End_Key =>
            declare
               Last : constant Natural := Natural (Item.Values.Length);
            begin
               if Item.Opened then
                  Changed := Item.Highlighted /= Last;
                  Item.Highlighted := Last;
               else
                  Changed := Item.Selected /= Last;
                  Item.Selected := Last;
                  Item.Highlighted := Last;
               end if;
            end;
         when others =>
            return Flyology_TUI.Components.Interactions.Ignored;
      end case;
      return
        (Handled => True,
         Activated => Changed and then not Item.Opened,
         Changed => Changed,
         others => <>);
   end Handle;

   function Hit_Row
     (Item : Model; Event : Flyology_TUI.Mouse.Local_Event) return Natural is
   begin
      if Event.X < 0 or else Event.X >= Integer (Width (Item))
        or else Event.Y < 0 or else Event.Y >= Integer (Height (Item))
      then
         return 0;
      end if;
      return Natural (Event.Y) + 1;
   end Hit_Row;

   function Handle
     (Item  : in out Model;
      Event : Flyology_TUI.Mouse.Local_Event)
      return Flyology_TUI.Components.Interactions.Update_Result
   is
      Hit     : constant Natural := Hit_Row (Item, Event);
      Result  : Flyology_TUI.Components.Interactions.Update_Result;
      Changed : Boolean := False;
   begin
      if Event.Action = Flyology_TUI.Events.Mouse_Wheel
        and then Item.Enabled and then not Item.Values.Is_Empty
        and then Hit > 0 and then Event.Wheel_Y /= 0
      then
         if Event.Wheel_Y = Integer'First then
            Move (Item, Integer'Last, Changed);
         else
            Move (Item, -Event.Wheel_Y, Changed);
         end if;
         return
           (Handled => True,
            Activated => Changed and then not Item.Opened,
            Changed => Changed,
            others => <>);
      elsif Event.Button /= Flyology_TUI.Events.Left_Button then
         return Result;
      elsif Event.Action = Flyology_TUI.Events.Mouse_Click then
         if Item.Opened and then Hit = 0 then
            return Dismiss (Item);
         elsif Item.Enabled and then Hit > 0 then
            Item.Armed_Row := Hit;
            Item.Capturing := True;
            return
              (Handled         => True,
               Focus_Requested => True,
               Capture         =>
                 Flyology_TUI.Components.Interactions.Acquire_Capture,
               others          => <>);
         end if;
      elsif Event.Action = Flyology_TUI.Events.Mouse_Release
        and then Item.Capturing
      then
         Result.Handled := True;
         Result.Capture :=
           Flyology_TUI.Components.Interactions.Release_Capture;
         if Item.Enabled
           and then Item.Armed_Row > 0
           and then Hit = Item.Armed_Row
         then
            if Hit = 1 then
               if Item.Opened then
                  Close (Item);
               else
                  Open (Item);
               end if;
               Result.Changed := True;
            elsif Item.Opened then
               declare
                  Choice : constant Natural := Hit - 1;
               begin
                  Result.Changed := Item.Selected /= Choice;
                  Item.Selected := Choice;
                  Item.Highlighted := Choice;
                  Result.Activated := True;
                  Close (Item);
               end;
            end if;
         end if;
         Item.Armed_Row := 0;
         Item.Capturing := False;
         return Result;
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
   begin null; end Update;

   procedure Update
     (Item  : in out Model;
      Event : Flyology_TUI.Mouse.Local_Event)
   is
      Discard : constant Flyology_TUI.Components.Interactions.Update_Result :=
        Handle (Item, Event);
      pragma Unreferenced (Discard);
   begin null; end Update;

   function Render
     (Item      : Model;
      Look      : Appearance;
      Has_Focus : Boolean := False)
      return Flyology_TUI.Surfaces.Surface
   is
      Result : Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.Create (Width (Item), Height (Item));
      Header_Style : constant Flyology_TUI.Styles.Style :=
        (if not Item.Enabled then Look.Disabled
         elsif Has_Focus then Look.Focused
         else Look.Normal);
      Header_Label : constant Wide_Wide_String :=
        (if Item.Values.Is_Empty then ""
         else Label (Item.Values.Element (Item.Selected - 1)));
      Header_Padding : constant Natural :=
        Width (Item) - Flyology_TUI.Glyphs.Width_Of (Header_Label) - 5;
   begin
      Result.Write
        (0, 0,
         "[ " & Header_Label
           & Wide_Wide_String'(1 .. Header_Padding => ' ')
           & (if Item.Opened then " ^]" else " v]"),
         Header_Style);
      if Item.Opened then
         for Index in 1 .. Length (Item) loop
            declare
               Style : constant Flyology_TUI.Styles.Style :=
                 (if Index = Item.Highlighted then Look.Highlighted
                  elsif Index = Item.Selected then Look.Selected
                  else Look.Normal);
            begin
               Result.Write
                 (0, Index,
                  (if Index = Item.Selected then "> " else "  ")
                    & Label (Item.Values.Element (Index - 1)),
                  Style);
            end;
         end loop;
      end if;
      return Result;
   end Render;

   function Render
     (Item      : Model;
      Theme     : Flyology_TUI.Themes.Theme;
      Has_Focus : Boolean := False)
      return Flyology_TUI.Surfaces.Surface is
     (Render (Item, From_Theme (Theme), Has_Focus));

end Flyology_TUI.Components.Dropdowns;
