with Ada.Characters.Latin_1;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Strings.Wide_Wide_Unbounded;
with Interfaces.C;
with Flyology_TUI.Application_Events;
with Flyology_TUI.Backends;
with Flyology_TUI.Backends.Headless;
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
   end record;

   procedure Runner_Initialize
     (Item : in out Runner_Model;
      Next : in out App_Transitions.Transition) is
   begin
      Item.Count := 0;
      App_Transitions.Run (Next, (Saved_Value => 7));
   end Runner_Initialize;

   procedure Runner_Update
     (Item  : in out Runner_Model;
      Event : App_Events.Event;
      Next  : in out App_Transitions.Transition) is
   begin
      if Event.Kind = App_Events.Application_Message then
         Item.Count := Event.Application.Amount;
         App_Transitions.Quit (Next);
      end if;
   end Runner_Update;

   function Runner_Present
     (Item : Runner_Model) return Flyology_TUI.Views.View
   is
      pragma Unreferenced (Item);
   begin
      return Flyology_TUI.Views.Plain ("runner");
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
      Execute     => Execute);

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
      Runtime.Run (State, Backend);
      Assert (State.Count = 7, "command result did not reach model");
      Assert (Backend.Render_Count >= 2, "runner did not render updates");
      Assert (not Backend.Is_Open, "runner did not close backend");

      declare
         Partial : Partial_Backend;
         Raised  : Boolean := False;
      begin
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
   Test_Input;
   Test_Mouse;
   Test_POSIX_Poll;
   Test_Components;
   Test_Themes;
   Test_Runner;
end Flyology_TUI_Tests;
