with Ada.Strings.Wide_Wide_Unbounded;
with Ada.Text_IO;
with Ada.Unchecked_Conversion;
with Flyology_TUI.Components;
with Flyology_TUI.Components.Indicators;
with Flyology_TUI.Components.Interactions;
with Flyology_TUI.Components.Progress_Groups;
with Flyology_TUI.Components.Sparklines;
with Flyology_TUI.Events;
with Flyology_TUI.Mouse;
with Flyology_TUI.Numeric_Series;
with Flyology_TUI.Styles;
with Flyology_TUI.Surfaces;
with Flyology_TUI.Themes;
with Interfaces;

procedure Visual_Components_Tests is
   package Text renames Ada.Strings.Wide_Wide_Unbounded;
   package Number_Series is new Flyology_TUI.Numeric_Series
     (Sample_Type => Integer, Maximum_Capacity => 4);

   function Convert (Value : Integer) return Long_Float is
     (Long_Float (Value));

   package Sparklines is new Flyology_TUI.Components.Sparklines
     (Samples => Number_Series, To_Long_Float => Convert);

   function Decode is new Ada.Unchecked_Conversion
     (Source => Interfaces.Unsigned_64, Target => Long_Float);

   function Convert_Nonfinite (Value : Integer) return Long_Float is
      pragma Suppress (Validity_Check);
   begin
      if Value = 98 then
         return Decode (16#7FF0_0000_0000_0000#);
      elsif Value = 99 then
         return Decode (16#7FF8_0000_0000_0000#);
      else
         return Long_Float (Value);
      end if;
   end Convert_Nonfinite;

   package Nonfinite_Sparklines is new Flyology_TUI.Components.Sparklines
     (Samples => Number_Series, To_Long_Float => Convert_Nonfinite);

   package Progress_Groups is new Flyology_TUI.Components.Progress_Groups
     (Item_Id => Natural, Maximum_Items => 3);

   package Lifecycle_Groups is new Flyology_TUI.Components.Progress_Groups
     (Item_Id => Natural, Maximum_Items => 7);

   use type Flyology_TUI.Events.Mouse_Action;
   use type Flyology_TUI.Events.Mouse_Button;
   use type Flyology_TUI.Styles.Style;
   use type Lifecycle_Groups.Progress_Mode;
   use type Lifecycle_Groups.Work_State;
   use type Progress_Groups.Progress_Mode;
   use type Progress_Groups.Work_State;
   use type Sparklines.Scale_Mode;

   procedure Assert (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         raise Program_Error with Message;
      end if;
   end Assert;

   function Cell
     (Item : Flyology_TUI.Surfaces.Surface;
      X, Y : Natural) return Wide_Wide_String
   is (Text.To_Wide_Wide_String (Item.Element (X, Y).Glyph));

   function Row
     (Item : Flyology_TUI.Surfaces.Surface;
      Y    : Natural) return Wide_Wide_String
   is
      Result : Text.Unbounded_Wide_Wide_String;
   begin
      for X in 0 .. Item.Width - 1 loop
         declare
            Value : constant Wide_Wide_String := Cell (Item, X, Y);
         begin
            if Value'Length = 0 then
               Text.Append (Result, ' ');
            else
               Text.Append (Result, Value);
            end if;
         end;
      end loop;
      return Text.To_Wide_Wide_String (Result);
   end Row;

   procedure Expect_Capacity
     (Action : not null access procedure;
      Message : String)
   is
      Raised : Boolean := False;
   begin
      begin
         Action.all;
      exception
         when Flyology_TUI.Components.Capacity_Error =>
            Raised := True;
      end;
      Assert (Raised, Message);
   end Expect_Capacity;

   procedure Expect_Structure
     (Action : not null access procedure;
      Message : String)
   is
      Raised : Boolean := False;
   begin
      begin
         Action.all;
      exception
         when Flyology_TUI.Components.Structure_Error =>
            Raised := True;
      end;
      Assert (Raised, Message);
   end Expect_Structure;

   procedure Test_Series is
      Item : Number_Series.Series := Number_Series.Create (3);

      procedure Oversized is
         Discard : Number_Series.Series := Number_Series.Create (4);
         pragma Unreferenced (Discard);
      begin
         Discard := Number_Series.Create (5);
      end Oversized;
   begin
      Assert
        (Item.Capacity = 3 and then Item.Length = 0 and then Item.Is_Empty,
         "numeric series did not preserve requested capacity");
      Item.Append (1);
      Item.Append (2);
      Item.Append (3);
      Item.Append (4);
      Assert
        (Item.Length = 3
         and then Item.Element (1) = 2
         and then Item.Element (2) = 3
         and then Item.Element (3) = 4,
         "numeric series ring order was not oldest to newest after wrap");
      Expect_Capacity (Oversized'Access, "oversized series did not fail");
      Assert
        (Item.Length = 3 and then Item.Element (1) = 2,
         "unrelated capacity failure mutated a series");
      Item.Clear;
      Assert (Item.Is_Empty and then Item.Length = 0, "series clear failed");
   end Test_Series;

   procedure Test_Sparklines is
      Item : Number_Series.Series := Number_Series.Create;
      Empty : constant Flyology_TUI.Surfaces.Surface :=
        Sparklines.Render (Item, 3);
      Zero : constant Flyology_TUI.Surfaces.Surface :=
        Sparklines.Render (Item, 0, Theme => Flyology_TUI.Themes.Charm);

      procedure Reversed is
      begin
         declare
            Bad : constant Sparklines.Scale := Sparklines.Fixed (2.0, -2.0);
         begin
            Assert
              (Bad.Mode = Sparklines.Fixed_Range,
               "reversed test unexpectedly constructed an automatic scale");
         end;
      end Reversed;

      procedure Equal_Bounds is
      begin
         declare
            Bad : constant Sparklines.Scale := Sparklines.Fixed (1.0, 1.0);
         begin
            Assert
              (Bad.Mode = Sparklines.Fixed_Range,
               "equal-bounds test unexpectedly constructed an automatic scale");
         end;
      end Equal_Bounds;

      procedure Render_NaN is
         Values : Number_Series.Series := Number_Series.Create;
         Discard : Flyology_TUI.Surfaces.Surface;
      begin
         Values.Append (99);
         Discard := Nonfinite_Sparklines.Render (Values, 1);
      end Render_NaN;

      procedure Render_Infinity is
         Values : Number_Series.Series := Number_Series.Create;
         Discard : Flyology_TUI.Surfaces.Surface;
      begin
         Values.Append (98);
         Discard := Nonfinite_Sparklines.Render (Values, 1);
      end Render_Infinity;

      procedure Fixed_NaN is
         pragma Suppress (Validity_Check);
         Values : Number_Series.Series := Number_Series.Create;
         Bad : constant Sparklines.Scale :=
           (Mode    => Sparklines.Fixed_Range,
            Minimum => Decode (16#7FF8_0000_0000_0000#),
            Maximum => 1.0);
         Discard : Flyology_TUI.Surfaces.Surface;
      begin
         Values.Append (0);
         Discard := Sparklines.Render (Values, 1, Bad);
      end Fixed_NaN;

      procedure Fixed_Infinity is
         pragma Suppress (Validity_Check);
         Values : Number_Series.Series := Number_Series.Create;
         Bad : constant Sparklines.Scale :=
           (Mode    => Sparklines.Fixed_Range,
            Minimum => 0.0,
            Maximum => Decode (16#7FF0_0000_0000_0000#));
         Discard : Flyology_TUI.Surfaces.Surface;
      begin
         Values.Append (0);
         Discard := Sparklines.Render (Values, 1, Bad);
      end Fixed_Infinity;
   begin
      Assert
        (Sparklines.From_Theme (Flyology_TUI.Themes.Charm).High =
           Flyology_TUI.Themes.Charm.Success,
         "sparkline theme mapping changed");
      Assert
        (Empty.Width = 3 and then Empty.Height = 1 and then Row (Empty, 0) = "   ",
         "empty sparkline dimensions or cells were wrong");
      Assert
        (Zero.Width = 0 and then Zero.Height = 1,
         "zero-width sparkline was not legal");

      Item.Append (8);
      declare
         Singleton : constant Flyology_TUI.Surfaces.Surface :=
           Sparklines.Render (Item, 3);
      begin
         Assert (Row (Singleton, 0) = "▄  ", "singleton baseline changed");
      end;

      Item.Clear;
      Item.Append (4);
      Item.Append (4);
      Item.Append (4);
      Assert
        (Row (Sparklines.Render (Item, 3), 0) = "▄▄▄",
         "constant-series baseline was not the fourth bar");

      Item.Clear;
      Item.Append (-3);
      Item.Append (-2);
      Item.Append (-1);
      Assert
        (Row (Sparklines.Render (Item, 3), 0) = "▁▄█",
         "negative automatic scale mapped to the wrong bars");

      Item.Clear;
      Item.Append (-1);
      Item.Append (0);
      Item.Append (1);
      Assert
        (Row (Sparklines.Render (Item, 3), 0) = "▁▄█",
         "mixed-sign automatic scale mapped to the wrong bars");

      Item.Clear;
      Item.Append (0);
      Item.Append (5);
      Item.Append (10);
      Assert
        (Row
           (Sparklines.Render
              (Item, 3, Scaling => Sparklines.Fixed (0.0, 10.0)),
            0) = "▁▄█",
         "fixed sparkline scale mapped to the wrong bars");

      Item.Clear;
      Item.Append (1);
      Item.Append (2);
      Item.Append (3);
      Item.Append (4);
      Assert
        (Row (Sparklines.Render (Item, 2), 0) = "▁█",
         "sparkline did not select and rescale the newest visible suffix");

      Expect_Structure (Reversed'Access, "reversed scale was accepted");
      Expect_Structure (Equal_Bounds'Access, "equal fixed scale was accepted");
      Expect_Structure
        (Render_NaN'Access, "converted NaN reached sparkline indexing");
      Expect_Structure
        (Render_Infinity'Access,
         "converted infinity reached sparkline indexing");
      Expect_Structure
        (Fixed_NaN'Access, "NaN fixed bound was accepted");
      Expect_Structure
        (Fixed_Infinity'Access, "infinite fixed bound was accepted");
   end Test_Sparklines;

   procedure Test_Indicators is
      use Flyology_TUI.Components.Indicators;
      Empty_Segments : constant Segment_Array (1 .. 0) := (others => <>);
      Full : constant Segment_Array :=
        (Make_Segment ("L", Low),
         Make_Segment ("N", Normal),
         Make_Segment ("C", Critical));
      Tie : constant Segment_Array :=
        (Make_Segment ("A", Low),
         Make_Segment ("B", Low),
         Make_Segment ("C", Critical));
      High_Bound : constant
        Segment_Array (Positive'Last .. Positive'Last) :=
          (Positive'Last => Make_Segment ("H", Critical));

      procedure Too_Many is
         Values : Segment_Array (1 .. Maximum_Segments + 1);
         Discard : Flyology_TUI.Surfaces.Surface;
      begin
         for Index in Values'Range loop
            Values (Index) := Make_Segment ("x");
         end loop;
         Discard := Status_Line (Values, 1);
      end Too_Many;
   begin
      Assert
        (From_Theme (Flyology_TUI.Themes.Charm).Separator =
           Flyology_TUI.Themes.Charm.Border,
         "indicator theme mapping changed");
      Assert (Row (Badge ("OK"), 0) = "[OK]", "badge glyphs changed");
      declare
         Wide_Badge : constant Flyology_TUI.Surfaces.Surface := Badge ("界");
      begin
         Assert
           (Wide_Badge.Width = 4
            and then Cell (Wide_Badge, 1, 0) = "界"
            and then Wide_Badge.Element (2, 0).Continuation,
            "wide badge label did not preserve terminal cell geometry");
      end;
      Assert
        (Row (Badge ("+", Success_Tone, Flyology_TUI.Themes.Charm), 0) =
           "[+]",
         "themed badge output changed");
      Assert
        (Divider (0).Width = 0 and then Divider (0).Height = 1,
         "zero-width divider was not legal");
      Assert
        (Row (Divider (5, "x"), 0) = "─ x ─",
         "labeled divider output changed");
      Assert
        (Row (Divider (6, "界"), 0) = "─ 界  ─",
         "wide divider label alignment changed");
      Assert
        (Row (Divider (1, "wide"), 0) = " ",
         "tiny divider did not use deterministic right clipping");
      Assert
        (Row (Gauge (0.5, 5), 0) = "██░░░",
         "gauge fill output changed");
      Assert
        (Gauge (0.5, 0).Width = 0,
         "zero-width gauge was not legal");
      Assert
        (Row (Key_Value ("abc", "9", 5), 0) = "abc 9",
         "key/value alignment changed");
      Assert
        (Row (Key_Value ("abc", "long", 2), 0) = "lo",
         "key/value tiny-width value priority changed");
      Assert
        (Row (Key_Value ("界", "✓", 5), 0) = "界   ✓",
         "wide key/value cell alignment changed");
      Assert
        (Status_Line (Empty_Segments, 0).Width = 0,
         "empty status line was not legal");
      Assert
        (Row (Status_Line (Full, 9), 0) = "L │ N │ C",
         "full status line output changed");
      Assert
        (Row (Status_Line (Full, 5), 0) = "N │ C",
         "status line did not remove the lowest priority first");
      Assert
        (Row (Status_Line (Tie, 5), 0) = "A │ C",
         "status line tie did not remove the rightmost segment first");
      Assert
        (Row
           (Status_Line
              ((1 => Make_Segment ("critical", Critical)), 3),
            0) = "cri",
         "single status segment did not clip deterministically");
      Assert
        (Row (Status_Line (High_Bound, 1), 0) = "H",
         "high-bound singleton status segment overflowed its index");
      declare
         Wide_Status : constant Flyology_TUI.Surfaces.Surface :=
           Status_Line ((1 => Make_Segment ("界", Critical)), 2);
      begin
         Assert
           (Cell (Wide_Status, 0, 0) = "界"
            and then Wide_Status.Element (1, 0).Continuation,
            "wide status label did not preserve its continuation cell");
      end;
      Expect_Capacity
        (Too_Many'Access, "status line capacity overflow was accepted");
   end Test_Indicators;

   procedure Test_Progress_Groups is
      Item : Progress_Groups.Model := Progress_Groups.Create (9);
      Zero_Weight : Progress_Groups.Model := Progress_Groups.Create (3);
      Long_Phase : Progress_Groups.Model := Progress_Groups.Create (16);
      Lifecycle : Lifecycle_Groups.Model := Lifecycle_Groups.Create (12);

      function Key
        (Kind : Flyology_TUI.Events.Key_Kind)
         return Flyology_TUI.Events.Terminal_Event
      is
      begin
         case Kind is
            when Flyology_TUI.Events.Arrow_Up_Key =>
               return Flyology_TUI.Events.Pressed
                 ((Kind => Flyology_TUI.Events.Arrow_Up_Key, others => <>));
            when Flyology_TUI.Events.Enter_Key =>
               return Flyology_TUI.Events.Pressed
                 ((Kind => Flyology_TUI.Events.Enter_Key, others => <>));
            when others =>
               raise Program_Error with "unsupported test key";
         end case;
      end Key;

      procedure Add_Overflow is
      begin
         Item.Add_Determinate (40, "D");
      end Add_Overflow;

      procedure Add_Duplicate is
      begin
         Item.Add_Determinate (10, "duplicate");
      end Add_Duplicate;

      procedure Missing_Remove is
      begin
         Item.Remove (999);
      end Missing_Remove;

      procedure Missing_Select is
      begin
         Item.Select_Item (999);
      end Missing_Select;

      procedure Missing_Value is
      begin
         Item.Set_Value (999, 1.0);
      end Missing_Value;

      procedure Missing_Mode is
      begin
         Item.Set_Mode (999, Progress_Groups.Indeterminate);
      end Missing_Mode;

      procedure Missing_Work_State is
      begin
         Item.Set_Work_State (999, Progress_Groups.Failed);
      end Missing_Work_State;

      procedure Missing_Mode_Query is
         Discard : Progress_Groups.Progress_Mode;
      begin
         Discard := Item.Mode (999);
      end Missing_Mode_Query;

      procedure Missing_Work_Query is
         Discard : Progress_Groups.Work_State;
      begin
         Discard := Item.Work_Status (999);
      end Missing_Work_Query;

      Result : Flyology_TUI.Components.Interactions.Update_Result;
   begin
      Assert
        (Progress_Groups.From_Theme (Flyology_TUI.Themes.Charm).Complete =
           Flyology_TUI.Themes.Charm.Success,
         "progress group theme mapping changed");
      Zero_Weight.Add_Determinate (100, "zero", 0.0, 1.0);
      Assert
        (Zero_Weight.Weighted_Total = 0.0
         and then Row (Zero_Weight.Render_Segments (3), 0) = "   ",
         "zero-weight progress rows contributed to an aggregate");
      Assert
        (Item.Is_Empty
         and then Item.Length = 0
         and then Item.Render.Width = 9
         and then Item.Render.Height = 0
         and then Item.Weighted_Total = 0.0,
         "empty progress group state was wrong");

      Item.Add_Determinate (10, "A", 1.0, 0.25);
      Item.Add_Indeterminate (20, "B", 9.0);
      Item.Add_Determinate (30, "C", 3.0, 0.75);
      Assert
        (Item.Length = 3
         and then Item.Mode (10) = Progress_Groups.Determinate
         and then Item.Mode (20) = Progress_Groups.Indeterminate
         and then Item.Work_Status (20) = Progress_Groups.Running
         and then abs (Item.Weighted_Total - 0.625) < 0.000_001,
         "progress weighted total or states were wrong");
      Assert
        (Row (Item.Render, 0) = "›▶ A █░░░"
         and then Row (Item.Render, 1) = " ▶ B ▓░░░"
         and then Row (Item.Render, 2) = " ▶ C ███░",
         "progress group exact row output changed");
      Assert
        (Row (Item.Render_Segments (13), 0) = "░▓░░░░░░░░██░",
         "weighted segmented progress output changed");
      Assert
        (Item.Render_Segments (0).Width = 0,
         "zero-width segmented progress was not legal");

      Item.Advance;
      Assert
        (Row (Item.Render (Flyology_TUI.Themes.Charm), 1) =
           " ▶ B ░▓░░",
         "indeterminate advance did not move one phase");

      Long_Phase.Add_Indeterminate
        (101, "R", Work => Progress_Groups.Running);
      Long_Phase.Add_Indeterminate
        (102, "P", Work => Progress_Groups.Paused);
      Long_Phase.Add_Indeterminate
        (103, "N", Work => Progress_Groups.Pending);
      Long_Phase.Advance (5);
      Assert
        (Row (Long_Phase.Render, 0) = "›▶ R ░░░░░▓░░░░░"
         and then Row (Long_Phase.Render, 1) =
           " ‖ P ▓░░░░░░░░░░"
         and then Row (Long_Phase.Render, 2) =
           " ○ N ▓░░░░░░░░░░",
         "long indeterminate row did not traverse or freeze by work state");
      Assert
        (Row (Long_Phase.Render_Segments (18), 0) =
           "░░░░░▓▓░░░░░▓░░░░░",
         "long indeterminate segmented progress did not use full width");
      Long_Phase.Advance (Positive'Last);
      Assert
        (Row (Long_Phase.Render, 0) = "›▶ R ░░░░▓░░░░░░",
         "indeterminate phase overflow did not wrap safely");

      Lifecycle.Add_Determinate
        (1, "P", 1.0, 0.2, Lifecycle_Groups.Pending);
      Lifecycle.Add_Indeterminate
        (2, "PI", 1.0, Lifecycle_Groups.Pending);
      Lifecycle.Add_Indeterminate
        (3, "R", 1.0, Lifecycle_Groups.Running);
      Lifecycle.Add_Determinate
        (4, "Z", 1.0, 0.4, Lifecycle_Groups.Paused);
      Lifecycle.Add_Indeterminate
        (5, "S", 1.0, Lifecycle_Groups.Succeeded);
      Lifecycle.Add_Determinate
        (6, "F", 1.0, 0.6, Lifecycle_Groups.Failed);
      Lifecycle.Add_Determinate
        (7, "C", 1.0, 0.9, Lifecycle_Groups.Cancelled);
      Assert
        (Lifecycle.Work_Status (1) = Lifecycle_Groups.Pending
         and then Lifecycle.Work_Status (3) = Lifecycle_Groups.Running
         and then Lifecycle.Work_Status (4) = Lifecycle_Groups.Paused
         and then Lifecycle.Work_Status (5) = Lifecycle_Groups.Succeeded
         and then Lifecycle.Work_Status (6) = Lifecycle_Groups.Failed
         and then Lifecycle.Work_Status (7) = Lifecycle_Groups.Cancelled
         and then Lifecycle.Mode (5) = Lifecycle_Groups.Indeterminate,
         "progress lifecycle or measurement queries were not orthogonal");
      Assert
        (abs (Lifecycle.Weighted_Total - 0.44) < 0.000_001,
         "lifecycle weighted-total policy changed");
      declare
         Styled : constant Flyology_TUI.Surfaces.Surface :=
           Lifecycle.Render (Flyology_TUI.Themes.Charm);
         Theme_Appearance : constant Lifecycle_Groups.Appearance :=
           Lifecycle_Groups.From_Theme (Flyology_TUI.Themes.Charm);
      begin
         Assert
           (Cell (Styled, 1, 0) = "○"
            and then Cell (Styled, 1, 2) = "▶"
            and then Cell (Styled, 1, 3) = "‖"
            and then Cell (Styled, 1, 4) = "✓"
            and then Cell (Styled, 1, 5) = "✕"
            and then Cell (Styled, 1, 6) = "⊘"
            and then Styled.Element (1, 5).Appearance =
              Theme_Appearance.Failed_State,
            "work-state glyphs or lifecycle styles were not distinct");
      end;

      Expect_Capacity (Add_Overflow'Access, "progress capacity was exceeded");
      Assert
        (Item.Length = 3 and then Item.Selected_Id = 10,
         "capacity failure partially changed the progress group");
      Expect_Structure (Add_Duplicate'Access, "duplicate progress id accepted");

      Item.Select_Item (20);
      Item.Set_Value (10, 0.5);
      Assert
        (Item.Selected_Id = 20 and then Item.Value (10) = 0.5,
         "progress updates did not preserve selected identity");
      Item.Set_Mode (10, Progress_Groups.Indeterminate);
      Assert
        (Item.Mode (10) = Progress_Groups.Indeterminate,
         "progress determinate-to-indeterminate transition failed");
      Item.Set_Mode (10, Progress_Groups.Determinate);
      Item.Set_Work_State (10, Progress_Groups.Paused);
      Assert
        (Item.Work_Status (10) = Progress_Groups.Paused
         and then Item.Value (10) = 0.5,
         "progress work state changed its measurement value");
      Item.Set_Work_State (10, Progress_Groups.Running);

      Expect_Structure (Missing_Remove'Access, "missing remove id accepted");
      Expect_Structure (Missing_Select'Access, "missing select id accepted");
      Expect_Structure (Missing_Value'Access, "missing value id accepted");
      Expect_Structure (Missing_Mode'Access, "missing mode id accepted");
      Expect_Structure
        (Missing_Work_State'Access, "missing work-state id accepted");
      Expect_Structure
        (Missing_Mode_Query'Access, "missing mode query id accepted");
      Expect_Structure
        (Missing_Work_Query'Access, "missing work query id accepted");
      Assert
        (Item.Length = 3
         and then Item.Selected_Id = 20
         and then Item.Value (10) = 0.5
         and then Item.Mode (20) = Progress_Groups.Indeterminate
         and then Item.Work_Status (20) = Progress_Groups.Running,
         "missing-id failures partially changed progress state");

      Result := Item.Handle
        (Flyology_TUI.Mouse.Local_Event'
           (X        => 0,
            Y        => 2,
            Button   => Flyology_TUI.Events.Left_Button,
            Action   => Flyology_TUI.Events.Mouse_Click,
            Modified => (others => False),
            Wheel_X  => 0,
            Wheel_Y  => 0));
      Assert
        (Result.Handled and then Result.Focus_Requested and then Result.Changed
         and then Item.Selected_Id = 30,
         "progress mouse click did not select its row");

      Result := Item.Handle (Key (Flyology_TUI.Events.Arrow_Up_Key));
      Assert
        (Result.Handled and then Result.Changed and then Item.Selected_Id = 20,
         "progress keyboard selection failed");

      Result := Item.Handle
        (Flyology_TUI.Mouse.Local_Event'
           (X        => Integer'First,
            Y        => Integer'Last,
            Button   => Flyology_TUI.Events.No_Button,
            Action   => Flyology_TUI.Events.Mouse_Wheel,
            Modified => (others => False),
            Wheel_X  => 0,
            Wheel_Y  => Integer'First));
      Assert
        (not Result.Handled and then Item.Selected_Id = 20,
         "out-of-bounds extreme wheel event changed selection");

      Result := Item.Handle
        (Flyology_TUI.Mouse.Local_Event'
           (X        => 0,
            Y        => 0,
            Button   => Flyology_TUI.Events.No_Button,
            Action   => Flyology_TUI.Events.Mouse_Wheel,
            Modified => (others => False),
            Wheel_X  => 0,
            Wheel_Y  => Integer'First));
      Assert
        (Result.Handled and then Result.Changed and then Item.Selected_Id = 30,
         "in-bounds negative extreme wheel did not move by sign");

      Result := Item.Handle
        (Flyology_TUI.Mouse.Local_Event'
           (X        => 0,
            Y        => 0,
            Button   => Flyology_TUI.Events.No_Button,
            Action   => Flyology_TUI.Events.Mouse_Wheel,
            Modified => (others => False),
            Wheel_X  => 0,
            Wheel_Y  => Integer'Last));
      Assert
        (Result.Handled and then Result.Changed and then Item.Selected_Id = 20,
         "in-bounds positive extreme wheel did not move by sign");

      Result := Item.Handle (Key (Flyology_TUI.Events.Enter_Key));
      Assert
        (Result.Handled and then Result.Activated,
         "progress enter did not activate the selected row");

      Item.Select_Item (30);
      Item.Remove (10);
      Assert
        (Item.Length = 2 and then Item.Selected_Id = 30,
         "progress removal changed a different selected identity");
   end Test_Progress_Groups;

begin
   Test_Series;
   Test_Sparklines;
   Test_Indicators;
   Test_Progress_Groups;
   Ada.Text_IO.Put_Line ("visual component tests passed");
end Visual_Components_Tests;
