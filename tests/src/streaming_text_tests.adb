with Ada.Text_IO;
with Flyology_TUI.Colors;
with Flyology_TUI.Components;
with Flyology_TUI.Components.Interactions;
with Flyology_TUI.Components.Streaming_Texts;
with Flyology_TUI.Events;
with Flyology_TUI.Mouse;
with Flyology_TUI.Styles;
with Flyology_TUI.Surfaces;
with Flyology_TUI.Themes;

procedure Streaming_Text_Tests is
   package Rejecting is new Flyology_TUI.Components.Streaming_Texts
     (Max_Code_Points    => 8,
      Max_Lines          => 3,
      Max_Viewport_Cells => 64);

   package Trimming is new Flyology_TUI.Components.Streaming_Texts
     (Max_Code_Points    => 3,
      Max_Lines          => 2,
      Max_Viewport_Cells => 64);

   package Roomy is new Flyology_TUI.Components.Streaming_Texts
     (Max_Code_Points    => 64,
      Max_Lines          => 8,
      Max_Viewport_Cells => 256);

   use type Flyology_TUI.Components.Interactions.Capture_Action;
   use type Flyology_TUI.Styles.Style;
   use type Rejecting.Operation_Result;
   use type Rejecting.Stream_State;
   use type Roomy.Operation_Result;
   use type Trimming.Operation_Result;

   Combining_Acute : constant Wide_Wide_String :=
     (1 => Wide_Wide_Character'Val (16#0301#));

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
      Value.Repeated := False;
      return Flyology_TUI.Events.Pressed (Value);
   end Key;

   function Mouse
     (X, Y    : Integer;
      Action  : Flyology_TUI.Events.Mouse_Action;
      Button  : Flyology_TUI.Events.Mouse_Button :=
        Flyology_TUI.Events.No_Button;
      Wheel_Y : Integer := 0) return Flyology_TUI.Mouse.Local_Event
   is (X        => X,
       Y        => Y,
       Button   => Button,
       Action   => Action,
       Modified => (others => False),
       Wheel_X  => 0,
       Wheel_Y  => Wheel_Y);

   function Glyph
     (Item : Flyology_TUI.Surfaces.Surface;
      X, Y : Natural) return Wide_Wide_String
   is (Flyology_TUI.Surfaces.Text.To_Wide_Wide_String
         (Item.Element (X, Y).Glyph));

   procedure Test_Clusters_Wrapping_And_Appearance is
      Item : Roomy.Model := Roomy.Create (4, 3);
      Frame : Flyology_TUI.Surfaces.Surface;
      Look : Roomy.Appearance;
      Finish_Item : Roomy.Model := Roomy.Create (4, 1);
   begin
      Assert (Item.Append ("e") = Roomy.Applied, "base append failed");
      Assert
        (Item.Append (Combining_Acute) = Roomy.Applied,
         "combining append failed");
      Frame := Item.Render;
      Assert
        (Glyph (Frame, 0, 0) = "e" & Combining_Acute,
         "a cluster split across chunks was not rendered atomically");

      Assert
        (Item.Replace
           ("A" & Wide_Wide_Character'Val (9) & "B"
            & Wide_Wide_Character'Val (10) & "界C") = Roomy.Applied,
         "mixed text replacement failed");
      Assert
        (Item.Code_Point_Count = 6 and then Item.Logical_Line_Count = 2,
         "mixed text accounting is wrong");
      Assert (Item.Visual_Row_Count = 3, "tab or newline wrapping is wrong");
      Frame := Item.Render;
      Assert
        (Glyph (Frame, 0, 0) = "A"
         and then Glyph (Frame, 0, 1) = "B"
         and then Glyph (Frame, 0, 2) = "界"
         and then Frame.Element (1, 2).Continuation
         and then Glyph (Frame, 2, 2) = "C",
         "mixed tab, line, or wide-glyph rendering is wrong");
      Assert
        (Item.Replace ("ABCD" & Wide_Wide_Character'Val (9) & "X") =
           Roomy.Applied
         and then Item.Visual_Row_Count = 3,
         "a tab at an exact wrap boundary used the previous row's column");

      Assert
        (Finish_Item.Replace ("done") = Roomy.Applied
         and then Finish_Item.Finish = Roomy.Applied,
         "finished appearance setup failed");
      Look.Finished_Text := Flyology_TUI.Styles.Emphasized
        (Flyology_TUI.Styles.Default);
      Look.Focused_Text := Flyology_TUI.Styles.With_Foreground
        (Flyology_TUI.Styles.Default,
         Flyology_TUI.Colors.Basic (Flyology_TUI.Colors.Cyan));
      Frame := Finish_Item.Render (Look);
      Assert
        (Frame.Element (0, 0).Appearance = Look.Finished_Text,
         "terminal state did not select the configured appearance");
      Frame := Finish_Item.Render (Look, Has_Focus => True);
      Assert
        (Frame.Element (0, 0).Appearance = Look.Focused_Text,
         "focus did not select the configured appearance");
      Assert
        (Roomy.From_Theme (Flyology_TUI.Themes.Charm).Failed_Text =
           Flyology_TUI.Themes.Charm.Error,
         "theme conversion did not use the error role");
   end Test_Clusters_Wrapping_And_Appearance;

   procedure Test_Reject_And_Trim_Atomicity is
      Reject_Item : Rejecting.Model := Rejecting.Create (4, 2);
      Trim_Item : Trimming.Model :=
        Trimming.Create (3, 2, Overflow => Trimming.Trim_Oldest);
      Oversized : constant Wide_Wide_String (1 .. 1_000) := (others => 'x');
      High_Bound : constant Wide_Wide_String
        (Positive'Last .. Positive'Last) := (others => 'z');
      Before_First : Natural;
      Before_Follow : Boolean;
   begin
      Assert
        (Reject_Item.Replace ("ok") = Rejecting.Applied,
         "reject model setup failed");
      Reject_Item.Set_Follow_Tail (False);
      Before_First := Reject_Item.First_Visible_Row;
      Before_Follow := Reject_Item.Is_Following_Tail;
      Assert
        (Reject_Item.Append (Oversized) = Rejecting.Rejected_Capacity,
         "oversized input was not rejected");
      Assert
        (Reject_Item.Content = "ok"
         and then Reject_Item.First_Visible_Row = Before_First
         and then Reject_Item.Is_Following_Tail = Before_Follow,
         "capacity rejection was not atomic");
      Assert
        (Reject_Item.Replace (High_Bound) = Rejecting.Applied
         and then Reject_Item.Content = "z"
         and then Reject_Item.Replace ("") = Rejecting.Applied
         and then Reject_Item.Content = "",
         "replacement mishandled an extreme string bound or empty content");
      Assert
        (Reject_Item.Replace ("ok") = Rejecting.Applied,
         "reject model reset failed");
      Assert
        (Reject_Item.Append
           (Wide_Wide_Character'Val (10) & "a"
            & Wide_Wide_Character'Val (10) & "b"
            & Wide_Wide_Character'Val (10) & "c") =
           Rejecting.Rejected_Capacity
         and then Reject_Item.Content = "ok",
         "line-capacity rejection mutated the model");

      Assert
        (Trim_Item.Replace
           ("a" & Wide_Wide_Character'Val (10) & "b"
            & Wide_Wide_Character'Val (10) & "c") = Trimming.Applied,
         "line-trimming replacement failed");
      Assert
        (Trim_Item.Content =
           "b" & Wide_Wide_Character'Val (10) & "c"
         and then Trim_Item.Logical_Line_Count = 2,
         "oldest complete line was not trimmed first");

      Assert
        (Trim_Item.Replace ("a") = Trimming.Applied
         and then Trim_Item.Append (Combining_Acute & "bc") =
           Trimming.Applied
         and then Trim_Item.Content = "bc",
         "a grapheme spanning append chunks was split during trimming");
      Assert
        (Trim_Item.Replace ("a" & Combining_Acute & Combining_Acute
           & Combining_Acute) = Trimming.Applied
         and then Trim_Item.Content = "",
         "an over-cap single cluster was retained partially");
      Assert
        (Trim_Item.Replace (Oversized) = Trimming.Applied
         and then Trim_Item.Code_Point_Count = 3
         and then Trim_Item.Content = "xxx",
         "trim mode retained unbounded history");
   end Test_Reject_And_Trim_Atomicity;

   procedure Test_State_Transitions is
      Finished_Item : Rejecting.Model := Rejecting.Create (2, 1);
      Failed_Item : Rejecting.Model := Rejecting.Create (2, 1);
      Cancelled_Item : Rejecting.Model := Rejecting.Create (2, 1);
   begin
      Assert
        (Finished_Item.Finish = Rejecting.Applied
         and then Finished_Item.State = Rejecting.Finished,
         "finish transition failed");
      Assert
        (Finished_Item.Append ("x") = Rejecting.Rejected_State
         and then Finished_Item.Replace ("") = Rejecting.Rejected_State
         and then Finished_Item.Fail = Rejecting.Rejected_State,
         "finished state accepted an illegal transition");
      Assert
        (Failed_Item.Fail = Rejecting.Applied
         and then Failed_Item.State = Rejecting.Failed
         and then Failed_Item.Cancel = Rejecting.Rejected_State,
         "failed state transition is not terminal");
      Assert
        (Cancelled_Item.Cancel = Rejecting.Applied
         and then Cancelled_Item.State = Rejecting.Cancelled
         and then Cancelled_Item.Finish = Rejecting.Rejected_State,
         "cancelled state transition is not terminal");
   end Test_State_Transitions;

   procedure Test_Follow_Unseen_And_Scrolling is
      Item : Roomy.Model := Roomy.Create (3, 2);
      Result : Flyology_TUI.Components.Interactions.Update_Result;
   begin
      Assert
        (Item.Append ("abcdefghi") = Roomy.Applied
         and then Item.Visual_Row_Count = 3
         and then Item.First_Visible_Row = 1
         and then Item.Is_Following_Tail,
         "follow-tail did not track wrapped rows");

      Item.Set_Follow_Tail (False);
      Result := Item.Scroll (-1);
      Assert
        (Result.Handled and then Result.Changed
         and then Item.First_Visible_Row = 0
         and then not Item.Is_Following_Tail,
         "manual scrolling did not suspend follow-tail");
      Assert
        (Item.Append
           (Wide_Wide_Character'Val (10) & "jkl") = Roomy.Applied
         and then Item.First_Visible_Row = 0
         and then Item.Unseen_Row_Count > 0
         and then Item.Unseen_Chunk_Count = 1,
         "detached append did not track unseen wrapped content");

      Result := Item.Handle (Key (Flyology_TUI.Events.End_Key));
      Assert
        (Result.Handled and then Result.Changed
         and then Item.Is_Following_Tail
         and then Item.Unseen_Row_Count = 0
         and then Item.Unseen_Chunk_Count = 0,
         "End did not acknowledge unseen content and resume following");

      Result := Item.Handle (Key (Flyology_TUI.Events.Home_Key));
      Assert
        (Result.Handled and then Item.First_Visible_Row = 0,
         "Home did not reach the first wrapped row");
      Result := Item.Handle
        (Mouse
           (0, 0, Flyology_TUI.Events.Mouse_Wheel,
            Wheel_Y => Integer'Last));
      Assert
        (Result.Handled and then Result.Focus_Requested
         and then Result.Capture =
           Flyology_TUI.Components.Interactions.No_Capture_Change,
         "extreme upward wheel input was mishandled");
      Result := Item.Handle
        (Mouse
           (0, 0, Flyology_TUI.Events.Mouse_Wheel,
            Wheel_Y => Integer'First));
      Assert
        (Result.Handled and then Item.Is_Following_Tail,
         "extreme downward wheel input did not clamp to the tail");
      Result := Item.Handle
        (Mouse (0, 0, Flyology_TUI.Events.Mouse_Wheel, Wheel_Y => 0));
      Assert (not Result.Handled, "zero wheel input was not ignored");
      Result := Item.Handle
        (Mouse (-1, 0, Flyology_TUI.Events.Mouse_Wheel, Wheel_Y => 1));
      Assert (not Result.Handled, "out-of-bounds wheel input was handled");
      Result := Item.Handle
        (Mouse
           (0, 0, Flyology_TUI.Events.Mouse_Click,
            Button => Flyology_TUI.Events.Right_Button));
      Assert (not Result.Handled, "non-left click requested focus");
      Result := Item.Handle
        (Mouse
           (0, 0, Flyology_TUI.Events.Mouse_Click,
            Button => Flyology_TUI.Events.Left_Button));
      Assert
        (Result.Handled and then Result.Focus_Requested
         and then Result.Capture =
           Flyology_TUI.Components.Interactions.No_Capture_Change,
         "left click did not request focus without capture");
   end Test_Follow_Unseen_And_Scrolling;

   procedure Test_Resize_Preflight_And_Zero_Extents is
      Item : Rejecting.Model := Rejecting.Create (4, 2);
      Result : Rejecting.Operation_Result;
      Frame : Flyology_TUI.Surfaces.Surface;
   begin
      Assert
        (Item.Replace ("界x") = Rejecting.Applied,
         "resize setup failed");
      Item.Set_Follow_Tail (False);
      Result := Item.Resize (Natural'Last, 2);
      Assert
        (Result = Rejecting.Rejected_Geometry
         and then Item.Viewport_Width = 4
         and then Item.Viewport_Height = 2
         and then not Item.Is_Following_Tail,
         "invalid resize was not atomically rejected");

      Result := Item.Resize (Natural'Last, 0);
      Assert
        (Result = Rejecting.Applied
         and then Item.Viewport_Width = Natural'Last
         and then Item.Viewport_Height = 0
         and then Item.Visual_Row_Count = 1,
         "zero-height geometry was not handled without multiplication");
      Frame := Item.Render;
      Assert
        (Frame.Width = Natural'Last and then Frame.Height = 0,
         "zero-height render did not preserve the accepted geometry");

      Assert
        (Item.Resize (1, 4) = Rejecting.Applied,
         "narrow resize failed");
      Frame := Item.Render;
      Assert
        (Glyph (Frame, 0, 0) = "?",
         "a wide glyph in one column did not use the safe fallback");
      Assert
        (Item.Resize (0, Natural'Last) = Rejecting.Applied
         and then Item.Visual_Row_Count = 0,
         "zero-width geometry was not handled without multiplication");
      Frame := Item.Render;
      Assert
        (Frame.Width = 0 and then Frame.Height = Natural'Last,
         "zero-width render did not preserve the accepted geometry");
      Assert
        (not Rejecting.Fits_Viewport (Natural'Last, Natural'Last),
         "viewport preflight overflowed on extreme dimensions");
      declare
         Raised : Boolean := False;
      begin
         begin
            declare
               Invalid : constant Rejecting.Model :=
                 Rejecting.Create (Natural'Last, 2);
               pragma Unreferenced (Invalid);
            begin
               null;
            end;
         exception
            when Flyology_TUI.Components.Capacity_Error =>
               Raised := True;
         end;
         Assert (Raised, "Create did not reject oversized geometry");
      end;
   end Test_Resize_Preflight_And_Zero_Extents;

begin
   Test_Clusters_Wrapping_And_Appearance;
   Test_Reject_And_Trim_Atomicity;
   Test_State_Transitions;
   Test_Follow_Unseen_And_Scrolling;
   Test_Resize_Preflight_And_Zero_Extents;
   Ada.Text_IO.Put_Line ("streaming text tests passed");
end Streaming_Text_Tests;
