with Ada.Strings.Wide_Wide_Unbounded;
with Flyology_TUI.Glyphs;

package body Flyology_TUI.Components.Selectors is
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

   function Find (Item : Model; Id : Id_Type) return Natural is
   begin
      if Item.Values.Is_Empty then
         return 0;
      end if;
      for Index in 0 .. Natural (Item.Values.Length) - 1 loop
         if Id_Of (Item.Values.Element (Index)) = Id then
            return Index + 1;
         end if;
      end loop;
      return 0;
   end Find;

   function Was_Selected (Item : Model; Id : Id_Type) return Boolean is
      Index : constant Natural := Find (Item, Id);
   begin
      return Index > 0 and then Item.Selected.Element (Index - 1);
   end Was_Selected;

   procedure Set_Items (Item : in out Model; Values : Item_Array) is
      New_Values   : Item_Vectors.Vector;
      New_Selected : Boolean_Vectors.Vector;
      New_Focused  : Natural := 0;
      Kept_One     : Boolean := False;
   begin
      Validate (Values);
      for Value of Values loop
         New_Values.Append (Value);
         declare
            Keep : constant Boolean :=
              Was_Selected (Item, Id_Of (Value))
              and then
                (Item.Kind = Flyology_TUI.Components.Multiple_Selection
                 or else not Kept_One);
         begin
            New_Selected.Append (Keep);
            Kept_One := Kept_One or else Keep;
         end;
      end loop;

      if not New_Values.Is_Empty then
         if Item.Focused > 0 then
            declare
               Old_Id : constant Id_Type :=
                 Id_Of (Item.Values.Element (Item.Focused - 1));
            begin
               for Index in 0 .. Natural (New_Values.Length) - 1 loop
                  if Id_Of (New_Values.Element (Index)) = Old_Id then
                     New_Focused := Index + 1;
                     exit;
                  end if;
               end loop;
            end;
         end if;
         if New_Focused = 0 then
            New_Focused := 1;
         end if;
      end if;

      Item.Values := New_Values;
      Item.Selected := New_Selected;
      Item.Focused := New_Focused;
      Item.Armed := 0;
   end Set_Items;

   function Create
     (Values  : Item_Array;
      Mode    : Flyology_TUI.Components.Selection_Mode :=
        Flyology_TUI.Components.Single_Selection;
      Enabled : Boolean := True) return Model
   is
      Result : Model;
   begin
      Result.Kind := Mode;
      Result.Enabled := Enabled;
      Set_Items (Result, Values);
      return Result;
   end Create;

   procedure Replace_Selection (Item : in out Model; Values : Id_Array) is
      Replacement : Boolean_Vectors.Vector;
   begin
      if Values'Length > Capacity then
         raise Flyology_TUI.Components.Capacity_Error;
      elsif Item.Kind = Flyology_TUI.Components.Single_Selection
        and then Values'Length > 1
      then
         raise Flyology_TUI.Components.Structure_Error;
      end if;

      for Left in Values'Range loop
         if Find (Item, Values (Left)) = 0 then
            raise Flyology_TUI.Components.Structure_Error;
         end if;
         for Right in Values'Range loop
            if Right > Left
              and then Values (Left) = Values (Right)
            then
               raise Flyology_TUI.Components.Structure_Error;
            end if;
         end loop;
      end loop;

      if not Item.Values.Is_Empty then
         for Index in 0 .. Natural (Item.Values.Length) - 1 loop
            declare
               Chosen : Boolean := False;
            begin
               for Value of Values loop
                  Chosen := Chosen or else
                  Id_Of (Item.Values.Element (Index)) = Value;
               end loop;
               Replacement.Append (Chosen);
            end;
         end loop;
      end if;
      Item.Selected := Replacement;
      Item.Armed := 0;
   end Replace_Selection;

   procedure Set_Selected
     (Item : in out Model;
      Id   : Id_Type;
      Value : Boolean := True)
   is
      Index : constant Natural := Find (Item, Id);
   begin
      if Index = 0 then
         raise Flyology_TUI.Components.Structure_Error;
      end if;
      if Value and then
        Item.Kind = Flyology_TUI.Components.Single_Selection
      then
         for Position in 0 .. Natural (Item.Selected.Length) - 1 loop
            Item.Selected.Replace_Element (Position, False);
         end loop;
      end if;
      Item.Selected.Replace_Element (Index - 1, Value);
      Item.Focused := Index;
      Item.Armed := 0;
   end Set_Selected;

   function Length (Item : Model) return Natural is
     (Natural (Item.Values.Length));
   function Is_Empty (Item : Model) return Boolean is (Item.Values.Is_Empty);

   function Selected_Count (Item : Model) return Natural is
      Result : Natural := 0;
   begin
      for Value of Item.Selected loop
         if Value then
            Result := Result + 1;
         end if;
      end loop;
      return Result;
   end Selected_Count;

   function Is_Selected (Item : Model; Id : Id_Type) return Boolean is
   begin
      return Was_Selected (Item, Id);
   end Is_Selected;

   function Mode (Item : Model)
      return Flyology_TUI.Components.Selection_Mode is (Item.Kind);

   procedure Set_Enabled (Item : in out Model; Enabled : Boolean) is
   begin
      Item.Enabled := Enabled;
      if not Enabled then
         Item.Armed := 0;
      end if;
   end Set_Enabled;

   function Is_Enabled (Item : Model) return Boolean is (Item.Enabled);

   procedure Move_Focus (Item : in out Model; Amount : Integer) is
      Last : constant Integer := Integer (Item.Values.Length);
   begin
      if Last > 0 then
         Item.Focused := Natural
           (Integer'Max
              (1, Integer'Min (Last, Integer (Item.Focused) + Amount)));
      end if;
   end Move_Focus;

   function Toggle_Focused
     (Item : in out Model)
      return Flyology_TUI.Components.Interactions.Update_Result
   is
      Position : constant Natural := Item.Focused - 1;
      Before   : constant Boolean := Item.Selected.Element (Position);
   begin
      if Item.Kind = Flyology_TUI.Components.Single_Selection then
         for Index in 0 .. Natural (Item.Selected.Length) - 1 loop
            Item.Selected.Replace_Element (Index, False);
         end loop;
         Item.Selected.Replace_Element (Position, True);
         return
           (Handled => True, Activated => True, Changed => not Before,
            others => <>);
      else
         Item.Selected.Replace_Element (Position, not Before);
         return
           (Handled => True, Activated => True, Changed => True, others => <>);
      end if;
   end Toggle_Focused;

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
   begin
      if not Item.Enabled or else Item.Values.Is_Empty
        or else Event.Kind /= Flyology_TUI.Events.Key_Press
      then
         return Flyology_TUI.Components.Interactions.Ignored;
      end if;
      case Event.Key.Kind is
         when Flyology_TUI.Events.Arrow_Up_Key =>
            declare
               Before : constant Natural := Item.Focused;
            begin
               Move_Focus (Item, -1);
               return
                 (Handled => True,
                  Changed => Item.Focused /= Before,
                  others => <>);
            end;
         when Flyology_TUI.Events.Arrow_Down_Key =>
            declare
               Before : constant Natural := Item.Focused;
            begin
               Move_Focus (Item, 1);
               return
                 (Handled => True,
                  Changed => Item.Focused /= Before,
                  others => <>);
            end;
         when Flyology_TUI.Events.Home_Key =>
            declare
               Before : constant Natural := Item.Focused;
            begin
               Item.Focused := 1;
               return
                 (Handled => True,
                  Changed => Item.Focused /= Before,
                  others => <>);
            end;
         when Flyology_TUI.Events.End_Key =>
            declare
               Before : constant Natural := Item.Focused;
            begin
               Item.Focused := Natural (Item.Values.Length);
               return
                 (Handled => True,
                  Changed => Item.Focused /= Before,
                  others => <>);
            end;
         when others =>
            if Is_Activation_Key (Event) then
               return Toggle_Focused (Item);
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
            Item.Focused := Hit;
            Result := Toggle_Focused (Item);
            Result.Focus_Requested := True;
            Result.Capture :=
              Flyology_TUI.Components.Interactions.Release_Capture;
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
               Chosen : constant Boolean :=
                 Item.Selected.Element (Index - 1);
               Focused : constant Boolean :=
                 Has_Focus and then Item.Focused = Index;
               Style : constant Flyology_TUI.Styles.Style :=
                 (if not Item.Enabled then Look.Disabled
                  elsif Focused then Look.Focused
                  elsif Chosen then Look.Selected
                  else Look.Normal);
            begin
               Result.Write
                 (0, Index - 1,
                  (if Chosen then "[x] " else "[ ] ")
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

end Flyology_TUI.Components.Selectors;
