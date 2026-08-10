with Ada.Strings.Wide_Wide_Unbounded;
with Ada.Text_IO;
with Flyology_TUI.Colors;
with Flyology_TUI.Components.Interactions;
with Flyology_TUI.Components.Scrollbars;
with Flyology_TUI.Components.Split_Panes;
with Flyology_TUI.Components.Windows;
with Flyology_TUI.Events;
with Flyology_TUI.Geometry;
with Flyology_TUI.Layouts.Boxes;
with Flyology_TUI.Mouse;
with Flyology_TUI.Styles;
with Flyology_TUI.Surfaces;
with Flyology_TUI.Themes;

procedure Window_Components_Tests is
   package Text renames Ada.Strings.Wide_Wide_Unbounded;
   use type Flyology_TUI.Components.Interactions.Capture_Action;
   use type Flyology_TUI.Colors.Color;
   use type Flyology_TUI.Geometry.Point;
   use type Flyology_TUI.Geometry.Rectangle;
   use type Flyology_TUI.Layouts.Boxes.Direction;
   use type Flyology_TUI.Styles.Style;

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
        Flyology_TUI.Events.Left_Button;
      Wheel_X : Integer := 0;
      Wheel_Y : Integer := 0) return Flyology_TUI.Mouse.Local_Event
   is
     (X        => X,
      Y        => Y,
      Button   => Button,
      Action   => Action,
      Modified => (others => False),
      Wheel_X  => Wheel_X,
      Wheel_Y  => Wheel_Y);

   function Key
     (Kind    : Flyology_TUI.Events.Key_Kind;
      Alt     : Boolean := False;
      Control : Boolean := False;
      Shift   : Boolean := False)
      return Flyology_TUI.Events.Terminal_Event
   is
      Value : Flyology_TUI.Events.Key_Event (Kind);
   begin
      Value.Modified :=
        (Shift => Shift, Control => Control, Alt => Alt, Super => False);
      return Flyology_TUI.Events.Pressed (Value);
   end Key;

   function Cell_Text
     (Item : Flyology_TUI.Surfaces.Surface;
      X, Y : Natural) return Wide_Wide_String
   is (Text.To_Wide_Wide_String (Item.Element (X, Y).Glyph));

   procedure Test_Window_Resize_Directions is
      Workspace : constant Flyology_TUI.Geometry.Rectangle :=
        (X => 0, Y => 0, Width => 40, Height => 30);

      procedure Verify
        (Name : String;
         Press_X, Press_Y, Drag_X, Drag_Y : Integer;
         Expected : Flyology_TUI.Geometry.Rectangle)
      is
         Window : Flyology_TUI.Components.Windows.Model :=
           Flyology_TUI.Components.Windows.Create
             (X => 2, Y => 2, Width => 10, Height => 8);
         Press_Result : constant
           Flyology_TUI.Components.Interactions.Update_Result :=
             Window.Handle
               (Pointer
                  (Press_X, Press_Y,
                   Flyology_TUI.Events.Mouse_Click),
                Workspace);
         Drag_Result : constant
           Flyology_TUI.Components.Interactions.Update_Result :=
             Window.Handle
               (Pointer
                  (Drag_X, Drag_Y,
                   Flyology_TUI.Events.Mouse_Drag),
                Workspace);
         Release_Result : constant
           Flyology_TUI.Components.Interactions.Update_Result :=
             Window.Handle
               (Pointer
                  (Drag_X, Drag_Y,
                   Flyology_TUI.Events.Mouse_Release),
                Workspace);
      begin
         Assert
           (Press_Result.Capture =
              Flyology_TUI.Components.Interactions.Acquire_Capture,
            Name & " did not acquire capture");
         Assert (Drag_Result.Changed, Name & " did not resize");
         Assert
           (Window.Bounds = Expected, Name & " produced wrong bounds");
         Assert
           (Release_Result.Capture =
              Flyology_TUI.Components.Interactions.Release_Capture,
            Name & " did not release capture");
      end Verify;
   begin
      Verify ("north", 3, 2, 3, 0, (2, 0, 10, 10));
      Verify ("south", 5, 9, 5, 12, (2, 2, 10, 11));
      Verify ("west", 2, 5, 0, 5, (0, 2, 12, 8));
      Verify ("east", 11, 5, 14, 5, (2, 2, 13, 8));
      Verify ("north-west", 2, 2, 0, 0, (0, 0, 12, 10));
      Verify ("north-east", 11, 2, 14, 0, (2, 0, 13, 10));
      Verify ("south-west", 2, 9, 0, 12, (0, 2, 12, 11));
      Verify ("south-east", 11, 9, 14, 12, (2, 2, 13, 11));
   end Test_Window_Resize_Directions;

   procedure Test_Window_Interaction is
      Workspace : constant Flyology_TUI.Geometry.Rectangle :=
        (X => 0, Y => 0, Width => 30, Height => 20);
      Window : Flyology_TUI.Components.Windows.Model :=
        Flyology_TUI.Components.Windows.Create
          (X => 2, Y => 2, Width => 10, Height => 8);
      Press_Result : Flyology_TUI.Components.Interactions.Update_Result;
      Drag_Result : Flyology_TUI.Components.Interactions.Update_Result;
      Release_Result : Flyology_TUI.Components.Interactions.Update_Result;
   begin
      Press_Result := Window.Handle
        (Pointer (5, 2, Flyology_TUI.Events.Mouse_Click), Workspace);
      Drag_Result := Window.Handle
        (Pointer (50, 50, Flyology_TUI.Events.Mouse_Drag), Workspace);
      Release_Result := Window.Handle
        (Pointer (50, 50, Flyology_TUI.Events.Mouse_Release), Workspace);
      Assert
        (Press_Result.Focus_Requested
         and then Press_Result.Capture =
           Flyology_TUI.Components.Interactions.Acquire_Capture
         and then Flyology_TUI.Components.Windows.Focused (Window),
         "window header did not request focus and capture");
      Assert
        (Drag_Result.Changed
         and then Window.Bounds = (20, 12, 10, 8),
         "captured window drag did not continue outside old bounds");
      Assert
        (Release_Result.Capture =
           Flyology_TUI.Components.Interactions.Release_Capture,
         "window drag did not release capture outside bounds");

      declare
         Client_Click : constant
           Flyology_TUI.Components.Interactions.Update_Result :=
             Window.Handle
               (Pointer (21, 13, Flyology_TUI.Events.Mouse_Click),
                Workspace);
      begin
         Assert
           (Client_Click.Handled and then Client_Click.Focus_Requested,
            "window client click did not request focus");
      end;

      Window := Flyology_TUI.Components.Windows.Create
        (X => 2, Y => 2, Width => 10, Height => 8);
      Press_Result := Window.Handle
        (Pointer (10, 2, Flyology_TUI.Events.Mouse_Click), Workspace);
      Release_Result := Window.Handle
        (Pointer (9, 2, Flyology_TUI.Events.Mouse_Release), Workspace);
      Assert
        (not Release_Result.Activated,
         "window close activated after release outside the control");
      Press_Result := Window.Handle
        (Pointer (10, 2, Flyology_TUI.Events.Mouse_Click), Workspace);
      Release_Result := Window.Handle
        (Pointer
           (10, 2, Flyology_TUI.Events.Mouse_Release,
            Button => Flyology_TUI.Events.Right_Button),
         Workspace);
      Assert
        (not Release_Result.Activated
         and then Release_Result.Capture =
           Flyology_TUI.Components.Interactions.No_Capture_Change,
         "window close consumed a mismatched release button");
      Release_Result := Window.Handle
        (Pointer (10, 2, Flyology_TUI.Events.Mouse_Release), Workspace);
      Assert
        (Release_Result.Activated
         and then Release_Result.Capture =
           Flyology_TUI.Components.Interactions.Release_Capture,
         "window close did not activate on matching release");

      Window := Flyology_TUI.Components.Windows.Create
        (X => 0, Y => 0, Width => 1, Height => 1,
         Minimum_Width => 1, Minimum_Height => 1,
         Movable => False, Resizable => False);
      Press_Result := Window.Handle
        (Pointer (0, 0, Flyology_TUI.Events.Mouse_Click), Workspace);
      Release_Result := Window.Handle
        (Pointer (0, 0, Flyology_TUI.Events.Mouse_Release), Workspace);
      Assert
        (Press_Result.Capture =
           Flyology_TUI.Components.Interactions.No_Capture_Change
         and then not Release_Result.Activated,
         "width-one window activated an invisible close control");
      declare
         Rendered : constant Flyology_TUI.Surfaces.Surface :=
           Window.Render
             ("", Flyology_TUI.Surfaces.Create (0, 0),
              (X => 0, Y => 0, Width => 1, Height => 1),
              Flyology_TUI.Themes.Default);
      begin
         Assert
           (Cell_Text (Rendered, 0, 0) /= "×",
            "width-one window rendered an interactive close glyph");
      end;

      Window := Flyology_TUI.Components.Windows.Create
        (X => 0, Y => 0, Width => 2, Height => 1,
         Minimum_Width => 1, Minimum_Height => 1,
         Movable => False, Resizable => False);
      Press_Result := Window.Handle
        (Pointer (0, 0, Flyology_TUI.Events.Mouse_Click), Workspace);
      Release_Result := Window.Handle
        (Pointer (0, 0, Flyology_TUI.Events.Mouse_Release), Workspace);
      Assert
        (Press_Result.Capture =
           Flyology_TUI.Components.Interactions.Acquire_Capture
         and then Release_Result.Activated,
         "visible width-two close control did not activate");
      declare
         Rendered : constant Flyology_TUI.Surfaces.Surface :=
           Window.Render
             ("", Flyology_TUI.Surfaces.Create (0, 0),
              (X => 0, Y => 0, Width => 2, Height => 1),
              Flyology_TUI.Themes.Default);
      begin
         Assert
           (Cell_Text (Rendered, 0, 0) = "×",
            "width-two window did not render its close hit target");
      end;
   end Test_Window_Interaction;

   procedure Test_Window_Clamping_And_Keyboard is
      Workspace : constant Flyology_TUI.Geometry.Rectangle :=
        (X => 0, Y => 0, Width => 30, Height => 20);
      Window : Flyology_TUI.Components.Windows.Model :=
        Flyology_TUI.Components.Windows.Create
          (X => 2, Y => 2, Width => 10, Height => 8,
           Minimum_Width => 4, Minimum_Height => 3);
      Result : Flyology_TUI.Components.Interactions.Update_Result;
   begin
      Result := Window.Handle
        (Pointer (11, 5, Flyology_TUI.Events.Mouse_Click), Workspace);
      Result := Window.Handle
        (Pointer (-100, 5, Flyology_TUI.Events.Mouse_Drag), Workspace);
      Assert
        (Result.Changed and then Window.Bounds.Width = 4,
         "window resize did not clamp to its minimum");
      Result := Window.Handle
        (Pointer (-100, 5, Flyology_TUI.Events.Mouse_Release), Workspace);

      Window := Flyology_TUI.Components.Windows.Create
        (X => 2, Y => 2, Width => 10, Height => 8);
      Result := Window.Handle
        (Key (Flyology_TUI.Events.Arrow_Right_Key,
              Alt => True, Shift => True),
         Workspace);
      Assert
        (Result.Changed and then Window.Bounds.X = 7,
         "shift-alt keyboard move did not use accelerated step");
      Result := Window.Handle
        (Key (Flyology_TUI.Events.Arrow_Down_Key, Control => True),
         Workspace);
      Assert
        (Result.Changed and then Window.Bounds.Height = 9,
         "control-arrow keyboard resize failed");

      Result := Window.Handle
        (Key (Flyology_TUI.Events.Arrow_Right_Key, Alt => True),
         (X => 0, Y => 0, Width => 3, Height => 2));
      Assert
        (Window.Bounds = (0, 0, 3, 2),
         "workspace smaller than minimum did not become effective minimum");

      Window := Flyology_TUI.Components.Windows.Create
        (X => -3, Y => -4, Width => 6, Height => 5);
      Result := Window.Handle
        (Key (Flyology_TUI.Events.Arrow_Left_Key, Alt => True),
         (X => 7, Y => 8, Width => 0, Height => 0));
      Assert
        (Window.Bounds = (7, 8, 6, 5),
         "empty workspace policy changed the window size");

      Window := Flyology_TUI.Components.Windows.Create
        (X => 0, Y => 0, Width => 2, Height => 1,
         Minimum_Width => 5, Minimum_Height => 4);
      Assert
        (Window.Bounds = (0, 0, 5, 4),
         "window creation did not honor a larger configured minimum");
   end Test_Window_Clamping_And_Keyboard;

   procedure Test_Window_Workspace_Constrain is
      Window : Flyology_TUI.Components.Windows.Model :=
        Flyology_TUI.Components.Windows.Create
          (X => 18, Y => 9, Width => 16, Height => 10,
           Minimum_Width => 8, Minimum_Height => 4);
      Result : Flyology_TUI.Components.Interactions.Update_Result;
   begin
      Window.Constrain_To ((X => 0, Y => 0, Width => 20, Height => 6));
      Assert
        (Window.Bounds = (4, 0, 16, 6),
         "workspace constrain did not keep the complete window reachable");

      Result := Window.Handle
        (Pointer (6, 0, Flyology_TUI.Events.Mouse_Click),
         (X => 0, Y => 0, Width => 20, Height => 6));
      Assert
        (Result.Capture =
           Flyology_TUI.Components.Interactions.Acquire_Capture,
         "window did not acquire capture before constrain interruption");
      Window.Constrain_To ((X => 0, Y => 0, Width => 10, Height => 5));
      Assert
        (Window.Bounds = (0, 0, 10, 5),
         "constrain did not adopt a workspace below the configured minimum");
      Result := Window.Handle
        (Pointer (100, 100, Flyology_TUI.Events.Mouse_Drag),
         (X => 0, Y => 0, Width => 10, Height => 5));
      Assert
        (not Result.Handled and then Window.Bounds = (0, 0, 10, 5),
         "constrain did not cancel the active semantic drag");
      Result := Window.Handle
        (Pointer (100, 100, Flyology_TUI.Events.Mouse_Release),
         (X => 0, Y => 0, Width => 10, Height => 5));
      Assert
        (Result.Capture =
           Flyology_TUI.Components.Interactions.Release_Capture,
         "constrain stranded existing capture ownership");

      Window.Constrain_To ((X => 7, Y => 8, Width => 0, Height => 0));
      Assert
        (Window.Bounds = (7, 8, 10, 5),
         "empty workspace constrain changed the retained window size");
   end Test_Window_Workspace_Constrain;

   procedure Test_Window_Render is
      Window : constant Flyology_TUI.Components.Windows.Model :=
        Flyology_TUI.Components.Windows.Create
          (X => -3, Y => 0, Width => 6, Height => 4);
      Content : constant Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.From_Text ("payload");
      Rendered : constant Flyology_TUI.Surfaces.Surface :=
        Window.Render
          ("界a title much wider than the frame",
           Content,
           (X => 0, Y => 0, Width => 5, Height => 3),
           Flyology_TUI.Themes.Charm);
      Origin : constant Flyology_TUI.Geometry.Point := Window.Client_Origin;
      Framed : constant Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Components.Windows.Render
          (Flyology_TUI.Components.Windows.Create
             (X => 0, Y => 0, Width => 6, Height => 4),
           "a title that is too wide",
           Flyology_TUI.Surfaces.From_Text ("XXXXXXXXXXXX"),
           (X => 0, Y => 0, Width => 6, Height => 4),
           Flyology_TUI.Themes.Default);
   begin
      Assert
        (Rendered.Width = 5 and then Rendered.Height = 3,
         "offscreen window render changed workspace dimensions");
      Assert
        (not Rendered.Element (0, 0).Continuation,
         "clipped wide title left an orphan continuation cell");
      Assert
        (Origin = (X => -2, Y => 1)
         and then Window.Client_Region.Width = 4
         and then Window.Client_Region.Height = 2,
         "window client geometry is incorrect");
      Assert
        (Cell_Text (Framed, 5, 2) = "│"
         and then Cell_Text (Framed, 3, 3) = "─"
         and then Cell_Text (Framed, 5, 0) = "┐",
         "external title or content overwrote the window frame");
   end Test_Window_Render;

   procedure Test_Window_Chrome_Theme_Mapping is
      Decorated : constant Flyology_TUI.Styles.Style :=
        (Foreground    =>
           Flyology_TUI.Colors.Basic (Flyology_TUI.Colors.Bright_Magenta),
         Background    =>
           Flyology_TUI.Colors.Basic (Flyology_TUI.Colors.Black),
         Bold          => True,
         Faint         => True,
         Italic        => True,
         Underline     => True,
         Blink         => True,
         Reverse_Video => True,
         Strikethrough => True);
      Theme : constant Flyology_TUI.Themes.Theme :=
        (Primary     => Flyology_TUI.Styles.Default,
         Muted       => Flyology_TUI.Styles.Default,
         Selected    => Flyology_TUI.Styles.Default,
         Focused     => Decorated,
         Border      => Decorated,
         Input       => Flyology_TUI.Styles.Default,
         Placeholder => Flyology_TUI.Styles.Default,
         Error       => Flyology_TUI.Styles.Default,
         Success     => Flyology_TUI.Styles.Default);
      Mapped : constant Flyology_TUI.Components.Windows.Appearance :=
        Flyology_TUI.Components.Windows.From_Theme (Theme);
      Window : Flyology_TUI.Components.Windows.Model :=
        Flyology_TUI.Components.Windows.Create
          (X => 0, Y => 0, Width => 8, Height => 4);
      Rendered : Flyology_TUI.Surfaces.Surface;
      Explicit : Flyology_TUI.Components.Windows.Appearance := Mapped;
   begin
      Assert
        (Mapped.Frame.Foreground = Decorated.Foreground
         and then Mapped.Frame.Background = Decorated.Background
         and then Mapped.Frame.Bold
         and then Mapped.Frame.Faint
         and then Mapped.Frame.Reverse_Video
         and then not Mapped.Frame.Italic
         and then not Mapped.Frame.Underline
         and then not Mapped.Frame.Blink
         and then not Mapped.Frame.Strikethrough,
         "window theme mapping leaked text decoration into frame chrome");
      Assert
        (Mapped.Focused_Frame = Mapped.Frame
         and then Mapped.Focused_Title = Decorated,
         "window theme mapping removed title emphasis or frame color");

      Window.Focus;
      Rendered := Window.Render
        ("focused", Flyology_TUI.Surfaces.Create (0, 0),
         (X => 0, Y => 0, Width => 8, Height => 4), Theme);
      Assert
        (not Rendered.Element (0, 1).Appearance.Underline
         and then Rendered.Element (2, 0).Appearance = Decorated,
         "focused theme render decorated the border or flattened the title");

      Explicit.Focused_Frame := Decorated;
      Rendered := Window.Render
        ("focused", Flyology_TUI.Surfaces.Create (0, 0),
         (X => 0, Y => 0, Width => 8, Height => 4), Explicit);
      Assert
        (Rendered.Element (0, 1).Appearance = Decorated,
         "explicit window appearance lost caller-controlled decoration");
   end Test_Window_Chrome_Theme_Mapping;

   procedure Test_Split_Panes is
      use Flyology_TUI.Components.Split_Panes;
      Split : Model :=
        Create
          (Flyology_TUI.Layouts.Boxes.Horizontal,
           Width => 10, Height => 3, First_Span => 4,
           First_Minimum => 2, Second_Minimum => 2);
      Result : Flyology_TUI.Components.Interactions.Update_Result;
      Rendered : Flyology_TUI.Surfaces.Surface;
   begin
      Assert
        (Split.First_Region = (0, 0, 4, 3)
         and then Split.Divider_Region = (4, 0, 1, 3)
         and then Split.Second_Region = (5, 0, 5, 3),
         "split pane initial geometry is incorrect");
      Result := Split.Handle
        (Pointer (4, 1, Flyology_TUI.Events.Mouse_Click));
      Assert
        (Result.Focus_Requested
         and then Result.Capture =
           Flyology_TUI.Components.Interactions.Acquire_Capture,
         "split divider did not acquire capture");
      Result := Split.Handle
        (Pointer (6, -10, Flyology_TUI.Events.Mouse_Drag));
      Assert
        (Result.Changed and then Split.First_Span = 6,
         "split divider drag did not change span");
      Result := Split.Handle
        (Pointer (100, -10, Flyology_TUI.Events.Mouse_Release));
      Assert
        (Result.Capture =
           Flyology_TUI.Components.Interactions.Release_Capture,
         "split divider did not release capture outside bounds");
      Result := Split.Handle
        (Key (Flyology_TUI.Events.Arrow_Left_Key, Shift => True));
      Assert
        (Result.Changed and then Split.First_Span = 2,
         "split keyboard resize did not clamp to minimum");

      Rendered := Split.Render
        (Flyology_TUI.Surfaces.From_Text ("AAAAAAAAAA"),
         Flyology_TUI.Surfaces.From_Text ("B"),
         Flyology_TUI.Themes.Charm);
      Assert
        (Cell_Text (Rendered, 0, 0) = "A"
         and then Cell_Text (Rendered, 2, 0) = "│"
         and then Cell_Text (Rendered, 3, 0) = "B",
         "split rendering ignored child or divider regions");

      Split := Create
        (Flyology_TUI.Layouts.Boxes.Horizontal,
         Width => 2, Height => 1, First_Span => 0,
         First_Minimum => 3, Second_Minimum => 3);
      Assert
        (Split.First_Span = 1
         and then Split.Second_Region.Width = 0,
         "tiny split did not apply deterministic minimum priority");
      Split.Resize (0, 0);
      Assert
        (Split.First_Region = (0, 0, 0, 0)
         and then Split.Divider_Region = (0, 0, 0, 0)
         and then Split.Second_Region = (0, 0, 0, 0),
         "empty split geometry is not empty");

      Split := Create
        (Flyology_TUI.Layouts.Boxes.Vertical,
         Width => 2, Height => 8, First_Span => 3,
         First_Minimum => 1, Second_Minimum => 1);
      Result := Split.Handle
        (Key (Flyology_TUI.Events.Arrow_Down_Key));
      Assert
        (Result.Changed and then Split.First_Span = 4,
         "vertical split keyboard parity failed");
      Result := Split.Handle
        (Pointer (0, 4, Flyology_TUI.Events.Mouse_Click));
      Result := Split.Handle
        (Pointer (0, 5, Flyology_TUI.Events.Mouse_Drag));
      Assert
        (Result.Changed and then Split.First_Span = 5,
         "vertical split mouse parity failed");
      Result := Split.Handle
        (Pointer (0, 5, Flyology_TUI.Events.Mouse_Release));
      Assert
        (Result.Capture =
           Flyology_TUI.Components.Interactions.Release_Capture,
         "vertical split mouse release did not end capture");
   end Test_Split_Panes;

   procedure Test_Scrollbars is
      use Flyology_TUI.Components.Scrollbars;
      Bar : Model :=
        Create (Flyology_TUI.Layouts.Boxes.Vertical, Length => 10);
      Result : Flyology_TUI.Components.Interactions.Update_Result;
      Rendered : Flyology_TUI.Surfaces.Surface;
   begin
      Bar.Configure (Total => 100, Page_Size => 20, First => 999);
      Assert
        (Bar.First = 80,
         "scrollbar Configure did not atomically clamp First");
      Bar.Configure (Total => 100, Page_Size => 20, First => 0);
      Assert
        (Bar.Region = (0, 0, 1, 10)
         and then Bar.Thumb_Region = (0, 1, 1, 1),
         "scrollbar initial regions are incorrect");

      Result := Bar.Handle
        (Pointer (0, 9, Flyology_TUI.Events.Mouse_Click));
      Assert
        (Result.Changed and then Bar.First = 1,
         "scrollbar forward arrow did not advance");
      Result := Bar.Handle
        (Pointer (0, 0, Flyology_TUI.Events.Mouse_Click));
      Assert
        (Result.Changed and then Bar.First = 0,
         "scrollbar backward arrow did not retreat");
      Bar.Configure (Total => 100, Page_Size => 20, First => 0);
      Result := Bar.Handle
        (Pointer (0, 5, Flyology_TUI.Events.Mouse_Click));
      Assert
        (Result.Changed and then Bar.First = 20,
         "scrollbar track click did not page forward");
      Bar.Configure (Total => 100, Page_Size => 20, First => 40);
      Result := Bar.Handle
        (Pointer
           (0, 5, Flyology_TUI.Events.Mouse_Wheel,
            Button => Flyology_TUI.Events.No_Button,
            Wheel_Y => 1));
      Assert
        (Result.Changed and then Bar.First = 39,
         "scrollbar wheel did not scroll backward");

      Bar.Configure (Total => 100, Page_Size => 20, First => 0);
      Result := Bar.Handle
        (Pointer (0, 1, Flyology_TUI.Events.Mouse_Click));
      Assert
        (Result.Capture =
           Flyology_TUI.Components.Interactions.Acquire_Capture,
         "scrollbar thumb did not acquire capture");
      Result := Bar.Handle
        (Pointer (0, 100, Flyology_TUI.Events.Mouse_Drag));
      Assert
        (Result.Changed and then Bar.First = 80,
         "scrollbar thumb drag did not clamp at maximum");
      Result := Bar.Handle
        (Pointer (-10, -10, Flyology_TUI.Events.Mouse_Release));
      Assert
        (Result.Capture =
           Flyology_TUI.Components.Interactions.Release_Capture,
         "scrollbar outside release did not release capture");

      Result := Bar.Handle (Key (Flyology_TUI.Events.Home_Key));
      Result := Bar.Handle (Key (Flyology_TUI.Events.Page_Down_Key));
      Assert
        (Bar.First = 20, "scrollbar keyboard page navigation failed");
      Result := Bar.Handle (Key (Flyology_TUI.Events.End_Key));
      Assert (Bar.First = 80, "scrollbar End key failed");

      Bar.Configure (Total => 10, Page_Size => 10, First => 9);
      Assert
        (Bar.First = 0 and then Bar.Thumb_Region.Height = 8,
         "non-scrollable scrollbar did not fill its track");
      Rendered := Bar.Render (Flyology_TUI.Themes.Charm);
      Assert
        (Rendered.Width = 1 and then Rendered.Height = 10
         and then Cell_Text (Rendered, 0, 0) = "▲"
         and then Cell_Text (Rendered, 0, 9) = "▼",
         "vertical scrollbar render is incorrect");

      Bar := Create (Flyology_TUI.Layouts.Boxes.Horizontal, Length => 1);
      Bar.Configure (Total => 0, Page_Size => 0, First => 20);
      Rendered := Bar.Render (Flyology_TUI.Themes.Default);
      Assert
        (Bar.First = 0
         and then Rendered.Width = 1 and then Rendered.Height = 1,
         "tiny empty scrollbar is incorrect");
      Bar.Resize (0);
      Rendered := Bar.Render (Flyology_TUI.Themes.Default);
      Assert
        (Rendered.Width = 0 and then Rendered.Height = 0
         and then Bar.Thumb_Region.Width = 0,
         "zero-length scrollbar is not empty");
   end Test_Scrollbars;

   procedure Test_Disabled_And_Interrupted_Capture is
      Workspace : constant Flyology_TUI.Geometry.Rectangle :=
        (X => 0, Y => 0, Width => 30, Height => 20);
      Disabled_Style : constant Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Emphasized (Flyology_TUI.Styles.Default);
      Window_Appearance : constant
        Flyology_TUI.Components.Windows.Appearance :=
          (Disabled => Disabled_Style, others => Flyology_TUI.Styles.Default);
      Split_Appearance : constant
        Flyology_TUI.Components.Split_Panes.Appearance :=
          (Disabled => Disabled_Style, others => Flyology_TUI.Styles.Default);
      Scroll_Appearance : constant
        Flyology_TUI.Components.Scrollbars.Appearance :=
          (Disabled => Disabled_Style, others => Flyology_TUI.Styles.Default);
      Window : Flyology_TUI.Components.Windows.Model :=
        Flyology_TUI.Components.Windows.Create
          (X => 2, Y => 2, Width => 10, Height => 8);
      Split : Flyology_TUI.Components.Split_Panes.Model :=
        Flyology_TUI.Components.Split_Panes.Create
          (Flyology_TUI.Layouts.Boxes.Horizontal,
           Width => 10, Height => 3, First_Span => 4,
           First_Minimum => 2, Second_Minimum => 2);
      Bar : Flyology_TUI.Components.Scrollbars.Model :=
        Flyology_TUI.Components.Scrollbars.Create
          (Flyology_TUI.Layouts.Boxes.Vertical, Length => 10);
      Result : Flyology_TUI.Components.Interactions.Update_Result;
      Before : Flyology_TUI.Geometry.Rectangle;
      First_Before : Natural;
      Rendered : Flyology_TUI.Surfaces.Surface;
   begin
      --  Disabling a captured move cancels movement but retains the release.
      Result := Window.Handle
        (Pointer (5, 2, Flyology_TUI.Events.Mouse_Click), Workspace);
      Assert
        (Result.Capture =
           Flyology_TUI.Components.Interactions.Acquire_Capture,
         "window move did not acquire capture before disable");
      Before := Window.Bounds;
      Window.Set_Enabled (False);
      Result := Window.Handle
        (Pointer (15, 10, Flyology_TUI.Events.Mouse_Drag), Workspace);
      Assert
        (not Result.Changed and then Window.Bounds = Before,
         "disabled captured window continued moving");
      Result := Window.Handle
        (Pointer (15, 10, Flyology_TUI.Events.Mouse_Release), Workspace);
      Assert
        (Result.Capture =
           Flyology_TUI.Components.Interactions.Release_Capture,
         "disabled moved window leaked capture");

      --  The same ownership rule applies to every resize handle.
      Window := Flyology_TUI.Components.Windows.Create
        (X => 2, Y => 2, Width => 10, Height => 8);
      Result := Window.Handle
        (Pointer (11, 5, Flyology_TUI.Events.Mouse_Click), Workspace);
      Before := Window.Bounds;
      Window.Set_Enabled (False);
      Result := Window.Handle
        (Pointer (20, 5, Flyology_TUI.Events.Mouse_Drag), Workspace);
      Assert
        (not Result.Changed and then Window.Bounds = Before,
         "disabled captured window continued resizing");
      Result := Window.Handle
        (Pointer (20, 5, Flyology_TUI.Events.Mouse_Release), Workspace);
      Assert
        (Result.Capture =
           Flyology_TUI.Components.Interactions.Release_Capture,
         "disabled resized window leaked capture");

      --  Close activation is cancelled, while capture still has to unwind.
      Window := Flyology_TUI.Components.Windows.Create
        (X => 2, Y => 2, Width => 10, Height => 8);
      Result := Window.Handle
        (Pointer (10, 2, Flyology_TUI.Events.Mouse_Click), Workspace);
      Window.Set_Enabled (False);
      Result := Window.Handle
        (Pointer (10, 2, Flyology_TUI.Events.Mouse_Release), Workspace);
      Assert
        (not Result.Activated
         and then Result.Capture =
           Flyology_TUI.Components.Interactions.Release_Capture,
         "disabled close activated or leaked capture");
      Assert
        (not Window.Is_Enabled,
         "window enabled query disagrees with disabled state");
      Result := Window.Handle
        (Key (Flyology_TUI.Events.Arrow_Right_Key, Alt => True), Workspace);
      Assert
        (not Result.Handled,
         "disabled window handled keyboard movement");
      Rendered := Window.Render
        ("disabled", Flyology_TUI.Surfaces.From_Text ("content"),
         Workspace, Window_Appearance);
      Assert
        (Rendered.Element (2, 2).Appearance = Disabled_Style,
         "explicit disabled window appearance was not rendered");
      Rendered := Window.Render
        ("disabled", Flyology_TUI.Surfaces.Create (0, 0),
         Workspace, Flyology_TUI.Themes.Charm);
      Assert
        (Rendered.Element (2, 2).Appearance = Flyology_TUI.Themes.Charm.Muted
         and then
           Flyology_TUI.Components.Windows.From_Theme
             (Flyology_TUI.Themes.Charm).Disabled =
               Flyology_TUI.Themes.Charm.Muted,
         "window theme did not map its disabled role");

      --  Split Resize cancels dragging, but not application capture ownership.
      Result := Split.Handle
        (Pointer (4, 1, Flyology_TUI.Events.Mouse_Click));
      Split.Resize (12, 3);
      Split.Set_Enabled (False);
      First_Before := Split.First_Span;
      Result := Split.Handle
        (Pointer (8, 1, Flyology_TUI.Events.Mouse_Drag));
      Assert
        (not Result.Changed and then Split.First_Span = First_Before,
         "disabled resized split continued dragging");
      Result := Split.Handle
        (Pointer (8, 1, Flyology_TUI.Events.Mouse_Release));
      Assert
        (Result.Capture =
           Flyology_TUI.Components.Interactions.Release_Capture
         and then not Split.Is_Enabled,
         "disabled resized split leaked capture");
      Result := Split.Handle
        (Key (Flyology_TUI.Events.Arrow_Right_Key));
      Assert
        (not Result.Handled and then Split.First_Span = First_Before,
         "disabled split handled keyboard resizing");
      Rendered := Split.Render
        (Flyology_TUI.Surfaces.Create (0, 0),
         Flyology_TUI.Surfaces.Create (0, 0), Split_Appearance);
      Assert
        (Rendered.Element
           (Natural (Split.Divider_Region.X), 0).Appearance = Disabled_Style,
         "explicit disabled split appearance was not rendered");
      Assert
        (Flyology_TUI.Components.Split_Panes.From_Theme
           (Flyology_TUI.Themes.Charm).Disabled =
             Flyology_TUI.Themes.Charm.Muted,
         "split theme did not map its disabled role");
      Rendered := Split.Render
        (Flyology_TUI.Surfaces.Create (0, 0),
         Flyology_TUI.Surfaces.Create (0, 0),
         Flyology_TUI.Themes.Charm);
      Assert
        (Rendered.Element
           (Natural (Split.Divider_Region.X), 0).Appearance =
             Flyology_TUI.Themes.Charm.Muted,
         "disabled split theme appearance was not rendered");

      --  Configure and Resize can invalidate the thumb, but a later release
      --  must still relinquish the capture acquired for it.
      Bar.Configure (Total => 100, Page_Size => 20, First => 0);
      Result := Bar.Handle
        (Pointer (0, 1, Flyology_TUI.Events.Mouse_Click));
      Assert
        (Result.Capture =
           Flyology_TUI.Components.Interactions.Acquire_Capture,
         "scrollbar thumb did not acquire capture before reconfigure");
      Bar.Configure (Total => 10, Page_Size => 10, First => 0);
      Bar.Resize (0);
      Bar.Set_Enabled (False);
      Result := Bar.Handle
        (Pointer (-10, -10, Flyology_TUI.Events.Mouse_Release));
      Assert
        (Result.Capture =
           Flyology_TUI.Components.Interactions.Release_Capture
         and then not Bar.Is_Enabled,
         "disabled reconfigured scrollbar leaked capture");
      Bar.Resize (5);
      Bar.Configure (Total => 20, Page_Size => 5, First => 0);
      Result := Bar.Handle
        (Pointer (0, 4, Flyology_TUI.Events.Mouse_Click));
      Assert
        (not Result.Handled and then Bar.First = 0,
         "disabled scrollbar changed through mouse input");
      Result := Bar.Handle (Key (Flyology_TUI.Events.Page_Down_Key));
      Assert
        (not Result.Handled and then Bar.First = 0,
         "disabled scrollbar changed through keyboard input");
      Rendered := Bar.Render (Scroll_Appearance);
      Assert
        (Rendered.Element (0, 0).Appearance = Disabled_Style,
         "explicit disabled scrollbar appearance was not rendered");
      Assert
        (Flyology_TUI.Components.Scrollbars.From_Theme
           (Flyology_TUI.Themes.Charm).Disabled =
             Flyology_TUI.Themes.Charm.Muted,
         "scrollbar theme did not map its disabled role");
      Rendered := Bar.Render (Flyology_TUI.Themes.Charm);
      Assert
        (Rendered.Element (0, 0).Appearance =
           Flyology_TUI.Themes.Charm.Muted,
         "disabled scrollbar theme appearance was not rendered");
   end Test_Disabled_And_Interrupted_Capture;

begin
   Test_Window_Resize_Directions;
   Test_Window_Interaction;
   Test_Window_Clamping_And_Keyboard;
   Test_Window_Workspace_Constrain;
   Test_Window_Render;
   Test_Window_Chrome_Theme_Mapping;
   Test_Split_Panes;
   Test_Scrollbars;
   Test_Disabled_And_Interrupted_Capture;
   Ada.Text_IO.Put_Line ("window component tests passed");
end Window_Components_Tests;
