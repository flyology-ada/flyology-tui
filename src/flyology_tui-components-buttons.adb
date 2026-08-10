with Flyology_TUI.Glyphs;

package body Flyology_TUI.Components.Buttons is
   use type Flyology_TUI.Events.Key_Kind;
   use type Flyology_TUI.Events.Mouse_Action;
   use type Flyology_TUI.Events.Mouse_Button;
   use type Flyology_TUI.Events.Terminal_Event_Kind;

   function From_Theme
     (Theme : Flyology_TUI.Themes.Theme) return Appearance is
     (Normal   => Theme.Primary,
      Focused  => Theme.Focused,
      Pressed  => Theme.Selected,
      Disabled => Theme.Muted);

   function From_Palette
     (Palette : Flyology_TUI.Themes.Palette) return Appearance is
     (Normal   => Palette.Button,
      Focused  => Palette.Button_Focused,
      Pressed  => Palette.Button_Pressed,
      Disabled => Palette.Disabled);

   function Create
     (Label   : Wide_Wide_String;
      Enabled : Boolean := True) return Model is
     (Caption => Text.To_Unbounded_Wide_Wide_String (Label),
      Enabled => Enabled,
      Armed   => False,
      Capturing => False);

   procedure Set_Label (Item : in out Model; Label : Wide_Wide_String) is
   begin
      Item.Caption := Text.To_Unbounded_Wide_Wide_String (Label);
      Item.Armed := False;
   end Set_Label;

   function Label (Item : Model) return Wide_Wide_String is
     (Text.To_Wide_Wide_String (Item.Caption));

   procedure Set_Enabled (Item : in out Model; Enabled : Boolean) is
   begin
      Item.Enabled := Enabled;
      if not Enabled then
         Item.Armed := False;
      end if;
   end Set_Enabled;

   function Is_Enabled (Item : Model) return Boolean is (Item.Enabled);
   function Is_Armed (Item : Model) return Boolean is (Item.Armed);

   function Width (Item : Model) return Natural is
     (Flyology_TUI.Glyphs.Width_Of (Label (Item)) + 4);

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

   function Inside (Item : Model; Event : Flyology_TUI.Mouse.Local_Event)
      return Boolean is
     (Event.X >= 0
      and then Event.Y = 0
      and then Event.X < Integer (Width (Item)));

   function Handle
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Terminal_Event)
      return Flyology_TUI.Components.Interactions.Update_Result
   is
   begin
      if Item.Enabled and then Is_Activation_Key (Event) then
         return
           (Handled => True, Activated => True, others => <>);
      end if;
      return Flyology_TUI.Components.Interactions.Ignored;
   end Handle;

   function Handle
     (Item  : in out Model;
      Event : Flyology_TUI.Mouse.Local_Event)
      return Flyology_TUI.Components.Interactions.Update_Result
   is
      Result : Flyology_TUI.Components.Interactions.Update_Result;
   begin
      if Event.Button /= Flyology_TUI.Events.Left_Button then
         return Result;
      elsif Event.Action = Flyology_TUI.Events.Mouse_Click then
         if Item.Enabled and then Inside (Item, Event) then
            Item.Armed := True;
            Item.Capturing := True;
            return
              (Handled         => True,
               Changed         => True,
               Focus_Requested => True,
               Capture         =>
                 Flyology_TUI.Components.Interactions.Acquire_Capture,
               others          => <>);
         end if;
      elsif Event.Action = Flyology_TUI.Events.Mouse_Release
        and then Item.Capturing
      then
         Result.Activated :=
           Item.Enabled and then Item.Armed and then Inside (Item, Event);
         Result.Changed := Item.Armed;
         Item.Armed := False;
         Item.Capturing := False;
         Result.Handled := True;
         Result.Capture :=
           Flyology_TUI.Components.Interactions.Release_Capture;
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
     (Item       : Model;
      Look       : Appearance;
      Has_Focus  : Boolean := False)
      return Flyology_TUI.Surfaces.Surface
   is
      Style : constant Flyology_TUI.Styles.Style :=
        (if not Item.Enabled then Look.Disabled
         elsif Item.Armed then Look.Pressed
         elsif Has_Focus then Look.Focused
         else Look.Normal);
   begin
      return Flyology_TUI.Surfaces.From_Text
        ("[ " & Label (Item) & " ]", Style);
   end Render;

   function Render
     (Item       : Model;
      Theme      : Flyology_TUI.Themes.Theme;
      Has_Focus  : Boolean := False)
      return Flyology_TUI.Surfaces.Surface is
     (Render (Item, From_Theme (Theme), Has_Focus));

end Flyology_TUI.Components.Buttons;
