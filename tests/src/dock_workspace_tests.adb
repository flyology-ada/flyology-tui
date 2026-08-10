with Ada.Strings.Wide_Wide_Unbounded;
with Ada.Text_IO;
with Flyology_TUI.Components;
with Flyology_TUI.Components.Dock_Workspaces;
with Flyology_TUI.Components.Interactions;
with Flyology_TUI.Events;
with Flyology_TUI.Geometry;
with Flyology_TUI.Mouse;
with Flyology_TUI.Surfaces;
with Flyology_TUI.Themes;

procedure Dock_Workspace_Tests is
   type Pane_Id is (Inspector, Outline, Output);

   function Label (Id : Pane_Id) return Wide_Wide_String is
     (case Id is
         when Inspector => "Inspector",
         when Outline   => "Outline",
         when Output    => "Output");

   package Docks is new Flyology_TUI.Components.Dock_Workspaces
     (Pane_Id       => Pane_Id,
      Maximum_Panes => 3,
      Label          => Label);

   package Text renames Ada.Strings.Wide_Wide_Unbounded;
   use type Docks.Dock_Side;
   use type Docks.Pane_Placement;
   use type Flyology_TUI.Components.Interactions.Capture_Action;
   use type Flyology_TUI.Geometry.Rectangle;

   Children : constant Docks.Surface_Array :=
     [Inspector => Flyology_TUI.Surfaces.From_Text ("inspector body"),
      Outline   => Flyology_TUI.Surfaces.From_Text ("outline body"),
      Output    => Flyology_TUI.Surfaces.From_Text ("output body")];

   function Definitions return Docks.Pane_Definition_Array is
     [10 =>
        (Id => Output, Side => Docks.Dock_Bottom,
         Dock_Extent => 5, Minimum_Extent => 2,
         Float_X => 10, Float_Y => 8, Float_Width => 24, Float_Height => 7,
         others => <>),
      11 =>
        (Id => Inspector, Side => Docks.Dock_Left,
         Dock_Extent => 20, Minimum_Extent => 8,
         Float_X => 4, Float_Y => 2, Float_Width => 26, Float_Height => 9,
         others => <>),
      12 =>
        (Id => Outline, Side => Docks.Dock_Right,
         Dock_Extent => 16, Minimum_Extent => 6,
         Float_X => 28, Float_Y => 3, Float_Width => 24, Float_Height => 8,
         Initially_Floating => True,
         others => <>)];

   procedure Assert (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         raise Program_Error with Message;
      end if;
   end Assert;

   function Pointer
     (X, Y   : Integer;
      Action : Flyology_TUI.Events.Mouse_Action;
      Button : Flyology_TUI.Events.Mouse_Button :=
        Flyology_TUI.Events.Left_Button)
      return Flyology_TUI.Mouse.Local_Event
   is
     (X        => X,
      Y        => Y,
      Button   => Button,
      Action   => Action,
      Modified => (others => False),
      Wheel_X  => 0,
      Wheel_Y  => 0);

   function Key
     (Kind    : Flyology_TUI.Events.Key_Kind;
      Shift   : Boolean := False;
      Control : Boolean := False;
      Alt     : Boolean := False)
      return Flyology_TUI.Events.Terminal_Event
   is
      Value : Flyology_TUI.Events.Key_Event (Kind);
   begin
      Value.Modified :=
        (Shift => Shift, Control => Control, Alt => Alt, Super => False);
      return Flyology_TUI.Events.Pressed (Value);
   end Key;

   function Text_Key (Value : Wide_Wide_Character)
      return Flyology_TUI.Events.Terminal_Event
   is
      Key_Value : Flyology_TUI.Events.Key_Event
        (Flyology_TUI.Events.Text_Key);
   begin
      Key_Value.Value := Text.To_Unbounded_Wide_Wide_String ((1 => Value));
      return Flyology_TUI.Events.Pressed (Key_Value);
   end Text_Key;

   procedure Test_Layout_And_Programmatic_State is
      Item : Docks.Model := Docks.Create (Definitions, 60, 20);
      View : Docks.Presentation :=
        Item.Present (Children, Flyology_TUI.Themes.Charm);
   begin
      Assert
        (Item.Pane_Count = 3
         and then Item.Has_Pane (Inspector)
         and then Item.Placement (Outline) = Docks.Floating,
         "configured panes were not retained");
      Assert
        (Docks.Center_Region (View) = (20, 0, 40, 15)
         and then Docks.Pane_Region (View, Inspector) = (0, 1, 20, 19)
         and then Docks.Pane_Region (View, Output) = (20, 16, 40, 4),
         "dock layout did not reserve exact edge regions");
      Assert
        (Docks.Header_Region (View, Outline).Y = 3
         and then Docks.Pane_Region (View, Outline).X = 29,
         "floating pane geometry did not follow its stable ID");

      Item.Toggle_Collapsed (Inspector);
      View := Item.Present (Children, Flyology_TUI.Themes.Charm);
      Assert
        (Item.Is_Collapsed (Inspector)
         and then Docks.Center_Region (View) = (3, 0, 57, 15)
         and then Docks.Pane_Region (View, Inspector).Height = 0,
         "collapsed dock did not become a bounded rail");
      Item.Toggle_Collapsed (Inspector);
      Item.Float_Pane (Inspector);
      Assert
        (Item.Placement (Inspector) = Docks.Floating,
         "programmatic float did not preserve pane identity");
      Item.Dock_Pane (Inspector, Docks.Dock_Left);
      Assert
        (Item.Placement (Inspector) = Docks.Docked
         and then Item.Side (Inspector) = Docks.Dock_Left,
         "programmatic dock did not restore the pane");
   end Test_Layout_And_Programmatic_State;

   procedure Test_Keyboard is
      Item : Docks.Model := Docks.Create (Definitions, 60, 20);
      Result : Flyology_TUI.Components.Interactions.Update_Result;
   begin
      Item.Focus;
      Item.Focus_Pane (Inspector);
      Result := Item.Handle (Key (Flyology_TUI.Events.Enter_Key));
      Assert
        (Result.Handled and then Result.Activated and then Result.Changed
         and then Item.Is_Collapsed (Inspector),
         "Enter did not collapse the focused dock");
      Result := Item.Handle (Text_Key ('f'));
      Assert
        (Result.Activated and then Item.Placement (Inspector) = Docks.Floating,
         "F did not float the focused pane");
      Result := Item.Handle (Text_Key ('F'));
      Assert
        (Result.Activated and then Item.Placement (Inspector) = Docks.Docked,
         "F did not return the pane to its remembered dock");
      Result := Item.Handle
        (Key (Flyology_TUI.Events.Arrow_Up_Key, Shift => True));
      Assert
        (Result.Activated
         and then Item.Side (Inspector) = Docks.Dock_Top,
         "Shift-arrow did not move the pane to a free dock edge");
      Result := Item.Handle
        (Key (Flyology_TUI.Events.Arrow_Down_Key, Shift => True));
      Assert
        (Result.Handled and then Result.Rejected and then not Result.Changed,
         "occupied dock edge was not rejected atomically");
      Result := Item.Handle (Key (Flyology_TUI.Events.Tab_Key));
      Assert
        (Result.Handled and then Result.Changed
         and then Item.Focused_Pane /= Inspector,
         "Tab did not select another stable pane");
   end Test_Keyboard;

   procedure Test_Mouse_Chrome_And_Body_Pass_Through is
      Item : Docks.Model := Docks.Create (Definitions, 60, 20);
      View : Docks.Presentation :=
        Item.Present (Children, Flyology_TUI.Themes.Charm);
      Header : Flyology_TUI.Geometry.Rectangle :=
        Docks.Header_Region (View, Inspector);
      Content_Area : constant Flyology_TUI.Geometry.Rectangle :=
        Docks.Pane_Region (View, Inspector);
      Result : Flyology_TUI.Components.Interactions.Update_Result;
   begin
      Result := Item.Handle
        (View, Pointer (Content_Area.X + 2, Content_Area.Y + 1,
         Flyology_TUI.Events.Mouse_Click));
      Assert
        (not Result.Handled and then not Result.Focus_Requested,
         "caller-owned dock body click was consumed");

      Result := Item.Handle
        (View, Pointer (Header.X, Header.Y,
         Flyology_TUI.Events.Mouse_Click));
      Assert
        (Result.Handled
         and then Result.Capture =
           Flyology_TUI.Components.Interactions.Acquire_Capture,
         "collapse chrome did not acquire capture");
      Result := Item.Handle
        (View, Pointer (Header.X, Header.Y,
         Flyology_TUI.Events.Mouse_Release));
      Assert
        (Result.Activated and then Item.Is_Collapsed (Inspector)
         and then Result.Capture =
           Flyology_TUI.Components.Interactions.Release_Capture,
         "matching collapse release did not update the dock");

      View := Item.Present (Children, Flyology_TUI.Themes.Charm);
      Header := Docks.Header_Region (View, Inspector);
      Result := Item.Handle
        (View, Pointer (Header.X + Integer (Header.Width) - 1, Header.Y,
         Flyology_TUI.Events.Mouse_Click));
      Assert
        (Result.Capture =
           Flyology_TUI.Components.Interactions.Acquire_Capture,
         "float chrome did not acquire capture");
      Result := Item.Handle
        (View, Pointer (Header.X + Integer (Header.Width) - 1, Header.Y,
         Flyology_TUI.Events.Mouse_Release));
      Assert
        (Result.Activated and then Item.Placement (Inspector) = Docks.Floating,
         "float chrome did not move the pane into a window");
   end Test_Mouse_Chrome_And_Body_Pass_Through;

   procedure Test_Window_Drag_And_Edge_Dock is
      Item : Docks.Model := Docks.Create (Definitions, 60, 20);
      View : Docks.Presentation;
      Header : Flyology_TUI.Geometry.Rectangle;
      Result : Flyology_TUI.Components.Interactions.Update_Result;
   begin
      Item.Float_Pane (Inspector);
      View := Item.Present (Children, Flyology_TUI.Themes.Charm);
      Header := Docks.Header_Region (View, Inspector);
      Result := Item.Handle
        (View, Pointer (Header.X + 4, Header.Y,
         Flyology_TUI.Events.Mouse_Click));
      Assert
        (Result.Capture =
           Flyology_TUI.Components.Interactions.Acquire_Capture,
         "floating header did not acquire move capture");
      Result := Item.Handle
        (View, Pointer (59, Header.Y + 2,
         Flyology_TUI.Events.Mouse_Drag));
      Assert (Result.Handled, "floating window drag was ignored");
      declare
         Drag_View : constant Docks.Presentation :=
           Item.Present (Children, Flyology_TUI.Themes.Charm);
      begin
         Assert
           (Text.To_Wide_Wide_String
              (Docks.Frame (Drag_View).Element (59, 0).Glyph) = ":",
            "edge drag did not expose a structural dock target");
      end;
      Result := Item.Handle
        (View, Pointer (59, Header.Y + 2,
         Flyology_TUI.Events.Mouse_Release));
      Assert
        (Result.Capture =
           Flyology_TUI.Components.Interactions.Release_Capture
         and then Result.Activated
         and then Item.Placement (Inspector) = Docks.Docked
         and then Item.Side (Inspector) = Docks.Dock_Right,
         "edge release did not dock the dragged window");
   end Test_Window_Drag_And_Edge_Dock;

   procedure Test_Stale_Disabled_And_Responsive is
      Item : Docks.Model := Docks.Create (Definitions, 60, 20);
      Old_View : constant Docks.Presentation :=
        Item.Present (Children, Flyology_TUI.Themes.Charm);
      Result : Flyology_TUI.Components.Interactions.Update_Result;
      Tiny : Docks.Presentation;
   begin
      Item.Resize (1, 1);
      Result := Item.Handle
        (Old_View, Pointer (0, 0, Flyology_TUI.Events.Mouse_Click));
      Assert
        (Result.Rejected and then not Result.Handled,
         "stale dock geometry accepted a new gesture");
      Tiny := Item.Present (Children, Flyology_TUI.Themes.Charm);
      Assert
        (Docks.Frame (Tiny).Width = 1 and then Docks.Frame (Tiny).Height = 1
         and then Docks.Center_Region (Tiny).Width <= 1
         and then Docks.Center_Region (Tiny).Height <= 1,
         "tiny workspace did not remain bounded");
      Item.Set_Enabled (False);
      Result := Item.Handle
        (Tiny, Pointer (0, 0, Flyology_TUI.Events.Mouse_Click));
      Assert (not Result.Handled, "disabled workspace consumed input");
   end Test_Stale_Disabled_And_Responsive;

   procedure Test_Capture_Interruption_And_Appearance is
      Item : Docks.Model := Docks.Create (Definitions, 60, 20);
      View : constant Docks.Presentation :=
        Item.Present (Children, Flyology_TUI.Themes.Charm);
      Header : constant Flyology_TUI.Geometry.Rectangle :=
        Docks.Header_Region (View, Inspector);
      Result : Flyology_TUI.Components.Interactions.Update_Result;
      Look : constant Docks.Appearance :=
        Docks.From_Theme (Flyology_TUI.Themes.Charm);
   begin
      Result := Item.Handle
        (View, Pointer (Header.X, Header.Y,
         Flyology_TUI.Events.Mouse_Click));
      Assert
        (Result.Capture =
           Flyology_TUI.Components.Interactions.Acquire_Capture,
         "dock interruption setup did not capture");
      Item.Resize (61, 20);
      Result := Item.Handle
        (View, Pointer (Header.X, Header.Y,
         Flyology_TUI.Events.Mouse_Release));
      Assert
        (Result.Capture =
           Flyology_TUI.Components.Interactions.Release_Capture
         and then not Result.Activated
         and then not Item.Is_Collapsed (Inspector),
         "intervening geometry change activated stale dock chrome");
      Assert
        (not Look.Focused_Header.Underline
         and then not Look.Focused_Header.Italic
         and then not Look.Focused_Rail.Underline,
         "theme mapping leaked text decoration across dock chrome");
   end Test_Capture_Interruption_And_Appearance;

   procedure Test_Validation is
      Failed : Boolean := False;
      Item : Docks.Model := Docks.Create (Definitions, 20, 8);
   begin
      begin
         declare
            Duplicate : Docks.Model := Docks.Create
              ([1 => Definitions (10),
                2 => Definitions (10)], 20, 8);
         begin
            Duplicate.Focus;
         end;
      exception
         when Flyology_TUI.Components.Structure_Error => Failed := True;
      end;
      Assert (Failed, "duplicate pane IDs were accepted");

      Failed := False;
      begin
         declare
            Same_Side : Docks.Model := Docks.Create
              ([1 => Definitions (10),
                2 =>
                  (Definitions (11) with delta Side => Docks.Dock_Bottom)],
               20, 8);
         begin
            Same_Side.Focus;
         end;
      exception
         when Flyology_TUI.Components.Structure_Error => Failed := True;
      end;
      Assert (Failed, "duplicate occupied dock sides were accepted");

      Failed := False;
      begin
         declare
            Too_Many : Docks.Model := Docks.Create
              ([1 => Definitions (10),
                2 => Definitions (11),
                3 => Definitions (12),
                4 =>
                  (Definitions (12) with delta Id => Inspector)], 20, 8);
         begin
            Too_Many.Focus;
         end;
      exception
         when Flyology_TUI.Components.Capacity_Error => Failed := True;
      end;
      Assert (Failed, "pane capacity overflow was not rejected first");

      Failed := False;
      begin
         Item.Dock_Pane (Outline, Docks.Dock_Left);
      exception
         when Flyology_TUI.Components.Structure_Error => Failed := True;
      end;
      Assert
        (Failed and then Item.Placement (Outline) = Docks.Floating,
         "occupied programmatic dock changed state before rejection");

      Failed := False;
      begin
         declare
            Too_Large : Docks.Model :=
              Docks.Create (Definitions, Natural'Last, 2);
         begin
            Too_Large.Focus;
         end;
      exception
         when Flyology_TUI.Components.Capacity_Error => Failed := True;
      end;
      Assert (Failed, "unrenderable workspace geometry was accepted");

      declare
         Fixed : Docks.Model := Docks.Create
           ([1 =>
              (Id => Inspector, Side => Docks.Dock_Left,
               Dock_Extent => 8, Minimum_Extent => 4,
               Float_X => 1, Float_Y => 1,
               Float_Width => 10, Float_Height => 5,
               Collapsible => False, others => <>)], 20, 8);
         Result : Flyology_TUI.Components.Interactions.Update_Result;
      begin
         Fixed.Focus;
         Result := Fixed.Handle (Key (Flyology_TUI.Events.Enter_Key));
         Assert
           (Result.Handled and then not Result.Activated
            and then not Result.Changed
            and then not Fixed.Is_Collapsed (Inspector),
            "non-collapsible dock reported a false activation");
      end;
   end Test_Validation;
begin
   Test_Layout_And_Programmatic_State;
   Test_Keyboard;
   Test_Mouse_Chrome_And_Body_Pass_Through;
   Test_Window_Drag_And_Edge_Dock;
   Test_Stale_Disabled_And_Responsive;
   Test_Capture_Interruption_And_Appearance;
   Test_Validation;
   Ada.Text_IO.Put_Line ("dock workspace tests passed");
end Dock_Workspace_Tests;
