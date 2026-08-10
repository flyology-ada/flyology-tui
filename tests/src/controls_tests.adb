with Ada.Strings.Wide_Wide_Unbounded;
with Ada.Text_IO;
with Ada.Numerics.Long_Elementary_Functions;
with Flyology_TUI.Components;
with Flyology_TUI.Components.Buttons;
with Flyology_TUI.Components.Check_Boxes;
with Flyology_TUI.Components.Dropdowns;
with Flyology_TUI.Components.Interactions;
with Flyology_TUI.Components.Radio_Groups;
with Flyology_TUI.Components.Selectors;
with Flyology_TUI.Components.Tabs;
with Flyology_TUI.Color_Profiles;
with Flyology_TUI.Colors;
with Flyology_TUI.Events;
with Flyology_TUI.Mouse;
with Flyology_TUI.Styles;
with Flyology_TUI.Surfaces;
with Flyology_TUI.Themes;

procedure Controls_Tests is
   package Text renames Ada.Strings.Wide_Wide_Unbounded;
   use type Flyology_TUI.Components.Check_Boxes.Check_State;
   use type Flyology_TUI.Components.Interactions.Capture_Action;
   use type Flyology_TUI.Color_Profiles.Profile;
   use type Flyology_TUI.Colors.ANSI_Color;
   use type Flyology_TUI.Colors.Color;
   use type Flyology_TUI.Colors.Color_Kind;
   use type Flyology_TUI.Styles.Style;

   type Choice is (Alpha, Beta, Gamma, Fourth);

   function Choice_Id (Item : Choice) return Choice is (Item);
   function Choice_Label (Item : Choice) return Wide_Wide_String is
     (case Item is
         when Alpha => "Alpha",
         when Beta  => "Beta",
         when Gamma => "Gamma",
         when Fourth => "Fourth");

   package Radios is new Flyology_TUI.Components.Radio_Groups
     (Item_Type => Choice,
      Id_Type   => Choice,
      Id_Of     => Choice_Id,
      Label     => Choice_Label,
      Capacity  => 3);

   package Selections is new Flyology_TUI.Components.Selectors
     (Item_Type => Choice,
      Id_Type   => Choice,
      Id_Of     => Choice_Id,
      Label     => Choice_Label,
      Capacity  => 3);

   package Drops is new Flyology_TUI.Components.Dropdowns
     (Item_Type => Choice,
      Id_Type   => Choice,
      Id_Of     => Choice_Id,
      Label     => Choice_Label,
      Capacity  => 3);

   package Tab_Bars is new Flyology_TUI.Components.Tabs
     (Item_Type => Choice,
      Id_Type   => Choice,
      Id_Of     => Choice_Id,
      Label     => Choice_Label,
      Capacity  => 3);

   procedure Assert (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         raise Program_Error with Message;
      end if;
   end Assert;

   function Linear_Channel
     (Value : Flyology_TUI.Colors.Channel) return Long_Float
   is
      Sample : constant Long_Float := Long_Float (Value) / 255.0;
      Base   : Long_Float;
   begin
      if Sample <= 0.04045 then
         return Sample / 12.92;
      end if;
      Base := (Sample + 0.055) / 1.055;
      return Ada.Numerics.Long_Elementary_Functions.Exp
        (2.4 * Ada.Numerics.Long_Elementary_Functions.Log (Base));
   end Linear_Channel;

   function Luminance
     (Color : Flyology_TUI.Colors.Color) return Long_Float
   is
   begin
      Assert
        (Color.Kind = Flyology_TUI.Colors.RGB,
         "contrast test requires an exact RGB color");
      return
        0.2126 * Linear_Channel (Color.Red_Value)
        + 0.7152 * Linear_Channel (Color.Green_Value)
        + 0.0722 * Linear_Channel (Color.Blue_Value);
   end Luminance;

   function Contrast
     (Left, Right : Flyology_TUI.Colors.Color) return Long_Float
   is
      Left_Light  : constant Long_Float := Luminance (Left);
      Right_Light : constant Long_Float := Luminance (Right);
   begin
      return
        (Long_Float'Max (Left_Light, Right_Light) + 0.05)
        / (Long_Float'Min (Left_Light, Right_Light) + 0.05);
   end Contrast;

   function Key (Kind : Flyology_TUI.Events.Key_Kind)
      return Flyology_TUI.Events.Terminal_Event
   is
      Value : Flyology_TUI.Events.Key_Event (Kind);
   begin
      Value.Modified := (others => False);
      Value.Repeated := False;
      return Flyology_TUI.Events.Pressed (Value);
   end Key;

   function Space return Flyology_TUI.Events.Terminal_Event is
     (Flyology_TUI.Events.Pressed
        ((Kind     => Flyology_TUI.Events.Text_Key,
          Modified => (others => False),
          Repeated => False,
          Value    => Text.To_Unbounded_Wide_Wide_String (" "))));

   function Mouse
     (X, Y   : Integer;
      Action : Flyology_TUI.Events.Mouse_Action;
      Button : Flyology_TUI.Events.Mouse_Button :=
        Flyology_TUI.Events.Left_Button;
      Wheel_Y : Integer := 0) return Flyology_TUI.Mouse.Local_Event is
     (X        => X,
      Y        => Y,
      Button   => Button,
      Action   => Action,
      Modified => (others => False),
      Wheel_X  => 0,
      Wheel_Y  => Wheel_Y);

   function Cell_Text
     (Item : Flyology_TUI.Surfaces.Surface;
      X, Y : Natural) return Wide_Wide_String is
     (Text.To_Wide_Wide_String (Item.Element (X, Y).Glyph));

   procedure Test_Button is
      Item : Flyology_TUI.Components.Buttons.Model :=
        Flyology_TUI.Components.Buttons.Create ("Save");
      Result : Flyology_TUI.Components.Interactions.Update_Result;
      Frame : constant Flyology_TUI.Surfaces.Surface :=
        Item.Render (Flyology_TUI.Themes.Charm, Has_Focus => True);
   begin
      Assert
        (Frame.Width = 8 and then Cell_Text (Frame, 0, 0) = "[",
         "button rendering lost its hit geometry");
      Result := Item.Handle (Key (Flyology_TUI.Events.Enter_Key));
      Assert (Result.Activated, "Enter did not activate button");
      Result := Item.Handle
        (Mouse (1, 0, Flyology_TUI.Events.Mouse_Click));
      Assert
        (Result.Focus_Requested
         and then Result.Capture =
           Flyology_TUI.Components.Interactions.Acquire_Capture,
         "button press did not request focus and capture");
      Result := Item.Handle
        (Mouse (-1, 0, Flyology_TUI.Events.Mouse_Release));
      Assert
        (not Result.Activated
         and then Result.Capture =
           Flyology_TUI.Components.Interactions.Release_Capture,
         "button release outside did not cancel and release capture");
      Result := Item.Handle (Mouse (1, 0, Flyology_TUI.Events.Mouse_Click));
      Result := Item.Handle (Mouse (1, 0, Flyology_TUI.Events.Mouse_Release));
      Assert
        (Result.Activated,
         "mouse release inside did not activate button");
      Result := Item.Handle (Mouse (1, 0, Flyology_TUI.Events.Mouse_Click));
      Item.Set_Label ("Store");
      Item.Set_Enabled (False);
      Result := Item.Handle (Mouse (1, 0, Flyology_TUI.Events.Mouse_Release));
      Assert
        (not Result.Activated
         and then Result.Capture =
           Flyology_TUI.Components.Interactions.Release_Capture,
         "button setter or disable stranded capture");
      Result := Item.Handle (Space);
      Assert (not Result.Activated, "disabled button accepted keyboard input");
      Result := Item.Handle (Mouse (1, 0, Flyology_TUI.Events.Mouse_Click));
      Assert
        (not Result.Handled
         and then Result.Capture =
           Flyology_TUI.Components.Interactions.No_Capture_Change,
         "disabled button captured the mouse");
   end Test_Button;

   procedure Test_Check_Box is
      Item : Flyology_TUI.Components.Check_Boxes.Model :=
        Flyology_TUI.Components.Check_Boxes.Create
          ("Inherited", Flyology_TUI.Components.Check_Boxes.Mixed);
      Result : Flyology_TUI.Components.Interactions.Update_Result;
   begin
      Result := Item.Handle (Space);
      Assert
        (Result.Changed and then Result.Activated
         and then Item.State = Flyology_TUI.Components.Check_Boxes.Checked,
         "mixed checkbox did not toggle to checked");
      Result := Item.Handle (Mouse (1, 0, Flyology_TUI.Events.Mouse_Click));
      Result := Item.Handle (Mouse (1, 0, Flyology_TUI.Events.Mouse_Release));
      Assert
        (Result.Activated
         and then Item.State = Flyology_TUI.Components.Check_Boxes.Unchecked,
         "checkbox mouse activation differs from keyboard activation");
      Item.Set_State (Flyology_TUI.Components.Check_Boxes.Mixed);
      Result := Item.Handle (Mouse (1, 0, Flyology_TUI.Events.Mouse_Click));
      Result := Item.Handle (Mouse (99, 0, Flyology_TUI.Events.Mouse_Release));
      Assert
        (not Result.Activated
         and then Item.State = Flyology_TUI.Components.Check_Boxes.Mixed,
         "checkbox release outside changed state");
      Result := Item.Handle (Mouse (1, 0, Flyology_TUI.Events.Mouse_Click));
      Item.Set_State (Flyology_TUI.Components.Check_Boxes.Checked);
      Item.Set_Enabled (False);
      Result := Item.Handle (Mouse (1, 0, Flyology_TUI.Events.Mouse_Release));
      Assert
        (not Result.Activated
         and then not Result.Changed
         and then Item.State = Flyology_TUI.Components.Check_Boxes.Checked
         and then Result.Capture =
           Flyology_TUI.Components.Interactions.Release_Capture,
         "checkbox setter or disable stranded capture");
      Result := Item.Handle (Space);
      Assert
        (not Result.Activated,
         "disabled checkbox accepted keyboard input");
      Result := Item.Handle (Mouse (1, 0, Flyology_TUI.Events.Mouse_Click));
      Assert (not Result.Handled, "disabled checkbox captured a press");
   end Test_Check_Box;

   procedure Test_Radios is
      Item : Radios.Model := Radios.Create ((Alpha, Beta, Gamma));
      Converging : Radios.Model := Radios.Create ((Alpha, Beta, Gamma));
      Result : Flyology_TUI.Components.Interactions.Update_Result;
      Raised : Boolean := False;
   begin
      Item.Select_Id (Beta);
      Item.Set_Items ((Gamma, Beta, Alpha));
      Assert
        (Item.Selected_Id = Beta,
         "radio selection did not follow stable ID");
      Result := Item.Handle (Key (Flyology_TUI.Events.Arrow_Down_Key));
      Assert
        (Result.Changed and then Item.Selected_Id = Alpha,
         "radio keyboard navigation did not choose focused row");
      Result := Item.Handle (Key (Flyology_TUI.Events.Arrow_Down_Key));
      Assert
        (Result.Handled
         and then not Result.Activated and then not Result.Changed,
         "radio navigation boundary reported activation");
      Result := Item.Handle (Space);
      Assert
        (Result.Activated and then not Result.Changed,
         "radio activation key did not activate an unchanged choice");
      Result := Converging.Handle
        (Mouse (0, 1, Flyology_TUI.Events.Mouse_Click));
      Result := Converging.Handle
        (Mouse (-1, 1, Flyology_TUI.Events.Mouse_Release));
      Result := Converging.Handle
        (Key (Flyology_TUI.Events.Arrow_Up_Key));
      Assert
        (Result.Handled and then Result.Changed
         and then not Result.Activated
         and then Converging.Selected_Id = Alpha,
         "radio focus convergence reported identity activation");
      Result := Item.Handle (Mouse (0, 0, Flyology_TUI.Events.Mouse_Click));
      Result := Item.Handle (Mouse (-1, 0, Flyology_TUI.Events.Mouse_Release));
      Assert
        (not Result.Activated and then Item.Selected_Id = Alpha,
         "radio release outside changed selection");
      Result := Item.Handle (Mouse (0, 0, Flyology_TUI.Events.Mouse_Click));
      Item.Set_Items ((Alpha, Beta, Gamma));
      Result := Item.Handle (Mouse (0, 0, Flyology_TUI.Events.Mouse_Release));
      Assert
        (not Result.Activated
         and then Result.Capture =
           Flyology_TUI.Components.Interactions.Release_Capture
         and then Item.Selected_Id = Alpha,
         "radio item replacement stranded or reactivated capture");
      begin
         Item.Set_Items ((Alpha, Beta, Beta));
      exception
         when Flyology_TUI.Components.Structure_Error => Raised := True;
      end;
      Assert
        (Raised and then Item.Selected_Id = Alpha and then Item.Length = 3,
         "radio duplicate-ID failure was not atomic");
      Raised := False;
      begin
         Item.Set_Items ((Alpha, Beta, Gamma, Fourth));
      exception
         when Flyology_TUI.Components.Capacity_Error => Raised := True;
      end;
      Assert
        (Raised and then Item.Selected_Id = Alpha and then Item.Length = 3,
         "radio capacity failure was not atomic");
      Result := Item.Handle (Mouse (0, 0, Flyology_TUI.Events.Mouse_Click));
      Item.Set_Enabled (False);
      Result := Item.Handle (Mouse (0, 0, Flyology_TUI.Events.Mouse_Release));
      Assert
        (not Result.Activated
         and then Result.Capture =
           Flyology_TUI.Components.Interactions.Release_Capture,
         "disabling a radio group stranded capture");
      Result := Item.Handle (Mouse (0, 0, Flyology_TUI.Events.Mouse_Click));
      Assert (not Result.Handled, "disabled radio captured a press");
   end Test_Radios;

   procedure Test_Selectors is
      Item : Selections.Model :=
        Selections.Create
          ((Alpha, Beta, Gamma),
           Flyology_TUI.Components.Multiple_Selection);
      Single : Selections.Model :=
        Selections.Create
          ((Alpha, Beta, Gamma),
           Flyology_TUI.Components.Single_Selection);
      Empty : constant Selections.Model :=
        Selections.Create
          (Selections.Item_Array'(1 .. 0 => Alpha),
           Flyology_TUI.Components.Multiple_Selection);
      Result : Flyology_TUI.Components.Interactions.Update_Result;
      Raised : Boolean := False;
   begin
      Item.Replace_Selection ((Alpha, Gamma));
      Item.Set_Items ((Gamma, Alpha, Beta));
      Assert
        (Item.Selected_Count = 2
         and then Item.Is_Selected (Alpha)
         and then Item.Is_Selected (Gamma),
         "multi-selection did not survive reorder by ID");
      Item.Replace_Selection ((1 => Beta));
      Assert
        (Item.Selected_Count = 1 and then Item.Is_Selected (Beta),
         "selection replacement did not replace the complete set");
      begin
         Item.Replace_Selection ((1 => Fourth));
      exception
         when Flyology_TUI.Components.Structure_Error => Raised := True;
      end;
      Assert
        (Raised and then Item.Selected_Count = 1
         and then Item.Is_Selected (Beta),
         "invalid selection replacement was not atomic");
      Raised := False;
      begin
         Item.Replace_Selection ((Beta, Beta));
      exception
         when Flyology_TUI.Components.Structure_Error => Raised := True;
      end;
      Assert
        (Raised and then Item.Selected_Count = 1
         and then Item.Is_Selected (Beta),
         "duplicate selection replacement was not atomic");
      Raised := False;
      begin
         Item.Replace_Selection ((Alpha, Beta, Gamma, Fourth));
      exception
         when Flyology_TUI.Components.Capacity_Error => Raised := True;
      end;
      Assert
        (Raised and then Item.Selected_Count = 1
         and then Item.Is_Selected (Beta),
         "selection replacement overflow was not atomic");
      Raised := False;
      Single.Set_Selected (Alpha);
      Single.Set_Selected (Gamma);
      Assert
        (Single.Selected_Count = 1
         and then Single.Is_Selected (Gamma)
         and then not Single.Is_Selected (Alpha),
         "single selector did not replace its prior selection");
      Result := Item.Handle (Key (Flyology_TUI.Events.Home_Key));
      Result := Item.Handle (Space);
      Assert (Result.Activated, "selector keyboard activation was ignored");
      Result := Item.Handle (Mouse (0, 1, Flyology_TUI.Events.Mouse_Click));
      Result := Item.Handle (Mouse (0, 1, Flyology_TUI.Events.Mouse_Release));
      Assert (Result.Activated, "selector mouse activation was ignored");
      Result := Item.Handle (Mouse (0, 0, Flyology_TUI.Events.Mouse_Click));
      Item.Replace_Selection ((1 => Beta));
      Result := Item.Handle (Mouse (0, 0, Flyology_TUI.Events.Mouse_Release));
      Assert
        (not Result.Activated
         and then Result.Capture =
           Flyology_TUI.Components.Interactions.Release_Capture
         and then Item.Selected_Count = 1 and then Item.Is_Selected (Beta),
         "selector replacement stranded or reactivated capture");
      Result := Item.Handle (Mouse (0, 0, Flyology_TUI.Events.Mouse_Click));
      Item.Set_Enabled (False);
      Result := Item.Handle (Mouse (0, 0, Flyology_TUI.Events.Mouse_Release));
      Assert
        (not Result.Activated
         and then Result.Capture =
           Flyology_TUI.Components.Interactions.Release_Capture,
         "disabling a selector stranded capture");
      Result := Item.Handle (Space);
      Assert
        (not Result.Activated,
         "disabled selector accepted keyboard input");
      Result := Item.Handle (Mouse (0, 0, Flyology_TUI.Events.Mouse_Click));
      Assert (not Result.Handled, "disabled selector captured a press");
      Item.Set_Enabled (True);
      Assert
        (Empty.Is_Empty
         and then Empty.Render (Flyology_TUI.Themes.Default).Height = 0,
         "empty selector did not render safely");
      begin
         Item.Set_Items ((Alpha, Beta, Beta));
      exception
         when Flyology_TUI.Components.Structure_Error => Raised := True;
      end;
      Assert
        (Raised and then Item.Length = 3 and then Item.Is_Selected (Beta),
         "selector duplicate-ID failure was not atomic");
      Raised := False;
      begin
         Item.Set_Items ((Alpha, Beta, Gamma, Fourth));
      exception
         when Flyology_TUI.Components.Capacity_Error => Raised := True;
      end;
      Assert
        (Raised and then Item.Length = 3,
         "selector capacity failure changed existing items");
   end Test_Selectors;

   procedure Test_Dropdown is
      Item : Drops.Model := Drops.Create ((Alpha, Beta, Gamma));
      Empty : constant Drops.Model :=
        Drops.Create (Drops.Item_Array'(1 .. 0 => Alpha));
      Result : Flyology_TUI.Components.Interactions.Update_Result;
      Raised : Boolean := False;
   begin
      Item.Select_Id (Beta);
      Item.Set_Items ((Gamma, Alpha, Beta));
      Assert (Item.Selected_Id = Beta, "dropdown selection did not follow ID");
      declare
         Frame : constant Flyology_TUI.Surfaces.Surface :=
           Item.Render (Flyology_TUI.Themes.Charm);
      begin
         Assert
           (Frame.Width = Item.Width
            and then Cell_Text (Frame, Frame.Width - 1, 0) = "]",
            "dropdown header width clipped its closing bracket");
      end;
      Result := Item.Handle (Key (Flyology_TUI.Events.Enter_Key));
      Result := Item.Handle (Key (Flyology_TUI.Events.Arrow_Up_Key));
      Result := Item.Handle (Key (Flyology_TUI.Events.Escape_Key));
      Assert
        (not Item.Is_Open and then Item.Selected_Id = Beta,
         "Escape did not cancel dropdown highlight");
      Result := Item.Handle (Key (Flyology_TUI.Events.Enter_Key));
      Result := Item.Handle (Key (Flyology_TUI.Events.Home_Key));
      Result := Item.Handle (Key (Flyology_TUI.Events.Enter_Key));
      Assert
        (Result.Activated and then Item.Selected_Id = Gamma,
         "dropdown keyboard commit failed");
      Result := Item.Handle (Mouse (1, 0, Flyology_TUI.Events.Mouse_Click));
      Result := Item.Handle (Mouse (1, 0, Flyology_TUI.Events.Mouse_Release));
      Assert (Item.Is_Open, "dropdown header click did not open popup");
      Result := Item.Handle
        (Mouse
           (1, 1, Flyology_TUI.Events.Mouse_Wheel,
            Flyology_TUI.Events.No_Button, Wheel_Y => -1));
      Assert
        (Result.Handled and then Item.Is_Open,
         "dropdown wheel was ignored");
      Result := Item.Handle (Key (Flyology_TUI.Events.Enter_Key));
      Assert
        (Result.Activated and then Item.Selected_Id = Alpha,
         "dropdown wheel highlight did not commit");
      Item.Open;
      Result := Item.Handle
        (Mouse
           (1, 1, Flyology_TUI.Events.Mouse_Wheel,
            Flyology_TUI.Events.No_Button, Wheel_Y => Integer'First));
      Result := Item.Handle (Key (Flyology_TUI.Events.Enter_Key));
      Assert
        (Result.Activated and then Item.Selected_Id = Beta,
         "dropdown Integer'First wheel did not clamp to the end");
      Item.Open;
      Result := Item.Handle
        (Mouse
           (1, 1, Flyology_TUI.Events.Mouse_Wheel,
            Flyology_TUI.Events.No_Button, Wheel_Y => Integer'Last));
      Result := Item.Handle (Key (Flyology_TUI.Events.Enter_Key));
      Assert
        (Result.Activated and then Item.Selected_Id = Gamma,
         "dropdown Integer'Last wheel did not clamp to the start");
      Item.Open;
      Result := Item.Handle (Mouse (1, 2, Flyology_TUI.Events.Mouse_Click));
      Result := Item.Handle (Mouse (1, 2, Flyology_TUI.Events.Mouse_Release));
      Assert
        (Result.Activated and then not Item.Is_Open,
         "dropdown option click did not commit and close");
      Item.Open;
      Result := Item.Handle (Mouse (1, 0, Flyology_TUI.Events.Mouse_Click));
      Result := Item.Handle (Mouse (-1, 0, Flyology_TUI.Events.Mouse_Release));
      Assert
        (not Result.Activated and then Item.Is_Open,
         "dropdown release outside committed or dismissed an armed press");
      Result := Item.Dismiss;
      Assert
        (Result.Handled and then not Item.Is_Open,
         "application dropdown dismissal did not close popup");
      Item.Open;
      Result := Item.Handle (Mouse (1, 1, Flyology_TUI.Events.Mouse_Click));
      Item.Close;
      Result := Item.Handle (Mouse (1, 1, Flyology_TUI.Events.Mouse_Release));
      Assert
        (not Result.Activated
         and then Result.Capture =
           Flyology_TUI.Components.Interactions.Release_Capture,
         "dropdown Close stranded or reactivated capture");
      Item.Open;
      Result := Item.Handle (Mouse (1, 0, Flyology_TUI.Events.Mouse_Click));
      Result := Item.Dismiss;
      Assert
        (not Result.Activated
         and then Result.Capture =
           Flyology_TUI.Components.Interactions.Release_Capture,
         "dropdown Dismiss did not release capture");
      Item.Open;
      Result := Item.Handle (Mouse (-1, -1, Flyology_TUI.Events.Mouse_Click));
      Assert (not Item.Is_Open, "signed outside click did not dismiss popup");
      begin
         Item.Set_Items ((Alpha, Beta, Beta));
      exception
         when Flyology_TUI.Components.Structure_Error => Raised := True;
      end;
      Assert
        (Raised and then Item.Length = 3 and then Item.Selected_Id = Alpha,
         "dropdown duplicate-ID failure was not atomic");
      Raised := False;
      begin
         Item.Set_Items ((Alpha, Beta, Gamma, Fourth));
      exception
         when Flyology_TUI.Components.Capacity_Error => Raised := True;
      end;
      Assert
        (Raised and then Item.Length = 3 and then Item.Selected_Id = Alpha,
         "dropdown capacity failure was not atomic");
      Result := Item.Handle (Mouse (1, 0, Flyology_TUI.Events.Mouse_Click));
      Item.Set_Enabled (False);
      Result := Item.Handle (Mouse (1, 0, Flyology_TUI.Events.Mouse_Release));
      Assert
        (not Result.Activated
         and then Result.Capture =
           Flyology_TUI.Components.Interactions.Release_Capture,
         "disabling a dropdown stranded capture");
      Result := Item.Handle (Mouse (1, 0, Flyology_TUI.Events.Mouse_Click));
      Assert (not Result.Handled, "disabled dropdown captured a press");
      Assert
        (Empty.Is_Empty
         and then Empty.Render (Flyology_TUI.Themes.Default).Height = 1,
         "empty dropdown did not render safely");
   end Test_Dropdown;

   procedure Test_Tabs is
      Item : Tab_Bars.Model := Tab_Bars.Create ((Alpha, Beta, Gamma));
      Converging : Tab_Bars.Model :=
        Tab_Bars.Create ((Alpha, Beta, Gamma));
      Empty : constant Tab_Bars.Model :=
        Tab_Bars.Create (Tab_Bars.Item_Array'(1 .. 0 => Alpha));
      Result : Flyology_TUI.Components.Interactions.Update_Result;
      Raised : Boolean := False;
   begin
      Item.Activate (Beta);
      Item.Set_Items ((Gamma, Beta, Alpha));
      Assert (Item.Active_Id = Beta, "active tab did not follow stable ID");
      Result := Item.Handle (Key (Flyology_TUI.Events.Arrow_Right_Key));
      Assert
        (Result.Activated and then Item.Active_Id = Alpha,
         "tab keyboard navigation did not activate the next tab");
      Result := Item.Handle (Key (Flyology_TUI.Events.Arrow_Right_Key));
      Assert
        (Result.Handled
         and then not Result.Activated and then not Result.Changed,
         "tab navigation boundary reported activation");
      Result := Item.Handle (Space);
      Assert
        (Result.Activated and then not Result.Changed,
         "tab activation key did not activate an unchanged tab");
      Result := Converging.Handle
        (Mouse (8, 0, Flyology_TUI.Events.Mouse_Click));
      Result := Converging.Handle
        (Mouse (-1, 0, Flyology_TUI.Events.Mouse_Release));
      Result := Converging.Handle
        (Key (Flyology_TUI.Events.Arrow_Left_Key));
      Assert
        (Result.Handled and then Result.Changed
         and then not Result.Activated
         and then Converging.Active_Id = Alpha,
         "tab focus convergence reported identity activation");
      Result := Item.Handle (Mouse (1, 0, Flyology_TUI.Events.Mouse_Click));
      Result := Item.Handle (Mouse (1, 0, Flyology_TUI.Events.Mouse_Release));
      Assert
        (Result.Activated and then Item.Active_Id = Gamma,
         "tab mouse activation failed");
      Result := Item.Handle (Mouse (1, 0, Flyology_TUI.Events.Mouse_Click));
      Result := Item.Handle (Mouse (-1, 0, Flyology_TUI.Events.Mouse_Release));
      Assert
        (not Result.Activated and then Item.Active_Id = Gamma,
         "tab release outside changed active tab");
      Result := Item.Handle (Mouse (1, 0, Flyology_TUI.Events.Mouse_Click));
      Item.Set_Items ((Alpha, Beta, Gamma));
      Result := Item.Handle (Mouse (1, 0, Flyology_TUI.Events.Mouse_Release));
      Assert
        (not Result.Activated
         and then Result.Capture =
           Flyology_TUI.Components.Interactions.Release_Capture
         and then Item.Active_Id = Gamma,
         "tab replacement stranded or reactivated capture");
      begin
         Item.Set_Items ((Alpha, Beta, Beta));
      exception
         when Flyology_TUI.Components.Structure_Error => Raised := True;
      end;
      Assert
        (Raised and then Item.Active_Id = Gamma and then Item.Length = 3,
         "tab duplicate-ID failure was not atomic");
      Raised := False;
      begin
         Item.Set_Items ((Alpha, Beta, Gamma, Fourth));
      exception
         when Flyology_TUI.Components.Capacity_Error => Raised := True;
      end;
      Assert
        (Raised and then Item.Active_Id = Gamma,
         "tab overflow was not atomic");
      Result := Item.Handle (Mouse (1, 0, Flyology_TUI.Events.Mouse_Click));
      Item.Set_Enabled (False);
      Result := Item.Handle (Mouse (1, 0, Flyology_TUI.Events.Mouse_Release));
      Assert
        (not Result.Activated
         and then Result.Capture =
           Flyology_TUI.Components.Interactions.Release_Capture,
         "disabling a tab bar stranded capture");
      Result := Item.Handle (Space);
      Assert
        (not Result.Activated,
         "disabled tab bar accepted keyboard input");
      Result := Item.Handle (Mouse (1, 0, Flyology_TUI.Events.Mouse_Click));
      Assert (not Result.Handled, "disabled tab bar captured a press");
      Assert
        (Empty.Is_Empty
         and then Empty.Render (Flyology_TUI.Themes.Default).Width = 0,
         "empty tabs did not render safely");
   end Test_Tabs;

   procedure Test_Appearances is
      Theme : constant Flyology_TUI.Themes.Theme :=
        Flyology_TUI.Themes.Charm;
      Button_Look : constant Flyology_TUI.Components.Buttons.Appearance :=
        Flyology_TUI.Components.Buttons.From_Theme (Theme);
      Check_Look : constant Flyology_TUI.Components.Check_Boxes.Appearance :=
        Flyology_TUI.Components.Check_Boxes.From_Theme (Theme);
      Radio_Look : constant Radios.Appearance := Radios.From_Theme (Theme);
      Selector_Look : constant Selections.Appearance :=
        Selections.From_Theme (Theme);
      Drop_Look : constant Drops.Appearance := Drops.From_Theme (Theme);
      Tab_Look : constant Tab_Bars.Appearance := Tab_Bars.From_Theme (Theme);
      Palette : constant Flyology_TUI.Themes.Palette :=
        Flyology_TUI.Themes.Charm_Palette;
      Palette_Button : constant Flyology_TUI.Components.Buttons.Appearance :=
        Flyology_TUI.Components.Buttons.From_Palette (Palette);
      Palette_Check : constant
        Flyology_TUI.Components.Check_Boxes.Appearance :=
          Flyology_TUI.Components.Check_Boxes.From_Palette (Palette);
      Palette_Radio : constant Radios.Appearance :=
        Radios.From_Palette (Palette);
      Palette_Selector : constant Selections.Appearance :=
        Selections.From_Palette (Palette);
      Palette_Drop : constant Drops.Appearance :=
        Drops.From_Palette (Palette);
      Palette_Tabs : constant Tab_Bars.Appearance :=
        Tab_Bars.From_Palette (Palette);
      Button : constant Flyology_TUI.Components.Buttons.Model :=
        Flyology_TUI.Components.Buttons.Create ("Go");
      Check : constant Flyology_TUI.Components.Check_Boxes.Model :=
        Flyology_TUI.Components.Check_Boxes.Create ("Flag");
      Radio : constant Radios.Model := Radios.Create ((Alpha, Beta));
      Selector : constant Selections.Model :=
        Selections.Create ((Alpha, Beta));
      Drop : constant Drops.Model := Drops.Create ((Alpha, Beta));
      Tabs : constant Tab_Bars.Model := Tab_Bars.Create ((Alpha, Beta));

      procedure Assert_Button_Profile
        (Name                : String;
         Item                : Flyology_TUI.Themes.Palette;
         Focused_Foreground  : Flyology_TUI.Colors.Color;
         Focused_Background  : Flyology_TUI.Colors.Color;
         Pressed_Foreground  : Flyology_TUI.Colors.Color;
         Pressed_Background  : Flyology_TUI.Colors.Color;
         Focused_ANSI_FG     : Flyology_TUI.Colors.ANSI_Color;
         Focused_ANSI_BG     : Flyology_TUI.Colors.ANSI_Color;
         Pressed_ANSI_FG     : Flyology_TUI.Colors.ANSI_Color;
         Pressed_ANSI_BG     : Flyology_TUI.Colors.ANSI_Color)
      is
         package Profiles renames Flyology_TUI.Color_Profiles;
         package Colors renames Flyology_TUI.Colors;
      begin
         Assert
           (Item.Button_Focused.Foreground = Focused_Foreground
            and then Item.Button_Focused.Background = Focused_Background
            and then Item.Button_Pressed.Foreground = Pressed_Foreground
            and then Item.Button_Pressed.Background = Pressed_Background,
            Name & " button colors changed from their audited RGB pairs");
         Assert
           (Contrast
              (Item.Button_Focused.Foreground,
               Item.Button_Focused.Background) >= 4.5
            and then Contrast
              (Item.Button_Pressed.Foreground,
               Item.Button_Pressed.Background) >= 4.5,
            Name & " button pair fell below 4.5:1 contrast");
         Assert
           (Profiles.Adapt
              (Item.Button_Focused.Foreground, Profiles.ANSI_16) =
                Colors.Basic (Focused_ANSI_FG)
            and then Profiles.Adapt
              (Item.Button_Focused.Background, Profiles.ANSI_16) =
                Colors.Basic (Focused_ANSI_BG)
            and then Profiles.Adapt
              (Item.Button_Pressed.Foreground, Profiles.ANSI_16) =
                Colors.Basic (Pressed_ANSI_FG)
            and then Profiles.Adapt
              (Item.Button_Pressed.Background, Profiles.ANSI_16) =
                Colors.Basic (Pressed_ANSI_BG)
            and then Focused_ANSI_FG /= Focused_ANSI_BG
            and then Pressed_ANSI_FG /= Pressed_ANSI_BG,
            Name & " button colors collapsed or changed under ANSI16");
      end Assert_Button_Profile;
   begin
      Assert_Button_Profile
        ("default Charm", Flyology_TUI.Themes.Charm_Palette,
         Flyology_TUI.Colors.True_Color (35, 35, 35),
         Flyology_TUI.Colors.True_Color (247, 128, 226),
         Flyology_TUI.Colors.True_Color (255, 253, 245),
         Flyology_TUI.Colors.True_Color (90, 86, 224),
         Flyology_TUI.Colors.Black, Flyology_TUI.Colors.White,
         Flyology_TUI.Colors.Bright_White,
         Flyology_TUI.Colors.Bright_Black);
      Assert_Button_Profile
        ("dark Charm", Flyology_TUI.Themes.Charm_Dark_Palette,
         Flyology_TUI.Colors.True_Color (35, 35, 35),
         Flyology_TUI.Colors.True_Color (247, 128, 226),
         Flyology_TUI.Colors.True_Color (255, 253, 245),
         Flyology_TUI.Colors.True_Color (90, 86, 224),
         Flyology_TUI.Colors.Black, Flyology_TUI.Colors.White,
         Flyology_TUI.Colors.Bright_White,
         Flyology_TUI.Colors.Bright_Black);
      Assert_Button_Profile
        ("light Charm", Flyology_TUI.Themes.Charm_Light_Palette,
         Flyology_TUI.Colors.True_Color (255, 253, 245),
         Flyology_TUI.Colors.True_Color (184, 50, 169),
         Flyology_TUI.Colors.True_Color (255, 253, 245),
         Flyology_TUI.Colors.True_Color (90, 86, 224),
         Flyology_TUI.Colors.Bright_White, Flyology_TUI.Colors.Magenta,
         Flyology_TUI.Colors.Bright_White,
         Flyology_TUI.Colors.Bright_Black);
      Assert
        (Button_Look.Normal = Theme.Primary
         and then Button_Look.Focused = Theme.Focused
         and then Button_Look.Pressed = Theme.Selected
         and then Button_Look.Disabled = Theme.Muted,
         "button theme mapping is incorrect");
      Assert
        (Check_Look.Normal = Theme.Primary
         and then Check_Look.Selected = Theme.Selected
         and then Check_Look.Focused = Theme.Focused
         and then Check_Look.Pressed = Theme.Selected
         and then Check_Look.Disabled = Theme.Muted,
         "checkbox theme mapping is incorrect");
      Assert
        (Radio_Look.Normal = Theme.Primary
         and then Radio_Look.Selected = Theme.Selected
         and then Radio_Look.Focused = Theme.Focused
         and then Radio_Look.Disabled = Theme.Muted,
         "radio theme mapping is incorrect");
      Assert
        (Selector_Look.Normal = Theme.Primary
         and then Selector_Look.Selected = Theme.Selected
         and then Selector_Look.Focused = Theme.Focused
         and then Selector_Look.Disabled = Theme.Muted,
         "selector theme mapping is incorrect");
      Assert
        (Drop_Look.Normal = Theme.Primary
         and then Drop_Look.Selected = Theme.Selected
         and then Drop_Look.Highlighted = Theme.Focused
         and then Drop_Look.Focused = Theme.Focused
         and then Drop_Look.Disabled = Theme.Muted,
         "dropdown theme mapping is incorrect");
      Assert
        (Tab_Look.Normal = Theme.Primary
         and then Tab_Look.Active = Theme.Selected
         and then Tab_Look.Focused = Theme.Focused
         and then Tab_Look.Disabled = Theme.Muted,
         "tab theme mapping is incorrect");
      Assert
        (Palette_Button.Normal = Palette.Button
         and then Palette_Button.Focused = Palette.Button_Focused
         and then Palette_Button.Pressed = Palette.Button_Pressed
         and then Palette_Check.Normal = Palette.Content
         and then Palette_Check.Selected = Palette.Selected
         and then Palette_Radio.Focused = Palette.Interaction
         and then Palette_Selector.Selected = Palette.Selected
         and then Palette_Drop.Highlighted = Palette.Button_Focused
         and then Palette_Tabs.Active = Palette.Button_Focused,
         "semantic palette mappings lost component-specific states");
      Assert
        (Flyology_TUI.Themes.Charm.Primary = Palette.Content
         and then Flyology_TUI.Themes.Charm.Primary =
           Flyology_TUI.Styles.Default
         and then Flyology_TUI.Themes.Charm.Selected /=
           Flyology_TUI.Themes.Charm.Focused
         and then Flyology_TUI.Themes.Charm.Border /=
           Flyology_TUI.Themes.Charm.Focused
         and then Flyology_TUI.Themes.Charm_Dark.Primary /=
           Flyology_TUI.Themes.Charm_Light.Primary,
         "Charm profiles did not preserve neutral content and state "
           & "hierarchy");
      Assert
        (not Palette.Muted.Faint
         and then Palette.Focused.Bold
         and then Palette.Focused.Underline
         and then Palette.Interaction.Underline
         and then Palette.Button_Focused.Bold
         and then Palette.Disabled.Faint,
         "Charm state hierarchy depends on color alone");
      for Profile in Flyology_TUI.Color_Profiles.Profile loop
         Assert
           ((if Profile = Flyology_TUI.Color_Profiles.Monochrome
             then Flyology_TUI.Color_Profiles.Adapt
               (Palette.Focused.Foreground, Profile) =
                 Flyology_TUI.Colors.Default
             else Flyology_TUI.Color_Profiles.Adapt
               (Palette.Focused.Foreground, Profile) /=
                 Flyology_TUI.Colors.Default),
            "Charm focus color did not degrade for a terminal profile");
      end loop;
      Assert
        (Button.Render (Button_Look).Element (0, 0).Appearance =
           Button_Look.Normal
         and then Check.Render (Check_Look).Element (0, 0).Appearance =
           Check_Look.Normal
         and then Radio.Render (Radio_Look).Element (0, 0).Appearance =
           Radio_Look.Selected
         and then Selector.Render (Selector_Look).Element (0, 0).Appearance =
           Selector_Look.Normal
         and then Drop.Render (Drop_Look).Element (0, 0).Appearance =
           Drop_Look.Normal
         and then Tabs.Render (Tab_Look).Element (0, 0).Appearance =
           Tab_Look.Active
         and then Tabs.Render
           (Tab_Look, Has_Focus => True).Element (0, 0).Appearance =
             Tab_Look.Active,
         "explicit component appearances were not used by Render");
      Assert
        (Text.To_Wide_Wide_String
           (Tabs.Render (Palette_Tabs).Element (0, 0).Glyph) = "["
         and then Tabs.Render (Palette_Tabs).Element (0, 0).Appearance =
           Palette_Tabs.Active,
         "active tab lost its persistent non-color cue");
   end Test_Appearances;

begin
   Test_Button;
   Test_Check_Box;
   Test_Radios;
   Test_Selectors;
   Test_Dropdown;
   Test_Tabs;
   Test_Appearances;
   Ada.Text_IO.Put_Line ("controls tests passed");
end Controls_Tests;
