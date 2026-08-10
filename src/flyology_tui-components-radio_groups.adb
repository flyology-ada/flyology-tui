with Ada.Strings.Wide_Wide_Unbounded;
with Flyology_TUI.Glyphs;

package body Flyology_TUI.Components.Radio_Groups is
   package Text renames Ada.Strings.Wide_Wide_Unbounded;
   use type Flyology_TUI.Events.Key_Kind;
   use type Flyology_TUI.Events.Mouse_Action;
   use type Flyology_TUI.Events.Mouse_Button;
   use type Flyology_TUI.Events.Terminal_Event_Kind;

   function From_Theme
     (Theme : Flyology_TUI.Themes.Theme) return Appearance is
     (Normal   => Theme.Primary,
      Selected => Theme.Selected,
      Focused  => Theme.Focused,
      Disabled => Theme.Muted);

   function From_Palette
     (Palette : Flyology_TUI.Themes.Palette) return Appearance is
     (Normal   => Palette.Content,
      Selected => Palette.Selected,
      Focused  => Palette.Interaction,
      Disabled => Palette.Disabled);

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
      Id     : Id_Type) return Natural
   is
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
      New_Focused  : Natural := 0;
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

         if Item.Focused > 0 then
            New_Focused := Find
              (New_Values, Id_Of (Item.Values.Element (Item.Focused - 1)));
         end if;
         if New_Focused = 0 then
            New_Focused := New_Selected;
         end if;
      end if;

      Item.Values := New_Values;
      Item.Selected := New_Selected;
      Item.Focused := New_Focused;
      Item.Armed := 0;
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

   function Length (Item : Model) return Natural is
     (Natural (Item.Values.Length));

   function Is_Empty (Item : Model) return Boolean is
     (Item.Values.Is_Empty);

   procedure Select_Id (Item : in out Model; Id : Id_Type) is
      Index : constant Natural := Find (Item.Values, Id);
   begin
      if Index = 0 then
         raise Flyology_TUI.Components.Structure_Error;
      end if;
      Item.Selected := Index;
      Item.Focused := Index;
      Item.Armed := 0;
   end Select_Id;

   function Selected_Id (Item : Model) return Id_Type is
     (Id_Of (Item.Values.Element (Item.Selected - 1)));

   procedure Set_Enabled (Item : in out Model; Enabled : Boolean) is
   begin
      Item.Enabled := Enabled;
      if not Enabled then
         Item.Armed := 0;
      end if;
   end Set_Enabled;

   function Is_Enabled (Item : Model) return Boolean is (Item.Enabled);

   function Is_Activation_Key
     (Event : Flyology_TUI.Events.Terminal_Event) return Boolean
   is
   begin
      if Event.Kind /= Flyology_TUI.Events.Key_Press then
         return False;
      elsif Event.Key.Kind = Flyology_TUI.Events.Enter_Key then
         return True;
      elsif Event.Key.Kind = Flyology_TUI.Events.Text_Key then
         return Text.To_Wide_Wide_String (Event.Key.Value) = " ";
      else
         return False;
      end if;
   end Is_Activation_Key;

   procedure Move_Focus (Item : in out Model; Amount : Integer) is
      Last : constant Integer := Integer (Item.Values.Length);
   begin
      if Last = 0 then
         return;
      end if;
      Item.Focused := Natural
        (Integer'Max (1, Integer'Min (Last, Integer (Item.Focused) + Amount)));
   end Move_Focus;

   function Choose_Focused
     (Item : in out Model)
      return Flyology_TUI.Components.Interactions.Update_Result
   is
      Changed : constant Boolean := Item.Selected /= Item.Focused;
   begin
      Item.Selected := Item.Focused;
      return
        (Handled => True, Activated => True, Changed => Changed, others => <>);
   end Choose_Focused;

   function Commit_Navigation
     (Item           : in out Model;
      Prior_Focus    : Natural;
      Prior_Selected : Natural)
      return Flyology_TUI.Components.Interactions.Update_Result
   is
      Focus_Changed : constant Boolean := Item.Focused /= Prior_Focus;
      Identity_Changed : constant Boolean :=
        Item.Focused /= Prior_Selected;
   begin
      Item.Selected := Item.Focused;
      return
        (Handled   => True,
         Activated => Identity_Changed,
         Changed   => Focus_Changed or else Identity_Changed,
         others    => <>);
   end Commit_Navigation;

   function Handle
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Terminal_Event)
      return Flyology_TUI.Components.Interactions.Update_Result
   is
      Prior_Focus    : Natural;
      Prior_Selected : Natural;
   begin
      if not Item.Enabled or else Item.Values.Is_Empty
        or else Event.Kind /= Flyology_TUI.Events.Key_Press
      then
         return Flyology_TUI.Components.Interactions.Ignored;
      end if;

      case Event.Key.Kind is
         when Flyology_TUI.Events.Arrow_Up_Key
            | Flyology_TUI.Events.Arrow_Left_Key =>
            Prior_Focus := Item.Focused;
            Prior_Selected := Item.Selected;
            Move_Focus (Item, -1);
            return Commit_Navigation
              (Item, Prior_Focus, Prior_Selected);
         when Flyology_TUI.Events.Arrow_Down_Key
            | Flyology_TUI.Events.Arrow_Right_Key =>
            Prior_Focus := Item.Focused;
            Prior_Selected := Item.Selected;
            Move_Focus (Item, 1);
            return Commit_Navigation
              (Item, Prior_Focus, Prior_Selected);
         when Flyology_TUI.Events.Home_Key =>
            Prior_Focus := Item.Focused;
            Prior_Selected := Item.Selected;
            Item.Focused := 1;
            return Commit_Navigation
              (Item, Prior_Focus, Prior_Selected);
         when Flyology_TUI.Events.End_Key =>
            Prior_Focus := Item.Focused;
            Prior_Selected := Item.Selected;
            Item.Focused := Natural (Item.Values.Length);
            return Commit_Navigation
              (Item, Prior_Focus, Prior_Selected);
         when others =>
            if Is_Activation_Key (Event) then
               return Choose_Focused (Item);
            end if;
      end case;
      return Flyology_TUI.Components.Interactions.Ignored;
   end Handle;

   function Hit_Row
     (Item : Model; Event : Flyology_TUI.Mouse.Local_Event) return Natural is
      Columns : Natural := 0;
   begin
      for Value of Item.Values loop
         Columns := Natural'Max
           (Columns, Flyology_TUI.Glyphs.Width_Of (Label (Value)) + 4);
      end loop;
      if Event.X < 0 or else Event.X >= Integer (Columns)
        or else Event.Y < 0
        or else Event.Y >= Integer (Item.Values.Length)
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
      Hit    : constant Natural := Hit_Row (Item, Event);
      Focus_Changed : constant Boolean := Item.Focused /= Hit;
      Result : Flyology_TUI.Components.Interactions.Update_Result;
   begin
      if Event.Button /= Flyology_TUI.Events.Left_Button then
         return Result;
      elsif Event.Action = Flyology_TUI.Events.Mouse_Click then
         if Item.Enabled and then Hit > 0 then
            Item.Armed := Hit;
            Item.Capturing := True;
            Item.Focused := Hit;
            return
              (Handled         => True,
               Changed         => Focus_Changed,
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
         if Item.Enabled and then Item.Armed > 0 and then Hit = Item.Armed then
            Result.Changed := Item.Selected /= Hit;
            Item.Selected := Hit;
            Item.Focused := Hit;
            Result.Activated := True;
         end if;
         Item.Armed := 0;
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
     (Item      : Model;
      Look      : Appearance;
      Has_Focus : Boolean := False)
      return Flyology_TUI.Surfaces.Surface
   is
      Columns : Natural := 0;
   begin
      for Value of Item.Values loop
         Columns := Natural'Max
           (Columns, Flyology_TUI.Glyphs.Width_Of (Label (Value)) + 4);
      end loop;
      declare
         Result : Flyology_TUI.Surfaces.Surface :=
           Flyology_TUI.Surfaces.Create (Columns, Length (Item));
      begin
         for Index in 1 .. Length (Item) loop
            declare
               Selected : constant Boolean := Index = Item.Selected;
               Focused  : constant Boolean :=
                 Has_Focus and then Index = Item.Focused;
               Style : constant Flyology_TUI.Styles.Style :=
                 (if not Item.Enabled then Look.Disabled
                  elsif Focused then Look.Focused
                  elsif Selected then Look.Selected
                  else Look.Normal);
            begin
               Result.Write
                 (0, Index - 1,
                  (if Selected then "(o) " else "( ) ")
                    & Label (Item.Values.Element (Index - 1)),
                  Style);
            end;
         end loop;
         return Result;
      end;
   end Render;

   function Render
     (Item      : Model;
      Theme     : Flyology_TUI.Themes.Theme;
      Has_Focus : Boolean := False)
      return Flyology_TUI.Surfaces.Surface is
     (Render (Item, From_Theme (Theme), Has_Focus));

end Flyology_TUI.Components.Radio_Groups;
