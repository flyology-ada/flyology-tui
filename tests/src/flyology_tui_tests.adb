with Ada.Characters.Latin_1;
with Ada.Environment_Variables;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Strings.Wide_Wide_Unbounded;
with Interfaces.C;
with Flyology_TUI.Application_Events;
with Flyology_TUI.Backends;
with Flyology_TUI.Backends.Headless;
with Flyology_TUI.Backends.POSIX;
with Flyology_TUI.Color_Profiles;
with Flyology_TUI.Colors;
with Flyology_TUI.Components.Help;
with Flyology_TUI.Components.Lists;
with Flyology_TUI.Components.Forms;
with Flyology_TUI.Components.Progress;
with Flyology_TUI.Components.Spinners;
with Flyology_TUI.Components.Text_Inputs;
with Flyology_TUI.Components.Viewports;
with Flyology_TUI.Events;
with Flyology_TUI.Glyphs;
with Flyology_TUI.Input;
with Flyology_TUI.Layouts;
with Flyology_TUI.Mouse;
with Flyology_TUI.Programs;
with Flyology_TUI.Renderers;
with Flyology_TUI.Runners;
with Flyology_TUI.Styles;
with Flyology_TUI.Surfaces;
with Flyology_TUI.Themes;
with Flyology_TUI.Transitions;
with Flyology_TUI.Views;

procedure Flyology_TUI_Tests is
   package Bytes renames Ada.Strings.Unbounded;
   package Text renames Ada.Strings.Wide_Wide_Unbounded;

   use type Flyology_TUI.Events.Key_Kind;
   use type Flyology_TUI.Events.Mouse_Action;
   use type Flyology_TUI.Events.Mouse_Button;
   use type Flyology_TUI.Events.Terminal_Event_Kind;
   use type Flyology_TUI.Color_Profiles.Policy;
   use type Flyology_TUI.Color_Profiles.Profile;
   use type Flyology_TUI.Colors.Color;
   use type Flyology_TUI.Styles.Style;
   use type Interfaces.C.int;

   ESC : constant Character := Ada.Characters.Latin_1.ESC;

   function POSIX_Poll
     (Input_FD, Wake_FD, Timeout_MS : Interfaces.C.int)
      return Interfaces.C.int
     with Import, Convention => C, External_Name => "flyology_tui_poll";

   function Mouse_Input
     (X, Y      : Natural;
      Action    : Flyology_TUI.Events.Mouse_Action;
      Button    : Flyology_TUI.Events.Mouse_Button :=
        Flyology_TUI.Events.No_Button;
      Wheel_X   : Integer := 0;
      Wheel_Y   : Integer := 0;
      Modified  : Flyology_TUI.Events.Modifiers := (others => False))
      return Flyology_TUI.Events.Terminal_Event
   is
     ((Kind  => Flyology_TUI.Events.Mouse_Input,
       Mouse =>
         (X        => X,
          Y        => Y,
          Button   => Button,
          Action   => Action,
          Modified => Modified,
          Wheel_X  => Wheel_X,
          Wheel_Y  => Wheel_Y)));

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

   type Message is record
      Amount       : Integer := 0;
      Request_Save : Boolean := False;
   end record;

   type Command is record
      Saved_Value : Integer := 0;
   end record;

   type Model is limited record
      Count  : Integer := 0;
      Starts : Natural := 0;
   end record;

   package App_Events is new Flyology_TUI.Application_Events (Message);
   package App_Transitions is new Flyology_TUI.Transitions (Command);
   use type App_Events.Event_Kind;

   procedure Initialize
     (Item : in out Model;
      Next : in out App_Transitions.Transition)
   is
      pragma Unreferenced (Next);
   begin
      Item.Starts := Item.Starts + 1;
   end Initialize;

   procedure Update
     (Item  : in out Model;
      Event : App_Events.Event;
      Next  : in out App_Transitions.Transition)
   is
   begin
      case Event.Kind is
         when App_Events.Application_Message =>
            Item.Count := Item.Count + Event.Application.Amount;
            if Event.Application.Request_Save then
               App_Transitions.Run (Next, (Saved_Value => Item.Count));
            end if;
         when App_Events.Terminal_Input =>
            if Event.Terminal.Kind = Flyology_TUI.Events.Interrupt then
               App_Transitions.Quit (Next);
            end if;
      end case;
   end Update;

   function Present (Item : Model) return Flyology_TUI.Views.View is
   begin
      if Item.Count = 3 then
         return Flyology_TUI.Views.Plain ("3");
      else
         return Flyology_TUI.Views.Plain ("other");
      end if;
   end Present;

   package Counter is new Flyology_TUI.Programs
     (Events      => App_Events,
      Transitions => App_Transitions,
      Model_Type  => Model,
      Initialize  => Initialize,
      Update      => Update,
      Present     => Present);

   procedure Test_Program is
      State  : Model;
      Next   : App_Transitions.Transition;
      Screen : Flyology_TUI.Views.View;
   begin
      App_Transitions.Run (Next, (Saved_Value => -1));
      Counter.Start (State, Next);
      Assert (State.Starts = 1, "initialize was not called");
      Assert
        (not App_Transitions.Has_Command (Next),
         "start retained a stale command");

      Counter.Dispatch
        (State,
         App_Events.From_Message ((Amount => 3, Request_Save => False)),
         Next);
      Assert (State.Count = 3, "message did not update model");
      Screen := Counter.Current_View (State);
      Assert (Cell_Text (Screen.Frame, 0, 0) = "3", "view is stale");

      Counter.Dispatch
        (State,
         App_Events.From_Message ((Amount => 2, Request_Save => True)),
         Next);
      Assert (App_Transitions.Has_Command (Next), "command was not emitted");
      Assert
        (App_Transitions.Pending_Command (Next).Saved_Value = 5,
         "command did not capture updated state");
   end Test_Program;

   procedure Test_Glyphs_And_Surfaces is
      Combining : constant Wide_Wide_String :=
        (1 => 'e', 2 => Wide_Wide_Character'Val (16#0301#));
      Bee : constant Wide_Wide_String :=
        (1 => Wide_Wide_Character'Val (16#1F41D#));
      Surface : Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.Create (4, 2);
   begin
      Assert
        (Flyology_TUI.Glyphs.Width_Of (Combining) = 1,
         "combining sequence occupied more than one cell");
      Assert
        (Flyology_TUI.Glyphs.Width_Of (Bee) = 2,
         "wide emoji did not occupy two cells");
      Surface.Put (0, 0, Bee);
      Assert
        (Surface.Element (1, 0).Continuation,
         "wide glyph continuation was not recorded");
      Surface.Put (1, 0, "x");
      Assert (Cell_Text (Surface, 0, 0) = " ", "wide origin was not cleared");
      Assert (Cell_Text (Surface, 1, 0) = "x", "replacement cell was lost");
      Surface.Write (0, 1, Combining);
      Assert (Cell_Text (Surface, 0, 1) = Combining, "cluster was split");
   end Test_Glyphs_And_Surfaces;

   procedure Test_Layout_And_Renderer is
      Accent : constant Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.With_Foreground
          (Flyology_TUI.Styles.Default,
           Flyology_TUI.Colors.Basic (Flyology_TUI.Colors.Bright_Cyan));
      Content : constant Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.From_Text ("ok", Accent);
      Box : constant Flyology_TUI.Layouts.Block :=
        (Padding => (Top => 0, Right => 1, Bottom => 0, Left => 1),
         Border  => Flyology_TUI.Layouts.Rounded,
         others  => <>);
      Framed : Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Layouts.Render (Box, Content);
      Renderer : Flyology_TUI.Renderers.Renderer;
      Output : Bytes.Unbounded_String;
      View : Flyology_TUI.Views.View :=
        Flyology_TUI.Views.From_Surface (Framed);
   begin
      Assert (Framed.Width = 6 and then Framed.Height = 3,
              "block geometry is incorrect");
      Assert (Cell_Text (Framed, 0, 0) = "╭", "rounded border is missing");
      Renderer.Render (View, Output);
      Assert
        (Ada.Strings.Fixed.Index (Bytes.To_String (Output), "ok") /= 0,
         "initial frame did not contain content");
      Renderer.Render (View, Output);
      Assert (Bytes.Length (Output) = 0, "unchanged frame emitted bytes");
      View.Mouse := Flyology_TUI.Views.Button_Events;
      Renderer.Render (View, Output);
      Assert
        (Ada.Strings.Fixed.Index
           (Bytes.To_String (Output), ESC & "[?1000h") /= 0
         and then Ada.Strings.Fixed.Index
           (Bytes.To_String (Output), ESC & "[?1006h") /= 0,
         "button mouse mode was not enabled with SGR coordinates");
      Framed.Put (2, 1, "x");
      View.Frame := Framed;
      Renderer.Render (View, Output);
      Assert
        (Ada.Strings.Fixed.Index (Bytes.To_String (Output), "x") /= 0,
         "changed cell was not rendered");
      View.Cursor.Visible := True;
      View.Cursor.Shape := Flyology_TUI.Views.Cursor_Bar;
      Renderer.Render (View, Output);
      View.Alternate_Screen := True;
      Renderer.Render (View, Output);
      Assert
        (Ada.Strings.Fixed.Index (Bytes.To_String (Output), "x") /= 0,
         "alternate-screen transition did not repaint the frame");
      Renderer.Reset (Output);
      Assert
        (Bytes.Length (Output) > 0,
         "renderer reset emitted no restore bytes");
      Assert
        (Ada.Strings.Fixed.Index
           (Bytes.To_String (Output), ESC & "[0 q") /= 0,
         "renderer reset did not restore the default cursor shape");
      Assert
        (Ada.Strings.Fixed.Index
           (Bytes.To_String (Output), ESC & "[?1000l") /= 0,
         "renderer reset did not disable button mouse mode");
   end Test_Layout_And_Renderer;

   procedure Test_Color_Profiles is
      package Profiles renames Flyology_TUI.Color_Profiles;
      package Colors renames Flyology_TUI.Colors;

      function Has (Source, Pattern : String) return Boolean is
        (Ada.Strings.Fixed.Index (Source, Pattern) /= 0);

      function Rendered_Style
        (Profile    : Profiles.Profile;
         Foreground : Colors.Color;
         Background : Colors.Color := Colors.Default) return String
      is
         Appearance : Flyology_TUI.Styles.Style :=
           Flyology_TUI.Styles.Default;
         Surface  : Flyology_TUI.Surfaces.Surface;
         Renderer : Flyology_TUI.Renderers.Renderer;
         Output   : Bytes.Unbounded_String;
      begin
         Appearance.Foreground := Foreground;
         Appearance.Background := Background;
         Surface := Flyology_TUI.Surfaces.From_Text ("x", Appearance);
         Renderer.Set_Color_Profile (Profile);
         Renderer.Render (Flyology_TUI.Views.From_Surface (Surface), Output);
         return Bytes.To_String (Output);
      end Rendered_Style;

      Adapted : Colors.Color;
   begin
      Assert
        (Profiles.Detect (True, "truecolor", "xterm-256color") =
           Profiles.Monochrome,
         "NO_COLOR did not suppress detected color support");
      Assert
        (Profiles.Detect (False, "TRUECOLOR", "dumb") =
           Profiles.Truecolor,
         "COLORTERM truecolor was not detected case-insensitively");
      Assert
        (Profiles.Detect (False, "", "xterm-direct") =
           Profiles.Truecolor,
         "direct-color TERM was not detected");
      Assert
        (Profiles.Detect (False, "", "screen-256color") =
           Profiles.ANSI_256,
         "256-color TERM was not detected");
      Assert
        (Profiles.Detect (False, "", "xterm") = Profiles.ANSI_16,
         "ordinary TERM did not conservatively select ANSI16");
      Assert
        (Profiles.Detect (False, "", "") = Profiles.Monochrome
         and then Profiles.Detect (False, "", "dumb") =
           Profiles.Monochrome,
         "missing or dumb TERM did not select monochrome");
      Assert
        (Profiles.Resolve (Profiles.Automatic, Profiles.ANSI_256) =
           Profiles.ANSI_256
         and then
           Profiles.Resolve
             (Profiles.Force_Truecolor, Profiles.Monochrome) =
               Profiles.Truecolor,
         "explicit color policy did not take precedence over detection");

      Adapted := Profiles.Adapt
        (Colors.True_Color (64, 0, 0), Profiles.ANSI_16);
      Assert
        (Adapted = Colors.Basic (Colors.Black),
         "ANSI16 nearest-color ties did not choose the lower entry");
      Adapted := Profiles.Adapt
        (Colors.True_Color (255, 0, 0), Profiles.ANSI_256);
      Assert
        (Adapted = Colors.Palette (9),
         "ANSI256 duplicate-color ties did not choose the lower index");
      Adapted := Profiles.Adapt
        (Colors.True_Color (95, 0, 0), Profiles.ANSI_256);
      Assert
        (Adapted = Colors.Palette (52),
         "RGB color did not quantize to the nearest xterm palette entry");
      Assert
        (Profiles.Adapt (Colors.Palette (196), Profiles.ANSI_256) =
           Colors.Palette (196)
         and then
           Profiles.Adapt (Colors.Palette (196), Profiles.ANSI_16) =
             Colors.Basic (Colors.Bright_Red),
         "indexed color preservation or ANSI16 degradation is incorrect");
      Assert
        (Profiles.Adapt
           (Colors.Basic (Colors.Bright_Cyan), Profiles.ANSI_16) =
           Colors.Basic (Colors.Bright_Cyan),
         "ANSI source color was not preserved by ANSI terminals");
      Assert
        (Profiles.Adapt (Colors.True_Color (1, 2, 3), Profiles.Monochrome) =
           Colors.Default
         and then Profiles.Adapt (Colors.Default, Profiles.Truecolor) =
           Colors.Default,
         "monochrome or terminal-default color adaptation is incorrect");

      declare
         Monochrome : constant String :=
           Rendered_Style
             (Profiles.Monochrome,
              Colors.True_Color (255, 0, 0),
              Colors.Palette (25));
         ANSI16 : constant String :=
           Rendered_Style
             (Profiles.ANSI_16,
              Colors.True_Color (255, 0, 0),
              Colors.True_Color (0, 0, 255));
         ANSI256 : constant String :=
           Rendered_Style
             (Profiles.ANSI_256,
              Colors.True_Color (95, 0, 0),
              Colors.True_Color (0, 0, 255));
         Truecolor : constant String :=
           Rendered_Style
             (Profiles.Truecolor,
              Colors.True_Color (1, 2, 3),
              Colors.Palette (25));
      begin
         Assert
           (Has
              (Monochrome,
               ESC & "[0m" & ESC & "[39m" & ESC & "[49m"),
            "monochrome renderer did not emit exact default-color SGR");
         Assert
           (Has (ANSI16, ESC & "[0m" & ESC & "[91m" & ESC & "[104m"),
            "ANSI16 renderer did not emit exact foreground/background SGR");
         Assert
           (Has
              (ANSI256,
               ESC & "[0m" & ESC & "[38;5;52m" & ESC & "[48;5;12m"),
            "ANSI256 renderer did not emit exact indexed SGR");
         Assert
           (Has
              (Truecolor,
               ESC & "[0m" & ESC & "[38;2;1;2;3m" & ESC & "[48;5;25m"),
            "default truecolor renderer changed source color encoding");
      end;

      declare
         Appearance : constant Flyology_TUI.Styles.Style :=
           Flyology_TUI.Styles.With_Foreground
             (Flyology_TUI.Styles.Default,
              Colors.True_Color (255, 0, 0));
         Surface : constant Flyology_TUI.Surfaces.Surface :=
           Flyology_TUI.Surfaces.From_Text ("x", Appearance);
         View : constant Flyology_TUI.Views.View :=
           Flyology_TUI.Views.From_Surface (Surface);
         Renderer : Flyology_TUI.Renderers.Renderer;
         Explicit : Flyology_TUI.Renderers.Renderer;
         Output : Bytes.Unbounded_String;
         Explicit_Output : Bytes.Unbounded_String;
      begin
         Assert
           (Renderer.Color_Profile = Profiles.Truecolor,
            "renderer default profile is not source-compatible truecolor");
         Renderer.Render (View, Output);
         Explicit.Set_Color_Profile (Profiles.Truecolor);
         Explicit.Render (View, Explicit_Output);
         Assert
           (Bytes.To_String (Output) = Bytes.To_String (Explicit_Output),
            "default renderer bytes differ from explicit truecolor output");
         Renderer.Render (View, Output);
         Assert (Bytes.Length (Output) = 0, "unchanged color frame redrew");
         Renderer.Set_Color_Profile (Profiles.ANSI_16);
         Renderer.Render (View, Output);
         Assert
           (Has (Bytes.To_String (Output), ESC & "[2J")
            and then Has (Bytes.To_String (Output), ESC & "[91m")
            and then Has (Bytes.To_String (Output), "x"),
            "profile change did not invalidate and repaint the frame");
         Renderer.Render (View, Output);
         Assert
           (Bytes.Length (Output) = 0,
            "profile repaint did not restore frame diffing");
      end;

      declare
         Backend : Flyology_TUI.Backends.POSIX.POSIX_Backend;
         Raised  : Boolean := False;
      begin
         Assert
           (Backend.Color_Policy = Profiles.Automatic,
            "POSIX backend color policy is not automatic by default");
         Backend.Set_Color_Policy (Profiles.Force_ANSI_256);
         Assert
           (Backend.Color_Policy = Profiles.Force_ANSI_256,
            "POSIX backend did not retain a pre-open color override");
         begin
            declare
               Unavailable : constant Profiles.Profile :=
                 Backend.Color_Profile;
               pragma Unreferenced (Unavailable);
            begin
               null;
            end;
         exception
            when Flyology_TUI.Backends.Backend_Error =>
               Raised := True;
         end;
         Assert
           (Raised,
            "POSIX backend exposed an unresolved profile before Open");
      end;

      declare
         Backend : Flyology_TUI.Backends.Headless.Headless_Backend;
         Raised  : Boolean := False;
      begin
         begin
            Backend.Render (Flyology_TUI.Views.Plain ("x"));
         exception
            when Flyology_TUI.Backends.Backend_Error =>
               Raised := True;
         end;
         Assert (Raised, "backend accepted rendering outside its lifecycle");
      end;
   end Test_Color_Profiles;

   procedure Test_POSIX_Color_Lifecycle is
      package Profiles renames Flyology_TUI.Color_Profiles;
      Backend : Flyology_TUI.Backends.POSIX.POSIX_Backend;
      Raised  : Boolean := False;
   begin
      --  This branch is run explicitly under a pseudo-terminal. The ordinary
      --  pipe-based suite cannot open a real POSIX terminal backend.
      if not Ada.Environment_Variables.Exists
        ("FLYOLOGY_TUI_TEST_POSIX_COLOR_LIFECYCLE")
      then
         return;
      end if;

      Backend.Set_Color_Policy (Profiles.Force_Truecolor);
      Backend.Open;
      begin
         Assert
           (Backend.Color_Profile = Profiles.Truecolor,
            "POSIX explicit profile did not override environment detection");
         begin
            Backend.Set_Color_Policy (Profiles.Force_ANSI_16);
         exception
            when Flyology_TUI.Backends.Backend_Error =>
               Raised := True;
         end;
         Assert
           (Raised,
            "POSIX backend accepted color configuration after Open");
      exception
         when others =>
            Backend.Close;
            raise;
      end;
      Backend.Close;
   end Test_POSIX_Color_Lifecycle;

   procedure Test_Input is
      Parser : Flyology_TUI.Input.Parser;
      Event : Flyology_TUI.Events.Terminal_Event;
      Available : Boolean;
   begin
      Parser.Feed (ESC & "[");
      Assert (not Parser.Has_Event, "partial CSI was emitted early");
      Parser.Feed ("A");
      Parser.Next_Event (Event, Available);
      Assert
        (Available and then Event.Kind = Flyology_TUI.Events.Key_Press
         and then Event.Key.Kind = Flyology_TUI.Events.Arrow_Up_Key,
         "split arrow sequence was not parsed");

      Parser.Feed (ESC & "[200~hello");
      Assert (not Parser.Has_Event, "paste was emitted before its terminator");
      Parser.Feed (" world" & ESC & "[201~");
      Parser.Next_Event (Event, Available);
      Assert
        (Available and then Event.Kind = Flyology_TUI.Events.Paste
         and then Text.To_Wide_Wide_String (Event.Pasted_Text) = "hello world",
         "bracketed paste was not reassembled");

      Parser.Feed (ESC & "[<64;3;4M");
      Parser.Next_Event (Event, Available);
      Assert
        (Available and then Event.Kind = Flyology_TUI.Events.Mouse_Input
         and then Event.Mouse.Action = Flyology_TUI.Events.Mouse_Wheel
         and then Event.Mouse.X = 2 and then Event.Mouse.Y = 3,
         "SGR mouse event was not parsed");

      Parser.Feed (ESC & "[<128;5;6M");
      Parser.Next_Event (Event, Available);
      Assert
        (Available and then Event.Kind = Flyology_TUI.Events.Mouse_Input
         and then Event.Mouse.Action = Flyology_TUI.Events.Mouse_Click
         and then Event.Mouse.Button =
           Flyology_TUI.Events.Auxiliary_Button_1
         and then Event.Mouse.X = 4 and then Event.Mouse.Y = 5,
         "SGR auxiliary mouse button was not parsed");

      Parser.Feed (ESC & "");
      Parser.Flush_Escape;
      Parser.Next_Event (Event, Available);
      Assert
        (Available and then Event.Key.Kind = Flyology_TUI.Events.Escape_Key,
         "escape timeout did not resolve escape key");

      Parser.Feed (ESC & "[");
      Parser.Flush_Escape;
      Parser.Next_Event (Event, Available);
      Assert
        (Available and then Event.Key.Kind = Flyology_TUI.Events.Escape_Key,
         "escape timeout did not resolve an incomplete CSI prefix");
      Parser.Next_Event (Event, Available);
      Assert
        (Available and then Event.Key.Kind = Flyology_TUI.Events.Text_Key
         and then Text.To_Wide_Wide_String (Event.Key.Value) = "[",
         "escape timeout swallowed an incomplete CSI suffix");

      Parser.Feed (ESC & "[Z");
      Parser.Next_Event (Event, Available);
      Assert
        (Available and then Event.Key.Kind = Flyology_TUI.Events.Tab_Key
         and then Event.Key.Modified.Shift,
         "shift-tab was not decoded from CSI Z");

      declare
         Limited_Parser : Flyology_TUI.Input.Parser;
      begin
         Limited_Parser.Initialize
           (Max_Pending_Bytes => 8, Max_Queued_Events => 2);
         begin
            Limited_Parser.Feed (ESC & "[1234567");
            Assert (False, "oversized pending input was accepted");
         exception
            when Flyology_TUI.Input.Input_Error => null;
         end;
         Assert
           (not Limited_Parser.Has_Event,
            "rejected pending input changed the event queue");

         Limited_Parser.Feed ("ab");
         begin
            Limited_Parser.Feed ("c");
            Assert (False, "event queue grew beyond its bound");
         exception
            when Flyology_TUI.Input.Input_Error => null;
         end;
         Limited_Parser.Next_Event (Event, Available);
         Assert (Available, "bounded event queue lost its first event");
         Limited_Parser.Next_Event (Event, Available);
         Assert (Available, "bounded event queue lost its second event");
         Assert
           (not Limited_Parser.Has_Event,
            "bounded event queue retained more than its capacity");
      end;
   end Test_Input;

   procedure Test_Mouse is
      Area : constant Flyology_TUI.Mouse.Region :=
        (X => 10, Y => 5, Width => 4, Height => 3);
      Event : constant Flyology_TUI.Events.Terminal_Event :=
        Mouse_Input
          (11, 7,
           Flyology_TUI.Events.Mouse_Drag,
           Flyology_TUI.Events.Left_Button,
           Modified => (Shift => True, others => False));
      Local : Flyology_TUI.Events.Terminal_Event;
   begin
      Assert
        (Flyology_TUI.Mouse.Contains (Area, Event.Mouse),
         "mouse region rejected an interior point");
      Assert
        (not Flyology_TUI.Mouse.Contains (Area, 14, 7),
         "mouse region included its right edge");
      Local := Flyology_TUI.Mouse.Localize (Event, Area);
      Assert
        (Local.Mouse.X = 1 and then Local.Mouse.Y = 2
         and then Local.Mouse.Action = Flyology_TUI.Events.Mouse_Drag
         and then Local.Mouse.Modified.Shift,
         "mouse localization changed event state");
   end Test_Mouse;

   procedure Test_POSIX_Poll is
   begin
      Assert
        (POSIX_Poll (999_998, 999_999, 0) < 0,
         "poll descriptor errors were reported as timeouts");
   end Test_POSIX_Poll;

   function Integer_Label (Item : Integer) return Wide_Wide_String is
      Image : constant String := Ada.Strings.Fixed.Trim
        (Integer'Image (Item), Ada.Strings.Both);
      Result : Wide_Wide_String (1 .. Image'Length);
   begin
      for Index in Image'Range loop
         Result (Index - Image'First + 1) :=
           Wide_Wide_Character'Val (Character'Pos (Image (Index)));
      end loop;
      return Result;
   end Integer_Label;

   package Integer_Lists is new Flyology_TUI.Components.Lists
     (Item_Type => Integer,
      Label     => Integer_Label);

   procedure Test_Components is
      Input : Flyology_TUI.Components.Text_Inputs.Model :=
        Flyology_TUI.Components.Text_Inputs.Create (10, "type");
      Parsed : Flyology_TUI.Input.Parser;
      Event : Flyology_TUI.Events.Terminal_Event;
      Available : Boolean;
      Progress : Flyology_TUI.Components.Progress.Model :=
        Flyology_TUI.Components.Progress.Create (10, False);
      Spinner : Flyology_TUI.Components.Spinners.Model;
      List : Integer_Lists.Model := Integer_Lists.Create (8, 3);
      Viewport : Flyology_TUI.Components.Viewports.Model :=
        Flyology_TUI.Components.Viewports.Create (2, 1);
      Form : Flyology_TUI.Components.Forms.Model :=
        Flyology_TUI.Components.Forms.Create
          (Flyology_TUI.Components.Forms.Field_Array'
             (1 =>
                (Label       => Text.To_Unbounded_Wide_Wide_String ("Name"),
                 Initial     => Text.Null_Unbounded_Wide_Wide_String,
                 Placeholder =>
                   Text.To_Unbounded_Wide_Wide_String ("name"))),
           Input_Width => 8);
      Mouse_Form : Flyology_TUI.Components.Forms.Model :=
        Flyology_TUI.Components.Forms.Create
          (Flyology_TUI.Components.Forms.Field_Array'
             (1 =>
                (Label       => Text.To_Unbounded_Wide_Wide_String ("One"),
                 Initial     => Text.Null_Unbounded_Wide_Wide_String,
                 Placeholder => Text.Null_Unbounded_Wide_Wide_String),
              2 =>
                (Label       => Text.To_Unbounded_Wide_Wide_String ("Two"),
                 Initial     => Text.Null_Unbounded_Wide_Wide_String,
                 Placeholder => Text.Null_Unbounded_Wide_Wide_String)),
           Input_Width => 8);
   begin
      Input.Focus;
      Parsed.Feed ("abc");
      while Parsed.Has_Event loop
         Parsed.Next_Event (Event, Available);
         Input.Update (Event);
      end loop;
      Assert (Input.Value = "abc", "text input rejected printable keys");
      Input.Update
        (Mouse_Input
           (0, 0,
            Flyology_TUI.Events.Mouse_Click,
            Flyology_TUI.Events.Left_Button));
      Input.Update
        (Flyology_TUI.Events.Pressed
           ((Kind     => Flyology_TUI.Events.Text_Key,
             Modified => (others => False),
             Repeated => False,
             Value    => Text.To_Unbounded_Wide_Wide_String ("z"))));
      Assert (Input.Value = "zabc", "mouse click did not place text cursor");
      Flyology_TUI.Components.Progress.Set (Progress, 0.5);
      Assert (Progress.Render.Width = 10, "progress width changed");
      Spinner.Tick;
      Assert (Spinner.Render.Width = 1, "spinner width is not stable");
      List.Set_Items ((1, 2, 3));
      List.Update
        (Flyology_TUI.Events.Pressed
           ((Kind     => Flyology_TUI.Events.Arrow_Down_Key,
             Modified => (others => False),
             Repeated => False)));
      Assert (List.Selected_Index = 1, "list selection did not move");
      List.Update
        (Mouse_Input
           (0, 2,
            Flyology_TUI.Events.Mouse_Click,
            Flyology_TUI.Events.Left_Button));
      Assert (List.Selected_Index = 2, "mouse click did not select list row");
      List.Update
        (Mouse_Input
           (0, 2, Flyology_TUI.Events.Mouse_Wheel, Wheel_Y => 1));
      Assert
        (List.Selected_Index = 1,
         "mouse wheel did not move list selection");
      Viewport.Set_Content (Flyology_TUI.Surfaces.From_Text ("abcd"));
      Viewport.Scroll (1, 0);
      Assert
        (Cell_Text (Viewport.Render, 0, 0) = "b",
         "viewport did not apply horizontal offset");
      Viewport.Set_Content
        (Flyology_TUI.Surfaces.From_Text
           ("a" & Wide_Wide_Character'Val (10)
            & "b" & Wide_Wide_Character'Val (10)
            & "c" & Wide_Wide_Character'Val (10) & "d"));
      Viewport.Update
        (Mouse_Input
           (0, 0, Flyology_TUI.Events.Mouse_Wheel, Wheel_Y => -1));
      Assert (Viewport.Y_Offset = 3, "mouse wheel did not scroll viewport");
      Form.Update
        (Flyology_TUI.Events.Pressed
           ((Kind     => Flyology_TUI.Events.Enter_Key,
             Modified => (others => False),
             Repeated => False)));
      Assert (Form.Submitted, "single-field form did not submit");
      Mouse_Form.Update
        (Mouse_Input
           (5, 1,
            Flyology_TUI.Events.Mouse_Click,
            Flyology_TUI.Events.Left_Button));
      Mouse_Form.Update
        (Flyology_TUI.Events.Pressed
           ((Kind     => Flyology_TUI.Events.Text_Key,
             Modified => (others => False),
             Repeated => False,
             Value    => Text.To_Unbounded_Wide_Wide_String ("x"))));
      Assert
        (Mouse_Form.Field_Value (2) = "x",
         "mouse click did not focus the selected form field");
      declare
         X, Y : Natural;
      begin
         Mouse_Form.Cursor_Position (X, Y);
         Assert
           (X = 6 and then Y = 1,
            "form did not report its active mouse cursor position");
      end;
   end Test_Components;

   procedure Test_Themes is
      Custom : Flyology_TUI.Themes.Theme := Flyology_TUI.Themes.Charm;
      Input  : Flyology_TUI.Components.Text_Inputs.Model :=
        Flyology_TUI.Components.Text_Inputs.Create (4, "hint");
      Empty_Input : constant Flyology_TUI.Components.Text_Inputs.Model :=
        Flyology_TUI.Components.Text_Inputs.Create (4, "hint");
      Spinner : constant Flyology_TUI.Components.Spinners.Model :=
        Flyology_TUI.Components.Spinners.Create;
      Progress : Flyology_TUI.Components.Progress.Model :=
        Flyology_TUI.Components.Progress.Create (2, False);
      List : Integer_Lists.Model := Integer_Lists.Create (8, 2);
      Form : constant Flyology_TUI.Components.Forms.Model :=
        Flyology_TUI.Components.Forms.Create
          (Flyology_TUI.Components.Forms.Field_Array'
             (1 =>
                (Label       => Text.To_Unbounded_Wide_Wide_String ("N"),
                 Initial     => Text.To_Unbounded_Wide_Wide_String ("x"),
                 Placeholder => Text.Null_Unbounded_Wide_Wide_String)),
           Input_Width => 4);
      Override : constant Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.With_Foreground
          (Flyology_TUI.Styles.Default,
           Flyology_TUI.Colors.Basic (Flyology_TUI.Colors.Bright_Red));
   begin
      Assert
        (Flyology_TUI.Themes.Default.Primary = Flyology_TUI.Styles.Default
         and then Flyology_TUI.Themes.Default.Success =
           Flyology_TUI.Styles.Default,
         "default theme changed terminal defaults");
      Custom.Input := Override;
      Input.Set_Value ("x");
      declare
         Rendered : constant Flyology_TUI.Surfaces.Surface :=
           Input.Render (Custom);
      begin
         Assert
           (Rendered.Element (0, 0).Appearance = Override,
            "text input did not use the theme Input role");
      end;
      Assert
        (Custom.Primary = Flyology_TUI.Themes.Charm.Primary,
         "overriding one theme role changed another role");

      declare
         Rendered : constant Flyology_TUI.Surfaces.Surface :=
           Empty_Input.Render (Custom);
      begin
         Assert
           (Rendered.Element (0, 0).Appearance = Custom.Placeholder,
            "text input did not use the theme Placeholder role");
      end;

      declare
         Rendered : constant Flyology_TUI.Surfaces.Surface :=
           Spinner.Render (Custom);
      begin
         Assert
           (Rendered.Element (0, 0).Appearance = Custom.Primary,
            "spinner did not use the theme Primary role");
      end;

      Progress.Set (0.5);
      declare
         Rendered : constant Flyology_TUI.Surfaces.Surface :=
           Progress.Render (Custom);
      begin
         Assert
           (Rendered.Element (0, 0).Appearance = Custom.Primary
            and then Rendered.Element (1, 0).Appearance = Custom.Muted,
            "progress did not map its theme roles");
      end;

      List.Set_Items ((1, 2));
      declare
         Rendered : constant Flyology_TUI.Surfaces.Surface :=
           List.Render (Custom);
      begin
         Assert
           (Rendered.Element (0, 0).Appearance = Custom.Selected
            and then Rendered.Element (0, 1).Appearance = Custom.Muted,
            "list did not map its theme roles");
      end;

      declare
         Rendered : constant Flyology_TUI.Surfaces.Surface :=
           Form.Render (Custom);
      begin
         Assert
           (Rendered.Element (0, 0).Appearance = Custom.Muted
            and then Rendered.Element (3, 0).Appearance = Custom.Focused,
            "form did not map its theme roles");
      end;

      declare
         Rendered : constant Flyology_TUI.Surfaces.Surface :=
           Flyology_TUI.Components.Help.Render
             (Flyology_TUI.Components.Help.Binding_Array'
                (1 =>
                   (Key         => Text.To_Unbounded_Wide_Wide_String ("k"),
                    Description => Text.To_Unbounded_Wide_Wide_String ("key"),
                    Enabled     => True)),
              Width => 8,
              Theme => Custom);
      begin
         Assert
           (Rendered.Element (0, 0).Appearance = Custom.Primary
            and then Rendered.Element (3, 0).Appearance = Custom.Muted,
            "help did not map its theme roles");
      end;
   end Test_Themes;

   type Runner_Model is limited record
      Count : Integer := 0;
      First_Result : Integer := 0;
      Second_Result : Integer := 0;
      Result_Count : Natural := 0;
      Width : Natural := 0;
      Height : Natural := 0;
   end record;

   Runner_First_Present_Sized : Boolean := True;

   procedure Runner_Initialize
     (Item : in out Runner_Model;
      Next : in out App_Transitions.Transition) is
   begin
      Item.Count := 0;
      Item.First_Result := 0;
      Item.Second_Result := 0;
      Item.Result_Count := 0;
      Item.Width := 0;
      Item.Height := 0;
      App_Transitions.Run (Next, (Saved_Value => 7));
   end Runner_Initialize;

   procedure Runner_Update
     (Item  : in out Runner_Model;
      Event : App_Events.Event;
      Next  : in out App_Transitions.Transition) is
   begin
      if Event.Kind = App_Events.Application_Message then
         Item.Count := Event.Application.Amount;
         Item.Result_Count := Item.Result_Count + 1;
         if Item.Result_Count = 1 then
            Item.First_Result := Event.Application.Amount;
         else
            Item.Second_Result := Event.Application.Amount;
            App_Transitions.Quit (Next);
         end if;
      elsif Event.Terminal.Kind = Flyology_TUI.Events.Resize then
         Item.Width := Event.Terminal.Width;
         Item.Height := Event.Terminal.Height;
         App_Transitions.Run (Next, (Saved_Value => 8));
      end if;
   end Runner_Update;

   function Runner_Present
     (Item : Runner_Model) return Flyology_TUI.Views.View
   is
   begin
      if Item.Width /= 93 or else Item.Height /= 31 then
         Runner_First_Present_Sized := False;
      end if;
      return Flyology_TUI.Views.From_Surface
        (Flyology_TUI.Surfaces.Create (Item.Width, Item.Height));
   end Runner_Present;

   procedure Execute
     (Item     : Command;
      Result   : out Message;
      Produced : out Boolean) is
   begin
      Result := (Amount => Item.Saved_Value, Request_Save => False);
      Produced := True;
   end Execute;

   package Runtime is new Flyology_TUI.Runners
     (Events      => App_Events,
      Transitions => App_Transitions,
      Model_Type  => Runner_Model,
      Initialize  => Runner_Initialize,
      Update      => Runner_Update,
      Present     => Runner_Present,
      Execute     => Execute,
      Command_Capacity => 1);

   type Partial_Backend is limited new Flyology_TUI.Backends.Backend with
      record
         Opened : Boolean := False;
         Closed : Boolean := False;
      end record;

   overriding procedure Open (Item : in out Partial_Backend);
   overriding procedure Close (Item : in out Partial_Backend);
   overriding procedure Next_Event
     (Item   : in out Partial_Backend;
      Event  : out Flyology_TUI.Events.Terminal_Event;
      Status : out Flyology_TUI.Backends.Input_Status);
   overriding procedure Render
     (Item : in out Partial_Backend;
      View : Flyology_TUI.Views.View);
   overriding procedure Interrupt (Item : in out Partial_Backend);

   overriding procedure Open (Item : in out Partial_Backend) is
   begin
      Item.Opened := True;
      raise Flyology_TUI.Backends.Backend_Error with
        "synthetic partial initialization";
   end Open;

   overriding procedure Close (Item : in out Partial_Backend) is
   begin
      Item.Opened := False;
      Item.Closed := True;
   end Close;

   overriding procedure Next_Event
     (Item   : in out Partial_Backend;
      Event  : out Flyology_TUI.Events.Terminal_Event;
      Status : out Flyology_TUI.Backends.Input_Status)
   is
      pragma Unreferenced (Item);
   begin
      Event := (Kind => Flyology_TUI.Events.Interrupt);
      Status := Flyology_TUI.Backends.Interrupted;
   end Next_Event;

   overriding procedure Render
     (Item : in out Partial_Backend;
      View : Flyology_TUI.Views.View)
   is
      pragma Unreferenced (Item, View);
   begin
      null;
   end Render;

   overriding procedure Interrupt (Item : in out Partial_Backend) is
      pragma Unreferenced (Item);
   begin
      null;
   end Interrupt;

   procedure Test_Runner is
      State : Runner_Model;
      Backend : Flyology_TUI.Backends.Headless.Headless_Backend;
   begin
      Backend.Set_Initial_Size (93, 31);
      Runner_First_Present_Sized := True;
      Runtime.Run (State, Backend);
      Assert
        (State.Result_Count = 2
         and then State.First_Result = 7
         and then State.Second_Result = 8,
         "initial and resize commands did not re-enter in order");
      Assert
        (State.Width = 93
         and then State.Height = 31
         and then Runner_First_Present_Sized,
         "runner rendered before delivering the initial terminal size");
      Assert (Backend.Render_Count >= 2, "runner did not render updates");
      Assert (not Backend.Is_Open, "runner did not close backend");

      declare
         Sized : Flyology_TUI.Backends.Headless.Headless_Backend;
         Width, Height : Natural := 1;
         Available : Boolean := False;
         Raised : Boolean := False;
      begin
         Sized.Set_Initial_Size (0, 0);
         Sized.Open;
         Sized.Current_Size (Width, Height, Available);
         Assert
           (Available and then Width = 0 and then Height = 0,
            "headless backend confused a zero size with unknown geometry");
         begin
            Sized.Set_Initial_Size (1, 1);
         exception
            when Flyology_TUI.Backends.Backend_Error => Raised := True;
         end;
         Sized.Close;
         Assert
           (Raised,
            "headless opening size changed while the backend was open");
      end;

      declare
         Partial : Partial_Backend;
         Raised  : Boolean := False;
         Width, Height : Natural := 0;
         Available : Boolean := False;
      begin
         Partial.Current_Size (Width, Height, Available);
         Assert
           (not Available and then Width = 0 and then Height = 0,
            "default backend size contract did not report unknown geometry");
         begin
            Runtime.Run (State, Partial);
         exception
            when Flyology_TUI.Backends.Backend_Error =>
               Raised := True;
         end;
         Assert (Raised, "runner suppressed an Open failure");
         Assert
           (Partial.Closed and then not Partial.Opened,
            "runner did not close a partially opened backend");
      end;
   end Test_Runner;

begin
   Test_Program;
   Test_Glyphs_And_Surfaces;
   Test_Layout_And_Renderer;
   Test_Color_Profiles;
   Test_POSIX_Color_Lifecycle;
   Test_Input;
   Test_Mouse;
   Test_POSIX_Poll;
   Test_Components;
   Test_Themes;
   Test_Runner;
end Flyology_TUI_Tests;
