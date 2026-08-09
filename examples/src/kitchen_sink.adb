with Ada.Exceptions;
with Ada.Strings.Wide_Wide_Unbounded;
with Ada.Text_IO;
with Flyology_TUI.Application_Events;
with Flyology_TUI.Backends;
with Flyology_TUI.Backends.POSIX;
with Flyology_TUI.Components.Forms;
with Flyology_TUI.Components.Help;
with Flyology_TUI.Components.Lists;
with Flyology_TUI.Components.Progress;
with Flyology_TUI.Components.Spinners;
with Flyology_TUI.Components.Text_Inputs;
with Flyology_TUI.Components.Viewports;
with Flyology_TUI.Events;
with Flyology_TUI.Layouts;
with Flyology_TUI.Mouse;
with Flyology_TUI.Runners;
with Flyology_TUI.Styles;
with Flyology_TUI.Surfaces;
with Flyology_TUI.Themes;
with Flyology_TUI.Transitions;
with Flyology_TUI.Views;

procedure Kitchen_Sink is
   package Text renames Ada.Strings.Wide_Wide_Unbounded;

   function U (Value : Wide_Wide_String)
      return Text.Unbounded_Wide_Wide_String
   is (Text.To_Unbounded_Wide_Wide_String (Value));

   function Label (Value : Text.Unbounded_Wide_Wide_String)
      return Wide_Wide_String
   is (Text.To_Wide_Wide_String (Value));

   package Lists is new Flyology_TUI.Components.Lists
     (Item_Type => Text.Unbounded_Wide_Wide_String,
      Label     => Label);

   type Message is (Animation_Tick);
   type Command is (Wait_For_Tick);
   type Pane is (Text_Pane, List_Pane, Viewport_Pane, Form_Pane);

   Text_Panel : constant Flyology_TUI.Mouse.Region :=
     (X => 0, Y => 2, Width => 28, Height => 7);
   List_Panel : constant Flyology_TUI.Mouse.Region :=
     (X => 0, Y => 10, Width => 29, Height => 10);
   Viewport_Panel : constant Flyology_TUI.Mouse.Region :=
     (X => 31, Y => 2, Width => 35, Height => 11);
   Form_Panel : constant Flyology_TUI.Mouse.Region :=
     (X => 31, Y => 14, Width => 33, Height => 8);

   Text_Content : constant Flyology_TUI.Mouse.Region :=
     (X => 2, Y => 6, Width => 24, Height => 1);
   List_Content : constant Flyology_TUI.Mouse.Region :=
     (X => 2, Y => 14, Width => 25, Height => 4);
   Viewport_Content : constant Flyology_TUI.Mouse.Region :=
     (X => 33, Y => 6, Width => 31, Height => 5);
   Form_Content : constant Flyology_TUI.Mouse.Region :=
     (X => 33, Y => 18, Width => 29, Height => 2);

   type Model is limited record
      Active   : Pane := Text_Pane;
      Spinner  : Flyology_TUI.Components.Spinners.Model :=
        Flyology_TUI.Components.Spinners.Create;
      Progress : Flyology_TUI.Components.Progress.Model :=
        Flyology_TUI.Components.Progress.Create (32, False);
      Input    : Flyology_TUI.Components.Text_Inputs.Model :=
        Flyology_TUI.Components.Text_Inputs.Create
          (24, "Type here; Unicode works");
      Choices  : Lists.Model := Lists.Create (25, 4);
      Viewport : Flyology_TUI.Components.Viewports.Model :=
        Flyology_TUI.Components.Viewports.Create (31, 5);
      Form     : Flyology_TUI.Components.Forms.Model;
   end record;

   package Events is new Flyology_TUI.Application_Events (Message);
   package Transitions is new Flyology_TUI.Transitions (Command);
   use type Events.Event_Kind;
   use type Flyology_TUI.Events.Key_Kind;
   use type Flyology_TUI.Events.Mouse_Action;
   use type Flyology_TUI.Events.Mouse_Button;
   use type Flyology_TUI.Events.Terminal_Event_Kind;

   Visual : constant Flyology_TUI.Themes.Theme :=
     Flyology_TUI.Themes.Charm;

   procedure Initialize
     (Item : in out Model;
      Next : in out Transitions.Transition) is
   begin
      Item.Input.Focus;
      Item.Choices.Set_Items
        ([U ("Typed messages"),
          U ("Declarative views"),
          U ("Bounded commands"),
          U ("Headless tests"),
          U ("POSIX backend"),
          U ("Windows boundary")]);
      Item.Viewport.Set_Content
        (Flyology_TUI.Surfaces.From_Text
           ("Arrow keys scroll this viewport." & Wide_Wide_Character'Val (10)
            & "The content is a styled cell surface." &
              Wide_Wide_Character'Val (10)
            & "Rendering compares the next frame" &
              Wide_Wide_Character'Val (10)
            & "with the previous frame and emits" &
              Wide_Wide_Character'Val (10)
            & "only changed terminal cells." & Wide_Wide_Character'Val (10)
            & "No application ANSI strings."));
      Item.Form := Flyology_TUI.Components.Forms.Create
        ([(Label       => U ("Name"),
           Initial     => U (""),
           Placeholder => U ("Ada programmer")),
          (Label       => U ("Project"),
           Initial     => U ("Flyology TUI"),
           Placeholder => U ("Project name"))],
         Input_Width => 20);
      Transitions.Run (Next, Wait_For_Tick);
   end Initialize;

   procedure Activate (Item : in out Model; Target : Pane) is
   begin
      if Item.Active = Text_Pane then
         Item.Input.Blur;
      end if;
      Item.Active := Target;
      if Item.Active = Text_Pane then
         Item.Input.Focus;
      end if;
   end Activate;

   procedure Next_Pane (Item : in out Model; Backwards : Boolean) is
      Position : Integer := Pane'Pos (Item.Active);
   begin
      if Backwards then
         Position :=
           (Position + Pane'Pos (Pane'Last)) mod (Pane'Pos (Pane'Last) + 1);
      else
         Position := (Position + 1) mod (Pane'Pos (Pane'Last) + 1);
      end if;
      Activate (Item, Pane'Val (Position));
   end Next_Pane;

   function Is_Control_C
     (Event : Flyology_TUI.Events.Terminal_Event) return Boolean
   is
     (Event.Kind = Flyology_TUI.Events.Key_Press
      and then Event.Key.Kind = Flyology_TUI.Events.Text_Key
      and then Event.Key.Modified.Control
      and then Text.To_Wide_Wide_String (Event.Key.Value) = "c");

   procedure Handle_Mouse
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Terminal_Event) is
   begin
      if Event.Mouse.Action = Flyology_TUI.Events.Mouse_Click
        and then Event.Mouse.Button = Flyology_TUI.Events.Left_Button
      then
         if Flyology_TUI.Mouse.Contains (Text_Panel, Event.Mouse) then
            Activate (Item, Text_Pane);
         elsif Flyology_TUI.Mouse.Contains (List_Panel, Event.Mouse) then
            Activate (Item, List_Pane);
         elsif Flyology_TUI.Mouse.Contains (Viewport_Panel, Event.Mouse) then
            Activate (Item, Viewport_Pane);
         elsif Flyology_TUI.Mouse.Contains (Form_Panel, Event.Mouse) then
            Activate (Item, Form_Pane);
         end if;
      end if;

      if Flyology_TUI.Mouse.Contains (Text_Content, Event.Mouse) then
         Item.Input.Update
           (Flyology_TUI.Mouse.Localize (Event, Text_Content));
      elsif Flyology_TUI.Mouse.Contains (List_Content, Event.Mouse) then
         Item.Choices.Update
           (Flyology_TUI.Mouse.Localize (Event, List_Content));
      elsif Flyology_TUI.Mouse.Contains (Viewport_Content, Event.Mouse) then
         Item.Viewport.Update
           (Flyology_TUI.Mouse.Localize (Event, Viewport_Content));
      elsif Flyology_TUI.Mouse.Contains (Form_Content, Event.Mouse) then
         Item.Form.Update
           (Flyology_TUI.Mouse.Localize (Event, Form_Content));
      end if;
   end Handle_Mouse;

   procedure Update
     (Item  : in out Model;
      Event : Events.Event;
      Next  : in out Transitions.Transition)
   is
   begin
      if Event.Kind = Events.Application_Message then
         Item.Spinner.Tick;
         if Item.Progress.Value >= 0.97 then
            Item.Progress.Set (0.0);
         else
            Item.Progress.Set (Item.Progress.Value + 0.03);
         end if;
         Transitions.Run (Next, Wait_For_Tick);
         return;
      end if;

      if Event.Terminal.Kind = Flyology_TUI.Events.Interrupt
        or else Is_Control_C (Event.Terminal)
      then
         Transitions.Quit (Next);
      elsif Event.Terminal.Kind = Flyology_TUI.Events.Key_Press
        and then Event.Terminal.Key.Kind = Flyology_TUI.Events.Tab_Key
      then
         Next_Pane (Item, Event.Terminal.Key.Modified.Shift);
      elsif Event.Terminal.Kind = Flyology_TUI.Events.Mouse_Input then
         Handle_Mouse (Item, Event.Terminal);
      else
         case Item.Active is
            when Text_Pane => Item.Input.Update (Event.Terminal);
            when List_Pane => Item.Choices.Update (Event.Terminal);
            when Viewport_Pane => Item.Viewport.Update (Event.Terminal);
            when Form_Pane => Item.Form.Update (Event.Terminal);
         end case;
      end if;
   end Update;

   function Panel
     (Name       : Wide_Wide_String;
      Content    : Flyology_TUI.Surfaces.Surface;
      Is_Active  : Boolean;
      Accent     : Flyology_TUI.Styles.Style;
      Muted      : Flyology_TUI.Styles.Style)
      return Flyology_TUI.Surfaces.Surface
   is
      Marker : constant Wide_Wide_String :=
        [1 => Wide_Wide_Character'Val
           (if Is_Active then 16#25CF# else 16#25CB#),
         2 => ' '];
      Heading : constant Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.From_Text
          (Marker & Name,
           (if Is_Active then Accent else Muted));
      Body_Surface : constant Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Layouts.Join_Vertically (Heading, Content, Gap => 1);
      Box : constant Flyology_TUI.Layouts.Block :=
        (Padding    => (Top => 1, Right => 1, Bottom => 1, Left => 1),
         Border     => Flyology_TUI.Layouts.Rounded,
         Appearance => (if Is_Active then Accent else Muted),
         others     => <>);
   begin
      return Flyology_TUI.Layouts.Render (Box, Body_Surface);
   end Panel;

   function Present (Item : Model) return Flyology_TUI.Views.View is
      Header : constant Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Layouts.Join_Horizontally
          (Item.Spinner.Render (Visual),
           Flyology_TUI.Surfaces.From_Text
             ("Flyology TUI kitchen sink", Visual.Primary),
           Gap => 1);
      Meter : constant Flyology_TUI.Surfaces.Surface :=
        Item.Progress.Render (Visual);
      Input_Panel : constant Flyology_TUI.Surfaces.Surface :=
        Panel
          ("Text input",
           Item.Input.Render (Visual),
           Item.Active = Text_Pane,
           Visual.Border,
           Visual.Muted);
      List_Panel : constant Flyology_TUI.Surfaces.Surface :=
        Panel
          ("Generic list",
           Item.Choices.Render (Visual),
           Item.Active = List_Pane,
           Visual.Border,
           Visual.Muted);
      Viewport_Panel : constant Flyology_TUI.Surfaces.Surface :=
        Panel
          ("Viewport",
           Item.Viewport.Render,
           Item.Active = Viewport_Pane,
           Visual.Border,
           Visual.Muted);
      Form_Panel : constant Flyology_TUI.Surfaces.Surface :=
        Panel
           ((if Item.Form.Submitted then "Form done" else "Form"),
           Item.Form.Render (Visual),
           Item.Active = Form_Pane,
           Visual.Border,
           Visual.Muted);
      Columns : constant Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Layouts.Join_Horizontally
          (Flyology_TUI.Layouts.Join_Vertically
             (Input_Panel, List_Panel, Gap => 1),
           Flyology_TUI.Layouts.Join_Vertically
             (Viewport_Panel, Form_Panel, Gap => 1),
           Gap => 2);
      Help : constant Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Components.Help.Render
          ([(Key         => U ("tab"),
             Description => U ("focus"),
             Enabled     => True),
            (Key         => U ("arrows"),
             Description => U ("move"),
             Enabled     => True),
            (Key         => U ("mouse"),
             Description => U ("click/wheel"),
             Enabled     => True),
            (Key         => U ("ctrl-c"),
             Description => U ("quit"),
             Enabled     => True)],
           Width             => 66,
           Vertical          => False,
           Theme             => Visual);
      Dashboard : constant Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Layouts.Join_Vertically
          (Flyology_TUI.Layouts.Join_Horizontally (Header, Meter, Gap => 3),
           Flyology_TUI.Layouts.Join_Vertically (Columns, Help, Gap => 1),
           Gap => 1);
      Result : Flyology_TUI.Views.View :=
        Flyology_TUI.Views.From_Surface (Dashboard);
   begin
      Result.Alternate_Screen := True;
      Result.Mouse := Flyology_TUI.Views.Button_Events;
      Result.Report_Focus := True;
      Result.Bracketed_Paste := True;
      Result.Window_Title := U ("Flyology TUI kitchen sink");
      if Item.Active = Text_Pane then
         Result.Cursor.Visible := True;
         Result.Cursor.X := Text_Content.X + Item.Input.Cursor_Column;
         Result.Cursor.Y := Text_Content.Y;
         Result.Cursor.Shape := Flyology_TUI.Views.Cursor_Bar;
         Result.Cursor.Blink := False;
      elsif Item.Active = Form_Pane
        and then not Item.Form.Submitted
        and then not Item.Form.Cancelled
      then
         declare
            X, Y : Natural;
         begin
            Item.Form.Cursor_Position (X, Y);
            Result.Cursor.Visible := True;
            Result.Cursor.X := Form_Content.X + X;
            Result.Cursor.Y := Form_Content.Y + Y;
            Result.Cursor.Shape := Flyology_TUI.Views.Cursor_Bar;
            Result.Cursor.Blink := False;
         end;
      end if;
      return Result;
   end Present;

   procedure Execute
     (Item     : Command;
      Result   : out Message;
      Produced : out Boolean)
   is
      pragma Unreferenced (Item);
   begin
      delay 0.12;
      Result := Animation_Tick;
      Produced := True;
   end Execute;

   package Runtime is new Flyology_TUI.Runners
     (Events      => Events,
      Transitions => Transitions,
      Model_Type  => Model,
      Initialize  => Initialize,
      Update      => Update,
      Present     => Present,
      Execute     => Execute,
      Event_Capacity => 64,
      Command_Capacity => 4);

   State : Model;
   Terminal : Flyology_TUI.Backends.POSIX.POSIX_Backend;
begin
   Runtime.Run (State, Terminal);
exception
   when Error : Flyology_TUI.Backends.Backend_Error =>
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "kitchen_sink: " & Ada.Exceptions.Exception_Message (Error));
end Kitchen_Sink;
