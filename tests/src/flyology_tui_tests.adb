with Ada.Characters.Latin_1;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Strings.Wide_Wide_Unbounded;
with Flyology_TUI.Application_Events;
with Flyology_TUI.Backends.Headless;
with Flyology_TUI.Colors;
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
with Flyology_TUI.Programs;
with Flyology_TUI.Renderers;
with Flyology_TUI.Runners;
with Flyology_TUI.Styles;
with Flyology_TUI.Surfaces;
with Flyology_TUI.Transitions;
with Flyology_TUI.Views;

procedure Flyology_TUI_Tests is
   package Bytes renames Ada.Strings.Unbounded;
   package Text renames Ada.Strings.Wide_Wide_Unbounded;

   use type Flyology_TUI.Events.Key_Kind;
   use type Flyology_TUI.Events.Mouse_Action;
   use type Flyology_TUI.Events.Terminal_Event_Kind;

   ESC : constant Character := Ada.Characters.Latin_1.ESC;

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
      Framed.Put (2, 1, "x");
      View.Frame := Framed;
      Renderer.Render (View, Output);
      Assert
        (Ada.Strings.Fixed.Index (Bytes.To_String (Output), "x") /= 0,
         "changed cell was not rendered");
      Renderer.Reset (Output);
      Assert
        (Bytes.Length (Output) > 0,
         "renderer reset emitted no restore bytes");
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

      Parser.Feed (ESC & "");
      Parser.Flush_Escape;
      Parser.Next_Event (Event, Available);
      Assert
        (Available and then Event.Key.Kind = Flyology_TUI.Events.Escape_Key,
         "escape timeout did not resolve escape key");
   end Test_Input;

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
      List : Integer_Lists.Model := Integer_Lists.Create (8, 2);
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
   begin
      Input.Focus;
      Parsed.Feed ("abc");
      while Parsed.Has_Event loop
         Parsed.Next_Event (Event, Available);
         Input.Update (Event);
      end loop;
      Assert (Input.Value = "abc", "text input rejected printable keys");
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
      Viewport.Set_Content (Flyology_TUI.Surfaces.From_Text ("abcd"));
      Viewport.Scroll (1, 0);
      Assert
        (Cell_Text (Viewport.Render, 0, 0) = "b",
         "viewport did not apply horizontal offset");
      Form.Update
        (Flyology_TUI.Events.Pressed
           ((Kind     => Flyology_TUI.Events.Enter_Key,
             Modified => (others => False),
             Repeated => False)));
      Assert (Form.Submitted, "single-field form did not submit");
   end Test_Components;

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

   procedure Test_Runner is
      State : Runner_Model;
      Backend : Flyology_TUI.Backends.Headless.Headless_Backend;
   begin
      Runtime.Run (State, Backend);
      Assert (State.Count = 7, "command result did not reach model");
      Assert (Backend.Render_Count >= 2, "runner did not render updates");
      Assert (not Backend.Is_Open, "runner did not close backend");
   end Test_Runner;

begin
   Test_Program;
   Test_Glyphs_And_Surfaces;
   Test_Layout_And_Renderer;
   Test_Input;
   Test_Components;
   Test_Runner;
end Flyology_TUI_Tests;
