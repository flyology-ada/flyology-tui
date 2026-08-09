with Ada.Strings.Wide_Wide_Unbounded;
with Ada.Text_IO;
with Flyology_TUI.Colors;
with Flyology_TUI.Components;
with Flyology_TUI.Components.Interactions;
with Flyology_TUI.Components.Menubars;
with Flyology_TUI.Events;
with Flyology_TUI.Geometry;
with Flyology_TUI.Mouse;
with Flyology_TUI.Styles;
with Flyology_TUI.Surfaces;
with Flyology_TUI.Themes;

procedure Menubar_Tests is
   package Text renames Ada.Strings.Wide_Wide_Unbounded;
   type Menu_Id is
     (File_Menu, Edit_Menu, View_Menu, Recent_Menu, More_Menu, Extra_Menu);
   type Item_Id is
     (New_Item, Separator_One, Auto_Save_Item, Mode_A_Item, Mode_B_Item,
      Recent_Submenu_Item, Recent_One_Item, More_Submenu_Item, Deep_Item,
      Copy_Item, Paste_Item, Wide_Item, Radio_Group_Id, Spare_Item,
      Duplicate_Item, Overflow_Item, Extra_Item);

   function Symbol (Code : Natural) return Wide_Wide_String is
     (Wide_Wide_String'(1 => Wide_Wide_Character'Val (Code)));

   function Menu_Label (Id : Menu_Id) return Wide_Wide_String is
     (case Id is
         when File_Menu   => "File",
         when Edit_Menu   => "Edit",
         when View_Menu   => "View",
         when Recent_Menu => "Recent",
         when More_Menu   => "More",
         when Extra_Menu  => "Extra");

   function Item_Label (Id : Item_Id) return Wide_Wide_String is
     (case Id is
         when New_Item            => "New",
         when Separator_One       => "",
         when Auto_Save_Item      => "Auto save",
         when Mode_A_Item         => "Mode A",
         when Mode_B_Item         => "Mode B",
         when Recent_Submenu_Item => "Recent",
         when Recent_One_Item     => "alpha.adb",
         when More_Submenu_Item   => "More",
         when Deep_Item           => "Deep action",
         when Copy_Item           => "Copy",
         when Paste_Item          => "Paste",
         when Wide_Item           => Symbol (16#1F41D#) & " wide",
         when others              => "metadata");

   function Shortcut_Label (Id : Item_Id) return Wide_Wide_String is
     (case Id is
         when New_Item   => "Ctrl+N",
         when Copy_Item  => "Ctrl+C",
         when Paste_Item => "Ctrl+V",
         when others     => "");

   function Menu_Mnemonic
     (Id : Menu_Id) return Wide_Wide_Character is
     (Menu_Label (Id) (1));

   function Item_Mnemonic
     (Id : Item_Id) return Wide_Wide_Character is
     (case Id is
         when New_Item            => 'n',
         when Auto_Save_Item      => 's',
         when Mode_A_Item         => 'a',
         when Mode_B_Item         => 'b',
         when Recent_Submenu_Item => 'r',
         when Recent_One_Item     => 'a',
         when More_Submenu_Item   => 'm',
         when Deep_Item           => 'd',
         when Copy_Item           => 'c',
         when Paste_Item          => 'p',
         when Wide_Item           => 'w',
         when others              => Wide_Wide_Character'Val (0));

   package Menus is new Flyology_TUI.Components.Menubars
     (Menu_Id         => Menu_Id,
      Item_Id         => Item_Id,
      Menu_Label      => Menu_Label,
      Item_Label      => Item_Label,
      Shortcut_Label  => Shortcut_Label,
      Menu_Mnemonic   => Menu_Mnemonic,
      Item_Mnemonic   => Item_Mnemonic,
      Maximum_Menus   => 6,
      Maximum_Items   => 16,
      Maximum_Depth   => 3);

   use type Flyology_TUI.Components.Interactions.Capture_Action;
   use type Flyology_TUI.Geometry.Rectangle;
   use type Flyology_TUI.Styles.Style;
   use type Menus.Item_Kind;
   use type Menus.Result_Kind;

   Base_Menus : constant Menus.Menu_Array :=
     [1 => (File_Menu, True, True),
      2 => (Edit_Menu, True, True),
      3 => (View_Menu, True, False),
      4 => (Recent_Menu, False, True),
      5 => (More_Menu, False, True)];

   Base_Items : constant Menus.Item_Array :=
     [Menus.Action (New_Item, File_Menu),
      Menus.Separator (Separator_One, File_Menu),
      Menus.Check (Auto_Save_Item, File_Menu),
      Menus.Radio
        (Mode_A_Item, File_Menu, Radio_Group_Id, Selected => True),
      Menus.Radio (Mode_B_Item, File_Menu, Radio_Group_Id),
      Menus.Submenu (Recent_Submenu_Item, File_Menu, Recent_Menu),
      Menus.Action (Recent_One_Item, Recent_Menu),
      Menus.Submenu (More_Submenu_Item, Recent_Menu, More_Menu),
      Menus.Action (Deep_Item, More_Menu),
      Menus.Action (Copy_Item, Edit_Menu, Enabled => False),
      Menus.Action (Paste_Item, Edit_Menu),
      Menus.Action (Wide_Item, Edit_Menu)];

   procedure Assert (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         raise Program_Error with Message;
      end if;
   end Assert;

   function Key
     (Kind : Flyology_TUI.Events.Key_Kind)
      return Flyology_TUI.Events.Terminal_Event
   is
      Value : Flyology_TUI.Events.Key_Event (Kind);
   begin
      Value.Modified := (others => False);
      return Flyology_TUI.Events.Pressed (Value);
   end Key;

   function Text_Key
     (Value : Wide_Wide_String)
      return Flyology_TUI.Events.Terminal_Event
   is
      Key_Value : Flyology_TUI.Events.Key_Event
        (Flyology_TUI.Events.Text_Key);
   begin
      Key_Value.Modified := (others => False);
      Key_Value.Value := Text.To_Unbounded_Wide_Wide_String (Value);
      return Flyology_TUI.Events.Pressed (Key_Value);
   end Text_Key;

   function Pointer
     (X, Y : Integer;
      Action : Flyology_TUI.Events.Mouse_Action;
      Button : Flyology_TUI.Events.Mouse_Button :=
        Flyology_TUI.Events.Left_Button)
      return Flyology_TUI.Mouse.Local_Event is
     (X => X, Y => Y, Action => Action, Button => Button,
      Modified => (others => False), Wheel_X => 0, Wheel_Y => 0);

   function Center
     (Region : Flyology_TUI.Geometry.Rectangle)
      return Flyology_TUI.Geometry.Point is
     (X => Region.X + Integer (Region.Width / 2),
      Y => Region.Y + Integer (Region.Height / 2));

   procedure Test_Create_And_State is
      Item : Menus.Model;
   begin
      Assert
        (Base_Items (3).Kind = Menus.Check_Item
         and then Base_Items (3).Menu = File_Menu
         and then Base_Items (4).Kind = Menus.Radio_Item
         and then Base_Items (6).Kind = Menus.Submenu_Item,
         "item constructors corrupted discriminants");
      Item := Menus.Create (Base_Menus, Base_Items);
      Assert
        (Item.Menu_Count = 5 and then Item.Item_Count = 12,
         "bounded menu content was not retained");
      Assert
        (Item.Contains_Menu (Recent_Menu)
         and then Item.Contains_Item (Wide_Item),
         "stable ids were not queryable");
      Assert
        (not Item.Is_Checked (Auto_Save_Item)
         and then Item.Is_Checked (Mode_A_Item)
         and then not Item.Is_Checked (Mode_B_Item),
         "initial check/radio state was incorrect");
      Item.Set_Checked (Auto_Save_Item);
      Item.Set_Checked (Mode_B_Item);
      Assert
        (Item.Is_Checked (Auto_Save_Item)
         and then not Item.Is_Checked (Mode_A_Item)
         and then Item.Is_Checked (Mode_B_Item),
         "check or radio mutation was not typed by stable id");
   end Test_Create_And_State;

   procedure Test_Keyboard is
      Item : Menus.Model := Menus.Create (Base_Menus, Base_Items);
      Result : Menus.Update_Result;
   begin
      Result := Item.Handle (Key (Flyology_TUI.Events.Arrow_Down_Key));
      Assert
        (Menus.Interaction (Result).Handled and then Item.Is_Open
         and then Item.Highlighted_Item = New_Item,
         "down did not open the focused top-level menu");
      Result := Item.Handle (Key (Flyology_TUI.Events.Arrow_Down_Key));
      Assert
        (Item.Highlighted_Item = Auto_Save_Item,
         "keyboard navigation did not skip a separator");
      Result := Item.Handle (Text_Key ("s"));
      Assert
        (Result.Kind = Menus.Check_Changed
         and then Menus.Activated_Item (Result) = Auto_Save_Item
         and then Menus.Checked_Value (Result)
         and then not Item.Is_Open,
         "check mnemonic did not return a typed change");

      Result := Item.Handle (Text_Key ("f"));
      Result := Item.Handle (Key (Flyology_TUI.Events.End_Key));
      Assert
        (Item.Highlighted_Item = Recent_Submenu_Item,
         "End did not select the last enabled item");
      Result := Item.Handle (Key (Flyology_TUI.Events.Arrow_Right_Key));
      Assert
        (Item.Open_Depth = 2
         and then Item.Highlighted_Item = Recent_One_Item,
         "Right did not open the first nested submenu");
      Result := Item.Handle (Key (Flyology_TUI.Events.End_Key));
      Result := Item.Handle (Key (Flyology_TUI.Events.Arrow_Right_Key));
      Assert
        (Item.Open_Depth = 3 and then Item.Highlighted_Item = Deep_Item,
         "nested submenu depth did not converge");
      Result := Item.Handle (Key (Flyology_TUI.Events.Arrow_Right_Key));
      Assert
        (Menus.Interaction (Result).Handled
         and then not Menus.Interaction (Result).Changed
         and then Item.Open_Depth = 3,
         "non-submenu Right reported a state change");
      Result := Item.Handle (Key (Flyology_TUI.Events.Escape_Key));
      Assert
        (Menus.Interaction (Result).Changed
         and then Item.Open_Depth = 2
         and then Item.Highlighted_Item = More_Submenu_Item,
         "Escape did not close only the deepest submenu");
      Result := Item.Handle (Key (Flyology_TUI.Events.Arrow_Right_Key));
      Result := Item.Handle (Key (Flyology_TUI.Events.Enter_Key));
      Assert
        (Result.Kind = Menus.Action_Activated
         and then Menus.Activated_Menu (Result) = More_Menu
         and then Menus.Activated_Item (Result) = Deep_Item
         and then not Item.Is_Open,
         "nested command activation was not typed");

      Result := Item.Handle (Text_Key ("e"));
      Result := Item.Handle (Key (Flyology_TUI.Events.Arrow_Down_Key));
      Assert
        (Item.Highlighted_Item = Wide_Item,
         "down did not wrap past the last enabled item");
      Result := Item.Handle (Key (Flyology_TUI.Events.Home_Key));
      Assert
        (Item.Highlighted_Item = Paste_Item,
         "disabled first item was not skipped");
      Result := Item.Handle (Key (Flyology_TUI.Events.Escape_Key));
      Assert (not Item.Is_Open, "Escape did not close the menu");

      Result := Item.Handle (Text_Key ("f"));
      Result := Item.Handle (Text_Key ("b"));
      Assert
        (Result.Kind = Menus.Radio_Changed
         and then Menus.Activated_Item (Result) = Mode_B_Item
         and then Menus.Radio_Group (Result) = Radio_Group_Id
         and then Item.Is_Checked (Mode_B_Item)
         and then not Item.Is_Checked (Mode_A_Item),
         "radio mnemonic did not return the typed group change");
   end Test_Keyboard;

   procedure Test_Mouse_And_Presentation is
      Item : Menus.Model := Menus.Create (Base_Menus, Base_Items);
      Layout : Menus.Presentation := Item.Present
        (80, 20, 0, 0, Flyology_TUI.Themes.Charm, True);
      File_Region : constant Flyology_TUI.Geometry.Rectangle :=
        Menus.Menu_Region (Layout, File_Menu);
      File_Point : constant Flyology_TUI.Geometry.Point :=
        Center (File_Region);
      Result : Menus.Update_Result;
      Interaction : Flyology_TUI.Components.Interactions.Update_Result;
   begin
      Assert
        (Menus.Frame (Layout).Width = 80
         and then Menus.Frame (Layout).Height = 20
         and then Menus.Bar_Region (Layout) = (0, 0, 80, 1),
         "presentation did not retain its responsive viewport");
      Result := Item.Handle
        (Pointer (File_Point.X, File_Point.Y,
                  Flyology_TUI.Events.Mouse_Click), Layout);
      Interaction := Menus.Interaction (Result);
      Assert
        (Interaction.Handled and then Interaction.Focus_Requested
         and then Interaction.Capture =
           Flyology_TUI.Components.Interactions.Acquire_Capture,
         "menubar press did not request focus and capture");
      Result := Item.Handle
        (Pointer (File_Point.X, File_Point.Y,
                  Flyology_TUI.Events.Mouse_Release), Layout);
      Assert
        (Menus.Interaction (Result).Capture =
           Flyology_TUI.Components.Interactions.Release_Capture
         and then Item.Is_Open,
         "menubar release did not preserve the open menu");

      Layout := Item.Present (80, 20, 0, 0, Flyology_TUI.Themes.Charm, True);
      declare
         Region : constant Flyology_TUI.Geometry.Rectangle :=
           Menus.Item_Region (Layout, New_Item);
         Point : constant Flyology_TUI.Geometry.Point := Center (Region);
      begin
         Result := Item.Handle
           (Pointer (Point.X, Point.Y, Flyology_TUI.Events.Mouse_Click),
            Layout);
         Assert
           (Menus.Interaction (Result).Capture =
              Flyology_TUI.Components.Interactions.Acquire_Capture,
            "menu item press did not acquire capture");
         Result := Item.Handle
           (Pointer (Point.X, Point.Y, Flyology_TUI.Events.Mouse_Release),
            Layout);
         Assert
           (Result.Kind = Menus.Action_Activated
            and then Menus.Activated_Item (Result) = New_Item
            and then Menus.Interaction (Result).Capture =
              Flyology_TUI.Components.Interactions.Release_Capture,
            "mouse release did not match keyboard activation semantics");
      end;

      Item.Open_Menu (File_Menu);
      Layout := Item.Present (80, 20, 0, 0, Flyology_TUI.Themes.Charm);
      declare
         Region : constant Flyology_TUI.Geometry.Rectangle :=
           Menus.Item_Region (Layout, Auto_Save_Item);
         Point : constant Flyology_TUI.Geometry.Point := Center (Region);
      begin
         Result := Item.Handle
           (Pointer (Point.X, Point.Y, Flyology_TUI.Events.Mouse_Click),
            Layout);
         Result := Item.Dismiss;
         Assert
           (Menus.Interaction (Result).Capture =
              Flyology_TUI.Components.Interactions.Release_Capture
            and then not Item.Is_Open,
            "outside dismissal did not release application capture");
      end;
   end Test_Mouse_And_Presentation;

   procedure Test_Mouse_Capture_And_Nesting is
      Item : Menus.Model := Menus.Create (Base_Menus, Base_Items);
      Layout : Menus.Presentation;
      Result : Menus.Update_Result;
      Interaction : Flyology_TUI.Components.Interactions.Update_Result;
   begin
      Item.Open_Menu (File_Menu);
      Layout := Item.Present (80, 20, 0, 0, Flyology_TUI.Themes.Default);
      declare
         Region : constant Flyology_TUI.Geometry.Rectangle :=
           Menus.Item_Region (Layout, Auto_Save_Item);
         Point : constant Flyology_TUI.Geometry.Point := Center (Region);
      begin
         Result := Item.Handle
           (Pointer (Point.X, Point.Y, Flyology_TUI.Events.Mouse_Click),
            Layout);
         Result := Item.Handle
           (Pointer
              (Point.X, Point.Y, Flyology_TUI.Events.Mouse_Release,
               Flyology_TUI.Events.Right_Button),
            Layout);
         Assert
           (Menus.Interaction (Result).Capture =
              Flyology_TUI.Components.Interactions.No_Capture_Change,
            "unrelated release relinquished left-button capture");
         Result := Item.Handle
           (Pointer (-1, -1, Flyology_TUI.Events.Mouse_Release), Layout);
         Assert
           (Menus.Interaction (Result).Capture =
              Flyology_TUI.Components.Interactions.Release_Capture
            and then not Item.Is_Checked (Auto_Save_Item),
            "later left release did not unwind capture without activation");
      end;

      Result := Item.Handle
        (Pointer (79, 19, Flyology_TUI.Events.Mouse_Click), Layout);
      Assert
        (Menus.Interaction (Result).Handled
         and then Menus.Interaction (Result).Changed
         and then not Item.Is_Open,
         "outside left click did not dismiss the open overlay");
      Item.Open_Menu (File_Menu);

      Layout := Item.Present (80, 20, 0, 0, Flyology_TUI.Themes.Default);
      declare
         Region : constant Flyology_TUI.Geometry.Rectangle :=
           Menus.Item_Region (Layout, Recent_Submenu_Item);
         Point : constant Flyology_TUI.Geometry.Point := Center (Region);
      begin
         Result := Item.Handle
           (Pointer (Point.X, Point.Y, Flyology_TUI.Events.Mouse_Move),
            Layout);
         Assert
           (Menus.Interaction (Result).Handled and then Item.Open_Depth = 2,
            "submenu hover did not expose its nested overlay");
      end;
      Layout := Item.Present (80, 20, 0, 0, Flyology_TUI.Themes.Default);
      declare
         Region : constant Flyology_TUI.Geometry.Rectangle :=
           Menus.Item_Region (Layout, Recent_One_Item);
         Point : constant Flyology_TUI.Geometry.Point := Center (Region);
      begin
         Result := Item.Handle
           (Pointer (Point.X, Point.Y, Flyology_TUI.Events.Mouse_Click),
            Layout);
         Result := Item.Handle
           (Pointer (Point.X, Point.Y, Flyology_TUI.Events.Mouse_Release),
            Layout);
         Assert
           (Result.Kind = Menus.Action_Activated
            and then Menus.Activated_Item (Result) = Recent_One_Item,
            "nested mouse activation differed from keyboard activation");
      end;

      Item.Open_Menu (File_Menu);
      Layout := Item.Present (80, 20, 0, 0, Flyology_TUI.Themes.Default);
      declare
         Region : constant Flyology_TUI.Geometry.Rectangle :=
           Menus.Item_Region (Layout, Auto_Save_Item);
         Point : constant Flyology_TUI.Geometry.Point := Center (Region);
      begin
         Result := Item.Handle
           (Pointer (Point.X, Point.Y, Flyology_TUI.Events.Mouse_Click),
            Layout);
         Item.Set_Enabled (False);
         Result := Item.Handle
           (Pointer (Point.X, Point.Y, Flyology_TUI.Events.Mouse_Release),
            Layout);
         Interaction := Menus.Interaction (Result);
         Assert
           (Interaction.Handled
            and then Interaction.Capture =
              Flyology_TUI.Components.Interactions.Release_Capture
            and then not Interaction.Activated,
            "disable did not preserve capture until matching release");
      end;
      Result := Item.Handle (Text_Key ("f"));
      Assert
        (not Menus.Interaction (Result).Handled,
         "disabled menubar consumed keyboard input");
   end Test_Mouse_Capture_And_Nesting;

   procedure Test_Stable_Atomic_And_Stale is
      Item : Menus.Model := Menus.Create (Base_Menus, Base_Items);
      Old : Menus.Presentation;
      Result : Menus.Update_Result;
      Raised : Boolean := False;
      Reordered_Menus : constant Menus.Menu_Array :=
        [Base_Menus (2), Base_Menus (1), Base_Menus (3),
         Base_Menus (4), Base_Menus (5)];
      Reordered_Items : constant Menus.Item_Array :=
        [Base_Items (12), Base_Items (11), Base_Items (10),
         Base_Items (1), Base_Items (2), Base_Items (3), Base_Items (4),
         Base_Items (5), Base_Items (6), Base_Items (7), Base_Items (8),
         Base_Items (9)];
   begin
      Item.Set_Checked (Auto_Save_Item);
      Item.Set_Checked (Mode_B_Item);
      Item.Set_Item_Enabled (New_Item, False);
      Item.Set_Menu_Enabled (Edit_Menu, False);
      Item.Open_Menu (File_Menu);
      Result := Item.Handle (Key (Flyology_TUI.Events.End_Key));
      Result := Item.Handle (Key (Flyology_TUI.Events.Arrow_Right_Key));
      Assert (Item.Open_Depth = 2, "nested stable-state setup failed");
      Old := Item.Present (60, 12, 0, 0, Flyology_TUI.Themes.Default);
      declare
         Region : constant Flyology_TUI.Geometry.Rectangle :=
           Menus.Item_Region (Old, Recent_One_Item);
         Point : constant Flyology_TUI.Geometry.Point := Center (Region);
      begin
         Result := Item.Handle
           (Pointer (Point.X, Point.Y, Flyology_TUI.Events.Mouse_Click), Old);
         Assert
           (Menus.Interaction (Result).Capture =
              Flyology_TUI.Components.Interactions.Acquire_Capture,
            "stable replacement capture setup failed");
      end;
      Item.Set_Content (Reordered_Menus, Reordered_Items);
      Assert
        (Item.Is_Checked (Auto_Save_Item)
         and then Item.Is_Checked (Mode_B_Item)
         and then Item.Focused_Menu = File_Menu
         and then Item.Open_Depth = 2
         and then Item.Highlighted_Item = Recent_One_Item,
         "stable state did not follow ids across reorder");
      Result := Item.Handle
        (Pointer (-1, -1, Flyology_TUI.Events.Mouse_Release), Old);
      Assert
        (Menus.Interaction (Result).Capture =
           Flyology_TUI.Components.Interactions.Release_Capture
         and then Result.Kind = Menus.No_Result,
         "stale matching release did not unwind replacement capture");
      Result := Item.Handle
        (Pointer (0, 0, Flyology_TUI.Events.Mouse_Click), Old);
      Assert
        (Menus.Interaction (Result).Rejected,
         "stale presentation was not rejected");

      Item.Open_Menu (Edit_Menu);
      Assert (not Item.Is_Open, "menu enabled state did not follow its id");
      Item.Open_Menu (File_Menu);
      Result := Item.Handle (Key (Flyology_TUI.Events.Home_Key));
      Assert
        (Item.Highlighted_Item = Auto_Save_Item,
         "item enabled state did not follow its id");

      begin
         Item.Set_Content
           ([Base_Menus (1), Base_Menus (1)], Base_Items);
      exception
         when Flyology_TUI.Components.Structure_Error => Raised := True;
      end;
      Assert
        (Raised and then Item.Menu_Count = 5
         and then Item.Is_Checked (Auto_Save_Item),
         "duplicate-id failure was not atomic");
   end Test_Stable_Atomic_And_Stale;

   procedure Test_Structure_Failures is
      Item : Menus.Model := Menus.Create (Base_Menus, Base_Items);
      Raised : Boolean;

      procedure Expect_Structure
        (Menus_Value : Menus.Menu_Array; Items_Value : Menus.Item_Array)
      is
      begin
         Raised := False;
         begin
            Item.Set_Content (Menus_Value, Items_Value);
         exception
            when Flyology_TUI.Components.Structure_Error => Raised := True;
         end;
         Assert (Raised, "malformed menu graph was accepted");
      end Expect_Structure;

      procedure Expect_Capacity
        (Menus_Value : Menus.Menu_Array; Items_Value : Menus.Item_Array)
      is
      begin
         Raised := False;
         begin
            Item.Set_Content (Menus_Value, Items_Value);
         exception
            when Flyology_TUI.Components.Capacity_Error => Raised := True;
         end;
         Assert
           (Raised and then Item.Menu_Count = 5 and then Item.Item_Count = 12,
            "capacity failure was not atomic");
      end Expect_Capacity;
   begin
      Expect_Structure
        ([1 => (File_Menu, True, True),
          2 => (Recent_Menu, False, True)],
         [1 => Menus.Action (New_Item, File_Menu)]);
      Expect_Structure
        ([1 => (File_Menu, True, True),
          2 => (Recent_Menu, False, True),
          3 => (More_Menu, False, True)],
         [Menus.Submenu (Recent_Submenu_Item, File_Menu, Recent_Menu),
          Menus.Submenu (More_Submenu_Item, Recent_Menu, More_Menu),
          Menus.Submenu (Spare_Item, More_Menu, Recent_Menu)]);
      Expect_Structure
        ([1 => (File_Menu, True, True)],
         [Menus.Radio
            (Mode_A_Item, File_Menu, Radio_Group_Id, Selected => True),
          Menus.Radio
            (Mode_B_Item, File_Menu, Radio_Group_Id, Selected => True)]);
      Expect_Structure
        ([1 => (File_Menu, True, True)],
         [1 => Menus.Action (New_Item, Edit_Menu)]);
      Expect_Structure
        ([1 => (File_Menu, True, True)],
         [1 => Menus.Submenu
           (Recent_Submenu_Item, File_Menu, Recent_Menu)]);
      Expect_Structure
        ([1 => (File_Menu, True, True)],
         [Menus.Action (New_Item, File_Menu),
          Menus.Action (New_Item, File_Menu)]);

      Expect_Capacity
        ([Base_Menus (1), Base_Menus (2), Base_Menus (3), Base_Menus (4),
          Base_Menus (5), (Extra_Menu, False, True), Base_Menus (1)],
         Base_Items);
      Expect_Capacity
        (Base_Menus,
         [Base_Items (1), Base_Items (2), Base_Items (3), Base_Items (4),
          Base_Items (5), Base_Items (6), Base_Items (7), Base_Items (8),
          Base_Items (9), Base_Items (10), Base_Items (11), Base_Items (12),
          Menus.Action (Spare_Item, File_Menu),
          Menus.Action (Duplicate_Item, File_Menu),
          Menus.Action (Overflow_Item, File_Menu),
          Menus.Action (Extra_Item, File_Menu),
          Menus.Action (Spare_Item, File_Menu)]);
      Expect_Capacity
        ([1 => (File_Menu, True, True),
          2 => (Recent_Menu, False, True),
          3 => (More_Menu, False, True),
          4 => (Extra_Menu, False, True)],
         [Menus.Submenu (Recent_Submenu_Item, File_Menu, Recent_Menu),
          Menus.Submenu (More_Submenu_Item, Recent_Menu, More_Menu),
          Menus.Submenu (Spare_Item, More_Menu, Extra_Menu),
          Menus.Action (Deep_Item, Extra_Menu)]);
   end Test_Structure_Failures;

   procedure Test_Tiny_Extreme_And_Appearance is
      Item : Menus.Model := Menus.Create (Base_Menus, Base_Items);
      Tiny : Menus.Presentation;
      Raised : Boolean := False;
      Look : Menus.Appearance := Menus.From_Theme (Flyology_TUI.Themes.Charm);
      Surface : Flyology_TUI.Surfaces.Surface;
      Result : Menus.Update_Result;
      Empty : Menus.Model := Menus.Create
        ([1 .. 0 => (File_Menu, True, True)],
         [1 .. 0 => Menus.Action (New_Item, File_Menu)]);
   begin
      Tiny := Empty.Present (1, 1, 0, 0, Flyology_TUI.Themes.Default);
      Result := Empty.Handle (Key (Flyology_TUI.Events.Arrow_Down_Key));
      Assert
        (Menus.Frame (Tiny).Width = 1
         and then not Menus.Interaction (Result).Handled,
         "empty menubar was not inert and renderable");
      Tiny := Item.Present (0, 0, Integer'First, Integer'Last, Look);
      Assert
        (Menus.Frame (Tiny).Width = 0
         and then Menus.Frame (Tiny).Height = 0,
         "empty extreme-origin presentation was not safe");
      Tiny := Item.Present (1, 1, -5, -1, Look);
      Assert
        (Menus.Frame (Tiny).Width = 1
         and then Menus.Frame (Tiny).Height = 1
         and then Menus.Bar_Region (Tiny).Width <= 1,
         "tiny signed-origin presentation escaped its viewport");
      Item.Open_Menu (Edit_Menu);
      Tiny := Item.Present (12, 5, 0, 0, Look, True);
      Assert
        (Menus.Has_Item_Region (Tiny, Wide_Item)
         and then Menus.Item_Region (Tiny, Wide_Item).Width <= 10,
         "wide-glyph item was not clipped with its popup");
      Look.Bar := Flyology_TUI.Styles.With_Foreground
        (Flyology_TUI.Styles.Default,
         Flyology_TUI.Colors.Basic (Flyology_TUI.Colors.Red));
      Surface := Item.Render (20, 5, 0, 0, Look, True);
      Assert
        (Surface.Element (0, 0).Appearance = Look.Bar,
         "explicit appearance did not reach rendered menu cells");
      Assert
        (Menus.From_Theme (Flyology_TUI.Themes.Charm).Highlighted =
           Flyology_TUI.Themes.Charm.Selected,
         "theme mapping did not remain caller driven");
      Result := Item.Handle
        (Pointer (Integer'First, Integer'Last,
                  Flyology_TUI.Events.Mouse_Wheel,
                  Flyology_TUI.Events.No_Button), Tiny);
      Assert
        (not Menus.Interaction (Result).Handled,
         "extreme wheel input was unexpectedly consumed");
      begin
         Tiny := Item.Present (Natural'Last, 2, 0, 0, Look);
      exception
         when Flyology_TUI.Components.Capacity_Error => Raised := True;
      end;
      Assert (Raised, "surface-capacity overflow was not preflighted");
   end Test_Tiny_Extreme_And_Appearance;

begin
   Test_Create_And_State;
   Test_Keyboard;
   Test_Mouse_And_Presentation;
   Test_Mouse_Capture_And_Nesting;
   Test_Stable_Atomic_And_Stale;
   Test_Structure_Failures;
   Test_Tiny_Extreme_And_Appearance;
   Ada.Text_IO.Put_Line ("menubar tests passed");
end Menubar_Tests;
