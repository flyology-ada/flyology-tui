with Ada.Strings.Wide_Wide_Unbounded;
with Ada.Text_IO;
with Flyology_TUI.Components;
with Flyology_TUI.Components.Forms;
with Flyology_TUI.Components.Interactions;
with Flyology_TUI.Components.Lists;
with Flyology_TUI.Components.Progress;
with Flyology_TUI.Components.Progress_Groups;
with Flyology_TUI.Components.Tabs;
with Flyology_TUI.Components.Text_Inputs;
with Flyology_TUI.Events;
with Flyology_TUI.Geometry;
with Flyology_TUI.Mouse;
with Flyology_TUI.Styles;
with Flyology_TUI.Surfaces;

procedure Responsive_Geometry_Tests is
   package Text renames Ada.Strings.Wide_Wide_Unbounded;

   function Integer_Label (Item : Integer) return Wide_Wide_String is
     (if Item = 10 then "ten"
      elsif Item = 20 then "twenty"
      else "thirty");

   package Integer_Lists is new Flyology_TUI.Components.Lists
     (Item_Type => Integer, Label => Integer_Label);

   package Work_Groups is new Flyology_TUI.Components.Progress_Groups
     (Item_Id => Integer, Maximum_Items => 4);

   type Tab_Id is (Alpha, Beta, Gamma, Delta_Tab);

   function Tab_Label (Item : Tab_Id) return Wide_Wide_String is
     (case Item is
         when Alpha => "alpha",
         when Beta  => "beta",
         when Gamma => "gamma",
         when Delta_Tab => "delta");

   function Tab_Id_Of (Item : Tab_Id) return Tab_Id is (Item);

   package Tabs is new Flyology_TUI.Components.Tabs
     (Item_Type => Tab_Id,
      Id_Type   => Tab_Id,
      Id_Of     => Tab_Id_Of,
      Label     => Tab_Label,
      Capacity  => 8);

   use type Flyology_TUI.Styles.Style;
   use type Flyology_TUI.Components.Interactions.Capture_Action;
   use type Flyology_TUI.Geometry.Rectangle;

   procedure Assert (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         raise Program_Error with Message;
      end if;
   end Assert;

   function Key (Kind : Flyology_TUI.Events.Key_Kind)
      return Flyology_TUI.Events.Terminal_Event
   is
      Value : Flyology_TUI.Events.Key_Event (Kind);
   begin
      Value.Modified := (others => False);
      return Flyology_TUI.Events.Pressed (Value);
   end Key;

   function Click (X, Y : Natural)
      return Flyology_TUI.Events.Terminal_Event
   is
     (Kind  => Flyology_TUI.Events.Mouse_Input,
      Mouse =>
        (X        => X,
         Y        => Y,
         Button   => Flyology_TUI.Events.Left_Button,
         Action   => Flyology_TUI.Events.Mouse_Click,
         Modified => (others => False),
         Wheel_X  => 0,
         Wheel_Y  => 0));

   function Wheel (X, Y : Natural; Amount : Integer)
      return Flyology_TUI.Events.Terminal_Event
   is
     (Kind  => Flyology_TUI.Events.Mouse_Input,
      Mouse =>
        (X        => X,
         Y        => Y,
         Button   => Flyology_TUI.Events.No_Button,
         Action   => Flyology_TUI.Events.Mouse_Wheel,
         Modified => (others => False),
         Wheel_X  => 0,
         Wheel_Y  => Amount));

   function Pointer
     (X, Y   : Integer;
      Action : Flyology_TUI.Events.Mouse_Action)
      return Flyology_TUI.Mouse.Local_Event
   is
     (X        => X,
      Y        => Y,
      Button   => Flyology_TUI.Events.Left_Button,
      Action   => Action,
      Modified => (others => False),
      Wheel_X  => 0,
      Wheel_Y  => 0);

   procedure Test_Text_Input is
      Item : Flyology_TUI.Components.Text_Inputs.Model :=
        Flyology_TUI.Components.Text_Inputs.Create (4, "hint");
      Custom : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Frame : Flyology_TUI.Surfaces.Surface;
   begin
      Item.Set_Value ("abcdef");
      Item.Focus;
      Item.Set_Width (0);
      Frame := Item.Render (Custom, Custom);
      Assert
        (Item.Width = 0 and then Frame.Width = 0 and then Frame.Height = 1
         and then Item.Cursor_Column = 0 and then Item.Value = "abcdef"
         and then Item.Focused,
         "zero-width text input lost retained state or geometry");
      Item.Update (Click (0, 0));
      Assert (Item.Focused, "clipped text input changed focus");
      Item.Set_Width (2);
      Custom.Bold := True;
      Frame := Item.Render (Custom, Flyology_TUI.Styles.Default);
      Assert
        (Item.Width = 2 and then Frame.Width = 2
         and then Frame.Element (0, 0).Appearance = Custom,
         "text input resize or external appearance was lost");
      Item.Set_Width (Natural'Last);
      Assert
        (Item.Width = Natural'Last and then Item.Value = "abcdef",
         "large text input width changed content");
   end Test_Text_Input;

   procedure Test_List is
      Values : constant Integer_Lists.Item_Array (7 .. 9) :=
        [7 => 10, 8 => 20, 9 => 30];
      Item : Integer_Lists.Model := Integer_Lists.Create (4, 2);
      Raised : Boolean := False;
      Before : Natural;
      Frame : Flyology_TUI.Surfaces.Surface;
   begin
      Item.Set_Items (Values);
      Item.Update (Key (Flyology_TUI.Events.Arrow_Down_Key));
      Before := Item.Selected_Index;
      Item.Set_Size (0, 0);
      Frame := Item.Render;
      Assert
        (Item.Width = 0 and then Item.Height = 0
         and then Frame.Width = 0 and then Frame.Height = 0
         and then Item.Selected_Index = Before,
         "zero-size list lost selection or geometry");
      Item.Set_Size (2, 1);
      begin
         Item.Set_Size (Natural'Last, 2);
      exception
         when Flyology_TUI.Components.Capacity_Error => Raised := True;
      end;
      Assert
        (Raised and then Item.Width = 2 and then Item.Height = 1
         and then Item.Selected_Index = Before,
         "overflowing list resize was not atomic");
      Item.Update (Click (0, 0));
      Assert
        (Item.Selected_Index = Before,
         "mouse did not select the sole visible retained row");
      Item.Set_Size (0, Natural'Last);
      Item.Update (Key (Flyology_TUI.Events.Page_Down_Key));
      Assert
        (Item.Selected_Index = 2,
         "page-down overflowed instead of saturating with a huge height");
      Item.Update (Key (Flyology_TUI.Events.Home_Key));
      Item.Set_Size (1, Natural'Last);
      Item.Update (Wheel (0, 0, Integer'First));
      Assert
        (Item.Selected_Index = 2,
         "minimum wheel delta overflowed instead of saturating");
      Raised := False;
      begin
         declare
            Invalid : constant Integer_Lists.Model :=
              Integer_Lists.Create (Positive'Last, 2);
         begin
            Assert (Invalid.Width = 0, "unreachable invalid list");
         end;
      exception
         when Flyology_TUI.Components.Capacity_Error => Raised := True;
      end;
      Assert (Raised, "overflowing list construction was accepted");
   end Test_List;

   procedure Test_Form is
      Fields : constant Flyology_TUI.Components.Forms.Field_Array (4 .. 5) :=
        [4 =>
           (Label       => Text.To_Unbounded_Wide_Wide_String ("Name"),
            Initial     => Text.To_Unbounded_Wide_Wide_String ("Ada"),
            Placeholder => Text.Null_Unbounded_Wide_Wide_String),
         5 =>
           (Label       => Text.To_Unbounded_Wide_Wide_String ("City"),
            Initial     => Text.To_Unbounded_Wide_Wide_String ("Paris"),
            Placeholder => Text.Null_Unbounded_Wide_Wide_String)];
      Empty : constant Flyology_TUI.Components.Forms.Field_Array
        (1 .. 0) := [];
      Item : Flyology_TUI.Components.Forms.Model :=
        Flyology_TUI.Components.Forms.Create (Fields, 5);
      Empty_Item : Flyology_TUI.Components.Forms.Model :=
        Flyology_TUI.Components.Forms.Create (Empty, 3);
      Raised : Boolean := False;
      Frame : Flyology_TUI.Surfaces.Surface;
   begin
      Item.Set_Input_Width (0);
      Frame := Item.Render;
      Assert
        (Item.Input_Width = 0 and then Frame.Width = 6
         and then Frame.Height = 2 and then Item.Field_Value (1) = "Ada",
         "zero-width form inputs changed values or outer geometry");
      Item.Set_Input_Width (3);
      begin
         Item.Set_Input_Width (Natural'Last / 2);
      exception
         when Flyology_TUI.Components.Capacity_Error => Raised := True;
      end;
      Assert
        (Raised and then Item.Input_Width = 3
         and then Item.Field_Value (2) = "Paris",
         "overflowing form cell product was not rejected atomically");
      Raised := False;
      begin
         Item.Set_Input_Width (Natural'Last);
      exception
         when Flyology_TUI.Components.Capacity_Error => Raised := True;
      end;
      Assert
        (Raised and then Item.Input_Width = 3
         and then Item.Field_Value (2) = "Paris",
         "overflowing form width was not atomic");
      Empty_Item.Set_Input_Width (Natural'Last);
      Assert
        (Empty_Item.Input_Width = Natural'Last
         and then Empty_Item.Render.Width = 0,
         "empty form rejected a non-rendered retained width");
   end Test_Form;

   procedure Test_Progress is
      Item : Flyology_TUI.Components.Progress.Model :=
        Flyology_TUI.Components.Progress.Create (8, False);
      Group : Work_Groups.Model := Work_Groups.Create (8);
      Frame : Flyology_TUI.Surfaces.Surface;
   begin
      Item.Set (0.5);
      Item.Set_Width (0);
      Frame := Item.Render;
      Assert
        (Item.Width = 0 and then Frame.Width = 0 and then Item.Value = 0.5,
         "progress resize lost value or zero geometry");
      Item.Set_Width (1);
      Assert (Item.Render.Width = 1, "tiny progress width was not retained");

      Group.Add_Determinate (1, "compile", Value => 0.5);
      Group.Set_Width (0);
      Frame := Group.Render;
      Assert
        (Group.Width = 0 and then Frame.Width = 0 and then Frame.Height = 1
         and then Group.Value (1) = 0.5,
         "progress group zero width lost its rows or values");
      Group.Set_Width (2);
      Assert
        (Group.Render.Width = 2 and then Group.Length = 1,
         "progress group tiny width changed entries");
      Group.Set_Width (Natural'Last);
      Assert
        (Group.Width = Natural'Last and then Group.Length = 1,
         "large progress group width changed entries");
      declare
         Raised : Boolean := False;
      begin
         begin
            Group.Add_Determinate (2, "link", Value => 0.25);
         exception
            when Flyology_TUI.Components.Capacity_Error => Raised := True;
         end;
         Assert
           (Raised and then Group.Width = Natural'Last
            and then Group.Length = 1 and then Group.Value (1) = 0.5,
            "overflowing progress row insertion was not atomic");
      end;
      Group.Set_Width (2);
      Group.Add_Indeterminate (2, "link");
      declare
         Raised : Boolean := False;
      begin
         begin
            Group.Set_Width (Natural'Last);
         exception
            when Flyology_TUI.Components.Capacity_Error => Raised := True;
         end;
         Assert
           (Raised and then Group.Width = 2 and then Group.Length = 2,
            "overflowing progress group resize was not atomic");
      end;

      declare
         Other : Work_Groups.Model := Work_Groups.Create (Natural'Last);
         Raised : Boolean := False;
      begin
         Other.Add_Indeterminate (1, "scan");
         begin
            Other.Add_Indeterminate (2, "index");
         exception
            when Flyology_TUI.Components.Capacity_Error => Raised := True;
         end;
         Assert
           (Raised and then Other.Width = Natural'Last
            and then Other.Length = 1,
            "overflowing indeterminate row insertion was not atomic");
      end;
   end Test_Progress;

   procedure Test_Tabs is
      Values : constant Tabs.Item_Array (5 .. 8) :=
        [5 => Alpha, 6 => Beta, 7 => Gamma, 8 => Delta_Tab];
      Item : Tabs.Model := Tabs.Create (Values);
      Mouse_Item : Tabs.Model := Tabs.Create (Values);
      Legacy_Item : Tabs.Model := Tabs.Create (Values);
      Look : Tabs.Appearance := (others => Flyology_TUI.Styles.Default);
      Layout : Tabs.Presentation;
      Zero : Tabs.Presentation;
      Narrow : Tabs.Presentation;
      Wide : Tabs.Presentation;
      Region : Flyology_TUI.Geometry.Rectangle;
      Press, Release : Flyology_TUI.Components.Interactions.Update_Result;
      Keyboard : Flyology_TUI.Components.Interactions.Update_Result;
      Frozen : Flyology_TUI.Surfaces.Surface;
   begin
      Look.Active.Bold := True;
      Assert
        (Item.Width = 30 and then Item.Render (Look).Width = 30,
         "legacy tab width or render compatibility changed");

      Item.Activate (Delta_Tab);
      Layout := Item.Present (8, Look);
      Region := Tabs.Tab_Region (Layout, Delta_Tab);
      Assert
        (Tabs.Frame (Layout).Width = 8
         and then Tabs.Frame (Layout).Height = 1
         and then Tabs.Has_Tab (Layout, Delta_Tab)
         and then not Tabs.Has_Tab (Layout, Gamma)
         and then Region = (1, 0, 7, 1)
         and then
           Tabs.Frame (Layout).Element
             (Natural (Region.X), 0).Appearance = Look.Active,
         "narrow tabs did not keep the complete active tab visible");
      Frozen := Tabs.Frame (Layout);

      Narrow := Item.Present (3, Look);
      Assert
        (Tabs.Frame (Narrow).Width = 3
         and then Tabs.Tab_Region (Narrow, Delta_Tab) = (0, 0, 3, 1),
         "overwide active tab did not retain its leading clipped cells");
      Zero := Item.Present (0, Look);
      Assert
        (Tabs.Frame (Zero).Width = 0 and then Tabs.Frame (Zero).Height = 1
         and then not Tabs.Has_Tab (Zero, Delta_Tab),
         "zero-width tab presentation retained a hit region");

      for Id in Tab_Id loop
         Item.Activate (Id);
         Narrow := Item.Present (7, Look);
         Assert
           (Tabs.Has_Tab (Narrow, Id)
            and then Tabs.Tab_Region (Narrow, Id).Width > 0
            and then Tabs.Tab_Region (Narrow, Id).Width <= 7,
            "active tab disappeared from a narrow presentation");
      end loop;
      Assert
        (Tabs.Has_Tab (Layout, Delta_Tab)
         and then Tabs.Tab_Region (Layout, Delta_Tab) = (1, 0, 7, 1)
         and then Frozen.Width = 8
         and then Frozen.Element (1, 0).Appearance = Look.Active,
         "presentation changed after later model activation");

      Wide := Mouse_Item.Present (40, Look);
      Region := Tabs.Tab_Region (Wide, Delta_Tab);
      Press := Mouse_Item.Handle
        (Pointer
           (Region.X, 0, Flyology_TUI.Events.Mouse_Click),
         Wide);
      Release := Mouse_Item.Handle
        (Pointer
           (Region.X, 0, Flyology_TUI.Events.Mouse_Release),
         Wide);
      Item.Activate (Alpha);
      Keyboard := Item.Handle (Key (Flyology_TUI.Events.End_Key));
      Assert
        (Press.Capture =
           Flyology_TUI.Components.Interactions.Acquire_Capture
         and then Release.Capture =
           Flyology_TUI.Components.Interactions.Release_Capture
         and then Release.Activated
         and then Mouse_Item.Active_Id = Delta_Tab
         and then Item.Active_Id = Delta_Tab
         and then Keyboard.Handled,
         "tab keyboard and presentation mouse navigation diverged");

      Press := Mouse_Item.Handle
        (Pointer (7, 0, Flyology_TUI.Events.Mouse_Click), Wide);
      Assert
        (not Press.Handled,
         "tab presentation treated a separator as a tab hit");

      Region := (X => 23, Y => 0, Width => 7, Height => 1);
      Press := Legacy_Item.Handle
        (Pointer
           (Region.X, 0, Flyology_TUI.Events.Mouse_Click));
      Release := Legacy_Item.Handle
        (Pointer
           (Region.X, 0, Flyology_TUI.Events.Mouse_Release));
      Assert
        (Press.Handled and then Release.Activated
         and then Legacy_Item.Active_Id = Delta_Tab,
         "legacy full-width tab mouse handling changed");
   end Test_Tabs;

begin
   Test_Text_Input;
   Test_List;
   Test_Form;
   Test_Progress;
   Test_Tabs;
   Ada.Text_IO.Put_Line ("responsive geometry tests passed");
end Responsive_Geometry_Tests;
