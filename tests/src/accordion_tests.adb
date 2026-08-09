with Ada.Strings.Wide_Wide_Unbounded;
with Ada.Text_IO;
with Flyology_TUI.Components;
with Flyology_TUI.Components.Accordions;
with Flyology_TUI.Components.Interactions;
with Flyology_TUI.Events;
with Flyology_TUI.Geometry;
with Flyology_TUI.Mouse;
with Flyology_TUI.Styles;
with Flyology_TUI.Surfaces;
with Flyology_TUI.Themes;

procedure Accordion_Tests is
   package Text renames Ada.Strings.Wide_Wide_Unbounded;

   type Section_Id is (One, Two, Three, Four, Five);

   function Identity (Item : Section_Id) return Section_Id is (Item);

   function Section_Label (Item : Section_Id) return Wide_Wide_String is
     (case Item is
         when One   => "Overview",
         when Two   => "界 details",
         when Three => "Settings",
         when Four  => "Logs",
         when Five  => "Overflow");

   package Accordions is new Flyology_TUI.Components.Accordions
     (Section_Type => Section_Id,
      Id_Type      => Section_Id,
      Id_Of        => Identity,
      Label        => Section_Label,
      Capacity     => 4);

   No_Sections : constant Accordions.Section_Array (1 .. 0) :=
     (others => One);
   No_Bodies : constant Accordions.Body_Array (1 .. 0) :=
     (others =>
        (Id      => One,
         Content => Flyology_TUI.Surfaces.Create (0, 0)));

   use type Accordions.Expansion_Mode;
   use type Flyology_TUI.Components.Interactions.Capture_Action;
   use type Flyology_TUI.Geometry.Rectangle;
   use type Flyology_TUI.Styles.Style;

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

   function Space return Flyology_TUI.Events.Terminal_Event is
     (Flyology_TUI.Events.Pressed
        ((Kind     => Flyology_TUI.Events.Text_Key,
          Modified => (others => False),
          Repeated => False,
          Value    => Text.To_Unbounded_Wide_Wide_String (" "))));

   function Pointer
     (X, Y   : Integer;
      Action : Flyology_TUI.Events.Mouse_Action;
      Button : Flyology_TUI.Events.Mouse_Button :=
        Flyology_TUI.Events.Left_Button)
      return Flyology_TUI.Mouse.Local_Event is
     (X        => X,
      Y        => Y,
      Button   => Button,
      Action   => Action,
      Modified => (others => False),
      Wheel_X  => 0,
      Wheel_Y  => 0);

   function Cell_Text
     (Item : Flyology_TUI.Surfaces.Surface;
      X, Y : Natural) return Wide_Wide_String is
     (Text.To_Wide_Wide_String (Item.Element (X, Y).Glyph));

   procedure Expect_Capacity
     (Action  : not null access procedure;
      Message : String)
   is
      Raised : Boolean := False;
   begin
      begin
         Action.all;
      exception
         when Flyology_TUI.Components.Capacity_Error => Raised := True;
      end;
      Assert (Raised, Message);
   end Expect_Capacity;

   procedure Expect_Structure
     (Action  : not null access procedure;
      Message : String)
   is
      Raised : Boolean := False;
   begin
      begin
         Action.all;
      exception
         when Flyology_TUI.Components.Structure_Error => Raised := True;
      end;
      Assert (Raised, Message);
   end Expect_Structure;

   procedure Test_Empty_And_Tiny is
      Empty : Accordions.Model := Accordions.Create (No_Sections);
      Layout : constant Accordions.Presentation :=
        Empty.Present (No_Bodies, 0, Flyology_TUI.Themes.Default);
      Result : Flyology_TUI.Components.Interactions.Update_Result;
   begin
      Assert
        (Empty.Is_Empty and then Empty.Length = 0
         and then Accordions.Frame (Layout).Width = 0
         and then Accordions.Frame (Layout).Height = 0,
         "empty accordion did not produce an empty presentation");
      Result := Empty.Handle (Key (Flyology_TUI.Events.Arrow_Down_Key));
      Assert (not Result.Handled, "empty accordion handled keyboard input");
      Result := Empty.Handle
        (Pointer
           (Integer'First, Integer'Last,
            Flyology_TUI.Events.Mouse_Click),
         Layout);
      Assert
        (not Result.Handled,
         "empty accordion handled extreme mouse input");

      declare
         Item : constant Accordions.Model := Accordions.Create ((1 => Two));
         Zero : constant Accordions.Presentation :=
           Item.Present
             (No_Bodies, 0, Flyology_TUI.Themes.Charm,
              Has_Focus => True);
         Tiny : constant Flyology_TUI.Surfaces.Surface :=
           Item.Render
             (No_Bodies, 3, Flyology_TUI.Themes.Charm,
              Has_Focus => True);
      begin
         Assert
           (Accordions.Frame (Zero).Width = 0
            and then Accordions.Frame (Zero).Height = 1
            and then Accordions.Header_Region (Zero, Two) = (0, 0, 0, 1),
            "zero-width accordion lost deterministic header geometry");
         Assert
           (Tiny.Width = 3 and then Tiny.Height = 1
            and then not Tiny.Element (0, 0).Continuation
            and then not Tiny.Element (1, 0).Continuation
            and then not Tiny.Element (2, 0).Continuation,
            "tiny Unicode header left invalid continuation geometry");
      end;
   end Test_Empty_And_Tiny;

   procedure Test_Expansion_And_Stable_Ids is
      Item : Accordions.Model := Accordions.Create
        ((One, Two, Three), Accordions.Multiple_Expansion);
      Result : Flyology_TUI.Components.Interactions.Update_Result;

      procedure Duplicate is
      begin
         Item.Set_Sections ((One, Two, Two));
      end Duplicate;

      procedure Oversized is
      begin
         Item.Set_Sections ((One, Two, Three, Four, Five));
      end Oversized;

      procedure Missing_Id is
      begin
         Item.Set_Expanded (Five);
      end Missing_Id;
   begin
      Assert
        (Item.Mode = Accordions.Multiple_Expansion
         and then Item.Focused_Id = One,
         "accordion creation did not establish mode or focus");
      Item.Set_Expanded (Two);
      Item.Set_Expanded (Three);
      Result := Item.Handle (Key (Flyology_TUI.Events.Arrow_Down_Key));
      Assert
        (Result.Changed and then Item.Focused_Id = Two,
         "keyboard navigation did not focus the second section");
      Item.Set_Sections ((Three, Two, Four));
      Assert
        (Item.Focused_Id = Two
         and then Item.Is_Expanded (Two)
         and then Item.Is_Expanded (Three)
         and then not Item.Is_Expanded (Four),
         "section state did not follow stable ids through replacement");

      Expect_Structure
        (Duplicate'Access, "duplicate replacement was accepted");
      Assert
        (Item.Length = 3 and then Item.Focused_Id = Two
         and then Item.Is_Expanded (Two),
         "duplicate replacement failure mutated accordion state");
      Expect_Capacity
        (Oversized'Access, "oversized replacement was accepted");
      Assert
        (Item.Length = 3 and then Item.Contains (Four),
         "capacity failure mutated accordion state");
      Expect_Structure
        (Missing_Id'Access, "unknown programmatic section was accepted");

      Item.Collapse_All;
      Assert
        (not Item.Is_Expanded (Two) and then not Item.Is_Expanded (Three),
         "Collapse_All left expanded sections");
      Item.Expand_All;
      Assert
        (Item.Is_Expanded (Three)
         and then Item.Is_Expanded (Two)
         and then Item.Is_Expanded (Four),
         "Expand_All did not expand every section");
   end Test_Expansion_And_Stable_Ids;

   procedure Test_Single_And_Disabled_Navigation is
      Item : Accordions.Model := Accordions.Create ((One, Two, Three));
      Result : Flyology_TUI.Components.Interactions.Update_Result;
   begin
      Item.Set_Expanded (One);
      Item.Set_Expanded (Two);
      Assert
        (not Item.Is_Expanded (One) and then Item.Is_Expanded (Two),
         "single expansion allowed two open sections");

      Item.Set_Section_Enabled (Two, False);
      Result := Item.Handle (Key (Flyology_TUI.Events.Arrow_Down_Key));
      Assert
        (Result.Changed and then Item.Focused_Id = Three,
         "down navigation did not skip a disabled section");
      Result := Item.Handle (Key (Flyology_TUI.Events.Arrow_Up_Key));
      Assert
        (Result.Changed and then Item.Focused_Id = One,
         "up navigation did not skip a disabled section");
      Result := Item.Handle (Key (Flyology_TUI.Events.End_Key));
      Assert
        (Result.Changed and then Item.Focused_Id = Three,
         "End did not select the last enabled section");
      Result := Item.Handle (Key (Flyology_TUI.Events.Home_Key));
      Assert
        (Result.Changed and then Item.Focused_Id = One,
         "Home did not select the first enabled section");

      Result := Item.Handle (Key (Flyology_TUI.Events.Arrow_Right_Key));
      Assert
        (Result.Activated and then Item.Is_Expanded (One)
         and then not Item.Is_Expanded (Two),
         "Right did not expand the focused section in single mode");
      Result := Item.Handle (Key (Flyology_TUI.Events.Arrow_Right_Key));
      Assert
        (Result.Handled and then not Result.Changed,
         "Right changed an already expanded section");
      Result := Item.Handle (Key (Flyology_TUI.Events.Arrow_Left_Key));
      Assert
        (Result.Activated and then not Item.Is_Expanded (One),
         "Left did not collapse the focused section");
      Result := Item.Handle (Space);
      Assert
        (Result.Activated and then Item.Is_Expanded (One),
         "Space did not toggle the focused section");
      Result := Item.Handle (Key (Flyology_TUI.Events.Enter_Key));
      Assert
        (Result.Activated and then not Item.Is_Expanded (One),
         "Enter did not toggle the focused section");

      Item.Set_Section_Enabled (One, False);
      Item.Set_Section_Enabled (Three, False);
      Assert
        (not Item.Has_Focused_Section,
         "all-disabled accordion retained a keyboard focus row");
      Result := Item.Handle (Space);
      Assert (not Result.Handled, "all-disabled accordion handled activation");
      Item.Set_Section_Enabled (Two);
      Assert
        (Item.Has_Focused_Section and then Item.Focused_Id = Two,
         "reenabling the first available section did not restore focus");
   end Test_Single_And_Disabled_Navigation;

   procedure Test_Presentation_And_Body_Validation is
      Item : Accordions.Model := Accordions.Create
        ((One, Two, Three), Accordions.Multiple_Expansion);
      First_Body : Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.From_Text
          ("first" & Wide_Wide_Character'Val (10) & "second");
      Third_Body : constant Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.From_Text ("界");

      procedure Missing_Body is
         Discard : Accordions.Presentation;
      begin
         Discard := Item.Present
           ((1 => (Id => One, Content => First_Body)),
            12, Flyology_TUI.Themes.Default);
      end Missing_Body;

      procedure Duplicate_Body is
         Discard : Accordions.Presentation;
      begin
         Discard := Item.Present
           (((Id => One, Content => First_Body),
             (Id => One, Content => Third_Body)),
            12, Flyology_TUI.Themes.Default);
      end Duplicate_Body;

      procedure Collapsed_Body is
         Discard : Accordions.Presentation;
      begin
         Discard := Item.Present
           (((Id => One, Content => First_Body),
             (Id => Two, Content => Third_Body)),
            12, Flyology_TUI.Themes.Default);
      end Collapsed_Body;
   begin
      Item.Set_Expanded (One);
      Item.Set_Expanded (Three);
      declare
         Layout : constant Accordions.Presentation := Item.Present
           (((Id => Three, Content => Third_Body),
             (Id => One, Content => First_Body)),
            12, Flyology_TUI.Themes.Charm, Has_Focus => True);
      begin
         Assert
           (Accordions.Frame (Layout).Width = 12
            and then Accordions.Frame (Layout).Height = 6,
            "accordion presentation dimensions are incorrect");
         Assert
           (Accordions.Header_Region (Layout, One) = (0, 0, 12, 1)
            and then Accordions.Body_Region (Layout, One) = (0, 1, 12, 2)
            and then Accordions.Header_Region (Layout, Two) = (0, 3, 12, 1)
            and then Accordions.Header_Region (Layout, Three) =
              (0, 4, 12, 1)
            and then Accordions.Body_Region (Layout, Three) =
              (0, 5, 12, 1),
            "accordion header/body regions do not match the frame");
         Assert
           (not Accordions.Has_Body_Region (Layout, Two)
            and then Accordions.Has_Section (Layout, Three)
            and then not Accordions.Has_Section (Layout, Five),
            "presentation region presence queries are incorrect");
         Assert
           (Cell_Text (Accordions.Frame (Layout), 0, 1) = "f"
            and then Cell_Text (Accordions.Frame (Layout), 0, 5) = "界",
            "external bodies were not clipped into their regions");

         First_Body.Put (0, 0, "X");
         Assert
           (Cell_Text (Accordions.Frame (Layout), 0, 1) = "f",
            "presentation retained a live external body surface");
      end;

      Expect_Structure
        (Missing_Body'Access, "missing expanded body was accepted");
      Expect_Structure
        (Duplicate_Body'Access, "duplicate body id was accepted");
      Expect_Structure
        (Collapsed_Body'Access, "body for collapsed section was accepted");
   end Test_Presentation_And_Body_Validation;

   procedure Test_Mouse_And_Nested_Routing is
      Item : Accordions.Model := Accordions.Create ((One, Two, Three));
      Layout : Accordions.Presentation := Item.Present
        (No_Bodies, 14, Flyology_TUI.Themes.Default);
      Result : Flyology_TUI.Components.Interactions.Update_Result;
   begin
      Result := Item.Handle
        (Pointer (2, 0, Flyology_TUI.Events.Mouse_Click), Layout);
      Assert
        (Result.Focus_Requested
         and then Result.Capture =
           Flyology_TUI.Components.Interactions.Acquire_Capture,
         "header press did not request focus and capture");
      Result := Item.Handle
        (Pointer (2, 0, Flyology_TUI.Events.Mouse_Release), Layout);
      Assert
        (Result.Activated and then Item.Is_Expanded (One)
         and then Result.Capture =
           Flyology_TUI.Components.Interactions.Release_Capture,
         "matching header release did not toggle and release capture");

      Layout := Item.Present
        ((1 =>
            (Id      => One,
             Content => Flyology_TUI.Surfaces.From_Text ("nested"))),
         14, Flyology_TUI.Themes.Default);
      Result := Item.Handle
        (Pointer (2, 1, Flyology_TUI.Events.Mouse_Click), Layout);
      Assert
        (not Result.Handled,
         "accordion consumed an event inside a nested body region");

      Result := Item.Handle
        (Pointer (2, 2, Flyology_TUI.Events.Mouse_Click), Layout);
      Result := Item.Handle
        (Pointer (-1, Integer'Last, Flyology_TUI.Events.Mouse_Release),
         Layout);
      Assert
        (not Result.Activated
         and then Result.Capture =
           Flyology_TUI.Components.Interactions.Release_Capture,
         "release outside activated or stranded capture");

      Result := Item.Handle
        (Pointer (2, 2, Flyology_TUI.Events.Mouse_Click), Layout);
      Result := Item.Handle
        (Pointer
           (2, 2, Flyology_TUI.Events.Mouse_Release,
            Flyology_TUI.Events.Right_Button),
         Layout);
      Assert
        (not Result.Handled,
         "mismatched button release ended accordion capture");
      Result := Item.Handle
        (Pointer (2, 2, Flyology_TUI.Events.Mouse_Release), Layout);
      Assert
        (Result.Activated
         and then Result.Capture =
           Flyology_TUI.Components.Interactions.Release_Capture,
         "matching release after mismatch did not unwind capture");

      Layout := Item.Present
        ((1 =>
            (Id      => Two,
             Content => Flyology_TUI.Surfaces.From_Text ("two"))),
         14, Flyology_TUI.Themes.Default);
      Item.Set_Section_Enabled (Three, False);
      Result := Item.Handle
        (Pointer (2, 3, Flyology_TUI.Events.Mouse_Click), Layout);
      Assert
        (not Result.Handled,
         "disabled section header acquired mouse capture");
   end Test_Mouse_And_Nested_Routing;

   procedure Test_Interrupted_Capture is
      Item : Accordions.Model := Accordions.Create ((One, Two, Three));
      Layout : Accordions.Presentation := Item.Present
        (No_Bodies, 10, Flyology_TUI.Themes.Default);
      Result : Flyology_TUI.Components.Interactions.Update_Result;
   begin
      Result := Item.Handle
        (Pointer (1, 0, Flyology_TUI.Events.Mouse_Click), Layout);
      Item.Set_Sections ((Three, Two, One));
      Result := Item.Handle
        (Pointer (1, 0, Flyology_TUI.Events.Mouse_Release), Layout);
      Assert
        (not Result.Activated
         and then Result.Capture =
           Flyology_TUI.Components.Interactions.Release_Capture
         and then not Item.Is_Expanded (One),
         "section replacement reactivated or stranded capture");

      Layout := Item.Present (No_Bodies, 10, Flyology_TUI.Themes.Default);
      Result := Item.Handle
        (Pointer (1, 0, Flyology_TUI.Events.Mouse_Click), Layout);
      Item.Set_Section_Enabled (Three, False);
      Result := Item.Handle
        (Pointer (1, 0, Flyology_TUI.Events.Mouse_Release), Layout);
      Assert
        (not Result.Activated
         and then Result.Capture =
           Flyology_TUI.Components.Interactions.Release_Capture,
         "section disable reactivated or stranded capture");

      Item.Set_Section_Enabled (Three);
      Layout := Item.Present (No_Bodies, 10, Flyology_TUI.Themes.Default);
      Result := Item.Handle
        (Pointer (1, 0, Flyology_TUI.Events.Mouse_Click), Layout);
      Item.Set_Expanded (Three);
      Result := Item.Handle
        (Pointer (1, 0, Flyology_TUI.Events.Mouse_Release), Layout);
      Assert
        (not Result.Activated
         and then Result.Capture =
           Flyology_TUI.Components.Interactions.Release_Capture
         and then Item.Is_Expanded (Three),
         "programmatic expansion reactivated or stranded capture");
   end Test_Interrupted_Capture;

   procedure Test_Appearance_And_Bounds is
      Item : constant Accordions.Model := Accordions.Create ((One, Two));
      Look : constant Accordions.Appearance :=
        Accordions.From_Theme (Flyology_TUI.Themes.Charm);

      procedure Too_Wide is
         Discard : Accordions.Presentation;
      begin
         Discard := Item.Present
           (No_Bodies,
            Natural (Integer'Last),
            Flyology_TUI.Themes.Default);
      end Too_Wide;
   begin
      Assert
        (Look.Header = Flyology_TUI.Themes.Charm.Primary
         and then Look.Expanded_Header = Flyology_TUI.Themes.Charm.Selected
         and then Look.Focused_Header = Flyology_TUI.Themes.Charm.Focused
         and then Look.Disabled_Header = Flyology_TUI.Themes.Charm.Muted
         and then Look.Content = Flyology_TUI.Themes.Charm.Primary,
         "accordion theme mapping changed");
      Expect_Capacity
        (Too_Wide'Access,
         "surface cell multiplication overflow was not rejected");

      declare
         subtype High_Index is Positive range
           Positive'Last - 1 .. Positive'Last;
         Values : constant Accordions.Section_Array (High_Index) :=
           (One, Two);
         High_Item : Accordions.Model := Accordions.Create (Values);
         Layout : Accordions.Presentation;
      begin
         High_Item.Set_Expanded (Two);
         declare
            Bodies : constant Accordions.Body_Array
              (Positive'Last .. Positive'Last) :=
                (Positive'Last =>
                   (Id => Two,
                    Content => Flyology_TUI.Surfaces.From_Text ("body")));
         begin
            Layout := High_Item.Present
              (Bodies, 8, Flyology_TUI.Themes.Default);
         end;
         Assert
           (Accordions.Frame (Layout).Height = 3
            and then Accordions.Body_Region (Layout, Two) = (0, 2, 8, 1),
            "high-bound input arrays leaked index assumptions");
      end;
   end Test_Appearance_And_Bounds;

begin
   Test_Empty_And_Tiny;
   Test_Expansion_And_Stable_Ids;
   Test_Single_And_Disabled_Navigation;
   Test_Presentation_And_Body_Validation;
   Test_Mouse_And_Nested_Routing;
   Test_Interrupted_Capture;
   Test_Appearance_And_Bounds;
   Ada.Text_IO.Put_Line ("accordion tests passed");
end Accordion_Tests;
