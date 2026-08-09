with Ada.Exceptions;
with Ada.Strings.Wide_Wide_Unbounded;
with Ada.Text_IO;
with Flyology_TUI.Application_Events;
with Flyology_TUI.Backends;
with Flyology_TUI.Backends.POSIX;
with Flyology_TUI.Components.Buttons;
with Flyology_TUI.Components.Check_Boxes;
with Flyology_TUI.Components.Dropdowns;
with Flyology_TUI.Components.Forms;
with Flyology_TUI.Components.Help;
with Flyology_TUI.Components.Interactions;
with Flyology_TUI.Components.Lists;
with Flyology_TUI.Components.Progress;
with Flyology_TUI.Components.Radio_Groups;
with Flyology_TUI.Components.Selectors;
with Flyology_TUI.Components.Spinners;
with Flyology_TUI.Components.Tabs;
with Flyology_TUI.Components.Text_Inputs;
with Flyology_TUI.Components.Viewports;
with Flyology_TUI.Events;
with Flyology_TUI.Geometry;
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

   function Text_Label (Value : Text.Unbounded_Wide_Wide_String)
      return Wide_Wide_String
   is (Text.To_Wide_Wide_String (Value));

   package Lists is new Flyology_TUI.Components.Lists
     (Item_Type => Text.Unbounded_Wide_Wide_String,
      Label     => Text_Label);

   type Page_Id is (Basics_Page, Controls_Page);

   function Page_Identity (Item : Page_Id) return Page_Id is (Item);

   function Page_Label (Item : Page_Id) return Wide_Wide_String is
     (case Item is
         when Basics_Page   => "Basics",
         when Controls_Page => "Controls");

   package Pages is new Flyology_TUI.Components.Tabs
     (Item_Type => Page_Id,
      Id_Type   => Page_Id,
      Id_Of     => Page_Identity,
      Label     => Page_Label,
      Capacity  => 8);

   type Choice_Id is (Alpha, Beta, Gamma);

   function Choice_Identity (Item : Choice_Id) return Choice_Id is (Item);

   function Choice_Label (Item : Choice_Id) return Wide_Wide_String is
     (case Item is
         when Alpha => "Alpha",
         when Beta  => "Beta",
         when Gamma => "Gamma");

   package Radios is new Flyology_TUI.Components.Radio_Groups
     (Item_Type => Choice_Id,
      Id_Type   => Choice_Id,
      Id_Of     => Choice_Identity,
      Label     => Choice_Label,
      Capacity  => 8);

   package Selectors is new Flyology_TUI.Components.Selectors
     (Item_Type => Choice_Id,
      Id_Type   => Choice_Id,
      Id_Of     => Choice_Identity,
      Label     => Choice_Label,
      Capacity  => 8);

   package Dropdowns is new Flyology_TUI.Components.Dropdowns
     (Item_Type => Choice_Id,
      Id_Type   => Choice_Id,
      Id_Of     => Choice_Identity,
      Label     => Choice_Label,
      Capacity  => 8);

   type Message is (Animation_Tick);
   type Command is (Wait_For_Tick);
   type Focus_Target is
     (Page_Navigation,
      Text_Field,
      List_Field,
      Viewport_Field,
      Form_Field,
      Button_Field,
      Check_Field,
      Radio_Field,
      Selector_Field,
      Dropdown_Field);
   type Capture_Target is
     (No_Capture,
      Page_Capture,
      Button_Capture,
      Check_Capture,
      Radio_Capture,
      Selector_Capture,
      Dropdown_Capture);

   Page_Tabs_Origin : constant Flyology_TUI.Geometry.Point := (X => 0, Y => 2);
   Text_Panel : constant Flyology_TUI.Mouse.Region :=
     (X => 0, Y => 4, Width => 28, Height => 7);
   List_Panel : constant Flyology_TUI.Mouse.Region :=
     (X => 0, Y => 12, Width => 29, Height => 10);
   Viewport_Panel : constant Flyology_TUI.Mouse.Region :=
     (X => 31, Y => 4, Width => 35, Height => 11);
   Form_Panel : constant Flyology_TUI.Mouse.Region :=
     (X => 31, Y => 16, Width => 33, Height => 8);

   Text_Content : constant Flyology_TUI.Mouse.Region :=
     (X => 2, Y => 8, Width => 24, Height => 1);
   List_Content : constant Flyology_TUI.Mouse.Region :=
     (X => 2, Y => 16, Width => 25, Height => 4);
   Viewport_Content : constant Flyology_TUI.Mouse.Region :=
     (X => 33, Y => 8, Width => 31, Height => 5);
   Form_Content : constant Flyology_TUI.Mouse.Region :=
     (X => 33, Y => 20, Width => 29, Height => 2);

   Button_Origin : constant Flyology_TUI.Geometry.Point := (X => 2, Y => 8);
   Check_Origin : constant Flyology_TUI.Geometry.Point := (X => 2, Y => 10);
   Radio_Origin : constant Flyology_TUI.Geometry.Point := (X => 30, Y => 8);
   Selector_Origin : constant Flyology_TUI.Geometry.Point := (X => 2, Y => 17);
   Dropdown_Origin : constant Flyology_TUI.Geometry.Point :=
     (X => 38, Y => 17);

   type Model is limited record
      Focus    : Focus_Target := Text_Field;
      Capture  : Capture_Target := No_Capture;
      Spinner  : Flyology_TUI.Components.Spinners.Model :=
        Flyology_TUI.Components.Spinners.Create;
      Progress : Flyology_TUI.Components.Progress.Model :=
        Flyology_TUI.Components.Progress.Create (32, False);
      Pages    : Kitchen_Sink.Pages.Model :=
        Kitchen_Sink.Pages.Create ([Basics_Page, Controls_Page]);
      Input    : Flyology_TUI.Components.Text_Inputs.Model :=
        Flyology_TUI.Components.Text_Inputs.Create
          (24, "Type here; Unicode works");
      Choices  : Lists.Model := Lists.Create (25, 4);
      Viewport : Flyology_TUI.Components.Viewports.Model :=
        Flyology_TUI.Components.Viewports.Create (31, 5);
      Form     : Flyology_TUI.Components.Forms.Model;
      Button   : Flyology_TUI.Components.Buttons.Model :=
        Flyology_TUI.Components.Buttons.Create ("Run command");
      Check    : Flyology_TUI.Components.Check_Boxes.Model :=
        Flyology_TUI.Components.Check_Boxes.Create ("Enable telemetry");
      Radios   : Kitchen_Sink.Radios.Model :=
        Kitchen_Sink.Radios.Create ([Alpha, Beta, Gamma]);
      Selector : Kitchen_Sink.Selectors.Model :=
        Kitchen_Sink.Selectors.Create
          ([Alpha, Beta, Gamma], Flyology_TUI.Components.Multiple_Selection);
      Dropdown : Kitchen_Sink.Dropdowns.Model :=
        Kitchen_Sink.Dropdowns.Create ([Alpha, Beta, Gamma]);
   end record;

   package Events is new Flyology_TUI.Application_Events (Message);
   package Transitions is new Flyology_TUI.Transitions (Command);
   use type Events.Event_Kind;
   use type Flyology_TUI.Components.Interactions.Capture_Action;
   use type Flyology_TUI.Events.Key_Kind;
   use type Flyology_TUI.Events.Mouse_Action;
   use type Flyology_TUI.Events.Mouse_Button;
   use type Flyology_TUI.Events.Terminal_Event_Kind;

   Visual : constant Flyology_TUI.Themes.Theme := Flyology_TUI.Themes.Charm;

   function Current_Page (Item : Model) return Page_Id is
     (Item.Pages.Active_Id);

   procedure Activate (Item : in out Model; Target : Focus_Target) is
   begin
      if Item.Focus = Text_Field then
         Item.Input.Blur;
      end if;
      Item.Focus := Target;
      if Item.Focus = Text_Field then
         Item.Input.Focus;
      end if;
   end Activate;

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
      Item.Selector.Set_Selected (Beta);
      Item.Selector.Set_Selected (Gamma);
      Transitions.Run (Next, Wait_For_Tick);
   end Initialize;

   procedure Next_Focus (Item : in out Model; Backwards : Boolean) is
   begin
      if Current_Page (Item) = Basics_Page then
         if Item.Focus not in Page_Navigation .. Form_Field then
            Activate (Item, Text_Field);
            return;
         end if;
         if Backwards then
            Activate
              (Item,
               (case Item.Focus is
                   when Page_Navigation => Form_Field,
                   when Text_Field      => Page_Navigation,
                   when List_Field      => Text_Field,
                   when Viewport_Field  => List_Field,
                   when Form_Field      => Viewport_Field,
                   when others          => Text_Field));
         else
            Activate
              (Item,
               (case Item.Focus is
                   when Page_Navigation => Text_Field,
                   when Text_Field      => List_Field,
                   when List_Field      => Viewport_Field,
                   when Viewport_Field  => Form_Field,
                   when Form_Field      => Page_Navigation,
                   when others          => Text_Field));
         end if;
      else
         if Item.Focus in Text_Field .. Form_Field then
            Activate (Item, Button_Field);
            return;
         end if;
         if Backwards then
            Activate
              (Item,
               (case Item.Focus is
                   when Page_Navigation => Dropdown_Field,
                   when Button_Field    => Page_Navigation,
                   when Check_Field     => Button_Field,
                   when Radio_Field     => Check_Field,
                   when Selector_Field  => Radio_Field,
                   when Dropdown_Field  => Selector_Field,
                   when others          => Button_Field));
         else
            Activate
              (Item,
               (case Item.Focus is
                   when Page_Navigation => Button_Field,
                   when Button_Field    => Check_Field,
                   when Check_Field     => Radio_Field,
                   when Radio_Field     => Selector_Field,
                   when Selector_Field  => Dropdown_Field,
                   when Dropdown_Field  => Page_Navigation,
                   when others          => Button_Field));
         end if;
      end if;
   end Next_Focus;

   function Is_Control_C
     (Event : Flyology_TUI.Events.Terminal_Event) return Boolean
   is
     (Event.Kind = Flyology_TUI.Events.Key_Press
      and then Event.Key.Kind = Flyology_TUI.Events.Text_Key
      and then Event.Key.Modified.Control
      and then Text.To_Wide_Wide_String (Event.Key.Value) = "c");

   procedure Apply_Result
     (Item   : in out Model;
      Target : Focus_Target;
      Owner  : Capture_Target;
      Result : Flyology_TUI.Components.Interactions.Update_Result) is
   begin
      if Result.Focus_Requested then
         Activate (Item, Target);
      end if;
      case Result.Capture is
         when Flyology_TUI.Components.Interactions.No_Capture_Change => null;
         when Flyology_TUI.Components.Interactions.Acquire_Capture =>
            Item.Capture := Owner;
         when Flyology_TUI.Components.Interactions.Release_Capture =>
            Item.Capture := No_Capture;
      end case;
   end Apply_Result;

   procedure Route_Captured_Mouse
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Mouse_Event) is
      use Flyology_TUI.Components.Interactions;
      Result : Update_Result;
   begin
      case Item.Capture is
         when No_Capture => return;
         when Page_Capture =>
            Result := Item.Pages.Handle
              (Flyology_TUI.Mouse.Relative (Event, Page_Tabs_Origin));
            Apply_Result (Item, Page_Navigation, Page_Capture, Result);
            if Current_Page (Item) = Basics_Page
              and then Item.Focus in Button_Field .. Dropdown_Field
            then
               Activate (Item, Text_Field);
            elsif Current_Page (Item) = Controls_Page
              and then Item.Focus in Text_Field .. Form_Field
            then
               Activate (Item, Button_Field);
            end if;
         when Button_Capture =>
            Result := Item.Button.Handle
              (Flyology_TUI.Mouse.Relative (Event, Button_Origin));
            Apply_Result (Item, Button_Field, Button_Capture, Result);
         when Check_Capture =>
            Result := Item.Check.Handle
              (Flyology_TUI.Mouse.Relative (Event, Check_Origin));
            Apply_Result (Item, Check_Field, Check_Capture, Result);
         when Radio_Capture =>
            Result := Item.Radios.Handle
              (Flyology_TUI.Mouse.Relative (Event, Radio_Origin));
            Apply_Result (Item, Radio_Field, Radio_Capture, Result);
         when Selector_Capture =>
            Result := Item.Selector.Handle
              (Flyology_TUI.Mouse.Relative (Event, Selector_Origin));
            Apply_Result (Item, Selector_Field, Selector_Capture, Result);
         when Dropdown_Capture =>
            Result := Item.Dropdown.Handle
              (Flyology_TUI.Mouse.Relative (Event, Dropdown_Origin));
            Apply_Result (Item, Dropdown_Field, Dropdown_Capture, Result);
      end case;
   end Route_Captured_Mouse;

   procedure Handle_Controls_Mouse
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Mouse_Event) is
      use Flyology_TUI.Components.Interactions;
      Button_Bounds : constant Flyology_TUI.Geometry.Rectangle :=
        (X => Button_Origin.X,
         Y => Button_Origin.Y,
         Width => Item.Button.Width,
         Height => 1);
      Check_Bounds : constant Flyology_TUI.Geometry.Rectangle :=
        (X => Check_Origin.X,
         Y => Check_Origin.Y,
         Width => Item.Check.Width,
         Height => 1);
      Radio_View : constant Flyology_TUI.Surfaces.Surface :=
        Item.Radios.Render (Visual, Item.Focus = Radio_Field);
      Radio_Bounds : constant Flyology_TUI.Geometry.Rectangle :=
        (X => Radio_Origin.X,
         Y => Radio_Origin.Y,
         Width => Flyology_TUI.Surfaces.Width (Radio_View),
         Height => Flyology_TUI.Surfaces.Height (Radio_View));
      Selector_View : constant Flyology_TUI.Surfaces.Surface :=
        Item.Selector.Render (Visual, Item.Focus = Selector_Field);
      Selector_Bounds : constant Flyology_TUI.Geometry.Rectangle :=
        (X => Selector_Origin.X,
         Y => Selector_Origin.Y,
         Width => Flyology_TUI.Surfaces.Width (Selector_View),
         Height => Flyology_TUI.Surfaces.Height (Selector_View));
      Dropdown_Bounds : constant Flyology_TUI.Geometry.Rectangle :=
        (X => Dropdown_Origin.X,
         Y => Dropdown_Origin.Y,
         Width => Item.Dropdown.Width,
         Height => Item.Dropdown.Height);
      Point : constant Flyology_TUI.Geometry.Point :=
        (X => Integer (Event.X), Y => Integer (Event.Y));
      Result : Update_Result;
   begin
      if Flyology_TUI.Geometry.Contains (Button_Bounds, Point) then
         Result := Item.Button.Handle
           (Flyology_TUI.Mouse.Relative (Event, Button_Origin));
         Apply_Result (Item, Button_Field, Button_Capture, Result);
      elsif Flyology_TUI.Geometry.Contains (Check_Bounds, Point) then
         Result := Item.Check.Handle
           (Flyology_TUI.Mouse.Relative (Event, Check_Origin));
         Apply_Result (Item, Check_Field, Check_Capture, Result);
      elsif Flyology_TUI.Geometry.Contains (Radio_Bounds, Point) then
         Result := Item.Radios.Handle
           (Flyology_TUI.Mouse.Relative (Event, Radio_Origin));
         Apply_Result (Item, Radio_Field, Radio_Capture, Result);
      elsif Flyology_TUI.Geometry.Contains (Selector_Bounds, Point) then
         Result := Item.Selector.Handle
           (Flyology_TUI.Mouse.Relative (Event, Selector_Origin));
         Apply_Result (Item, Selector_Field, Selector_Capture, Result);
      elsif Flyology_TUI.Geometry.Contains (Dropdown_Bounds, Point) then
         Result := Item.Dropdown.Handle
           (Flyology_TUI.Mouse.Relative (Event, Dropdown_Origin));
         Apply_Result (Item, Dropdown_Field, Dropdown_Capture, Result);
      end if;
   end Handle_Controls_Mouse;

   procedure Handle_Mouse
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Terminal_Event) is
      use Flyology_TUI.Components.Interactions;
      Tabs_Bounds : constant Flyology_TUI.Geometry.Rectangle :=
        (X => Page_Tabs_Origin.X,
         Y => Page_Tabs_Origin.Y,
         Width => Item.Pages.Width,
         Height => 1);
      Point : constant Flyology_TUI.Geometry.Point :=
        (X => Integer (Event.Mouse.X), Y => Integer (Event.Mouse.Y));
      Result : Update_Result;
   begin
      if Item.Capture /= No_Capture then
         Route_Captured_Mouse (Item, Event.Mouse);
         return;
      end if;

      if Current_Page (Item) = Controls_Page
        and then Item.Dropdown.Is_Open
        and then Event.Mouse.Action = Flyology_TUI.Events.Mouse_Click
        and then Event.Mouse.Button = Flyology_TUI.Events.Left_Button
      then
         declare
            Dropdown_Bounds : constant Flyology_TUI.Geometry.Rectangle :=
              (X => Dropdown_Origin.X,
               Y => Dropdown_Origin.Y,
               Width => Item.Dropdown.Width,
               Height => Item.Dropdown.Height);
         begin
            if not Flyology_TUI.Geometry.Contains (Dropdown_Bounds, Point) then
               Result := Item.Dropdown.Dismiss;
               Apply_Result
                 (Item, Dropdown_Field, Dropdown_Capture, Result);
            end if;
         end;
      end if;

      if Flyology_TUI.Geometry.Contains (Tabs_Bounds, Point) then
         Result := Item.Pages.Handle
           (Flyology_TUI.Mouse.Relative (Event.Mouse, Page_Tabs_Origin));
         Apply_Result (Item, Page_Navigation, Page_Capture, Result);
         return;
      end if;

      if Current_Page (Item) = Basics_Page then
         if Event.Mouse.Action = Flyology_TUI.Events.Mouse_Click
           and then Event.Mouse.Button = Flyology_TUI.Events.Left_Button
         then
            if Flyology_TUI.Mouse.Contains (Text_Panel, Event.Mouse) then
               Activate (Item, Text_Field);
            elsif Flyology_TUI.Mouse.Contains (List_Panel, Event.Mouse) then
               Activate (Item, List_Field);
            elsif Flyology_TUI.Mouse.Contains
              (Viewport_Panel, Event.Mouse)
            then
               Activate (Item, Viewport_Field);
            elsif Flyology_TUI.Mouse.Contains (Form_Panel, Event.Mouse) then
               Activate (Item, Form_Field);
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
      else
         Handle_Controls_Mouse (Item, Event.Mouse);
      end if;
   end Handle_Mouse;

   procedure Handle_Focused_Key
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Terminal_Event) is
      use Flyology_TUI.Components.Interactions;
      Result : Update_Result;
   begin
      case Item.Focus is
         when Page_Navigation =>
            Result := Item.Pages.Handle (Event);
            Apply_Result (Item, Page_Navigation, Page_Capture, Result);
         when Text_Field => Item.Input.Update (Event);
         when List_Field => Item.Choices.Update (Event);
         when Viewport_Field => Item.Viewport.Update (Event);
         when Form_Field => Item.Form.Update (Event);
         when Button_Field =>
            Result := Item.Button.Handle (Event);
            Apply_Result (Item, Button_Field, Button_Capture, Result);
         when Check_Field =>
            Result := Item.Check.Handle (Event);
            Apply_Result (Item, Check_Field, Check_Capture, Result);
         when Radio_Field =>
            Result := Item.Radios.Handle (Event);
            Apply_Result (Item, Radio_Field, Radio_Capture, Result);
         when Selector_Field =>
            Result := Item.Selector.Handle (Event);
            Apply_Result (Item, Selector_Field, Selector_Capture, Result);
         when Dropdown_Field =>
            Result := Item.Dropdown.Handle (Event);
            Apply_Result (Item, Dropdown_Field, Dropdown_Capture, Result);
      end case;

      if Current_Page (Item) = Basics_Page
        and then Item.Focus in Button_Field .. Dropdown_Field
      then
         Activate (Item, Text_Field);
      elsif Current_Page (Item) = Controls_Page
        and then Item.Focus in Text_Field .. Form_Field
      then
         Activate (Item, Button_Field);
      end if;
   end Handle_Focused_Key;

   procedure Update
     (Item  : in out Model;
      Event : Events.Event;
      Next  : in out Transitions.Transition) is
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
        and then not Item.Dropdown.Is_Open
      then
         Next_Focus (Item, Event.Terminal.Key.Modified.Shift);
      elsif Event.Terminal.Kind = Flyology_TUI.Events.Mouse_Input then
         Handle_Mouse (Item, Event.Terminal);
      else
         Handle_Focused_Key (Item, Event.Terminal);
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
          (Marker & Name, (if Is_Active then Accent else Muted));
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

   function Basics_View (Item : Model) return Flyology_TUI.Surfaces.Surface is
      Canvas : Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.Create (68, 20);
      Input_Panel : constant Flyology_TUI.Surfaces.Surface :=
        Panel
          ("Text input", Item.Input.Render (Visual),
           Item.Focus = Text_Field, Visual.Border, Visual.Muted);
      List_View : constant Flyology_TUI.Surfaces.Surface :=
        Panel
          ("Generic list", Item.Choices.Render (Visual),
           Item.Focus = List_Field, Visual.Border, Visual.Muted);
      Viewport_View : constant Flyology_TUI.Surfaces.Surface :=
        Panel
          ("Viewport", Item.Viewport.Render,
           Item.Focus = Viewport_Field, Visual.Border, Visual.Muted);
      Form_View : constant Flyology_TUI.Surfaces.Surface :=
        Panel
          ((if Item.Form.Submitted then "Form done" else "Form"),
           Item.Form.Render (Visual), Item.Focus = Form_Field,
           Visual.Border, Visual.Muted);
   begin
      Canvas.Overlay_Clipped (Input_Panel, 0, 0);
      Canvas.Overlay_Clipped (List_View, 0, 8);
      Canvas.Overlay_Clipped (Viewport_View, 31, 0);
      Canvas.Overlay_Clipped (Form_View, 31, 12);
      return Canvas;
   end Basics_View;

   function Controls_View
     (Item : Model) return Flyology_TUI.Surfaces.Surface
   is
      Canvas : Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.Create (68, 20);
      Action_Content : constant Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Layouts.Join_Vertically
          (Item.Button.Render (Visual, Item.Focus = Button_Field),
           Item.Check.Render (Visual, Item.Focus = Check_Field),
           Gap => 1);
      Action_View : constant Flyology_TUI.Surfaces.Surface :=
        Panel
          ("Actions", Action_Content,
           Item.Focus in Button_Field | Check_Field,
           Visual.Border, Visual.Muted);
      Radio_View : constant Flyology_TUI.Surfaces.Surface :=
        Panel
          ("Radio group",
           Item.Radios.Render (Visual, Item.Focus = Radio_Field),
           Item.Focus = Radio_Field, Visual.Border, Visual.Muted);
      Selector_View : constant Flyology_TUI.Surfaces.Surface :=
        Panel
          ("Multi selector",
           Item.Selector.Render (Visual, Item.Focus = Selector_Field),
           Item.Focus = Selector_Field, Visual.Border, Visual.Muted);
      Dropdown_View : constant Flyology_TUI.Surfaces.Surface :=
        Panel
          ("Dropdown",
           Item.Dropdown.Render (Visual, Item.Focus = Dropdown_Field),
           Item.Focus = Dropdown_Field, Visual.Border, Visual.Muted);
   begin
      Canvas.Overlay_Clipped (Action_View, 0, 0);
      Canvas.Overlay_Clipped (Radio_View, 28, 0);
      Canvas.Overlay_Clipped (Selector_View, 0, 9);
      Canvas.Overlay_Clipped (Dropdown_View, 36, 9);
      return Canvas;
   end Controls_View;

   function Present (Item : Model) return Flyology_TUI.Views.View is
      Header : constant Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Layouts.Join_Horizontally
          (Item.Spinner.Render (Visual),
           Flyology_TUI.Surfaces.From_Text
             ("Flyology TUI kitchen sink", Visual.Primary),
           Gap => 1);
      Meter : constant Flyology_TUI.Surfaces.Surface :=
        Item.Progress.Render (Visual);
      Page_Bar : constant Flyology_TUI.Surfaces.Surface :=
        Item.Pages.Render (Visual, Item.Focus = Page_Navigation);
      Page : constant Flyology_TUI.Surfaces.Surface :=
        (if Current_Page (Item) = Basics_Page
         then Basics_View (Item)
         else Controls_View (Item));
      Help : constant Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Components.Help.Render
          ([(Key => U ("tab"),
             Description => U ("focus"), Enabled => True),
            (Key => U ("arrows"),
             Description => U ("choose"), Enabled => True),
            (Key => U ("mouse"),
             Description => U ("activate"), Enabled => True),
            (Key => U ("ctrl-c"), Description => U ("quit"), Enabled => True)],
           Width => 68, Vertical => False, Theme => Visual);
      Dashboard : constant Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Layouts.Join_Vertically
          (Flyology_TUI.Layouts.Join_Horizontally (Header, Meter, Gap => 3),
           Flyology_TUI.Layouts.Join_Vertically
             (Page_Bar,
              Flyology_TUI.Layouts.Join_Vertically (Page, Help, Gap => 1),
              Gap => 1),
           Gap => 1);
      Result : Flyology_TUI.Views.View :=
        Flyology_TUI.Views.From_Surface (Dashboard);
   begin
      Result.Alternate_Screen := True;
      Result.Mouse := Flyology_TUI.Views.Button_Events;
      Result.Report_Focus := True;
      Result.Bracketed_Paste := True;
      Result.Window_Title := U ("Flyology TUI kitchen sink");
      if Current_Page (Item) = Basics_Page
        and then Item.Focus = Text_Field
      then
         Result.Cursor.Visible := True;
         Result.Cursor.X := Text_Content.X + Item.Input.Cursor_Column;
         Result.Cursor.Y := Text_Content.Y;
         Result.Cursor.Shape := Flyology_TUI.Views.Cursor_Bar;
         Result.Cursor.Blink := False;
      elsif Current_Page (Item) = Basics_Page
        and then Item.Focus = Form_Field
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
     (Events           => Events,
      Transitions      => Transitions,
      Model_Type       => Model,
      Initialize       => Initialize,
      Update           => Update,
      Present          => Present,
      Execute          => Execute,
      Event_Capacity   => 64,
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
