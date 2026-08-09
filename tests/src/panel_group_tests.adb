with Ada.Strings.Wide_Wide_Unbounded;
with Ada.Text_IO;
with Flyology_TUI.Colors;
with Flyology_TUI.Components;
with Flyology_TUI.Components.Interactions;
with Flyology_TUI.Components.Panel_Groups;
with Flyology_TUI.Events;
with Flyology_TUI.Geometry;
with Flyology_TUI.Layouts.Boxes;
with Flyology_TUI.Mouse;
with Flyology_TUI.Styles;
with Flyology_TUI.Surfaces;
with Flyology_TUI.Themes;

procedure Panel_Group_Tests is
   package Groups renames Flyology_TUI.Components.Panel_Groups;
   package Text renames Ada.Strings.Wide_Wide_Unbounded;
   use type Flyology_TUI.Components.Interactions.Capture_Action;
   use type Flyology_TUI.Geometry.Rectangle;
   use type Flyology_TUI.Layouts.Boxes.Direction;
   use type Flyology_TUI.Styles.Style;

   Vertical_Line : constant Wide_Wide_String :=
     (1 => Wide_Wide_Character'Val (16#2502#));
   Bee : constant Wide_Wide_String :=
     (1 => Wide_Wide_Character'Val (16#1F41D#));

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
     (Kind  : Flyology_TUI.Events.Key_Kind;
      Shift : Boolean := False)
      return Flyology_TUI.Events.Terminal_Event
   is
      Value : Flyology_TUI.Events.Key_Event (Kind);
   begin
      Value.Modified :=
        (Shift => Shift, Control => False, Alt => False, Super => False);
      return Flyology_TUI.Events.Pressed (Value);
   end Key;

   function Cell_Text
     (Item : Flyology_TUI.Surfaces.Surface;
      X, Y : Natural) return Wide_Wide_String
   is (Text.To_Wide_Wide_String (Item.Element (X, Y).Glyph));

   procedure Assert_Exact
     (Item        : Groups.Model;
      First, Last : Integer;
      Message     : String)
   is
      Total : Natural := 0;
   begin
      if Last < First then
         return;
      end if;
      for Index in First .. Last loop
         Total := Total + Item.Pane_Span (Index);
         if Index < Last then
            declare
               Divider : constant Flyology_TUI.Geometry.Rectangle :=
                 Item.Divider_Region (Index);
            begin
               Total := Total
                 + (if Item.Flow = Flyology_TUI.Layouts.Boxes.Horizontal
                    then Divider.Width else Divider.Height);
            end;
         end if;
      end loop;
      Assert
        (Total =
           (if Item.Flow = Flyology_TUI.Layouts.Boxes.Horizontal
            then Item.Width else Item.Height),
         Message);
   end Assert_Exact;

   procedure Test_Initial_Layout_And_Bounds is
      Constraints : constant Groups.Pane_Constraint_Array (10 .. 12) :=
        (10 => (Minimum_Span => 1, Initial_Span => 3, Weight => 1),
         11 => (Minimum_Span => 1, Initial_Span => 1, Weight => 2),
         12 => (Minimum_Span => 1, Initial_Span => 1, Weight => 1));
      Group : constant Groups.Model := Groups.Create
        (Flyology_TUI.Layouts.Boxes.Horizontal, 12, 4, Constraints);
   begin
      Assert
        (Group.Flow = Flyology_TUI.Layouts.Boxes.Horizontal
         and then Group.Width = 12 and then Group.Height = 4
         and then Group.Bounds = (0, 0, 12, 4),
         "group dimensions were not retained");
      Assert
        (Group.Pane_Count = 3 and then Group.Divider_Count = 2
         and then Group.Has_Pane (10) and then Group.Has_Pane (12)
         and then not Group.Has_Pane (9)
         and then Group.Has_Divider (10)
         and then not Group.Has_Divider (12),
         "high pane bounds were not retained");
      Assert
        (Group.Pane_Span (10) = 4
         and then Group.Pane_Span (11) = 3
         and then Group.Pane_Span (12) = 3,
         "initial spans and weights were not deterministic");
      Assert
        (Group.Pane_Region (10) = (0, 0, 4, 4)
         and then Group.Divider_Region (10) = (4, 0, 1, 4)
         and then Group.Pane_Region (11) = (5, 0, 3, 4)
         and then Group.Divider_Region (11) = (8, 0, 1, 4)
         and then Group.Pane_Region (12) = (9, 0, 3, 4),
         "pane and divider regions were not contiguous");
      Assert_Exact (Group, 10, 12, "initial spans did not fill extent");
   end Test_Initial_Layout_And_Bounds;

   procedure Test_Zero_One_And_Tiny is
      No_Constraints : constant Groups.Pane_Constraint_Array (4 .. 3) :=
        (others => <>);
      No_Children : constant Groups.Surface_Array (4 .. 3) :=
        (others => Flyology_TUI.Surfaces.Create (0, 0));
      Empty : constant Groups.Model := Groups.Create
        (Flyology_TUI.Layouts.Boxes.Horizontal, 7, 2, No_Constraints);
      Empty_Render : constant Flyology_TUI.Surfaces.Surface :=
        Empty.Render (No_Children, Flyology_TUI.Themes.Default);
      One_Constraint : constant Groups.Pane_Constraint_Array (20 .. 20) :=
        (20 => (Minimum_Span => 99, Initial_Span => 0, Weight => 1));
      One : constant Groups.Model := Groups.Create
        (Flyology_TUI.Layouts.Boxes.Vertical, 3, 2, One_Constraint);
      Tiny_Constraints : constant Groups.Pane_Constraint_Array (1 .. 3) :=
        (others => (Minimum_Span => 2, Initial_Span => 2, Weight => 1));
      Tiny : Groups.Model := Groups.Create
        (Flyology_TUI.Layouts.Boxes.Horizontal, 1, 2, Tiny_Constraints);
   begin
      Assert
        (Empty.Pane_Count = 0 and then Empty.Divider_Count = 0
         and then Flyology_TUI.Surfaces.Width (Empty_Render) = 7,
         "zero-pane group was not a safe blank surface");
      Assert
        (One.Pane_Span (20) = 2
         and then One.Pane_Region (20) = (0, 0, 3, 2)
         and then One.Divider_Count = 0,
         "one pane did not receive the complete major extent");
      Assert
        (Tiny.Pane_Span (1) = 0
         and then Tiny.Pane_Span (2) = 0
         and then Tiny.Pane_Span (3) = 0
         and then Tiny.Divider_Region (1).Width = 1
         and then Tiny.Divider_Region (2).Width = 0,
         "one-cell geometry did not prioritize the first divider");
      Assert_Exact (Tiny, 1, 3, "one-cell layout did not fill extent");
      Tiny.Resize (2, 2);
      Assert
        (Tiny.Divider_Region (1).Width = 1
         and then Tiny.Divider_Region (2).Width = 1,
         "two-cell geometry did not retain both dividers");
      Assert_Exact (Tiny, 1, 3, "two-cell layout did not fill extent");
      Tiny.Resize (3, 2);
      Assert
        (Tiny.Pane_Span (1) = 1
         and then Tiny.Pane_Span (2) = 0
         and then Tiny.Pane_Span (3) = 0,
         "tiny minimum priority was not assigned in pane order");
      Assert_Exact (Tiny, 1, 3, "three-cell layout did not fill extent");
   end Test_Zero_One_And_Tiny;

   procedure Test_All_Mouse_Dividers is
      Constraints : constant Groups.Pane_Constraint_Array (30 .. 33) :=
        (others => (Minimum_Span => 1, Initial_Span => 4, Weight => 1));
   begin
      for Divider_Index in 30 .. 32 loop
         declare
            Group : Groups.Model := Groups.Create
              (Flyology_TUI.Layouts.Boxes.Horizontal, 19, 3, Constraints);
            Region : constant Flyology_TUI.Geometry.Rectangle :=
              Group.Divider_Region (Divider_Index);
            Left_Before : constant Natural :=
              Group.Pane_Span (Divider_Index);
            Right_Before : constant Natural :=
              Group.Pane_Span (Divider_Index + 1);
            Press : constant
              Flyology_TUI.Components.Interactions.Update_Result :=
                Group.Handle
                  (Pointer (Region.X, 1, Flyology_TUI.Events.Mouse_Click));
            Drag : constant
              Flyology_TUI.Components.Interactions.Update_Result :=
                Group.Handle
                  (Pointer (Region.X + 2, 1,
                            Flyology_TUI.Events.Mouse_Drag));
            Wrong_Release : constant
              Flyology_TUI.Components.Interactions.Update_Result :=
                Group.Handle
                  (Pointer (-100, -100,
                            Flyology_TUI.Events.Mouse_Release,
                            Flyology_TUI.Events.Right_Button));
            Release : constant
              Flyology_TUI.Components.Interactions.Update_Result :=
                Group.Handle
                  (Pointer (-100, -100,
                            Flyology_TUI.Events.Mouse_Release));
         begin
            Assert
              (Press.Handled and then Press.Focus_Requested
               and then Press.Capture =
                 Flyology_TUI.Components.Interactions.Acquire_Capture,
               "divider did not request focus and capture");
            Assert
              (Drag.Changed
               and then Group.Pane_Span (Divider_Index) = Left_Before + 2
               and then Group.Pane_Span (Divider_Index + 1) =
                 Right_Before - 2,
               "divider drag did not resize its adjacent panes");
            Assert
              (Wrong_Release.Capture =
                 Flyology_TUI.Components.Interactions.No_Capture_Change,
               "mismatched release relinquished capture");
            Assert
              (Release.Handled
               and then Release.Capture =
                 Flyology_TUI.Components.Interactions.Release_Capture,
               "outside matching release did not relinquish capture");
            Assert_Exact
              (Group, 30, 33, "mouse resize changed the total extent");
         end;
      end loop;
   end Test_All_Mouse_Dividers;

   procedure Test_Body_Click_And_Snapshot_Input is
      Constraints : constant Groups.Pane_Constraint_Array (1 .. 3) :=
        (others => (Minimum_Span => 1, Initial_Span => 2, Weight => 1));
      Reconfigured : constant Groups.Pane_Constraint_Array (80 .. 82) :=
        (others => (Minimum_Span => 1, Initial_Span => 3, Weight => 1));
      Four_Panes : constant Groups.Pane_Constraint_Array (90 .. 93) :=
        (others => (Minimum_Span => 1, Initial_Span => 2, Weight => 1));
      Group : Groups.Model := Groups.Create
        (Flyology_TUI.Layouts.Boxes.Horizontal, 10, 3, Constraints);
      Old_Layout : constant Groups.Layout_Snapshot := Group.Layout;
      Old_Divider : constant Flyology_TUI.Geometry.Rectangle :=
        Groups.Divider_Region (Old_Layout, 1);
      Result : Flyology_TUI.Components.Interactions.Update_Result;
      Before : Natural;
   begin
      Result := Group.Handle
        (Pointer (0, 1, Flyology_TUI.Events.Mouse_Click));
      Assert
        (not Result.Handled and then not Result.Focus_Requested
         and then Result.Capture =
           Flyology_TUI.Components.Interactions.No_Capture_Change
         and then not Group.Focused,
         "pane body click was consumed instead of reaching its child");

      Group.Resize (16, 3);
      Before := Group.Pane_Span (1);
      Result := Group.Handle
        (Old_Layout,
         Pointer (Old_Divider.X, 1, Flyology_TUI.Events.Mouse_Click));
      Assert
        (Result.Handled and then Result.Focus_Requested
         and then Result.Capture =
           Flyology_TUI.Components.Interactions.Acquire_Capture,
         "stale resize snapshot did not identify its divider");
      Result := Group.Handle
        (Old_Layout,
         Pointer (Old_Divider.X + 2, 1,
                  Flyology_TUI.Events.Mouse_Drag));
      Assert
        (Result.Changed and then Group.Pane_Span (1) = Before + 2,
         "captured stale-snapshot drag did not resize current panes");
      Result := Group.Handle
        (Old_Layout,
         Pointer (-100, 1, Flyology_TUI.Events.Mouse_Release));
      Assert
        (Result.Capture =
           Flyology_TUI.Components.Interactions.Release_Capture,
         "stale resize snapshot did not release capture outside");

      Group.Configure (15, 3, Reconfigured);
      Before := Group.Pane_Span (80);
      Result := Group.Handle
        (Old_Layout,
         Pointer (Old_Divider.X, 1, Flyology_TUI.Events.Mouse_Click));
      Assert
        (Result.Capture =
           Flyology_TUI.Components.Interactions.Acquire_Capture
         and then Group.Focused_Divider = 80,
         "same-count Configure did not map snapshot divider by position");
      Result := Group.Handle
        (Old_Layout,
         Pointer (Old_Divider.X + 1, 1,
                  Flyology_TUI.Events.Mouse_Drag));
      Assert
        (Result.Changed and then Group.Pane_Span (80) = Before + 1,
         "same-count Configure snapshot drag used stale pane spans");
      Result := Group.Handle
        (Old_Layout,
         Pointer (-100, 1, Flyology_TUI.Events.Mouse_Release));
      Assert
        (Result.Capture =
           Flyology_TUI.Components.Interactions.Release_Capture,
         "same-count Configure snapshot did not release capture");

      Group.Configure (18, 3, Four_Panes);
      Result := Group.Handle
        (Old_Layout,
         Pointer (Old_Divider.X, 1, Flyology_TUI.Events.Mouse_Click));
      Assert
        (Result.Rejected and then not Result.Handled
         and then Result.Capture =
           Flyology_TUI.Components.Interactions.No_Capture_Change,
         "pane-count mismatch did not reject stale snapshot input");

      Group.Configure (10, 3, Constraints);
      declare
         Captured_Layout : constant Groups.Layout_Snapshot := Group.Layout;
         Captured_Divider : constant Flyology_TUI.Geometry.Rectangle :=
           Groups.Divider_Region (Captured_Layout, 1);
      begin
         Result := Group.Handle
           (Captured_Layout,
            Pointer (Captured_Divider.X, 1,
                     Flyology_TUI.Events.Mouse_Click));
         Group.Configure (18, 3, Four_Panes);
         Result := Group.Handle
           (Captured_Layout,
            Pointer (-100, 1, Flyology_TUI.Events.Mouse_Release));
         Assert
           (Result.Handled and then not Result.Rejected
            and then Result.Capture =
              Flyology_TUI.Components.Interactions.Release_Capture,
            "pane-count change stranded existing capture ownership");
      end;
   end Test_Body_Click_And_Snapshot_Input;

   procedure Test_Vertical_Mouse_And_Interruption is
      Constraints : constant Groups.Pane_Constraint_Array (1 .. 3) :=
        (others => (Minimum_Span => 2, Initial_Span => 4, Weight => 1));
      Group : Groups.Model := Groups.Create
        (Flyology_TUI.Layouts.Boxes.Vertical, 5, 14, Constraints);
      Region : Flyology_TUI.Geometry.Rectangle := Group.Divider_Region (2);
      Result : Flyology_TUI.Components.Interactions.Update_Result;
      Before : Natural;
   begin
      Result := Group.Handle
        (Pointer (2, Region.Y, Flyology_TUI.Events.Mouse_Click));
      Result := Group.Handle
        (Pointer (2, Region.Y - 2, Flyology_TUI.Events.Mouse_Drag));
      Assert
        (Result.Changed and then Group.Pane_Span (2) = 2,
         "vertical divider did not move or clamp to its minimum");
      Result := Group.Handle
        (Pointer (2, -50, Flyology_TUI.Events.Mouse_Release));
      Assert
        (Result.Capture =
           Flyology_TUI.Components.Interactions.Release_Capture,
         "vertical divider did not release outside");

      Region := Group.Divider_Region (1);
      Result := Group.Handle
        (Pointer (2, Region.Y, Flyology_TUI.Events.Mouse_Click));
      Group.Resize (5, 17);
      Before := Group.Pane_Span (1);
      Result := Group.Handle
        (Pointer (2, 100, Flyology_TUI.Events.Mouse_Drag));
      Assert
        (not Result.Handled and then Group.Pane_Span (1) = Before,
         "Resize did not cancel the semantic drag");
      Result := Group.Handle
        (Pointer (2, 100, Flyology_TUI.Events.Mouse_Release,
                  Flyology_TUI.Events.Middle_Button));
      Assert
        (Result.Capture =
           Flyology_TUI.Components.Interactions.No_Capture_Change,
         "interrupted drag released for a mismatched button");
      Result := Group.Handle
        (Pointer (2, 100, Flyology_TUI.Events.Mouse_Release));
      Assert
        (Result.Capture =
           Flyology_TUI.Components.Interactions.Release_Capture,
         "Resize did not preserve capture until matching release");

      Region := Group.Divider_Region (1);
      Result := Group.Handle
        (Pointer (2, Region.Y, Flyology_TUI.Events.Mouse_Click));
      Group.Configure (5, 18, Constraints);
      Before := Group.Pane_Span (1);
      Result := Group.Handle
        (Pointer (2, 100, Flyology_TUI.Events.Mouse_Drag));
      Assert
        (not Result.Handled and then Group.Pane_Span (1) = Before,
         "Configure did not cancel the semantic drag");
      Result := Group.Handle
        (Pointer (2, 100, Flyology_TUI.Events.Mouse_Release));
      Assert
        (Result.Capture =
           Flyology_TUI.Components.Interactions.Release_Capture,
         "Configure did not preserve capture until matching release");

      Region := Group.Divider_Region (1);
      Result := Group.Handle
        (Pointer (2, Region.Y, Flyology_TUI.Events.Mouse_Click));
      Group.Set_Enabled (False);
      Result := Group.Handle
        (Pointer (2, 100, Flyology_TUI.Events.Mouse_Drag));
      Assert (not Result.Handled, "disabled group continued its drag");
      Result := Group.Handle
        (Pointer (2, 100, Flyology_TUI.Events.Mouse_Release));
      Assert
        (Result.Capture =
           Flyology_TUI.Components.Interactions.Release_Capture,
         "disable did not preserve capture until matching release");
   end Test_Vertical_Mouse_And_Interruption;

   procedure Test_Keyboard is
      Constraints : constant Groups.Pane_Constraint_Array (7 .. 9) :=
        (others => (Minimum_Span => 2, Initial_Span => 6, Weight => 1));
      Horizontal : Groups.Model := Groups.Create
        (Flyology_TUI.Layouts.Boxes.Horizontal, 20, 3, Constraints);
      Vertical : Groups.Model := Groups.Create
        (Flyology_TUI.Layouts.Boxes.Vertical, 3, 20, Constraints);
      Result : Flyology_TUI.Components.Interactions.Update_Result;
      Before : Natural;
   begin
      Result := Horizontal.Handle
        (Key (Flyology_TUI.Events.Arrow_Right_Key));
      Assert (not Result.Handled, "unfocused group accepted keyboard input");
      Horizontal.Focus;
      Assert
        (Horizontal.Has_Focused_Divider
         and then Horizontal.Focused_Divider = 7,
         "focus did not select the first divider");
      Before := Horizontal.Pane_Span (7);
      Result := Horizontal.Handle
        (Key (Flyology_TUI.Events.Arrow_Right_Key));
      Assert
        (Result.Handled and then Result.Changed
         and then Horizontal.Pane_Span (7) = Before + 1,
         "Right did not move a horizontal divider");
      Result := Horizontal.Handle
        (Key (Flyology_TUI.Events.Tab_Key));
      Assert
        (Result.Changed and then Horizontal.Focused_Divider = 8,
         "Tab did not select the next divider");
      Result := Horizontal.Handle
        (Key (Flyology_TUI.Events.Tab_Key, Shift => True));
      Assert
        (Horizontal.Focused_Divider = 7,
         "Shift-Tab did not select the previous divider");
      Result := Horizontal.Handle (Key (Flyology_TUI.Events.End_Key));
      Assert
        (Horizontal.Focused_Divider = 8,
         "End did not select the last divider");
      Before := Horizontal.Pane_Span (8);
      Result := Horizontal.Handle
        (Key (Flyology_TUI.Events.Arrow_Left_Key, Shift => True));
      Assert
        (Result.Changed
         and then Horizontal.Pane_Span (8) =
           Natural'Max (2, Before - Natural'Min (5, Before)),
         "Shift-Left did not move by five or clamp to minimum");
      Result := Horizontal.Handle
        (Key (Flyology_TUI.Events.Arrow_Up_Key));
      Assert
        (not Result.Handled,
         "horizontal group accepted a vertical movement key");

      Vertical.Focus;
      Before := Vertical.Pane_Span (7);
      Result := Vertical.Handle
        (Key (Flyology_TUI.Events.Arrow_Down_Key));
      Assert
        (Result.Changed and then Vertical.Pane_Span (7) = Before + 1,
         "Down did not move a vertical divider");
      Result := Vertical.Handle (Key (Flyology_TUI.Events.Home_Key));
      Assert
        (Vertical.Focused_Divider = 7,
         "Home did not select the first divider");
   end Test_Keyboard;

   procedure Test_Minimums_Resize_And_Snapshot is
      Constraints : constant Groups.Pane_Constraint_Array (1 .. 3) :=
        (others => (Minimum_Span => 3, Initial_Span => 3, Weight => 1));
      Group : Groups.Model := Groups.Create
        (Flyology_TUI.Layouts.Boxes.Horizontal, 10, 2, Constraints);
      Before : constant Groups.Layout_Snapshot := Group.Layout;
      Region : constant Flyology_TUI.Geometry.Rectangle :=
        Group.Divider_Region (1);
      Result : Flyology_TUI.Components.Interactions.Update_Result;
      Children : constant Groups.Surface_Array (1 .. 3) :=
        (others => Flyology_TUI.Surfaces.Create (0, 0));
      Rendered : Flyology_TUI.Surfaces.Surface;
   begin
      Assert
        (Group.Pane_Span (1) = 3
         and then Group.Pane_Span (2) = 3
         and then Group.Pane_Span (3) = 2,
         "infeasible minimums did not use early-pane priority");
      Result := Group.Handle
        (Pointer (Region.X, 0, Flyology_TUI.Events.Mouse_Click));
      Result := Group.Handle
        (Pointer (Region.X - 2, 0, Flyology_TUI.Events.Mouse_Drag));
      Assert
        (not Result.Changed and then Group.Pane_Span (1) = 3,
         "infeasible minimum layout allowed divider movement");
      Result := Group.Handle
        (Pointer (Region.X, 0, Flyology_TUI.Events.Mouse_Release));

      Group.Resize (16, 2);
      Assert_Exact (Group, 1, 3, "responsive Resize lost exact total");
      Assert
        (Groups.Width (Before) = 10
         and then Groups.Pane_Region (Before, 1).Width = 3
         and then Group.Width = 16,
         "Resize mutated an existing layout snapshot");
      Rendered := Group.Render
        (Before, Children, Groups.From_Theme (Flyology_TUI.Themes.Default));
      Assert
        (Flyology_TUI.Surfaces.Width (Rendered) = 10,
         "snapshot Render did not use snapshot geometry");
   end Test_Minimums_Resize_And_Snapshot;

   procedure Test_Render_Clipping_And_Appearance is
      Constraints : constant Groups.Pane_Constraint_Array (40 .. 41) :=
        (others => (Minimum_Span => 1, Initial_Span => 1, Weight => 1));
      Group : Groups.Model := Groups.Create
        (Flyology_TUI.Layouts.Boxes.Horizontal, 3, 1, Constraints);
      Normal : constant Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.With_Foreground
          (Flyology_TUI.Styles.Default,
           Flyology_TUI.Colors.Basic (Flyology_TUI.Colors.Red));
      Focused : constant Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.With_Foreground
          (Flyology_TUI.Styles.Default,
           Flyology_TUI.Colors.Basic (Flyology_TUI.Colors.Green));
      Hovered : constant Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.With_Foreground
          (Flyology_TUI.Styles.Default,
           Flyology_TUI.Colors.Basic (Flyology_TUI.Colors.Yellow));
      Pressed : constant Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.With_Foreground
          (Flyology_TUI.Styles.Default,
           Flyology_TUI.Colors.Basic (Flyology_TUI.Colors.Blue));
      Disabled : constant Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.With_Foreground
          (Flyology_TUI.Styles.Default,
           Flyology_TUI.Colors.Basic (Flyology_TUI.Colors.Magenta));
      Pane : constant Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.With_Foreground
          (Flyology_TUI.Styles.Default,
           Flyology_TUI.Colors.Basic (Flyology_TUI.Colors.Cyan));
      Look : constant Groups.Appearance :=
        (Pane             => Pane,
         Divider          => Normal,
         Focused_Divider  => Focused,
         Hovered_Divider  => Hovered,
         Pressed_Divider  => Pressed,
         Disabled_Divider => Disabled);
      Children : constant Groups.Surface_Array (40 .. 41) :=
        (40 => Flyology_TUI.Surfaces.From_Text (Bee),
         41 => Flyology_TUI.Surfaces.From_Text ("z"));
      Result : Flyology_TUI.Components.Interactions.Update_Result;
      Rendered : Flyology_TUI.Surfaces.Surface :=
        Group.Render (Children, Look);
      Custom_Theme : Flyology_TUI.Themes.Theme := Flyology_TUI.Themes.Default;
   begin
      Assert
        (Cell_Text (Rendered, 0, 0) = " "
         and then not Rendered.Element (0, 0).Continuation,
         "clipped wide child left an orphan cell");
      Assert
        (Cell_Text (Rendered, 1, 0) = Vertical_Line
         and then Rendered.Element (1, 0).Appearance = Normal,
         "child content overwrote the normal divider");
      Assert (Cell_Text (Rendered, 2, 0) = "z",
              "second child was not rendered");

      Group.Focus;
      Rendered := Group.Render (Children, Look);
      Assert
        (Rendered.Element (1, 0).Appearance = Focused,
         "focused divider style was not used");
      Result := Group.Handle
        (Pointer (1, 0, Flyology_TUI.Events.Mouse_Move));
      Rendered := Group.Render (Children, Look);
      Assert
        (Result.Changed and then
         Rendered.Element (1, 0).Appearance = Hovered,
         "hovered divider style was not used");
      Result := Group.Handle
        (Pointer (1, 0, Flyology_TUI.Events.Mouse_Click));
      Rendered := Group.Render (Children, Look);
      Assert
        (Rendered.Element (1, 0).Appearance = Pressed,
         "pressed divider style was not used");
      Result := Group.Handle
        (Pointer (1, 0, Flyology_TUI.Events.Mouse_Release));
      Group.Set_Enabled (False);
      Rendered := Group.Render (Children, Look);
      Assert
        (Rendered.Element (1, 0).Appearance = Disabled,
         "disabled divider style was not used");

      Custom_Theme.Border := Normal;
      Custom_Theme.Focused := Hovered;
      Custom_Theme.Selected := Pressed;
      Custom_Theme.Muted := Disabled;
      Assert
        (Groups.From_Theme (Custom_Theme).Divider = Normal
         and then Groups.From_Theme (Custom_Theme).Hovered_Divider = Hovered
         and then Groups.From_Theme (Custom_Theme).Pressed_Divider = Pressed
         and then Groups.From_Theme (Custom_Theme).Disabled_Divider = Disabled,
         "theme roles were not mapped to divider states");
      Rendered := Group.Render (Children, Custom_Theme);
      Assert
        (Rendered.Element (1, 0).Appearance = Disabled,
         "theme Render did not borrow the disabled divider role");
   end Test_Render_Clipping_And_Appearance;

   procedure Test_Atomic_Capacity_And_Configure is
      Initial : constant Groups.Pane_Constraint_Array (5 .. 6) :=
        (others => (Minimum_Span => 1, Initial_Span => 3, Weight => 1));
      Replacement : constant Groups.Pane_Constraint_Array (80 .. 82) :=
        (others => (Minimum_Span => 1, Initial_Span => 2, Weight => 1));
      Group : Groups.Model := Groups.Create
        (Flyology_TUI.Layouts.Boxes.Horizontal, 9, 2, Initial);
      Old_First : constant Natural := Group.Pane_Span (5);
      Raised : Boolean := False;
   begin
      begin
         Group.Configure (Natural'Last, 2, Replacement);
      exception
         when Flyology_TUI.Components.Capacity_Error =>
            Raised := True;
      end;
      Assert
        (Raised and then Group.Width = 9 and then Group.Height = 2
         and then Group.Has_Pane (5) and then not Group.Has_Pane (80)
         and then Group.Pane_Span (5) = Old_First,
         "failed Configure partially changed the model");

      Raised := False;
      begin
         Group.Resize (Natural'Last, 2);
      exception
         when Flyology_TUI.Components.Capacity_Error =>
            Raised := True;
      end;
      Assert
        (Raised and then Group.Width = 9
         and then Group.Pane_Span (5) = Old_First,
         "failed Resize partially changed the model");

      Group.Configure (14, 2, Replacement);
      Assert
        (Group.Width = 14 and then Group.Pane_Count = 3
         and then Group.Has_Pane (80) and then Group.Has_Pane (82),
         "successful Configure did not replace geometry and bounds");
      Assert_Exact (Group, 80, 82, "configured layout did not fill extent");
   end Test_Atomic_Capacity_And_Configure;

begin
   Test_Initial_Layout_And_Bounds;
   Test_Zero_One_And_Tiny;
   Test_All_Mouse_Dividers;
   Test_Body_Click_And_Snapshot_Input;
   Test_Vertical_Mouse_And_Interruption;
   Test_Keyboard;
   Test_Minimums_Resize_And_Snapshot;
   Test_Render_Clipping_And_Appearance;
   Test_Atomic_Capacity_And_Configure;
   Ada.Text_IO.Put_Line ("panel group tests passed");
end Panel_Group_Tests;
