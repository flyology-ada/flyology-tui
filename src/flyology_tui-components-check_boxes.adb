with Flyology_TUI.Glyphs;

package body Flyology_TUI.Components.Check_Boxes is
   use type Flyology_TUI.Events.Key_Kind;
   use type Flyology_TUI.Events.Mouse_Action;
   use type Flyology_TUI.Events.Mouse_Button;
   use type Flyology_TUI.Events.Terminal_Event_Kind;

   function From_Theme
     (Theme : Flyology_TUI.Themes.Theme) return Appearance is
     (Normal   => Theme.Primary,
      Selected => Theme.Selected,
      Focused  => Theme.Focused,
      Pressed  => Theme.Selected,
      Disabled => Theme.Muted);

   function Create
     (Label   : Wide_Wide_String;
      State   : Check_State := Unchecked;
      Enabled : Boolean := True) return Model is
     (Caption => Text.To_Unbounded_Wide_Wide_String (Label),
      Value   => State,
      Enabled => Enabled,
      Armed   => False,
      Capturing => False);

   procedure Set_State (Item : in out Model; State : Check_State) is
   begin
      Item.Value := State;
      Item.Armed := False;
   end Set_State;

   function State (Item : Model) return Check_State is (Item.Value);

   procedure Set_Enabled (Item : in out Model; Enabled : Boolean) is
   begin
      Item.Enabled := Enabled;
      if not Enabled then
         Item.Armed := False;
      end if;
   end Set_Enabled;

   function Is_Enabled (Item : Model) return Boolean is (Item.Enabled);

   function Width (Item : Model) return Natural is
     (Flyology_TUI.Glyphs.Width_Of
        (Text.To_Wide_Wide_String (Item.Caption)) + 4);

   procedure Toggle (Item : in out Model) is
   begin
      Item.Value :=
        (case Item.Value is
            when Unchecked => Checked,
            when Checked   => Unchecked,
            when Mixed     => Checked);
   end Toggle;

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
         Toggle (Item);
         return
           (Handled => True, Activated => True, Changed => True, others => <>);
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
         declare
            Was_Armed : constant Boolean := Item.Armed;
            Activate : constant Boolean :=
              Item.Enabled and then Item.Armed and then Inside (Item, Event);
         begin
            Item.Armed := False;
            Item.Capturing := False;
            Result.Handled := True;
            Result.Changed := Was_Armed;
            Result.Capture :=
              Flyology_TUI.Components.Interactions.Release_Capture;
            if Activate then
               Toggle (Item);
               Result.Activated := True;
               Result.Changed := True;
            end if;
            return Result;
         end;
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
      Marker : constant Wide_Wide_String :=
        (case Item.Value is
            when Unchecked => "[ ] ",
            when Checked   => "[x] ",
            when Mixed     => "[-] ");
      Style : constant Flyology_TUI.Styles.Style :=
        (if not Item.Enabled then Look.Disabled
         elsif Item.Armed then Look.Pressed
         elsif Has_Focus then Look.Focused
         elsif Item.Value /= Unchecked then Look.Selected
         else Look.Normal);
   begin
      return Flyology_TUI.Surfaces.From_Text
        (Marker & Text.To_Wide_Wide_String (Item.Caption), Style);
   end Render;

   function Render
     (Item      : Model;
      Theme     : Flyology_TUI.Themes.Theme;
      Has_Focus : Boolean := False)
      return Flyology_TUI.Surfaces.Surface is
     (Render (Item, From_Theme (Theme), Has_Focus));

end Flyology_TUI.Components.Check_Boxes;
