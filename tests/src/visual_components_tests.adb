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

   use type Flyology_TUI.Events.Mouse_Action;
   use type Flyology_TUI.Events.Mouse_Button;
   use type Flyology_TUI.Styles.Style;
   use type Progress_Groups.Progress_State;
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

      Expect_Structure (Reversed'Access, "reversed scale was accepted");
      Expect_Structure (Equal_Bounds'Access, "equal fixed scale was accepted");
      Expect_Structure
        (Render_NaN'Access, "converted NaN reached sparkline indexing");
      Expect_Structure
        (Render_Infinity'Access,
         "converted infinity reached sparkline indexing");
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
      Expect_Capacity
        (Too_Many'Access, "status line capacity overflow was accepted");
   end Test_Indicators;

   procedure Test_Progress_Groups is
      Item : Progress_Groups.Model := Progress_Groups.Create (8);
      Zero_Weight : Progress_Groups.Model := Progress_Groups.Create (3);

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
         and then Item.Render.Width = 8
         and then Item.Render.Height = 0
         and then Item.Weighted_Total = 0.0,
         "empty progress group state was wrong");

      Item.Add_Determinate (10, "A", 1.0, 0.25);
      Item.Add_Indeterminate (20, "B", 9.0);
      Item.Add_Determinate (30, "C", 3.0, 0.75);
      Assert
        (Item.Length = 3
         and then Item.State (10) = Progress_Groups.Determinate
         and then Item.State (20) = Progress_Groups.Indeterminate
         and then abs (Item.Weighted_Total - 0.625) < 0.000_001,
         "progress weighted total or states were wrong");
      Assert
        (Row (Item.Render, 0) = "› A █░░░"
         and then Row (Item.Render, 1) = "  B ▓░░░"
         and then Row (Item.Render, 2) = "  C ███░",
         "progress group exact row output changed");
      Assert
        (Row (Item.Render_Segments (13), 0) = "░▓░░░░░░░░██░",
         "weighted segmented progress output changed");
      Assert
        (Item.Render_Segments (0).Width = 0,
         "zero-width segmented progress was not legal");

      Item.Advance;
      Assert
        (Row (Item.Render (Flyology_TUI.Themes.Charm), 1) = "  B ░▓░░",
         "indeterminate advance did not move one phase");

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
      Item.Set_Indeterminate (10);
      Assert
        (Item.State (10) = Progress_Groups.Indeterminate,
         "progress determinate-to-indeterminate transition failed");

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
           (X        => -1,
            Y        => -1,
            Button   => Flyology_TUI.Events.No_Button,
            Action   => Flyology_TUI.Events.Mouse_Wheel,
            Modified => (others => False),
            Wheel_X  => 0,
            Wheel_Y  => -1));
      Assert
        (Result.Handled and then Result.Changed and then Item.Selected_Id = 30,
         "progress wheel selection failed");

      Result := Item.Handle (Key (Flyology_TUI.Events.Enter_Key));
      Assert
        (Result.Handled and then Result.Activated,
         "progress enter did not activate the selected row");

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
