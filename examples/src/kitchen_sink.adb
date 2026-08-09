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
with Flyology_TUI.Components.Indicators;
with Flyology_TUI.Components.Lists;
with Flyology_TUI.Components.Progress;
with Flyology_TUI.Components.Progress_Groups;
with Flyology_TUI.Components.Radio_Groups;
with Flyology_TUI.Components.Scrollbars;
with Flyology_TUI.Components.Selectors;
with Flyology_TUI.Components.Sparklines;
with Flyology_TUI.Components.Spinners;
with Flyology_TUI.Components.Split_Panes;
with Flyology_TUI.Components.Tabs;
with Flyology_TUI.Components.Text_Inputs;
with Flyology_TUI.Components.Viewports;
with Flyology_TUI.Components.Windows;
with Flyology_TUI.Events;
with Flyology_TUI.Geometry;
with Flyology_TUI.Layouts;
with Flyology_TUI.Layouts.Boxes;
with Flyology_TUI.Layouts.Layers;
with Flyology_TUI.Mouse;
with Flyology_TUI.Numeric_Series;
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

   type Page_Id is
     (Basics_Page, Controls_Page, Telemetry_Page, Windows_Page);

   function Page_Identity (Item : Page_Id) return Page_Id is (Item);

   function Page_Label (Item : Page_Id) return Wide_Wide_String is
     (case Item is
         when Basics_Page   => "Basics",
         when Controls_Page => "Controls",
         when Telemetry_Page => "Telemetry",
         when Windows_Page   => "Windows");

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

   package Samples is new Flyology_TUI.Numeric_Series
     (Sample_Type      => Integer,
      Maximum_Capacity => 64);

   function Sample_Value (Value : Integer) return Long_Float is
     (Long_Float (Value));

   package Sparklines is new Flyology_TUI.Components.Sparklines
     (Samples       => Samples,
      To_Long_Float => Sample_Value);

   type Work_Id is (Build_Work, Test_Work, Deploy_Work);

   package Work_Progress is new Flyology_TUI.Components.Progress_Groups
     (Item_Id       => Work_Id,
      Maximum_Items => 8);

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
      Dropdown_Field,
      Telemetry_Field,
      Window_Field,
      Split_Field,
      Vertical_Scroll_Field,
      Horizontal_Scroll_Field);
   type Demo_Window is (Window_A, Window_B);
   type Capture_Target is
     (No_Capture,
      Page_Capture,
      Button_Capture,
      Check_Capture,
      Radio_Capture,
      Selector_Capture,
      Dropdown_Capture,
      First_Window_Capture,
      Second_Window_Capture,
      Split_Capture,
      Vertical_Scroll_Capture,
      Horizontal_Scroll_Capture);

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
   Telemetry_Origin : constant Flyology_TUI.Geometry.Point :=
     (X => 2, Y => 8);
   Windows_Page_Origin : constant Flyology_TUI.Geometry.Point :=
     (X => 0, Y => 4);
   Window_Workspace : constant Flyology_TUI.Geometry.Rectangle :=
     (X => 0, Y => 0, Width => 68, Height => 20);
   Vertical_Scroll_Origin : constant Flyology_TUI.Geometry.Point :=
     (X => 67, Y => 0);
   Horizontal_Scroll_Origin : constant Flyology_TUI.Geometry.Point :=
     (X => 0, Y => 19);

   type Model is limited record
      Focus    : Focus_Target := Text_Field;
      Capture  : Capture_Target := No_Capture;
      Spinner  : Flyology_TUI.Components.Spinners.Model :=
        Flyology_TUI.Components.Spinners.Create;
      Progress : Flyology_TUI.Components.Progress.Model :=
        Flyology_TUI.Components.Progress.Create (32, False);
      Pages    : Kitchen_Sink.Pages.Model :=
        Kitchen_Sink.Pages.Create
          ([Basics_Page, Controls_Page, Telemetry_Page, Windows_Page]);
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
      Samples  : Kitchen_Sink.Samples.Series :=
        Kitchen_Sink.Samples.Create (32);
      Work     : Kitchen_Sink.Work_Progress.Model :=
        Kitchen_Sink.Work_Progress.Create (30);
      Telemetry_Tick : Natural range 0 .. 999 := 0;
      Split : Flyology_TUI.Components.Split_Panes.Model :=
        Flyology_TUI.Components.Split_Panes.Create
          (Flyology_TUI.Layouts.Boxes.Horizontal,
           68, 20, First_Span => 25,
           First_Minimum => 10, Second_Minimum => 10);
      Vertical_Scroll : Flyology_TUI.Components.Scrollbars.Model :=
        Flyology_TUI.Components.Scrollbars.Create
          (Flyology_TUI.Layouts.Boxes.Vertical, 20);
      Horizontal_Scroll : Flyology_TUI.Components.Scrollbars.Model :=
        Flyology_TUI.Components.Scrollbars.Create
          (Flyology_TUI.Layouts.Boxes.Horizontal, 68);
      Window_A_Model : Flyology_TUI.Components.Windows.Model :=
        Flyology_TUI.Components.Windows.Create
          (2, 1, 32, 10, Minimum_Width => 16, Minimum_Height => 6);
      Window_B_Model : Flyology_TUI.Components.Windows.Model :=
        Flyology_TUI.Components.Windows.Create
          (28, 7, 36, 12, Minimum_Width => 18, Minimum_Height => 6);
      Top_Window : Demo_Window := Window_B;
      Focused_Window : Demo_Window := Window_B;
      Window_A_Visible : Boolean := True;
      Window_B_Visible : Boolean := True;
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
      Item.Input.Blur;
      Item.Window_A_Model.Blur;
      Item.Window_B_Model.Blur;
      Item.Split.Blur;
      Item.Vertical_Scroll.Blur;
      Item.Horizontal_Scroll.Blur;
      Item.Focus := Target;
      case Item.Focus is
         when Text_Field => Item.Input.Focus;
         when Window_Field =>
            if Item.Focused_Window = Window_A
              and then Item.Window_A_Visible
            then
               Item.Window_A_Model.Focus;
            elsif Item.Focused_Window = Window_B
              and then Item.Window_B_Visible
            then
               Item.Window_B_Model.Focus;
            elsif Item.Window_A_Visible then
               Item.Focused_Window := Window_A;
               Item.Top_Window := Window_A;
               Item.Window_A_Model.Focus;
            elsif Item.Window_B_Visible then
               Item.Focused_Window := Window_B;
               Item.Top_Window := Window_B;
               Item.Window_B_Model.Focus;
            else
               Item.Focus := Split_Field;
               Item.Split.Focus;
            end if;
         when Split_Field => Item.Split.Focus;
         when Vertical_Scroll_Field => Item.Vertical_Scroll.Focus;
         when Horizontal_Scroll_Field => Item.Horizontal_Scroll.Focus;
         when others => null;
      end case;
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
      for Value in -8 .. 8 loop
         Item.Samples.Append (Value * Value mod 13 - 6);
      end loop;
      Item.Work.Add_Determinate
        (Build_Work, "Build", Relative_Weight => 3.0, Value => 0.35);
      Item.Work.Add_Determinate
        (Test_Work, "Tests", Relative_Weight => 2.0, Value => 0.65,
         Work => Work_Progress.Paused);
      Item.Work.Add_Indeterminate
        (Deploy_Work, "Deploy", Relative_Weight => 1.0);
      Item.Vertical_Scroll.Configure
        (Total => 100, Page_Size => 20, First => 18);
      Item.Horizontal_Scroll.Configure
        (Total => 180, Page_Size => 68, First => 42);
      Transitions.Run (Next, Wait_For_Tick);
   end Initialize;

   procedure Next_Focus (Item : in out Model; Backwards : Boolean) is
      Has_Visible_Window : constant Boolean :=
        Item.Window_A_Visible or else Item.Window_B_Visible;
   begin
      case Current_Page (Item) is
      when Basics_Page =>
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
      when Controls_Page =>
         if Item.Focus not in Page_Navigation | Button_Field .. Dropdown_Field
         then
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
      when Telemetry_Page =>
         if Item.Focus not in Page_Navigation | Telemetry_Field then
            Activate (Item, Telemetry_Field);
         elsif Backwards then
            Activate
              (Item,
               (if Item.Focus = Page_Navigation
                then Telemetry_Field
                else Page_Navigation));
         else
            Activate
              (Item,
               (if Item.Focus = Page_Navigation
                then Telemetry_Field
                else Page_Navigation));
         end if;
      when Windows_Page =>
         if Item.Focus not in
           Page_Navigation | Window_Field .. Horizontal_Scroll_Field
         then
            Activate (Item, Window_Field);
            return;
         end if;
         if Backwards then
            Activate
              (Item,
               (case Item.Focus is
                   when Page_Navigation        => Horizontal_Scroll_Field,
                   when Window_Field           => Page_Navigation,
                   when Split_Field            =>
                     (if Has_Visible_Window
                      then Window_Field
                      else Page_Navigation),
                   when Vertical_Scroll_Field  => Split_Field,
                   when Horizontal_Scroll_Field => Vertical_Scroll_Field,
                   when others                 => Window_Field));
         else
            Activate
              (Item,
               (case Item.Focus is
                   when Page_Navigation         =>
                     (if Has_Visible_Window
                      then Window_Field
                      else Split_Field),
                   when Window_Field            => Split_Field,
                   when Split_Field             => Vertical_Scroll_Field,
                   when Vertical_Scroll_Field   => Horizontal_Scroll_Field,
                   when Horizontal_Scroll_Field => Page_Navigation,
                   when others                  => Window_Field));
         end if;
      end case;
   end Next_Focus;

   procedure Normalize_Focus (Item : in out Model) is
   begin
      case Current_Page (Item) is
         when Basics_Page =>
            if Item.Focus not in Page_Navigation .. Form_Field then
               Activate (Item, Text_Field);
            end if;
         when Controls_Page =>
            if Item.Focus not in
              Page_Navigation | Button_Field .. Dropdown_Field
            then
               Activate (Item, Button_Field);
            end if;
         when Telemetry_Page =>
            if Item.Focus not in Page_Navigation | Telemetry_Field then
               Activate (Item, Telemetry_Field);
            end if;
         when Windows_Page =>
            if Item.Focus not in
              Page_Navigation | Window_Field .. Horizontal_Scroll_Field
            then
               Activate (Item, Window_Field);
            end if;
      end case;
   end Normalize_Focus;

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

   procedure Apply_Window_Result
     (Item   : in out Model;
      Which  : Demo_Window;
      Result : Flyology_TUI.Components.Interactions.Update_Result) is
      Owner : constant Capture_Target :=
        (if Which = Window_A
         then First_Window_Capture
         else Second_Window_Capture);
   begin
      if Result.Focus_Requested then
         Item.Focused_Window := Which;
         Item.Top_Window := Which;
         Activate (Item, Window_Field);
      end if;
      case Result.Capture is
         when Flyology_TUI.Components.Interactions.No_Capture_Change => null;
         when Flyology_TUI.Components.Interactions.Acquire_Capture =>
            Item.Capture := Owner;
         when Flyology_TUI.Components.Interactions.Release_Capture =>
            Item.Capture := No_Capture;
      end case;
      if Result.Activated then
         if Which = Window_A then
            Item.Window_A_Visible := False;
         else
            Item.Window_B_Visible := False;
         end if;
         if Item.Window_A_Visible then
            Item.Focused_Window := Window_A;
            Item.Top_Window := Window_A;
            Activate (Item, Window_Field);
         elsif Item.Window_B_Visible then
            Item.Focused_Window := Window_B;
            Item.Top_Window := Window_B;
            Activate (Item, Window_Field);
         else
            Activate (Item, Split_Field);
         end if;
      end if;
   end Apply_Window_Result;

   procedure Route_Captured_Mouse
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Mouse_Event) is
      use Flyology_TUI.Components.Interactions;
      Result : Update_Result;
      Page_Event : Flyology_TUI.Mouse.Local_Event;
   begin
      case Item.Capture is
         when No_Capture => return;
         when Page_Capture =>
            Result := Item.Pages.Handle
              (Flyology_TUI.Mouse.Relative (Event, Page_Tabs_Origin));
            Apply_Result (Item, Page_Navigation, Page_Capture, Result);
            Normalize_Focus (Item);
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
         when First_Window_Capture =>
            Page_Event :=
              Flyology_TUI.Mouse.Relative (Event, Windows_Page_Origin);
            Result := Item.Window_A_Model.Handle
              (Page_Event, Window_Workspace);
            Apply_Window_Result (Item, Window_A, Result);
         when Second_Window_Capture =>
            Page_Event :=
              Flyology_TUI.Mouse.Relative (Event, Windows_Page_Origin);
            Result := Item.Window_B_Model.Handle
              (Page_Event, Window_Workspace);
            Apply_Window_Result (Item, Window_B, Result);
         when Split_Capture =>
            Page_Event :=
              Flyology_TUI.Mouse.Relative (Event, Windows_Page_Origin);
            Result := Item.Split.Handle (Page_Event);
            Apply_Result (Item, Split_Field, Split_Capture, Result);
         when Vertical_Scroll_Capture =>
            Page_Event :=
              Flyology_TUI.Mouse.Relative (Event, Windows_Page_Origin);
            Result := Item.Vertical_Scroll.Handle
              (Flyology_TUI.Mouse.Relative
                 (Page_Event, Vertical_Scroll_Origin));
            Apply_Result
              (Item, Vertical_Scroll_Field,
               Vertical_Scroll_Capture, Result);
         when Horizontal_Scroll_Capture =>
            Page_Event :=
              Flyology_TUI.Mouse.Relative (Event, Windows_Page_Origin);
            Result := Item.Horizontal_Scroll.Handle
              (Flyology_TUI.Mouse.Relative
                 (Page_Event, Horizontal_Scroll_Origin));
            Apply_Result
              (Item, Horizontal_Scroll_Field,
               Horizontal_Scroll_Capture, Result);
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

   procedure Handle_Telemetry_Mouse
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Mouse_Event) is
      use Flyology_TUI.Components.Interactions;
      Work_View : constant Flyology_TUI.Surfaces.Surface :=
        Item.Work.Render (Visual);
      Work_Bounds : constant Flyology_TUI.Geometry.Rectangle :=
        (X => Telemetry_Origin.X,
         Y => Telemetry_Origin.Y,
         Width => Flyology_TUI.Surfaces.Width (Work_View),
         Height => Flyology_TUI.Surfaces.Height (Work_View));
      Point : constant Flyology_TUI.Geometry.Point :=
        (X => Integer (Event.X), Y => Integer (Event.Y));
      Result : Update_Result;
   begin
      if Flyology_TUI.Geometry.Contains (Work_Bounds, Point) then
         Result := Item.Work.Handle
           (Flyology_TUI.Mouse.Relative (Event, Telemetry_Origin));
         Apply_Result (Item, Telemetry_Field, No_Capture, Result);
      end if;
   end Handle_Telemetry_Mouse;

   procedure Handle_Windows_Mouse
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Mouse_Event) is
      use Flyology_TUI.Components.Interactions;
      Page_Event : constant Flyology_TUI.Mouse.Local_Event :=
        Flyology_TUI.Mouse.Relative (Event, Windows_Page_Origin);
      Point : constant Flyology_TUI.Geometry.Point :=
        (X => Page_Event.X, Y => Page_Event.Y);
      Result : Update_Result;

      function Is_Hit (Which : Demo_Window) return Boolean is
        (case Which is
            when Window_A =>
              Item.Window_A_Visible
              and then Flyology_TUI.Geometry.Contains
                (Item.Window_A_Model.Bounds, Point),
            when Window_B =>
              Item.Window_B_Visible
              and then Flyology_TUI.Geometry.Contains
                (Item.Window_B_Model.Bounds, Point));

      procedure Route_Window (Which : Demo_Window) is
      begin
         if Which = Window_A then
            Result := Item.Window_A_Model.Handle
              (Page_Event, Window_Workspace);
         else
            Result := Item.Window_B_Model.Handle
              (Page_Event, Window_Workspace);
         end if;
         Apply_Window_Result (Item, Which, Result);
      end Route_Window;
   begin
      if Is_Hit (Item.Top_Window) then
         Route_Window (Item.Top_Window);
         return;
      elsif Is_Hit
        ((if Item.Top_Window = Window_A then Window_B else Window_A))
      then
         Route_Window
           ((if Item.Top_Window = Window_A then Window_B else Window_A));
         return;
      end if;

      if Flyology_TUI.Geometry.Contains
        ((X => Vertical_Scroll_Origin.X,
          Y => Vertical_Scroll_Origin.Y,
          Width => 1,
          Height => 20),
         Point)
      then
         Result := Item.Vertical_Scroll.Handle
           (Flyology_TUI.Mouse.Relative
              (Page_Event, Vertical_Scroll_Origin));
         Apply_Result
           (Item, Vertical_Scroll_Field, Vertical_Scroll_Capture, Result);
      elsif Flyology_TUI.Geometry.Contains
        ((X => Horizontal_Scroll_Origin.X,
          Y => Horizontal_Scroll_Origin.Y,
          Width => 68,
          Height => 1),
         Point)
      then
         Result := Item.Horizontal_Scroll.Handle
           (Flyology_TUI.Mouse.Relative
              (Page_Event, Horizontal_Scroll_Origin));
         Apply_Result
           (Item, Horizontal_Scroll_Field,
            Horizontal_Scroll_Capture, Result);
      elsif Flyology_TUI.Geometry.Contains (Window_Workspace, Point) then
         Result := Item.Split.Handle (Page_Event);
         Apply_Result (Item, Split_Field, Split_Capture, Result);
      end if;
   end Handle_Windows_Mouse;

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

      case Current_Page (Item) is
      when Basics_Page =>
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
      when Controls_Page =>
         Handle_Controls_Mouse (Item, Event.Mouse);
      when Telemetry_Page =>
         Handle_Telemetry_Mouse (Item, Event.Mouse);
      when Windows_Page =>
         Handle_Windows_Mouse (Item, Event.Mouse);
      end case;
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
         when Telemetry_Field =>
            Result := Item.Work.Handle (Event);
            Apply_Result (Item, Telemetry_Field, No_Capture, Result);
         when Window_Field =>
            if Item.Focused_Window = Window_A
              and then Item.Window_A_Visible
            then
               Result := Item.Window_A_Model.Handle
                 (Event, Window_Workspace);
               Apply_Window_Result (Item, Window_A, Result);
            elsif Item.Focused_Window = Window_B
              and then Item.Window_B_Visible
            then
               Result := Item.Window_B_Model.Handle
                 (Event, Window_Workspace);
               Apply_Window_Result (Item, Window_B, Result);
            elsif Item.Window_A_Visible then
               Item.Focused_Window := Window_A;
               Activate (Item, Window_Field);
               Result := Item.Window_A_Model.Handle
                 (Event, Window_Workspace);
               Apply_Window_Result (Item, Window_A, Result);
            elsif Item.Window_B_Visible then
               Item.Focused_Window := Window_B;
               Activate (Item, Window_Field);
               Result := Item.Window_B_Model.Handle
                 (Event, Window_Workspace);
               Apply_Window_Result (Item, Window_B, Result);
            end if;
         when Split_Field =>
            Result := Item.Split.Handle (Event);
            Apply_Result (Item, Split_Field, Split_Capture, Result);
         when Vertical_Scroll_Field =>
            Result := Item.Vertical_Scroll.Handle (Event);
            Apply_Result
              (Item, Vertical_Scroll_Field,
               Vertical_Scroll_Capture, Result);
         when Horizontal_Scroll_Field =>
            Result := Item.Horizontal_Scroll.Handle (Event);
            Apply_Result
              (Item, Horizontal_Scroll_Field,
               Horizontal_Scroll_Capture, Result);
      end case;
      Normalize_Focus (Item);
   end Handle_Focused_Key;

   procedure Update
     (Item  : in out Model;
      Event : Events.Event;
      Next  : in out Transitions.Transition) is
   begin
      if Event.Kind = Events.Application_Message then
         Item.Spinner.Tick;
         Item.Telemetry_Tick := (Item.Telemetry_Tick + 1) mod 1_000;
         Item.Samples.Append
           (Integer (Item.Telemetry_Tick mod 23) - 11);
         declare
            Percent : constant Natural := Item.Telemetry_Tick mod 101;
         begin
            Item.Work.Set_Value
              (Build_Work,
               Work_Progress.Fraction (Long_Float (Percent) / 100.0));
            Item.Work.Set_Work_State
              (Build_Work,
               (if Percent = 100
                then Work_Progress.Succeeded
                else Work_Progress.Running));
            Item.Work.Advance;
         end;
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

   function Telemetry_View
     (Item : Model) return Flyology_TUI.Surfaces.Surface
   is
      package Indicators renames Flyology_TUI.Components.Indicators;
      Canvas : Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.Create (68, 20);
      Work_View : constant Flyology_TUI.Surfaces.Surface :=
        Panel
          ("Work progress", Item.Work.Render (Visual),
           Item.Focus = Telemetry_Field, Visual.Border, Visual.Muted);
      Spark_View : constant Flyology_TUI.Surfaces.Surface :=
        Panel
          ("Bounded series",
           Sparklines.Render
             (Item.Samples, 28, Sparklines.Automatic, Visual),
           False, Visual.Border, Visual.Muted);
      Aggregate : constant Work_Progress.Fraction :=
        Item.Work.Weighted_Total;
      Summary : constant Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Layouts.Join_Horizontally
          (Indicators.Badge
             ("bounded", Indicators.Success_Tone, Visual),
           Flyology_TUI.Layouts.Join_Horizontally
             (Indicators.Gauge
                (Indicators.Ratio (Aggregate), 20, Visual),
              Indicators.Key_Value
                ("aggregate",
                 Integer'Wide_Wide_Image
                   (Integer (Long_Float (Aggregate) * 100.0)) & "%",
                 22,
                 Visual),
              Gap => 2),
           Gap => 2);
      Status : constant Flyology_TUI.Surfaces.Surface :=
        Indicators.Status_Line
          ([Indicators.Make_Segment
             ("RUNNING", Indicators.Critical, Indicators.Success_Tone),
            Indicators.Make_Segment
              ("paused tests", Indicators.Normal, Indicators.Warning_Tone),
            Indicators.Make_Segment
              ("ring:32", Indicators.Low, Indicators.Neutral)],
           64,
           Visual);
      Indicator_Content : constant Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Layouts.Join_Vertically
          (Indicators.Divider (64, "telemetry", Visual),
           Flyology_TUI.Layouts.Join_Vertically
             (Summary,
              Flyology_TUI.Layouts.Join_Vertically
                (Item.Work.Render_Segments (64, Visual), Status),
              Gap => 1));
      Indicator_View : constant Flyology_TUI.Surfaces.Surface :=
        Panel
          ("Immediate indicators", Indicator_Content,
           False, Visual.Border, Visual.Muted);
   begin
      Canvas.Overlay_Clipped (Work_View, 0, 0);
      Canvas.Overlay_Clipped (Spark_View, 36, 0);
      Canvas.Overlay_Clipped (Indicator_View, 0, 9);
      return Canvas;
   end Telemetry_View;

   function Windows_View
     (Item : Model) return Flyology_TUI.Surfaces.Surface
   is
      Base : constant Flyology_TUI.Surfaces.Surface :=
        Item.Split.Render
          (Flyology_TUI.Surfaces.From_Text
             ("split pane A" & Wide_Wide_Character'Val (10)
              & "drag the divider"),
           Flyology_TUI.Surfaces.From_Text
             ("split pane B" & Wide_Wide_Character'Val (10)
              & "arrows resize when focused"),
           Visual);
      Vertical_Bar : constant Flyology_TUI.Surfaces.Surface :=
        Item.Vertical_Scroll.Render (Visual);
      Horizontal_Bar : constant Flyology_TUI.Surfaces.Surface :=
        Item.Horizontal_Scroll.Render (Visual);
      Window_A_Bounds : constant Flyology_TUI.Geometry.Rectangle :=
        Item.Window_A_Model.Bounds;
      Window_B_Bounds : constant Flyology_TUI.Geometry.Rectangle :=
        Item.Window_B_Model.Bounds;
      Window_A_Surface : constant Flyology_TUI.Surfaces.Surface :=
        (if Item.Window_A_Visible
         then Item.Window_A_Model.Render
           ("Inspector",
            Flyology_TUI.Surfaces.From_Text
              ("Move: drag header" & Wide_Wide_Character'Val (10)
               & "Resize: borders" & Wide_Wide_Character'Val (10)
               & "Keyboard: alt/ctrl arrows"),
            Window_A_Bounds,
            Visual)
         else Flyology_TUI.Surfaces.Create (0, 0));
      Window_B_Surface : constant Flyology_TUI.Surfaces.Surface :=
        (if Item.Window_B_Visible
         then Item.Window_B_Model.Render
           ("Activity",
            Flyology_TUI.Surfaces.From_Text
              ("Application owns z-order." & Wide_Wide_Character'Val (10)
               & "Close requests are values." & Wide_Wide_Character'Val (10)
               & "Children remain external."),
            Window_B_Bounds,
            Visual)
         else Flyology_TUI.Surfaces.Create (0, 0));
      Lower_Window : constant Flyology_TUI.Surfaces.Surface :=
        (if Item.Top_Window = Window_A
         then Window_B_Surface
         else Window_A_Surface);
      Upper_Window : constant Flyology_TUI.Surfaces.Surface :=
        (if Item.Top_Window = Window_A
         then Window_A_Surface
         else Window_B_Surface);
      Lower_Bounds : constant Flyology_TUI.Geometry.Rectangle :=
        (if Item.Top_Window = Window_A
         then Window_B_Bounds
         else Window_A_Bounds);
      Upper_Bounds : constant Flyology_TUI.Geometry.Rectangle :=
        (if Item.Top_Window = Window_A
         then Window_A_Bounds
         else Window_B_Bounds);
   begin
      return Flyology_TUI.Layouts.Layers.Compose
        (68,
         20,
         [(Content => Base, X => 0, Y => 0,
           Transparent_Spaces => False),
          (Content => Vertical_Bar, X => 67, Y => 0,
           Transparent_Spaces => True),
          (Content => Horizontal_Bar, X => 0, Y => 19,
           Transparent_Spaces => True),
          (Content => Lower_Window, X => Lower_Bounds.X, Y => Lower_Bounds.Y,
           Transparent_Spaces => False),
          (Content => Upper_Window, X => Upper_Bounds.X, Y => Upper_Bounds.Y,
           Transparent_Spaces => False)]);
   end Windows_View;

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
        (case Current_Page (Item) is
            when Basics_Page   => Basics_View (Item),
            when Controls_Page => Controls_View (Item),
            when Telemetry_Page => Telemetry_View (Item),
            when Windows_Page   => Windows_View (Item));
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
