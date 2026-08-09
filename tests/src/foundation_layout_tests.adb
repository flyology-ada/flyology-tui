with Ada.Strings.Wide_Wide_Unbounded;
with Ada.Text_IO;
with Flyology_TUI.Components;
with Flyology_TUI.Components.Interactions;
with Flyology_TUI.Events;
with Flyology_TUI.Geometry;
with Flyology_TUI.Layouts.Boxes;
with Flyology_TUI.Layouts.Layers;
with Flyology_TUI.Mouse;
with Flyology_TUI.Surfaces;

procedure Foundation_Layout_Tests is
   package Text renames Ada.Strings.Wide_Wide_Unbounded;
   use type Flyology_TUI.Components.Interactions.Capture_Action;
   use type Flyology_TUI.Events.Mouse_Action;
   use type Flyology_TUI.Events.Mouse_Button;
   use type Flyology_TUI.Geometry.Point;
   use type Flyology_TUI.Geometry.Rectangle;

   procedure Assert (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         raise Program_Error with Message;
      end if;
   end Assert;

   function Cell_Text
     (Item : Flyology_TUI.Surfaces.Surface;
      X, Y : Natural) return Wide_Wide_String
   is (Text.To_Wide_Wide_String (Item.Element (X, Y).Glyph));

   procedure Test_Geometry_And_Mouse is
      Edge : constant Flyology_TUI.Geometry.Rectangle :=
        (X      => Integer'Last - 1,
         Y      => -2,
         Width  => 10,
         Height => 3);
      Empty : constant Flyology_TUI.Geometry.Rectangle :=
        (X => 0, Y => 0, Width => 0, Height => 1);
      Mouse : constant Flyology_TUI.Events.Mouse_Event :=
        (X        => 2,
         Y        => 3,
         Button   => Flyology_TUI.Events.Left_Button,
         Action   => Flyology_TUI.Events.Mouse_Drag,
         Modified => (Shift => True, others => False),
         Wheel_X  => -1,
         Wheel_Y  => 2);
      Local : constant Flyology_TUI.Mouse.Local_Event :=
        Flyology_TUI.Mouse.Relative
          (Mouse, Flyology_TUI.Geometry.Point'(X => 5, Y => 7));
      Saturated : constant Flyology_TUI.Mouse.Local_Event :=
        Flyology_TUI.Mouse.Relative
          (Flyology_TUI.Events.Mouse_Event'
             (X => Natural'Last, Y => 0, others => <>),
           Flyology_TUI.Geometry.Point'(X => Integer'First, Y => 0));
      Negative_Saturated : constant Flyology_TUI.Mouse.Local_Event :=
        Flyology_TUI.Mouse.Relative
          (Flyology_TUI.Mouse.Local_Event'
             (X => Integer'First, Y => Integer'First, others => <>),
           Flyology_TUI.Geometry.Point'(X => 1, Y => Integer'Last));
   begin
      Assert
        (Flyology_TUI.Geometry.Contains
           (Edge, (X => Integer'Last, Y => 0)),
         "rectangle containment overflowed at Integer'Last");
      Assert
        (not Flyology_TUI.Geometry.Contains (Edge, Integer'Last - 2, 0),
         "rectangle accepted a point before its origin");
      Assert
        (not Flyology_TUI.Geometry.Contains (Empty, 0, 0),
         "zero-width rectangle contains a point");
      Assert
        (Local.X = -3 and then Local.Y = -4
         and then Local.Button = Flyology_TUI.Events.Left_Button
         and then Local.Action = Flyology_TUI.Events.Mouse_Drag
         and then Local.Modified.Shift
         and then Local.Wheel_X = -1 and then Local.Wheel_Y = 2,
         "signed mouse localization lost coordinates or payload");
      Assert
        (Saturated.X = Integer'Last,
         "signed mouse localization did not saturate overflow");
      Assert
        (Negative_Saturated.X = Integer'First
         and then Negative_Saturated.Y = Integer'First,
         "signed mouse relocalization did not saturate underflow");
   end Test_Geometry_And_Mouse;

   procedure Test_Clipped_Overlay is
      Target : Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.Create (3, 1);
      Source : Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.Create (3, 1);
      Wide_Source : Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.Create (2, 1);
   begin
      Target.Write (0, 0, "abc");
      Source.Write (0, 0, "XYZ");
      Target.Overlay_Clipped (Source, -1, 0);
      Assert
        (Cell_Text (Target, 0, 0) = "Y"
         and then Cell_Text (Target, 1, 0) = "Z"
         and then Cell_Text (Target, 2, 0) = "c",
         "signed overlay did not clip its left edge");

      Source.Clear;
      Source.Write (0, 0, " A ");
      Target.Clear;
      Target.Write (0, 0, "abc");
      Target.Overlay_Clipped (Source, 0, 0, Transparent_Spaces => True);
      Assert
        (Cell_Text (Target, 0, 0) = "a"
         and then Cell_Text (Target, 1, 0) = "A"
         and then Cell_Text (Target, 2, 0) = "c",
         "transparent clipped overlay painted spaces");

      Wide_Source.Put (0, 0, "界");
      Target.Clear;
      Target.Write (0, 0, "abc");
      Target.Overlay_Clipped (Wide_Source, -1, 0);
      Assert
        (Cell_Text (Target, 0, 0) = " "
         and then not Target.Element (0, 0).Continuation
         and then Cell_Text (Target, 1, 0) = "b",
         "left-clipped wide glyph left an orphan span");

      Target.Clear;
      Target.Write (0, 0, "abc");
      Target.Overlay_Clipped (Wide_Source, 2, 0);
      Assert
        (Cell_Text (Target, 2, 0) = " "
         and then not Target.Element (2, 0).Continuation,
         "right-clipped wide glyph left an orphan span");

      declare
         Vertical_Target : Flyology_TUI.Surfaces.Surface :=
           Flyology_TUI.Surfaces.From_Text
             ("ab" & Wide_Wide_Character'Val (10) & "cd");
         Vertical_Source : constant Flyology_TUI.Surfaces.Surface :=
           Flyology_TUI.Surfaces.From_Text
             ("12" & Wide_Wide_Character'Val (10) & "34");
      begin
         Vertical_Target.Overlay_Clipped (Vertical_Source, 0, -1);
         Assert
           (Cell_Text (Vertical_Target, 0, 0) = "3"
            and then Cell_Text (Vertical_Target, 1, 0) = "4"
            and then Cell_Text (Vertical_Target, 0, 1) = "c",
            "signed overlay did not clip its top edge");

         Vertical_Target := Flyology_TUI.Surfaces.From_Text
           ("ab" & Wide_Wide_Character'Val (10) & "cd");
         Vertical_Target.Overlay_Clipped (Vertical_Source, 0, 1);
         Assert
           (Cell_Text (Vertical_Target, 0, 0) = "a"
            and then Cell_Text (Vertical_Target, 0, 1) = "1"
            and then Cell_Text (Vertical_Target, 1, 1) = "2",
            "signed overlay did not clip its bottom edge");

         Vertical_Target := Flyology_TUI.Surfaces.From_Text
           ("ab" & Wide_Wide_Character'Val (10) & "cd");
         Vertical_Target.Overlay_Clipped
           (Vertical_Source, Integer'First, 0);
         Vertical_Target.Overlay_Clipped
           (Vertical_Source, Integer'Last, 0);
         Vertical_Target.Overlay_Clipped
           (Vertical_Source, 0, Integer'First);
         Vertical_Target.Overlay_Clipped
           (Vertical_Source, 0, Integer'Last);
         Assert
           (Cell_Text (Vertical_Target, 0, 0) = "a"
            and then Cell_Text (Vertical_Target, 1, 0) = "b"
            and then Cell_Text (Vertical_Target, 0, 1) = "c"
            and then Cell_Text (Vertical_Target, 1, 1) = "d",
            "extreme signed overlay origin changed the target");
      end;
   end Test_Clipped_Overlay;

   procedure Test_Boxes is
      use Flyology_TUI.Layouts.Boxes;
      Items : constant Surface_Array :=
        (Flyology_TUI.Surfaces.From_Text ("A"),
         Flyology_TUI.Surfaces.From_Text ("BBBB"),
         Flyology_TUI.Surfaces.From_Text ("C"));
      Rules : constant Constraint_Array :=
        (Content_Size, Fill_Size, Fixed_Size (2));
      Box : constant Layout_Result :=
        Horizontally (Items, Rules, Width => 10, Height => 1, Gap => 1);
      Rendered : constant Flyology_TUI.Surfaces.Surface := Box.Frame;
      First : constant Flyology_TUI.Geometry.Rectangle := Box.Region (1);
      Second : constant Flyology_TUI.Geometry.Rectangle := Box.Region (2);
      Third : constant Flyology_TUI.Geometry.Rectangle := Box.Region (3);
      Weighted : constant Layout_Result :=
        Horizontally
          ((Flyology_TUI.Surfaces.From_Text ("1"),
            Flyology_TUI.Surfaces.From_Text ("2")),
           (Fill_Size (1), Fill_Size (2)),
           Width => 5,
           Height => 1);
      Vertical_Box : constant Layout_Result :=
        Vertically
          ((Flyology_TUI.Surfaces.From_Text ("a"),
            Flyology_TUI.Surfaces.From_Text ("b")),
           (Fixed_Size (1), Fill_Size),
           Width => 2,
           Height => 4,
           Gap => 1);
      Horizontal_Center : constant Layout_Result :=
        Horizontally
          ((1 => Flyology_TUI.Surfaces.From_Text ("h")),
           (1 => Fixed_Size (3)),
           Width => 3,
           Height => 5,
           Alignment => Center);
      Horizontal_Start : constant Layout_Result :=
        Horizontally
          ((1 => Flyology_TUI.Surfaces.From_Text ("h")),
           (1 => Fixed_Size (3)),
           Width => 3,
           Height => 5,
           Alignment => Start);
      Horizontal_Stretch : constant Layout_Result :=
        Horizontally
          ((1 => Flyology_TUI.Surfaces.From_Text ("h")),
           (1 => Fixed_Size (3)),
           Width => 3,
           Height => 5,
           Alignment => Stretch);
      Horizontal_End : constant Layout_Result :=
        Horizontally
          ((1 => Flyology_TUI.Surfaces.From_Text ("h")),
           (1 => Fixed_Size (3)),
           Width => 3,
           Height => 5,
           Alignment => End_Aligned);
      Vertical_Center : constant Layout_Result :=
        Vertically
          ((1 => Flyology_TUI.Surfaces.From_Text ("v")),
           (1 => Fixed_Size (3)),
           Width => 5,
           Height => 3,
           Alignment => Center);
      Vertical_Start : constant Layout_Result :=
        Vertically
          ((1 => Flyology_TUI.Surfaces.From_Text ("v")),
           (1 => Fixed_Size (3)),
           Width => 5,
           Height => 3,
           Alignment => Start);
      Vertical_Stretch : constant Layout_Result :=
        Vertically
          ((1 => Flyology_TUI.Surfaces.From_Text ("v")),
           (1 => Fixed_Size (3)),
           Width => 5,
           Height => 3,
           Alignment => Stretch);
      Vertical_End : constant Layout_Result :=
        Vertically
          ((1 => Flyology_TUI.Surfaces.From_Text ("v")),
           (1 => Fixed_Size (3)),
           Width => 5,
           Height => 3,
           Alignment => End_Aligned);
      High_Items : constant Surface_Array (10 .. 11) :=
        (10 => Flyology_TUI.Surfaces.From_Text ("L"),
         11 => Flyology_TUI.Surfaces.From_Text ("R"));
      High_Rules : constant Constraint_Array (20 .. 21) :=
        (20 => Content_Size, 21 => Content_Size);
      High_Box : constant Layout_Result :=
        Horizontally
          (High_Items, High_Rules, Width => 4, Height => 1, Gap => 1);
      Last_Items : constant
        Surface_Array (Positive'Last .. Positive'Last) :=
          (Positive'Last => Flyology_TUI.Surfaces.From_Text ("Z"));
      Last_Rules : constant
        Constraint_Array (Positive'Last .. Positive'Last) :=
          (Positive'Last => Content_Size);
      Last_Box : constant Layout_Result :=
        Horizontally
          (Last_Items, Last_Rules, Width => 2, Height => 1);
      Empty_Items : constant Surface_Array (1 .. 0) := (others => <>);
      Empty_Rules : constant Constraint_Array (1 .. 0) := (others => <>);
      Empty_Box : constant Layout_Result :=
        Horizontally
          (Empty_Items, Empty_Rules, Width => 4, Height => 2, Gap => 1);
      Zero_Width : constant Layout_Result :=
        Horizontally
          ((1 => Flyology_TUI.Surfaces.From_Text ("x")),
           (1 => Fill_Size),
           Width => 0,
           Height => 1);
      Zero_Height : constant Layout_Result :=
        Vertically
          ((1 => Flyology_TUI.Surfaces.From_Text ("x")),
           (1 => Fill_Size),
           Width => 1,
           Height => 0);
      Oversized_Gap : constant Layout_Result :=
        Horizontally
          ((Flyology_TUI.Surfaces.From_Text ("1"),
            Flyology_TUI.Surfaces.From_Text ("2"),
            Flyology_TUI.Surfaces.From_Text ("3")),
           (Content_Size, Content_Size, Content_Size),
           Width => 2,
           Height => 1,
           Gap => 10);
      Trailing : constant Layout_Result :=
        Horizontally
          ((1 => Flyology_TUI.Surfaces.From_Text ("t")),
           (1 => Content_Size),
           Width => 4,
           Height => 1,
           Alignment => Start);
      Raised : Boolean := False;
   begin
      Assert
        (First = (X => 0, Y => 0, Width => 1, Height => 1)
         and then Second = (X => 2, Y => 0, Width => 5, Height => 1)
         and then Third = (X => 8, Y => 0, Width => 2, Height => 1),
         "box placements do not match deterministic allocation");
      Assert
        (Cell_Text (Rendered, 0, 0) = "A"
         and then Cell_Text (Rendered, 2, 0) = "B"
         and then Cell_Text (Rendered, 6, 0) = " "
         and then Cell_Text (Rendered, 8, 0) = "C",
         "box children painted outside their placement regions");
      Assert
        (Weighted.Region (1).Width = 1
         and then Weighted.Region (2).Width = 4,
         "weighted fill did not distribute its remainder deterministically");
      Assert
        (Vertical_Box.Region (1).Y = 0
         and then Vertical_Box.Region (1).Height = 1
         and then Vertical_Box.Region (2).Y = 2
         and then Vertical_Box.Region (2).Height = 2,
         "vertical box placement is incorrect");
      Assert
        (Horizontal_Center.Region (1) =
           (X => 0, Y => 2, Width => 3, Height => 1)
         and then Cell_Text (Horizontal_Center.Frame, 0, 2) = "h"
         and then Horizontal_End.Region (1).Y = 4
         and then Horizontal_Start.Region (1).Y = 0
         and then Horizontal_Start.Region (1).Height = 1
         and then Horizontal_Stretch.Region (1).Y = 0
         and then Horizontal_Stretch.Region (1).Height = 5,
         "horizontal box cross-axis alignment is incorrect");
      Assert
        (Vertical_Center.Region (1) =
           (X => 2, Y => 0, Width => 1, Height => 3)
         and then Cell_Text (Vertical_Center.Frame, 2, 0) = "v"
         and then Vertical_End.Region (1).X = 4
         and then Vertical_Start.Region (1).X = 0
         and then Vertical_Start.Region (1).Width = 1
         and then Vertical_Stretch.Region (1).X = 0
         and then Vertical_Stretch.Region (1).Width = 5,
         "vertical box cross-axis alignment is incorrect");
      Assert
        (High_Box.Region (1) = (X => 0, Y => 0, Width => 1, Height => 1)
         and then High_Box.Region (2) =
           (X => 2, Y => 0, Width => 1, Height => 1)
         and then Cell_Text (High_Box.Frame, 0, 0) = "L"
         and then Cell_Text (High_Box.Frame, 2, 0) = "R",
         "box indexing assumed one-based input arrays");
      Assert
        (Last_Box.Region (1) =
           (X => 0, Y => 0, Width => 1, Height => 1)
         and then Cell_Text (Last_Box.Frame, 0, 0) = "Z",
         "box indexing overflowed at Positive'Last lower bounds");
      Assert
        (Empty_Box.Item_Count = 0
         and then Empty_Box.Frame.Width = 4
         and then Empty_Box.Frame.Height = 2,
         "zero-child box did not preserve its requested frame");
      Assert
        (Zero_Width.Region (1).Width = 0
         and then Zero_Width.Frame.Width = 0
         and then Zero_Height.Region (1).Height = 0
         and then Zero_Height.Frame.Height = 0,
         "zero-axis box allocated a nonzero slot");
      Assert
        (Oversized_Gap.Region (1) =
           (X => 0, Y => 0, Width => 0, Height => 1)
         and then Oversized_Gap.Region (2).X = 1
         and then Oversized_Gap.Region (2).Width = 0
         and then Oversized_Gap.Region (3).X = 2
         and then Oversized_Gap.Region (3).Width = 0,
         "gap larger than the major axis escaped its frame");
      Assert
        (Trailing.Region (1).Width = 1
         and then Cell_Text (Trailing.Frame, 0, 0) = "t"
         and then Cell_Text (Trailing.Frame, 3, 0) = " ",
         "unused major-axis space is not trailing");

      begin
         declare
            Invalid : constant Layout_Result :=
              Horizontally
                (Items,
                 (1 => Content_Size),
                 Width => 3,
                 Height => 1);
         begin
            pragma Unreferenced (Invalid);
         end;
      exception
         when Flyology_TUI.Components.Structure_Error =>
            Raised := True;
      end;
      Assert (Raised, "box accepted mismatched items and constraints");
   end Test_Boxes;

   procedure Test_Layers is
      use Flyology_TUI.Layouts.Layers;
      Bottom : constant Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.From_Text ("abc");
      Top : constant Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.From_Text (" X ");
      Items : constant Layer_Array :=
        ((Content => Bottom, X => 0, Y => 0, Transparent_Spaces => False),
         (Content => Top, X => 0, Y => 0, Transparent_Spaces => True));
      Rendered : constant Flyology_TUI.Surfaces.Surface :=
        Compose (3, 1, Items);
      On_Bottom : constant Hit_Result :=
        Topmost_At (Items, (X => 0, Y => 0));
      On_Top : constant Hit_Result :=
        Topmost_At (Items, (X => 1, Y => 0));
      Shifted : constant Flyology_TUI.Surfaces.Surface :=
        Compose
          (2,
           1,
           (1 =>
              (Content => Flyology_TUI.Surfaces.From_Text ("AB"),
               X => -1,
               Y => 0,
               Transparent_Spaces => False)));
      Wide : Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.Create (2, 1);
   begin
      Assert
        (Cell_Text (Rendered, 0, 0) = "a"
         and then Cell_Text (Rendered, 1, 0) = "X"
         and then Cell_Text (Rendered, 2, 0) = "c",
         "layer composition did not honor transparent spaces");
      Assert
        (On_Bottom.Found and then On_Bottom.Index = 1
         and then On_Bottom.Local = (X => 0, Y => 0),
         "transparent top layer intercepted a bottom-layer hit");
      Assert
        (On_Top.Found and then On_Top.Index = 2
         and then On_Top.Local = (X => 1, Y => 0),
         "topmost layer hit did not return local coordinates");
      Assert
        (Cell_Text (Shifted, 0, 0) = "B",
         "signed layer origin was not clipped during composition");

      Wide.Put (0, 0, "界");
      declare
         Wide_Layers : constant Layer_Array :=
           (1 =>
              (Content => Wide,
               X => 0,
               Y => 0,
               Transparent_Spaces => True));
         Continuation_Hit : constant Hit_Result :=
           Topmost_At (Wide_Layers, (X => 1, Y => 0));
      begin
         Assert
           (Continuation_Hit.Found and then Continuation_Hit.Index = 1,
            "wide-glyph continuation was treated as transparent");
      end;
   end Test_Layers;

begin
   Assert
     (Flyology_TUI.Components.Interactions.Ignored.Capture =
        Flyology_TUI.Components.Interactions.No_Capture_Change
      and then not Flyology_TUI.Components.Interactions.Ignored.Rejected,
      "default update result changes pointer capture");
   Test_Geometry_And_Mouse;
   Test_Clipped_Overlay;
   Test_Boxes;
   Test_Layers;
   Ada.Text_IO.Put_Line ("foundation/layout tests passed");
end Foundation_Layout_Tests;
