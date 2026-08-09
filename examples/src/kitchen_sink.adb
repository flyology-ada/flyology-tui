with Ada.Exceptions;
with Ada.Strings.Wide_Wide_Unbounded;
with Ada.Text_IO;
with Flyology_TUI.Application_Events;
with Flyology_TUI.Backends;
with Flyology_TUI.Backends.POSIX;
with Flyology_TUI.Components.Accordions;
with Flyology_TUI.Components.Breadcrumbs;
with Flyology_TUI.Components.Buttons;
with Flyology_TUI.Components.Check_Boxes;
with Flyology_TUI.Components.Chats;
with Flyology_TUI.Components.Dropdowns;
with Flyology_TUI.Components.Forms;
with Flyology_TUI.Components.Help;
with Flyology_TUI.Components.Interactions;
with Flyology_TUI.Components.Indicators;
with Flyology_TUI.Components.Lists;
with Flyology_TUI.Components.Panel_Groups;
with Flyology_TUI.Components.Progress;
with Flyology_TUI.Components.Progress_Groups;
with Flyology_TUI.Components.Radio_Groups;
with Flyology_TUI.Components.Scrollbars;
with Flyology_TUI.Components.Selectors;
with Flyology_TUI.Components.Sparklines;
with Flyology_TUI.Components.Spinners;
with Flyology_TUI.Components.Split_Panes;
with Flyology_TUI.Components.Streaming_Texts;
with Flyology_TUI.Components.Syntax_Editors;
with Flyology_TUI.Components.Tables;
with Flyology_TUI.Components.Tabs;
with Flyology_TUI.Components.Text_Areas;
with Flyology_TUI.Components.Text_Inputs;
with Flyology_TUI.Components.Trees;
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

   type Ada_Token is
     (Ada_Keyword, Ada_String, Ada_Comment, Ada_Identifier);
   type Ada_Lexer_State is (Ada_Normal);

   function Is_Name_Character (Value : Wide_Wide_Character) return Boolean is
     (Value in 'a' .. 'z'
      or else Value in 'A' .. 'Z'
      or else Value in '0' .. '9'
      or else Value = '_');

   function Is_Keyword (Value : Wide_Wide_String) return Boolean is
     (Value = "begin"
      or else Value = "end"
      or else Value = "function"
      or else Value = "package"
      or else Value = "procedure"
      or else Value = "return"
      or else Value = "type"
      or else Value = "with");

   procedure Next_Ada_Token
     (Line        : Wide_Wide_String;
      Initial     : Ada_Lexer_State;
      From        : Natural;
      Kind        : out Ada_Token;
      First, Last : out Natural;
      Final       : out Ada_Lexer_State;
      Has_Token   : out Boolean)
   is
      Position : Natural := From;
   begin
      Final := Initial;
      Kind := Ada_Identifier;
      while Position < Line'Length
        and then not Is_Name_Character (Line (Line'First + Position))
        and then Line (Line'First + Position) /= '"'
        and then not
          (Line (Line'First + Position) = '-'
           and then Position + 1 < Line'Length
           and then Line (Line'First + Position + 1) = '-')
      loop
         Position := Position + 1;
      end loop;
      First := Position;
      Last := Position;
      Has_Token := Position < Line'Length;
      if not Has_Token then
         return;
      elsif Line (Line'First + Position) = '-'
        and then Position + 1 < Line'Length
        and then Line (Line'First + Position + 1) = '-'
      then
         Kind := Ada_Comment;
         Last := Line'Length;
      elsif Line (Line'First + Position) = '"' then
         Kind := Ada_String;
         Last := Position + 1;
         while Last < Line'Length loop
            Last := Last + 1;
            exit when Line (Line'First + Last - 1) = '"';
         end loop;
      else
         while Last < Line'Length
           and then Is_Name_Character (Line (Line'First + Last))
         loop
            Last := Last + 1;
         end loop;
         Kind :=
           (if Is_Keyword
              (Line (Line'First + First .. Line'First + Last - 1))
            then Ada_Keyword else Ada_Identifier);
      end if;
   end Next_Ada_Token;

   package Ada_Editors is new Flyology_TUI.Components.Syntax_Editors
     (Token_Kind              => Ada_Token,
      Lexer_State             => Ada_Lexer_State,
      Initial_State           => Ada_Normal,
      Maximum_Tokens_Per_Line => 24,
      Next_Token              => Next_Ada_Token);

   type Page_Id is
     (Basics_Page,
      Controls_Page,
      Navigation_Page,
      Editors_Page,
      Telemetry_Page,
      Chat_Page,
      Panels_Page,
      Windows_Page);

   function Page_Identity (Item : Page_Id) return Page_Id is (Item);

   function Page_Label (Item : Page_Id) return Wide_Wide_String is
     (case Item is
         when Basics_Page   => "Basics",
         when Controls_Page => "Controls",
         when Navigation_Page => "Navigation",
         when Editors_Page => "Editors",
         when Telemetry_Page => "Telemetry",
         when Chat_Page      => "Chat",
         when Panels_Page    => "Panels",
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

   type Path_Id is
     (Workspace_Path, Project_Path, Examples_Path, Kitchen_Sink_Path);

   function Path_Identity (Item : Path_Id) return Path_Id is (Item);

   function Path_Label (Item : Path_Id) return Wide_Wide_String is
     (case Item is
         when Workspace_Path    => "flyology",
         when Project_Path      => "flyology-tui",
         when Examples_Path     => "examples",
         when Kitchen_Sink_Path => "kitchen sink");

   package Breadcrumbs is new Flyology_TUI.Components.Breadcrumbs
     (Item_Type => Path_Id,
      Id_Type   => Path_Id,
      Id_Of     => Path_Identity,
      Label     => Path_Label,
      Capacity  => 8);

   type Component_Id is
     (Runtime_Component,
      Backend_Component,
      Views_Component,
      Tests_Component);
   type Component_Column is (Name_Column, Status_Column);
   type Component_Row is record
      Id       : Component_Id;
      Priority : Natural;
   end record;

   function Component_Identity
     (Item : Component_Row) return Component_Id is (Item.Id);

   function Component_Name
     (Item : Component_Id) return Wide_Wide_String is
     (case Item is
         when Runtime_Component => "runtime",
         when Backend_Component => "POSIX backend",
         when Views_Component   => "views",
         when Tests_Component   => "headless tests");

   function Component_Cell
     (Item : Component_Row; Column : Component_Column)
      return Wide_Wide_String is
     (case Column is
         when Name_Column => Component_Name (Item.Id),
         when Status_Column =>
           (if Item.Priority = 1 then "ready"
            elsif Item.Priority = 2 then "active"
            else "bounded"));

   function Component_Less
     (Left, Right : Component_Row; Column : Component_Column)
      return Boolean is
     (case Column is
         when Name_Column => Left.Id < Right.Id,
         when Status_Column => Left.Priority < Right.Priority);

   package Tables is new Flyology_TUI.Components.Tables
     (Item_Type => Component_Row,
      Id_Type   => Component_Id,
      Column_Id => Component_Column,
      Id_Of     => Component_Identity,
      Cell      => Component_Cell,
      Less      => Component_Less,
      Capacity  => 8);

   Navigation_Columns : constant Tables.Column_Definitions :=
     [Name_Column =>
        (Heading       => U ("Component"),
         Width         => 14,
         Minimum_Width => 8,
         Align         => Tables.Align_Left,
         Sortable      => True),
      Status_Column =>
        (Heading       => U ("Status"),
         Width         => 9,
         Minimum_Width => 6,
         Align         => Tables.Align_Left,
         Sortable      => True)];

   type Tree_Id is
     (Root_Node,
      Source_Node,
      Components_Node,
      Table_Node,
      Tree_Node,
      Examples_Node);
   type Tree_Entry is record
      Id    : Tree_Id;
      Depth : Natural;
   end record;

   function Tree_Identity (Item : Tree_Entry) return Tree_Id is (Item.Id);

   function Tree_Label (Item : Tree_Entry) return Wide_Wide_String is
     (case Item.Id is
         when Root_Node       => "flyology-tui",
         when Source_Node     => "src",
         when Components_Node => "components",
         when Table_Node      => "tables",
         when Tree_Node       => "trees",
         when Examples_Node   => "examples");

   function Tree_Depth (Item : Tree_Entry) return Natural is (Item.Depth);

   package Trees is new Flyology_TUI.Components.Trees
     (Item_Type => Tree_Entry,
      Id_Type   => Tree_Id,
      Id_Of     => Tree_Identity,
      Label     => Tree_Label,
      Depth_Of  => Tree_Depth,
      Capacity  => 8);

   type Accordion_Id is
     (Overview_Section, Identity_Section, Composition_Section);

   function Accordion_Identity
     (Item : Accordion_Id) return Accordion_Id is (Item);

   function Accordion_Label
     (Item : Accordion_Id) return Wide_Wide_String is
     (case Item is
         when Overview_Section    => "Overview",
         when Identity_Section    => "Stable identity",
         when Composition_Section => "Composition");

   package Accordions is new Flyology_TUI.Components.Accordions
     (Section_Type => Accordion_Id,
      Id_Type      => Accordion_Id,
      Id_Of        => Accordion_Identity,
      Label        => Accordion_Label,
      Capacity     => 6);

   No_Accordion_Bodies : constant Accordions.Body_Array (1 .. 0) :=
     [others =>
        (Id      => Overview_Section,
         Content => Flyology_TUI.Surfaces.Create (0, 0))];

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

   type Chat_Message_Id is
     (Welcome_Message,
      User_Request_Message,
      Assistant_Message,
      Tool_Message,
      Completion_Message);
   type Chat_Author_Id is
     (System_Author, User_Author, Assistant_Author, Tool_Author);

   function Chat_Author_Label
     (Author : Chat_Author_Id) return Wide_Wide_String is
     (case Author is
         when System_Author    => "system",
         when User_Author      => "you",
         when Assistant_Author => "assistant",
         when Tool_Author      => "telemetry tool");

   package Chats is new Flyology_TUI.Components.Chats
     (Message_Id   => Chat_Message_Id,
      Author_Id    => Chat_Author_Id,
      Author_Label => Chat_Author_Label,
      Capacity     => 8);

   Chat_Max_Viewport_Cells : constant Positive := 1_024;
   Fallback_Terminal_Width : constant Positive := 80;
   Fallback_Terminal_Height : constant Positive := 24;
   Fallback_Content_Height : constant Positive :=
     Fallback_Terminal_Height - 3;

   package Chat_Streams is new Flyology_TUI.Components.Streaming_Texts
     (Max_Code_Points    => 512,
      Max_Lines          => 32,
      Max_Viewport_Cells => Chat_Max_Viewport_Cells);

   function Make_Chat_Message
     (Id       : Chat_Message_Id;
      Author   : Chat_Author_Id;
      Role     : Chats.Message_Role;
      Delivery : Chats.Delivery_State := Chats.Delivered;
      Sequence : Natural := 0) return Chats.Message is
     (Id, Author, Role, Delivery, Sequence);

   Initial_Chat_Messages : constant Chats.Message_Array :=
     [Make_Chat_Message
        (Welcome_Message, System_Author, Chats.System),
      Make_Chat_Message
        (User_Request_Message, User_Author, Chats.User),
      Make_Chat_Message
        (Assistant_Message, Assistant_Author, Chats.Assistant,
         Chats.Streaming),
      Make_Chat_Message
        (Tool_Message, Tool_Author, Chats.Tool)];

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
      Breadcrumb_Field,
      Table_Field,
      Tree_Field,
      Accordion_Field,
      Text_Area_Field,
      Syntax_Field,
      Telemetry_Field,
      Chat_Field,
      Chat_Stream_Field,
      Horizontal_Group_Field,
      Vertical_Group_Field,
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
      Accordion_Capture,
      Text_Area_Capture,
      Syntax_Capture,
      Horizontal_Group_Capture,
      Vertical_Group_Capture,
      First_Window_Capture,
      Second_Window_Capture,
      Split_Capture,
      Vertical_Scroll_Capture,
      Horizontal_Scroll_Capture);

   type Layout_Snapshot is record
      Width, Height : Natural := 0;
      Header, Tabs, Content, Help : Flyology_TUI.Geometry.Rectangle;
      First, Second, Third, Fourth : Flyology_TUI.Geometry.Rectangle;
      Left_Full, Right_Full, Top_Full, Bottom_Full :
        Flyology_TUI.Geometry.Rectangle;
      Text_Content, List_Content : Flyology_TUI.Geometry.Rectangle;
      Viewport_Content, Form_Content : Flyology_TUI.Geometry.Rectangle;
      Button_Origin, Check_Origin, Radio_Origin : Flyology_TUI.Geometry.Point;
      Selector_Origin, Dropdown_Origin : Flyology_TUI.Geometry.Point;
      Telemetry_Origin, Breadcrumb_Origin : Flyology_TUI.Geometry.Point;
      Table_Origin, Tree_Origin : Flyology_TUI.Geometry.Point;
      Accordion_Origin : Flyology_TUI.Geometry.Point;
      Text_Area_Origin, Syntax_Origin : Flyology_TUI.Geometry.Point;
      Chat_Origin, Windows_Origin : Flyology_TUI.Geometry.Point;
      Window_Workspace : Flyology_TUI.Geometry.Rectangle;
      Vertical_Scroll_Origin : Flyology_TUI.Geometry.Point;
      Horizontal_Scroll_Origin : Flyology_TUI.Geometry.Point;
      Horizontal_Group_Origin : Flyology_TUI.Geometry.Point;
      Vertical_Group_Origin : Flyology_TUI.Geometry.Point;
      Horizontal_Group_Region : Flyology_TUI.Geometry.Rectangle;
      Vertical_Group_Region : Flyology_TUI.Geometry.Rectangle;
   end record;

   type Model is limited record
      Focus    : Focus_Target := Text_Field;
      Capture  : Capture_Target := No_Capture;
      Spinner  : Flyology_TUI.Components.Spinners.Model :=
        Flyology_TUI.Components.Spinners.Create;
      Progress : Flyology_TUI.Components.Progress.Model :=
        Flyology_TUI.Components.Progress.Create (32, False);
      Pages    : Kitchen_Sink.Pages.Model :=
        Kitchen_Sink.Pages.Create
          ([Basics_Page,
            Controls_Page,
            Navigation_Page,
            Editors_Page,
            Telemetry_Page,
            Chat_Page,
            Panels_Page,
            Windows_Page]);
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
      Breadcrumb : Kitchen_Sink.Breadcrumbs.Model :=
        Kitchen_Sink.Breadcrumbs.Create
          ([Workspace_Path, Project_Path, Examples_Path, Kitchen_Sink_Path],
           Maximum_Width => 30);
      Table : Kitchen_Sink.Tables.Model :=
        Kitchen_Sink.Tables.Create
          ([(Id => Runtime_Component, Priority => 2),
            (Id => Backend_Component, Priority => 1),
            (Id => Views_Component, Priority => 3),
            (Id => Tests_Component, Priority => 1)],
           Navigation_Columns,
           Viewport_Rows => 4);
      Tree : Kitchen_Sink.Trees.Model :=
        Kitchen_Sink.Trees.Create
          ([(Id => Root_Node, Depth => 0),
            (Id => Source_Node, Depth => 1),
            (Id => Components_Node, Depth => 2),
            (Id => Table_Node, Depth => 3),
            (Id => Tree_Node, Depth => 3),
            (Id => Examples_Node, Depth => 1)],
           Viewport_Rows => 4);
      Accordion : Kitchen_Sink.Accordions.Model :=
        Kitchen_Sink.Accordions.Create
          ([Overview_Section, Identity_Section, Composition_Section]);
      Text_Area : Flyology_TUI.Components.Text_Areas.Model
        (2_048, 128, 32, 8_192) :=
        Flyology_TUI.Components.Text_Areas.Create
          (2_048, 128, 32, 8_192, 28, 13, "Write bounded notes...");
      Syntax : Kitchen_Sink.Ada_Editors.Model
        (4_096, 256, 32, 12_288) :=
        Kitchen_Sink.Ada_Editors.Create
          (4_096, 256, 32, 12_288, 28, 13, "Ada source");
      Samples  : Kitchen_Sink.Samples.Series :=
        Kitchen_Sink.Samples.Create (32);
      Work     : Kitchen_Sink.Work_Progress.Model :=
        Kitchen_Sink.Work_Progress.Create (30);
      Telemetry_Tick : Natural range 0 .. 999 := 0;
      Chat : Kitchen_Sink.Chats.Model := Kitchen_Sink.Chats.Create
        (Initial_Chat_Messages, Viewport_Rows => 18);
      Chat_Stream : Kitchen_Sink.Chat_Streams.Model :=
        Kitchen_Sink.Chat_Streams.Create
          (Fallback_Terminal_Width, 2,
           Overflow => Kitchen_Sink.Chat_Streams.Trim_Oldest);
      Chat_Stream_Step : Natural range 0 .. 40 := 0;
      Chat_Has_Notice : Boolean := False;
      Horizontal_Group : Flyology_TUI.Components.Panel_Groups.Model :=
        Flyology_TUI.Components.Panel_Groups.Create
          (Flyology_TUI.Layouts.Boxes.Horizontal,
           Fallback_Terminal_Width, 8,
           [1 => (Minimum_Span => 8, Initial_Span => 18, Weight => 1),
            2 => (Minimum_Span => 8, Initial_Span => 24, Weight => 2),
            3 => (Minimum_Span => 8, Initial_Span => 18, Weight => 1)]);
      Vertical_Group : Flyology_TUI.Components.Panel_Groups.Model :=
        Flyology_TUI.Components.Panel_Groups.Create
          (Flyology_TUI.Layouts.Boxes.Vertical,
           Fallback_Terminal_Width, 10,
           [1 => (Minimum_Span => 2, Initial_Span => 3, Weight => 1),
            2 => (Minimum_Span => 2, Initial_Span => 3, Weight => 2),
            3 => (Minimum_Span => 2, Initial_Span => 2, Weight => 1)]);
      Split : Flyology_TUI.Components.Split_Panes.Model :=
        Flyology_TUI.Components.Split_Panes.Create
          (Flyology_TUI.Layouts.Boxes.Horizontal,
           Fallback_Terminal_Width, Fallback_Content_Height,
           First_Span => 25,
           First_Minimum => 10, Second_Minimum => 10);
      Vertical_Scroll : Flyology_TUI.Components.Scrollbars.Model :=
        Flyology_TUI.Components.Scrollbars.Create
          (Flyology_TUI.Layouts.Boxes.Vertical, Fallback_Content_Height);
      Horizontal_Scroll : Flyology_TUI.Components.Scrollbars.Model :=
        Flyology_TUI.Components.Scrollbars.Create
          (Flyology_TUI.Layouts.Boxes.Horizontal,
           Fallback_Terminal_Width);
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
      Terminal_Width : Natural := Fallback_Terminal_Width;
      Terminal_Height : Natural := Fallback_Terminal_Height;
   end record;

   package Events is new Flyology_TUI.Application_Events (Message);
   package Transitions is new Flyology_TUI.Transitions (Command);
   use type Events.Event_Kind;
   use type Chat_Streams.Stream_State;
   use type Flyology_TUI.Components.Interactions.Capture_Action;
   use type Flyology_TUI.Events.Key_Kind;
   use type Flyology_TUI.Events.Mouse_Action;
   use type Flyology_TUI.Events.Mouse_Button;
   use type Flyology_TUI.Events.Terminal_Event_Kind;

   Visual : constant Flyology_TUI.Themes.Theme := Flyology_TUI.Themes.Charm;

   function Current_Page (Item : Model) return Page_Id is
     (Item.Pages.Active_Id);

   function Chat_Stream_Height (Item : Model) return Natural;
   procedure Reconcile_Chat (Item : in out Model);

   function Inset_Panel
     (Region : Flyology_TUI.Geometry.Rectangle)
      return Flyology_TUI.Geometry.Rectangle
   is
     ((X      => Region.X + Integer (Natural'Min (2, Region.Width)),
       Y      => Region.Y + Integer (Natural'Min (4, Region.Height)),
       Width  => (if Region.Width > 4 then Region.Width - 4 else 0),
       Height => (if Region.Height > 5 then Region.Height - 5 else 0)));

   function Origin
     (Region : Flyology_TUI.Geometry.Rectangle)
      return Flyology_TUI.Geometry.Point is
     ((X => Region.X, Y => Region.Y));

   function Mouse_Region
     (Region : Flyology_TUI.Geometry.Rectangle)
      return Flyology_TUI.Mouse.Region is
     ((X      => Natural (Integer'Max (0, Region.X)),
       Y      => Natural (Integer'Max (0, Region.Y)),
       Width  => Region.Width,
       Height => Region.Height));

   function Layout (Item : Model) return Layout_Snapshot is
      Result : Layout_Snapshot;
      Content_Height : Natural;
      Gap : Natural;
      Left_Width, Right_Width : Natural;
      Top_Height, Bottom_Height : Natural;

      function Fits
        (Region : Flyology_TUI.Geometry.Rectangle) return Boolean is
        (Region.X >= 0
         and then Region.Y >= 0
         and then Natural (Region.X) <= Result.Width
         and then Natural (Region.Y) <= Result.Height
         and then Region.Width <= Result.Width - Natural (Region.X)
         and then Region.Height <= Result.Height - Natural (Region.Y));

   begin
      Result.Width := Item.Terminal_Width;
      Result.Height := Item.Terminal_Height;
      Result.Header :=
        (X => 0, Y => 0, Width => Result.Width,
         Height => (if Result.Height > 0 then 1 else 0));
      Result.Tabs :=
        (X => 0, Y => Integer (Natural'Min (1, Result.Height)),
         Width => Result.Width,
         Height => (if Result.Height > 1 then 1 else 0));
      Result.Help :=
        (X => 0,
         Y => (if Result.Height > 2 then Integer (Result.Height - 1)
               else Integer (Result.Height)),
         Width => Result.Width,
         Height => (if Result.Height > 2 then 1 else 0));
      Content_Height := (if Result.Height > 3 then Result.Height - 3 else 0);
      Result.Content :=
        (X => 0, Y => Integer (Natural'Min (2, Result.Height)),
         Width => Result.Width, Height => Content_Height);

      Gap := (if Result.Width > 1 then 1 else 0);
      if Result.Width >= 56 then
         Left_Width := (Result.Width - Gap) / 2;
         Right_Width := Result.Width - Gap - Left_Width;
      else
         Left_Width := Result.Width;
         Right_Width := 0;
      end if;
      Top_Height := Content_Height / 2;
      Bottom_Height := Content_Height - Top_Height;
      Result.Left_Full :=
        (X => 0, Y => Result.Content.Y,
         Width => Left_Width, Height => Content_Height);
      Result.Right_Full :=
        (X => Integer
           ((if Right_Width > 0 then Left_Width + Gap else Result.Width)),
         Y => Result.Content.Y,
         Width => Right_Width, Height => Content_Height);
      Result.Top_Full :=
        (X => 0, Y => Result.Content.Y,
         Width => Result.Width, Height => Top_Height);
      Result.Bottom_Full :=
        (X => 0, Y => Result.Content.Y + Integer (Top_Height),
         Width => Result.Width, Height => Bottom_Height);

      if Right_Width > 0 then
         Result.First :=
           (X => 0, Y => Result.Content.Y,
            Width => Left_Width, Height => Top_Height);
         Result.Second :=
           (X => Integer (Left_Width + Gap), Y => Result.Content.Y,
            Width => Right_Width, Height => Top_Height);
         Result.Third :=
           (X => 0, Y => Result.Content.Y + Integer (Top_Height),
            Width => Left_Width, Height => Bottom_Height);
         Result.Fourth :=
           (X => Integer (Left_Width + Gap),
            Y => Result.Content.Y + Integer (Top_Height),
            Width => Right_Width, Height => Bottom_Height);
      else
         declare
            First_Height : constant Natural := Content_Height / 4;
            Second_Height : constant Natural := Content_Height / 4;
            Third_Height : constant Natural := Content_Height / 4;
            Fourth_Height : constant Natural :=
              Content_Height - First_Height - Second_Height - Third_Height;
         begin
            Result.First :=
              (X => 0, Y => Result.Content.Y, Width => Result.Width,
               Height => First_Height);
            Result.Second :=
              (X => 0,
               Y => Result.Content.Y + Integer (First_Height),
               Width => Result.Width, Height => Second_Height);
            Result.Third :=
              (X => 0,
               Y => Result.Content.Y
                 + Integer (First_Height + Second_Height),
               Width => Result.Width, Height => Third_Height);
            Result.Fourth :=
              (X => 0,
               Y => Integer
                 (Natural (Result.Content.Y)
                  + First_Height + Second_Height + Third_Height),
               Width => Result.Width, Height => Fourth_Height);
         end;
      end if;

      Result.Text_Content := Inset_Panel (Result.First);
      Result.Text_Content.Height :=
        Natural'Min (1, Result.Text_Content.Height);
      Result.List_Content := Inset_Panel (Result.Third);
      Result.Viewport_Content := Inset_Panel (Result.Second);
      Result.Form_Content := Inset_Panel (Result.Fourth);
      Result.Button_Origin := Origin (Inset_Panel (Result.First));
      Result.Check_Origin :=
        (X => Result.Button_Origin.X, Y => Result.Button_Origin.Y + 2);
      Result.Radio_Origin := Origin (Inset_Panel (Result.Second));
      Result.Selector_Origin := Origin (Inset_Panel (Result.Third));
      Result.Dropdown_Origin := Origin (Inset_Panel (Result.Fourth));
      Result.Telemetry_Origin := Origin (Inset_Panel (Result.First));
      Result.Breadcrumb_Origin := Origin (Inset_Panel (Result.First));
      Result.Table_Origin := Origin (Inset_Panel (Result.Third));
      Result.Tree_Origin := Origin (Inset_Panel (Result.Second));
      Result.Accordion_Origin := Origin (Inset_Panel (Result.Fourth));
      if Result.Right_Full.Width > 0 then
         Result.Text_Area_Origin := Origin (Inset_Panel (Result.Left_Full));
         Result.Syntax_Origin := Origin (Inset_Panel (Result.Right_Full));
      else
         Result.Text_Area_Origin := Origin (Inset_Panel (Result.Top_Full));
         Result.Syntax_Origin := Origin (Inset_Panel (Result.Bottom_Full));
      end if;
      Result.Chat_Origin := Origin (Result.Content);
      Result.Windows_Origin := Origin (Result.Content);
      Result.Window_Workspace :=
        (X => 0, Y => 0,
         Width => Result.Content.Width, Height => Result.Content.Height);
      Result.Vertical_Scroll_Origin :=
        (X => Integer'Max (0, Integer (Result.Content.Width) - 1), Y => 0);
      Result.Horizontal_Scroll_Origin :=
        (X => 0,
         Y => Integer'Max (0, Integer (Result.Content.Height) - 1));
      Result.Horizontal_Group_Region := Result.Top_Full;
      Result.Vertical_Group_Region := Result.Bottom_Full;
      Result.Horizontal_Group_Origin := Origin (Result.Top_Full);
      Result.Vertical_Group_Origin := Origin (Result.Bottom_Full);
      if not Fits (Result.Header)
        or else not Fits (Result.Tabs)
        or else not Fits (Result.Help)
        or else not Fits (Result.Content)
        or else not Fits (Result.First)
        or else not Fits (Result.Second)
        or else not Fits (Result.Third)
        or else not Fits (Result.Fourth)
        or else not Fits (Result.Left_Full)
        or else not Fits (Result.Right_Full)
        or else not Fits (Result.Top_Full)
        or else not Fits (Result.Bottom_Full)
      then
         raise Program_Error with "responsive layout escaped terminal bounds";
      end if;
      return Result;
   end Layout;

   procedure Resize_Components
     (Item : in out Model; Geometry : Layout_Snapshot)
   is
      use type Chat_Streams.Operation_Result;
      Editor_Region, Syntax_Region : Flyology_TUI.Geometry.Rectangle;
      Stream_Height : constant Natural := Chat_Stream_Height (Item);
      Stream_Width : constant Natural :=
        Natural'Min
          (Geometry.Content.Width,
           Chat_Max_Viewport_Cells /
             Natural'Max (1, Stream_Height));
      Result : Chat_Streams.Operation_Result;
   begin
      if Geometry.Right_Full.Width > 0 then
         Editor_Region := Inset_Panel (Geometry.Left_Full);
         Syntax_Region := Inset_Panel (Geometry.Right_Full);
      else
         Editor_Region := Inset_Panel (Geometry.Top_Full);
         Syntax_Region := Inset_Panel (Geometry.Bottom_Full);
      end if;
      if Editor_Region.Width > 0 and then Editor_Region.Height > 0 then
         Item.Text_Area.Set_Size
           (Positive (Editor_Region.Width), Positive (Editor_Region.Height));
      end if;
      if Syntax_Region.Width > 0 and then Syntax_Region.Height > 0 then
         Item.Syntax.Set_Size
           (Positive (Syntax_Region.Width), Positive (Syntax_Region.Height));
      end if;
      if Geometry.Viewport_Content.Width > 0
        and then Geometry.Viewport_Content.Height > 0
      then
         Item.Viewport.Resize
           (Positive (Geometry.Viewport_Content.Width),
            Positive (Geometry.Viewport_Content.Height));
      end if;
      Item.Breadcrumb.Set_Maximum_Width (Geometry.First.Width);
      Item.Table.Set_Viewport_Rows
        ((if Geometry.Third.Height > 5 then Geometry.Third.Height - 5 else 0));
      Item.Tree.Set_Maximum_Width
        ((if Geometry.Second.Width > 4 then Geometry.Second.Width - 4 else 0));
      Item.Tree.Set_Viewport_Rows
        ((if Geometry.Second.Height > 5
          then Geometry.Second.Height - 5 else 0));
      Item.Chat.Set_Viewport_Rows (Geometry.Content.Height);
      Result := Item.Chat_Stream.Resize
        (Stream_Width, Stream_Height);
      if Result = Chat_Streams.Rejected_Geometry then
         raise Program_Error with "responsive chat geometry was rejected";
      end if;
      Item.Split.Resize
        (Geometry.Window_Workspace.Width, Geometry.Window_Workspace.Height);
      Item.Vertical_Scroll.Resize (Geometry.Window_Workspace.Height);
      Item.Horizontal_Scroll.Resize (Geometry.Window_Workspace.Width);
      Item.Vertical_Scroll.Configure
        (Total => 100,
         Page_Size => Geometry.Window_Workspace.Height,
         First => Item.Vertical_Scroll.First);
      Item.Horizontal_Scroll.Configure
        (Total => 180,
         Page_Size => Geometry.Window_Workspace.Width,
         First => Item.Horizontal_Scroll.First);
      Item.Window_A_Model.Constrain_To (Geometry.Window_Workspace);
      Item.Window_B_Model.Constrain_To (Geometry.Window_Workspace);
      Item.Horizontal_Group.Resize
        (Geometry.Horizontal_Group_Region.Width,
         Geometry.Horizontal_Group_Region.Height);
      Item.Vertical_Group.Resize
        (Geometry.Vertical_Group_Region.Width,
         Geometry.Vertical_Group_Region.Height);
   end Resize_Components;

   procedure Set_Terminal_Size
     (Item : in out Model; Width, Height : Natural) is
   begin
      Item.Terminal_Width := Width;
      Item.Terminal_Height := Height;
      Resize_Components (Item, Layout (Item));
      Reconcile_Chat (Item);
   end Set_Terminal_Size;

   function Accordion_Presentation
     (Item : Model; Width : Natural) return Accordions.Presentation
   is
      package Indicators renames Flyology_TUI.Components.Indicators;
      Overview_Body : constant Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Layouts.Join_Horizontally
          (Indicators.Badge ("borrowed", Indicators.Success_Tone, Visual),
           Flyology_TUI.Surfaces.From_Text ("render-time surface"),
           Gap => 1);
      Identity_Body : constant Flyology_TUI.Surfaces.Surface :=
        Indicators.Key_Value ("selection", "stable IDs", Width, Visual);
      Composition_Body : constant Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Layouts.Join_Vertically
          (Indicators.Divider (Width, "external body", Visual),
           Flyology_TUI.Surfaces.From_Text ("events stay with the app"));
   begin
      if Item.Accordion.Is_Expanded (Overview_Section) then
         return Item.Accordion.Present
           ([1 => (Id => Overview_Section, Content => Overview_Body)],
            Width, Visual, Item.Focus = Accordion_Field);
      elsif Item.Accordion.Is_Expanded (Identity_Section) then
         return Item.Accordion.Present
           ([1 => (Id => Identity_Section, Content => Identity_Body)],
            Width, Visual, Item.Focus = Accordion_Field);
      elsif Item.Accordion.Is_Expanded (Composition_Section) then
         return Item.Accordion.Present
           ([1 => (Id => Composition_Section, Content => Composition_Body)],
            Width, Visual, Item.Focus = Accordion_Field);
      else
         return Item.Accordion.Present
           (No_Accordion_Bodies, Width, Visual,
            Item.Focus = Accordion_Field);
      end if;
   end Accordion_Presentation;

   function Chat_Stream_Height (Item : Model) return Natural is
     (Natural'Max
        (2, Natural'Min (6, Item.Chat_Stream.Visual_Row_Count)));

   procedure Set_Chat_Messages
     (Item     : in out Model;
      Delivery : Chats.Delivery_State)
   is
   begin
      if Item.Chat_Has_Notice then
         Item.Chat.Set_Messages
           ([Make_Chat_Message
               (Welcome_Message, System_Author, Chats.System),
             Make_Chat_Message
               (User_Request_Message, User_Author, Chats.User),
             Make_Chat_Message
               (Assistant_Message, Assistant_Author, Chats.Assistant,
                Delivery, Item.Telemetry_Tick),
             Make_Chat_Message
               (Tool_Message, Tool_Author, Chats.Tool),
             Make_Chat_Message
               (Completion_Message, System_Author, Chats.Notice)]);
      else
         Item.Chat.Set_Messages
           ([Make_Chat_Message
               (Welcome_Message, System_Author, Chats.System),
             Make_Chat_Message
               (User_Request_Message, User_Author, Chats.User),
             Make_Chat_Message
               (Assistant_Message, Assistant_Author, Chats.Assistant,
                Delivery, Item.Telemetry_Tick),
             Make_Chat_Message
               (Tool_Message, Tool_Author, Chats.Tool)]);
      end if;
   end Set_Chat_Messages;

   procedure Reconcile_Chat (Item : in out Model) is
      Height : constant Natural := Item.Chat_Stream.Viewport_Height;
   begin
      if Item.Chat_Has_Notice then
         Item.Chat.Reconcile_Measurements
           ([(Welcome_Message, 2, 0),
             (User_Request_Message, 3, 1),
             (Assistant_Message, Height, 1),
             (Tool_Message, 4, 0),
             (Completion_Message, 1, 0)]);
      else
         Item.Chat.Reconcile_Measurements
           ([(Welcome_Message, 2, 0),
             (User_Request_Message, 3, 1),
             (Assistant_Message, Height, 1),
             (Tool_Message, 4, 0)]);
      end if;
   end Reconcile_Chat;

   function Chat_Body
     (Item : Model;
      Id   : Chat_Message_Id;
      Width : Natural) return Chats.Body_Entry
   is
      package Indicators renames Flyology_TUI.Components.Indicators;
      Empty : constant Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.Create (0, 0);
   begin
      case Id is
         when Welcome_Message =>
            return
              (Id      => Id,
               Content => Flyology_TUI.Surfaces.From_Text
                 ("This transcript owns metadata and viewport state."
                  & Wide_Wide_Character'Val (10)
                  & "Every message body remains caller-owned."),
               Actions => Empty);
         when User_Request_Message =>
            return
              (Id      => Id,
               Content => Flyology_TUI.Surfaces.From_Text
                 ("Build a bounded chat surface."
                  & Wide_Wide_Character'Val (10)
                  & "Keep ordinary, streaming, and component bodies."
                  & Wide_Wide_Character'Val (10)
                  & "Route child input before transcript input."),
               Actions => Indicators.Badge
                 ("request · stable id", Indicators.Neutral, Visual));
         when Assistant_Message =>
            return
              (Id      => Id,
               Content => Item.Chat_Stream.Render
                 (Visual, Item.Focus = Chat_Stream_Field),
               Actions => Indicators.Badge
                 ((if Item.Chat_Stream.State = Chat_Streams.Finished
                   then "complete · deterministic"
                   else "streaming · wheel this body"),
                  (if Item.Chat_Stream.State = Chat_Streams.Finished
                   then Indicators.Success_Tone
                   else Indicators.Warning_Tone),
                  Visual));
         when Tool_Message =>
            declare
               Aggregate : constant Work_Progress.Fraction :=
                 Item.Work.Weighted_Total;
               First : constant Flyology_TUI.Surfaces.Surface :=
                 Indicators.Divider (Width, "component body", Visual);
               Second : constant Flyology_TUI.Surfaces.Surface :=
                 Indicators.Gauge
                   (Indicators.Ratio (Aggregate),
                    Natural'Min (30, Width), Visual);
               Third : constant Flyology_TUI.Surfaces.Surface :=
                 Sparklines.Render
                   (Item.Samples, Width, Sparklines.Automatic, Visual);
               Fourth : constant Flyology_TUI.Surfaces.Surface :=
                 Indicators.Status_Line
                   ([Indicators.Make_Segment
                       ("NO NETWORK", Indicators.High,
                        Indicators.Success_Tone),
                     Indicators.Make_Segment
                       ("serial update", Indicators.Normal,
                        Indicators.Neutral)],
                    Width, Visual);
            begin
               return
                 (Id      => Id,
                  Content => Flyology_TUI.Layouts.Join_Vertically
                    (First,
                     Flyology_TUI.Layouts.Join_Vertically
                       (Second,
                        Flyology_TUI.Layouts.Join_Vertically
                          (Third, Fourth))),
                  Actions => Empty);
            end;
         when Completion_Message =>
            return
              (Id      => Id,
               Content => Flyology_TUI.Surfaces.From_Text
                 ("The bounded stream rolled old history, then finished."),
               Actions => Empty);
      end case;
   end Chat_Body;

   function Chat_Bodies
     (Item   : Model;
      Layout : Chats.Layout_Plan;
      Width  : Natural) return Chats.Body_Array
   is
      Count : constant Natural := Chats.Required_Body_Count (Layout);
      Result : Chats.Body_Array (1 .. Count) :=
        [others =>
           (Id      => Welcome_Message,
            Content => Flyology_TUI.Surfaces.Create (0, 0),
            Actions => Flyology_TUI.Surfaces.Create (0, 0))];
   begin
      for Position in Result'Range loop
         Result (Position) := Chat_Body
           (Item, Chats.Required_Body_Id (Layout, Position), Width);
      end loop;
      return Result;
   end Chat_Bodies;

   function Chat_Footer
     (Item : Model; Width : Natural) return Flyology_TUI.Surfaces.Surface
   is
      package Indicators renames Flyology_TUI.Components.Indicators;
   begin
      return Indicators.Key_Value
        ("chat viewport",
         (if Item.Chat.Follows_Tail then "following tail" else "detached")
           & " · unread"
           & Natural'Wide_Wide_Image (Item.Chat.Unread_Count)
           & " · stream unseen"
           & Natural'Wide_Wide_Image
               (Item.Chat_Stream.Unseen_Chunk_Count),
         Width, Visual);
   end Chat_Footer;

   function Chat_Composer
     (Width : Natural) return Flyology_TUI.Surfaces.Surface is
      Result : Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.Create (Width, 1, Visual.Input);
   begin
      Result.Write
        (0, 0, "> visual composer · input model intentionally external",
         Visual.Input);
      return Result;
   end Chat_Composer;

   function Chat_Presentation
     (Item : Model; Geometry : Layout_Snapshot) return Chats.Presentation
   is
      Width : constant Natural := Geometry.Content.Width;
      Footer : constant Flyology_TUI.Surfaces.Surface :=
        Chat_Footer (Item, Width);
      Composer : constant Flyology_TUI.Surfaces.Surface :=
        Chat_Composer (Width);
      Layout : constant Chats.Layout_Plan := Item.Chat.Plan
        (Width, Footer.Height, Composer.Height);
      Bodies : constant Chats.Body_Array := Chat_Bodies (Item, Layout, Width);
   begin
      return Item.Chat.Present
        (Bodies, Width, Footer, Composer, Visual,
         Has_Focus => Item.Focus in Chat_Field | Chat_Stream_Field);
   end Chat_Presentation;

   procedure Advance_Chat_Stream (Item : in out Model) is
      use type Chat_Streams.Operation_Result;
      Result : Chat_Streams.Operation_Result := Chat_Streams.Unchanged;
      New_Height : Natural;
   begin
      if Item.Chat_Stream_Step < 40 then
         case Item.Chat_Stream_Step mod 8 is
            when 0 =>
               Result := Item.Chat_Stream.Append
                 ("Planning a bounded response..."
                  & Wide_Wide_Character'Val (10));
            when 1 =>
               Result := Item.Chat_Stream.Append
                 ("Inspecting stable message ids."
                  & Wide_Wide_Character'Val (10));
            when 2 =>
               Result := Item.Chat_Stream.Append
                 ("Borrowing only visible body surfaces."
                  & Wide_Wide_Character'Val (10));
            when 3 =>
               Result := Item.Chat_Stream.Append
                 ("Measuring wrapped output synchronously."
                  & Wide_Wide_Character'Val (10));
            when 4 =>
               Result := Item.Chat_Stream.Append
                 ("Routing child geometry before the transcript."
                  & Wide_Wide_Character'Val (10));
            when 5 =>
               Result := Item.Chat_Stream.Append
                 ("No task, callback, transport, or retained view."
                  & Wide_Wide_Character'Val (10));
            when 6 =>
               Result := Item.Chat_Stream.Append
                 ("Updating follow-tail through one serial owner."
                  & Wide_Wide_Character'Val (10));
            when others =>
               Result := Item.Chat_Stream.Append
                 ("Rolling bounded history without replacing the model."
                  & Wide_Wide_Character'Val (10));
         end case;
         Item.Chat_Stream_Step := Item.Chat_Stream_Step + 1;
      elsif Item.Chat_Stream.State = Chat_Streams.Streaming then
         Result := Item.Chat_Stream.Finish;
         Item.Chat_Has_Notice := True;
         Set_Chat_Messages (Item, Chats.Delivered);
      else
         return;
      end if;

      if Result in Chat_Streams.Rejected_Capacity
        | Chat_Streams.Rejected_State
        | Chat_Streams.Rejected_Geometry
      then
         raise Program_Error with "kitchen-sink stream transition rejected";
      end if;
      New_Height := Chat_Stream_Height (Item);
      Result := Item.Chat_Stream.Resize
        (Natural'Min
           (Item.Terminal_Width,
            Chat_Max_Viewport_Cells / Natural'Max (1, New_Height)),
         New_Height);
      if Result = Chat_Streams.Rejected_Geometry then
         raise Program_Error with "kitchen-sink stream resize rejected";
      end if;
      Reconcile_Chat (Item);
   end Advance_Chat_Stream;

   procedure Activate (Item : in out Model; Target : Focus_Target) is
   begin
      Item.Input.Blur;
      Item.Window_A_Model.Blur;
      Item.Window_B_Model.Blur;
      Item.Split.Blur;
      Item.Vertical_Scroll.Blur;
      Item.Horizontal_Scroll.Blur;
      Item.Text_Area.Blur;
      Item.Syntax.Blur;
      Item.Horizontal_Group.Blur;
      Item.Vertical_Group.Blur;
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
         when Text_Area_Field => Item.Text_Area.Focus;
         when Syntax_Field => Item.Syntax.Focus;
         when Horizontal_Group_Field => Item.Horizontal_Group.Focus;
         when Vertical_Group_Field => Item.Vertical_Group.Focus;
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
      Item.Tree.Set_Expanded (Root_Node);
      Item.Tree.Set_Expanded (Source_Node);
      Item.Tree.Set_Expanded (Components_Node);
      Item.Accordion.Set_Expanded (Overview_Section);
      Advance_Chat_Stream (Item);
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
        (Total => 180,
         Page_Size => Fallback_Terminal_Width,
         First => 42);
      declare
         Accepted : Boolean;
      begin
         Item.Text_Area.Try_Set_Text
           ("No-wrap scratchpad — λ and 🐝 stay whole."
            & Wide_Wide_Character'Val (10)
            & "Use arrows, selection, paste, undo, and the mouse."
            & Wide_Wide_Character'Val (10)
            & "This deliberately long line demonstrates horizontal "
            & "scrolling without changing the shared editor model.",
            Accepted);
         if not Accepted then
            raise Program_Error with "kitchen-sink text area seed overflow";
         end if;
         Item.Text_Area.Set_Wrap
           (Flyology_TUI.Components.Text_Areas.No_Wrap);
         Item.Syntax.Try_Set_Text
           ("with Ada.Text_IO;" & Wide_Wide_Character'Val (10)
            & Wide_Wide_Character'Val (10)
            & "procedure Hello is" & Wide_Wide_Character'Val (10)
            & "   Message : constant String := ""Hello, λ!"";"
            & Wide_Wide_Character'Val (10)
            & "begin" & Wide_Wide_Character'Val (10)
            & "   --  Highlighting advances on the app's budget."
            & Wide_Wide_Character'Val (10)
            & "   Ada.Text_IO.Put_Line (Message);"
            & Wide_Wide_Character'Val (10)
            & "end Hello;",
            Accepted);
         if not Accepted then
            raise Program_Error with "kitchen-sink syntax seed overflow";
         end if;
         Item.Syntax.Set_Wrap
           (Flyology_TUI.Components.Text_Areas.Soft_Wrap);
         Item.Syntax.Advance_Highlighting (32);
      end;
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
      when Navigation_Page =>
         if Item.Focus not in
           Page_Navigation | Breadcrumb_Field .. Accordion_Field
         then
            Activate (Item, Breadcrumb_Field);
            return;
         end if;
         if Backwards then
            Activate
              (Item,
               (case Item.Focus is
                   when Page_Navigation  => Accordion_Field,
                   when Breadcrumb_Field => Page_Navigation,
                   when Table_Field      => Breadcrumb_Field,
                   when Tree_Field       => Table_Field,
                   when Accordion_Field  => Tree_Field,
                   when others           => Breadcrumb_Field));
         else
            Activate
              (Item,
               (case Item.Focus is
                   when Page_Navigation  => Breadcrumb_Field,
                   when Breadcrumb_Field => Table_Field,
                   when Table_Field      => Tree_Field,
                   when Tree_Field       => Accordion_Field,
                   when Accordion_Field  => Page_Navigation,
                   when others           => Breadcrumb_Field));
         end if;
      when Editors_Page =>
         if Item.Focus not in
           Page_Navigation | Text_Area_Field | Syntax_Field
         then
            Activate (Item, Text_Area_Field);
            return;
         end if;
         if Backwards then
            Activate
              (Item,
               (case Item.Focus is
                   when Page_Navigation => Syntax_Field,
                   when Text_Area_Field => Page_Navigation,
                   when Syntax_Field    => Text_Area_Field,
                   when others          => Text_Area_Field));
         else
            Activate
              (Item,
               (case Item.Focus is
                   when Page_Navigation => Text_Area_Field,
                   when Text_Area_Field => Syntax_Field,
                   when Syntax_Field    => Page_Navigation,
                   when others          => Text_Area_Field));
         end if;
      when Chat_Page =>
         if Item.Focus not in
           Page_Navigation | Chat_Field | Chat_Stream_Field
         then
            Activate (Item, Chat_Field);
            return;
         end if;
         if Backwards then
            Activate
              (Item,
               (case Item.Focus is
                   when Page_Navigation => Chat_Stream_Field,
                   when Chat_Field      => Page_Navigation,
                   when Chat_Stream_Field => Chat_Field,
                   when others          => Chat_Field));
         else
            Activate
              (Item,
               (case Item.Focus is
                   when Page_Navigation => Chat_Field,
                   when Chat_Field      => Chat_Stream_Field,
                   when Chat_Stream_Field => Page_Navigation,
                   when others          => Chat_Field));
         end if;
      when Panels_Page =>
         if Item.Focus not in
           Page_Navigation | Horizontal_Group_Field | Vertical_Group_Field
         then
            Activate (Item, Horizontal_Group_Field);
            return;
         end if;
         if Backwards then
            Activate
              (Item,
               (case Item.Focus is
                   when Page_Navigation => Vertical_Group_Field,
                   when Horizontal_Group_Field => Page_Navigation,
                   when Vertical_Group_Field => Horizontal_Group_Field,
                   when others => Horizontal_Group_Field));
         else
            Activate
              (Item,
               (case Item.Focus is
                   when Page_Navigation => Horizontal_Group_Field,
                   when Horizontal_Group_Field => Vertical_Group_Field,
                   when Vertical_Group_Field => Page_Navigation,
                   when others => Horizontal_Group_Field));
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
         when Navigation_Page =>
            if Item.Focus not in
              Page_Navigation | Breadcrumb_Field .. Accordion_Field
            then
               Activate (Item, Breadcrumb_Field);
            end if;
         when Editors_Page =>
            if Item.Focus not in
              Page_Navigation | Text_Area_Field | Syntax_Field
            then
               Activate (Item, Text_Area_Field);
            end if;
         when Chat_Page =>
            if Item.Focus not in
              Page_Navigation | Chat_Field | Chat_Stream_Field
            then
               Activate (Item, Chat_Field);
            end if;
         when Panels_Page =>
            if Item.Focus not in
              Page_Navigation | Horizontal_Group_Field | Vertical_Group_Field
            then
               Activate (Item, Horizontal_Group_Field);
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
      Event : Flyology_TUI.Events.Mouse_Event;
      Geometry : Layout_Snapshot) is
      use Flyology_TUI.Components.Interactions;
      Result : Update_Result;
      Page_Event : Flyology_TUI.Mouse.Local_Event;
   begin
      case Item.Capture is
         when No_Capture => return;
         when Page_Capture =>
            Result := Item.Pages.Handle
              (Flyology_TUI.Mouse.Relative (Event, Origin (Geometry.Tabs)));
            Apply_Result (Item, Page_Navigation, Page_Capture, Result);
            Normalize_Focus (Item);
         when Button_Capture =>
            Result := Item.Button.Handle
              (Flyology_TUI.Mouse.Relative (Event, Geometry.Button_Origin));
            Apply_Result (Item, Button_Field, Button_Capture, Result);
         when Check_Capture =>
            Result := Item.Check.Handle
              (Flyology_TUI.Mouse.Relative (Event, Geometry.Check_Origin));
            Apply_Result (Item, Check_Field, Check_Capture, Result);
         when Radio_Capture =>
            Result := Item.Radios.Handle
              (Flyology_TUI.Mouse.Relative (Event, Geometry.Radio_Origin));
            Apply_Result (Item, Radio_Field, Radio_Capture, Result);
         when Selector_Capture =>
            Result := Item.Selector.Handle
              (Flyology_TUI.Mouse.Relative (Event, Geometry.Selector_Origin));
            Apply_Result (Item, Selector_Field, Selector_Capture, Result);
         when Dropdown_Capture =>
            Result := Item.Dropdown.Handle
              (Flyology_TUI.Mouse.Relative (Event, Geometry.Dropdown_Origin));
            Apply_Result (Item, Dropdown_Field, Dropdown_Capture, Result);
         when Accordion_Capture =>
            declare
               Presentation : constant Accordions.Presentation :=
                 Accordion_Presentation
                   (Item, Inset_Panel (Geometry.Fourth).Width);
            begin
               Result := Item.Accordion.Handle
                 (Flyology_TUI.Mouse.Relative
                    (Event, Geometry.Accordion_Origin), Presentation);
               Apply_Result
                 (Item, Accordion_Field, Accordion_Capture, Result);
            end;
         when Text_Area_Capture =>
            Result := Item.Text_Area.Handle
              (Flyology_TUI.Mouse.Relative
                 (Event, Geometry.Text_Area_Origin));
            Apply_Result
              (Item, Text_Area_Field, Text_Area_Capture, Result);
            Normalize_Focus (Item);
         when Syntax_Capture =>
            Result := Item.Syntax.Handle
              (Flyology_TUI.Mouse.Relative (Event, Geometry.Syntax_Origin));
            Apply_Result (Item, Syntax_Field, Syntax_Capture, Result);
            if Result.Changed then
               Item.Syntax.Advance_Highlighting (4);
            end if;
            Normalize_Focus (Item);
         when Horizontal_Group_Capture =>
            Result := Item.Horizontal_Group.Handle
              (Flyology_TUI.Mouse.Relative
                 (Event, Geometry.Horizontal_Group_Origin));
            Apply_Result
              (Item, Horizontal_Group_Field,
               Horizontal_Group_Capture, Result);
         when Vertical_Group_Capture =>
            Result := Item.Vertical_Group.Handle
              (Flyology_TUI.Mouse.Relative
                 (Event, Geometry.Vertical_Group_Origin));
            Apply_Result
              (Item, Vertical_Group_Field, Vertical_Group_Capture, Result);
         when First_Window_Capture =>
            Page_Event :=
              Flyology_TUI.Mouse.Relative (Event, Geometry.Windows_Origin);
            Result := Item.Window_A_Model.Handle
              (Page_Event, Geometry.Window_Workspace);
            Apply_Window_Result (Item, Window_A, Result);
         when Second_Window_Capture =>
            Page_Event :=
              Flyology_TUI.Mouse.Relative (Event, Geometry.Windows_Origin);
            Result := Item.Window_B_Model.Handle
              (Page_Event, Geometry.Window_Workspace);
            Apply_Window_Result (Item, Window_B, Result);
         when Split_Capture =>
            Page_Event :=
              Flyology_TUI.Mouse.Relative (Event, Geometry.Windows_Origin);
            Result := Item.Split.Handle (Page_Event);
            Apply_Result (Item, Split_Field, Split_Capture, Result);
         when Vertical_Scroll_Capture =>
            Page_Event :=
              Flyology_TUI.Mouse.Relative (Event, Geometry.Windows_Origin);
            Result := Item.Vertical_Scroll.Handle
              (Flyology_TUI.Mouse.Relative
                 (Page_Event, Geometry.Vertical_Scroll_Origin));
            Apply_Result
              (Item, Vertical_Scroll_Field,
               Vertical_Scroll_Capture, Result);
         when Horizontal_Scroll_Capture =>
            Page_Event :=
              Flyology_TUI.Mouse.Relative (Event, Geometry.Windows_Origin);
            Result := Item.Horizontal_Scroll.Handle
              (Flyology_TUI.Mouse.Relative
                 (Page_Event, Geometry.Horizontal_Scroll_Origin));
            Apply_Result
              (Item, Horizontal_Scroll_Field,
               Horizontal_Scroll_Capture, Result);
      end case;
   end Route_Captured_Mouse;

   procedure Handle_Controls_Mouse
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Mouse_Event;
      Geometry : Layout_Snapshot) is
      use Flyology_TUI.Components.Interactions;
      Button_Bounds : constant Flyology_TUI.Geometry.Rectangle :=
        (X => Geometry.Button_Origin.X,
         Y => Geometry.Button_Origin.Y,
         Width => Item.Button.Width,
         Height => 1);
      Check_Bounds : constant Flyology_TUI.Geometry.Rectangle :=
        (X => Geometry.Check_Origin.X,
         Y => Geometry.Check_Origin.Y,
         Width => Item.Check.Width,
         Height => 1);
      Radio_View : constant Flyology_TUI.Surfaces.Surface :=
        Item.Radios.Render (Visual, Item.Focus = Radio_Field);
      Radio_Bounds : constant Flyology_TUI.Geometry.Rectangle :=
        (X => Geometry.Radio_Origin.X,
         Y => Geometry.Radio_Origin.Y,
         Width => Flyology_TUI.Surfaces.Width (Radio_View),
         Height => Flyology_TUI.Surfaces.Height (Radio_View));
      Selector_View : constant Flyology_TUI.Surfaces.Surface :=
        Item.Selector.Render (Visual, Item.Focus = Selector_Field);
      Selector_Bounds : constant Flyology_TUI.Geometry.Rectangle :=
        (X => Geometry.Selector_Origin.X,
         Y => Geometry.Selector_Origin.Y,
         Width => Flyology_TUI.Surfaces.Width (Selector_View),
         Height => Flyology_TUI.Surfaces.Height (Selector_View));
      Dropdown_Bounds : constant Flyology_TUI.Geometry.Rectangle :=
        (X => Geometry.Dropdown_Origin.X,
         Y => Geometry.Dropdown_Origin.Y,
         Width => Item.Dropdown.Width,
         Height => Item.Dropdown.Height);
      Point : constant Flyology_TUI.Geometry.Point :=
        (X => Integer (Event.X), Y => Integer (Event.Y));
      Result : Update_Result;
   begin
      if Flyology_TUI.Geometry.Contains (Button_Bounds, Point) then
         Result := Item.Button.Handle
           (Flyology_TUI.Mouse.Relative (Event, Geometry.Button_Origin));
         Apply_Result (Item, Button_Field, Button_Capture, Result);
      elsif Flyology_TUI.Geometry.Contains (Check_Bounds, Point) then
         Result := Item.Check.Handle
           (Flyology_TUI.Mouse.Relative (Event, Geometry.Check_Origin));
         Apply_Result (Item, Check_Field, Check_Capture, Result);
      elsif Flyology_TUI.Geometry.Contains (Radio_Bounds, Point) then
         Result := Item.Radios.Handle
           (Flyology_TUI.Mouse.Relative (Event, Geometry.Radio_Origin));
         Apply_Result (Item, Radio_Field, Radio_Capture, Result);
      elsif Flyology_TUI.Geometry.Contains (Selector_Bounds, Point) then
         Result := Item.Selector.Handle
           (Flyology_TUI.Mouse.Relative (Event, Geometry.Selector_Origin));
         Apply_Result (Item, Selector_Field, Selector_Capture, Result);
      elsif Flyology_TUI.Geometry.Contains (Dropdown_Bounds, Point) then
         Result := Item.Dropdown.Handle
           (Flyology_TUI.Mouse.Relative (Event, Geometry.Dropdown_Origin));
         Apply_Result (Item, Dropdown_Field, Dropdown_Capture, Result);
      end if;
   end Handle_Controls_Mouse;

   procedure Handle_Telemetry_Mouse
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Mouse_Event;
      Geometry : Layout_Snapshot) is
      use Flyology_TUI.Components.Interactions;
      Work_View : constant Flyology_TUI.Surfaces.Surface :=
        Item.Work.Render (Visual);
      Work_Bounds : constant Flyology_TUI.Geometry.Rectangle :=
        (X => Geometry.Telemetry_Origin.X,
         Y => Geometry.Telemetry_Origin.Y,
         Width => Flyology_TUI.Surfaces.Width (Work_View),
         Height => Flyology_TUI.Surfaces.Height (Work_View));
      Point : constant Flyology_TUI.Geometry.Point :=
        (X => Integer (Event.X), Y => Integer (Event.Y));
      Result : Update_Result;
   begin
      if Flyology_TUI.Geometry.Contains (Work_Bounds, Point) then
         Result := Item.Work.Handle
           (Flyology_TUI.Mouse.Relative (Event, Geometry.Telemetry_Origin));
         Apply_Result (Item, Telemetry_Field, No_Capture, Result);
      end if;
   end Handle_Telemetry_Mouse;

   procedure Handle_Navigation_Mouse
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Mouse_Event;
      Geometry : Layout_Snapshot) is
      use Flyology_TUI.Components.Interactions;
      Point : constant Flyology_TUI.Geometry.Point :=
        (X => Integer (Event.X), Y => Integer (Event.Y));
      Breadcrumb_Bounds : constant Flyology_TUI.Geometry.Rectangle :=
        (X      => Geometry.Breadcrumb_Origin.X,
         Y      => Geometry.Breadcrumb_Origin.Y,
         Width  => Item.Breadcrumb.Width,
         Height => (if Item.Breadcrumb.Is_Empty then 0 else 1));
      Table_Bounds : constant Flyology_TUI.Geometry.Rectangle :=
        (X      => Geometry.Table_Origin.X,
         Y      => Geometry.Table_Origin.Y,
         Width  => Item.Table.Width,
         Height => Item.Table.Height);
      Tree_Bounds : constant Flyology_TUI.Geometry.Rectangle :=
        (X      => Geometry.Tree_Origin.X,
         Y      => Geometry.Tree_Origin.Y,
         Width  => Item.Tree.Width,
         Height => Item.Tree.Height);
      Presentation : constant Accordions.Presentation :=
        Accordion_Presentation (Item, Inset_Panel (Geometry.Fourth).Width);
      Accordion_Frame : constant Flyology_TUI.Surfaces.Surface :=
        Accordions.Frame (Presentation);
      Accordion_Bounds : constant Flyology_TUI.Geometry.Rectangle :=
        (X      => Geometry.Accordion_Origin.X,
         Y      => Geometry.Accordion_Origin.Y,
         Width  => Accordion_Frame.Width,
         Height => Accordion_Frame.Height);
      Result : Update_Result;
   begin
      if Flyology_TUI.Geometry.Contains (Breadcrumb_Bounds, Point) then
         Result := Item.Breadcrumb.Handle
           (Flyology_TUI.Mouse.Relative (Event, Geometry.Breadcrumb_Origin));
         Apply_Result
           (Item, Breadcrumb_Field, No_Capture, Result);
      elsif Flyology_TUI.Geometry.Contains (Table_Bounds, Point) then
         Result := Item.Table.Handle
           (Flyology_TUI.Mouse.Relative (Event, Geometry.Table_Origin));
         Apply_Result (Item, Table_Field, No_Capture, Result);
      elsif Flyology_TUI.Geometry.Contains (Tree_Bounds, Point) then
         Result := Item.Tree.Handle
           (Flyology_TUI.Mouse.Relative (Event, Geometry.Tree_Origin));
         Apply_Result (Item, Tree_Field, No_Capture, Result);
      elsif Flyology_TUI.Geometry.Contains (Accordion_Bounds, Point) then
         --  Accordion consumes only its header regions. Events in the
         --  externally owned body surfaces remain unhandled by the model.
         Result := Item.Accordion.Handle
           (Flyology_TUI.Mouse.Relative
              (Event, Geometry.Accordion_Origin), Presentation);
         Apply_Result
           (Item, Accordion_Field, Accordion_Capture, Result);
      end if;
   end Handle_Navigation_Mouse;

   procedure Handle_Editors_Mouse
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Mouse_Event;
      Geometry : Layout_Snapshot) is
      use Flyology_TUI.Components.Interactions;
      Point : constant Flyology_TUI.Geometry.Point :=
        (X => Integer (Event.X), Y => Integer (Event.Y));
      Text_Bounds : constant Flyology_TUI.Geometry.Rectangle :=
        (X      => Geometry.Text_Area_Origin.X,
         Y      => Geometry.Text_Area_Origin.Y,
         Width  => Item.Text_Area.Width,
         Height => Item.Text_Area.Height);
      Syntax_Bounds : constant Flyology_TUI.Geometry.Rectangle :=
        (X      => Geometry.Syntax_Origin.X,
         Y      => Geometry.Syntax_Origin.Y,
         Width  => Item.Syntax.Width,
         Height => Item.Syntax.Height);
      Result : Update_Result;
   begin
      if Flyology_TUI.Geometry.Contains (Text_Bounds, Point) then
         Result := Item.Text_Area.Handle
           (Flyology_TUI.Mouse.Relative
              (Event, Geometry.Text_Area_Origin));
         Apply_Result
           (Item, Text_Area_Field, Text_Area_Capture, Result);
      elsif Flyology_TUI.Geometry.Contains (Syntax_Bounds, Point) then
         Result := Item.Syntax.Handle
           (Flyology_TUI.Mouse.Relative (Event, Geometry.Syntax_Origin));
         Apply_Result (Item, Syntax_Field, Syntax_Capture, Result);
         if Result.Changed then
            Item.Syntax.Advance_Highlighting (4);
         end if;
      end if;
   end Handle_Editors_Mouse;

   procedure Handle_Chat_Mouse
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Mouse_Event;
      Geometry : Layout_Snapshot)
   is
      use Flyology_TUI.Components.Interactions;
      Presentation : constant Chats.Presentation :=
        Chat_Presentation (Item, Geometry);
      Plan : constant Chats.Layout_Plan := Chats.Layout (Presentation);
      Local : constant Flyology_TUI.Mouse.Local_Event :=
        Flyology_TUI.Mouse.Relative (Event, Geometry.Chat_Origin);
      Point : constant Flyology_TUI.Geometry.Point :=
        (X => Local.X, Y => Local.Y);
      Result : Update_Result;
   begin
      --  Child regions are application-owned. Route them before asking Chat
      --  to handle header or transcript-background input.
      for Position in 1 .. Chats.Required_Body_Count (Plan) loop
         declare
            Id : constant Chat_Message_Id :=
              Chats.Required_Body_Id (Plan, Position);
            Body_Area : constant Flyology_TUI.Geometry.Rectangle :=
              Chats.Body_Region (Presentation, Id);
         begin
            if Flyology_TUI.Geometry.Contains (Body_Area, Point) then
               if Id = Assistant_Message then
                  Result := Item.Chat_Stream.Handle
                    (Flyology_TUI.Mouse.Relative
                       (Local, (X => Body_Area.X, Y => Body_Area.Y)));
                  Apply_Result
                    (Item, Chat_Stream_Field, No_Capture, Result);
               elsif Event.Action = Flyology_TUI.Events.Mouse_Click
                 and then Event.Button = Flyology_TUI.Events.Left_Button
               then
                  Item.Chat.Select_Id (Id);
                  Activate (Item, Chat_Field);
               end if;
               return;
            elsif Chats.Has_Action_Region (Presentation, Id) then
               declare
                  Action_Area : constant
                    Flyology_TUI.Geometry.Rectangle :=
                      Chats.Action_Region (Presentation, Id);
               begin
                  if Flyology_TUI.Geometry.Contains (Action_Area, Point) then
                     if Event.Action = Flyology_TUI.Events.Mouse_Click
                       and then
                         Event.Button = Flyology_TUI.Events.Left_Button
                     then
                        Item.Chat.Select_Id (Id);
                        Activate (Item, Chat_Field);
                     end if;
                     return;
                  end if;
               end;
            end if;
         end;
      end loop;

      Result := Item.Chat.Handle (Local, Presentation);
      Apply_Result (Item, Chat_Field, No_Capture, Result);
   end Handle_Chat_Mouse;

   procedure Handle_Windows_Mouse
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Mouse_Event;
      Geometry : Layout_Snapshot) is
      use Flyology_TUI.Components.Interactions;
      Page_Event : constant Flyology_TUI.Mouse.Local_Event :=
        Flyology_TUI.Mouse.Relative (Event, Geometry.Windows_Origin);
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
              (Page_Event, Geometry.Window_Workspace);
         else
            Result := Item.Window_B_Model.Handle
              (Page_Event, Geometry.Window_Workspace);
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
        ((X => Geometry.Vertical_Scroll_Origin.X,
          Y => Geometry.Vertical_Scroll_Origin.Y,
          Width => 1,
          Height => Geometry.Window_Workspace.Height),
         Point)
      then
         Result := Item.Vertical_Scroll.Handle
           (Flyology_TUI.Mouse.Relative
              (Page_Event, Geometry.Vertical_Scroll_Origin));
         Apply_Result
           (Item, Vertical_Scroll_Field, Vertical_Scroll_Capture, Result);
      elsif Flyology_TUI.Geometry.Contains
        ((X => Geometry.Horizontal_Scroll_Origin.X,
          Y => Geometry.Horizontal_Scroll_Origin.Y,
          Width => Geometry.Window_Workspace.Width,
          Height => 1),
         Point)
      then
         Result := Item.Horizontal_Scroll.Handle
           (Flyology_TUI.Mouse.Relative
              (Page_Event, Geometry.Horizontal_Scroll_Origin));
         Apply_Result
           (Item, Horizontal_Scroll_Field,
            Horizontal_Scroll_Capture, Result);
      elsif Flyology_TUI.Geometry.Contains
        (Geometry.Window_Workspace, Point)
      then
         Result := Item.Split.Handle (Page_Event);
         Apply_Result (Item, Split_Field, Split_Capture, Result);
      end if;
   end Handle_Windows_Mouse;

   procedure Handle_Panels_Mouse
     (Item : in out Model;
      Event : Flyology_TUI.Events.Mouse_Event;
      Geometry : Layout_Snapshot)
   is
      use Flyology_TUI.Components.Interactions;
      Point : constant Flyology_TUI.Geometry.Point :=
        (X => Integer (Event.X), Y => Integer (Event.Y));
      Result : Update_Result;
   begin
      if Flyology_TUI.Geometry.Contains
        (Geometry.Horizontal_Group_Region, Point)
      then
         Result := Item.Horizontal_Group.Handle
           (Flyology_TUI.Mouse.Relative
              (Event, Geometry.Horizontal_Group_Origin));
         Apply_Result
           (Item, Horizontal_Group_Field, Horizontal_Group_Capture, Result);
      elsif Flyology_TUI.Geometry.Contains
        (Geometry.Vertical_Group_Region, Point)
      then
         Result := Item.Vertical_Group.Handle
           (Flyology_TUI.Mouse.Relative
              (Event, Geometry.Vertical_Group_Origin));
         Apply_Result
           (Item, Vertical_Group_Field, Vertical_Group_Capture, Result);
      end if;
   end Handle_Panels_Mouse;

   procedure Handle_Mouse
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Terminal_Event) is
      use Flyology_TUI.Components.Interactions;
      Geometry : constant Layout_Snapshot := Layout (Item);
      Tabs_Bounds : constant Flyology_TUI.Geometry.Rectangle :=
        (X => Geometry.Tabs.X,
         Y => Geometry.Tabs.Y,
         Width => Natural'Min (Item.Pages.Width, Geometry.Tabs.Width),
         Height => Geometry.Tabs.Height);
      Point : constant Flyology_TUI.Geometry.Point :=
        (X => Integer (Event.Mouse.X), Y => Integer (Event.Mouse.Y));
      Result : Update_Result;
   begin
      if Item.Capture /= No_Capture then
         Route_Captured_Mouse (Item, Event.Mouse, Geometry);
         return;
      end if;

      if Current_Page (Item) = Controls_Page
        and then Item.Dropdown.Is_Open
        and then Event.Mouse.Action = Flyology_TUI.Events.Mouse_Click
        and then Event.Mouse.Button = Flyology_TUI.Events.Left_Button
      then
         declare
            Dropdown_Bounds : constant Flyology_TUI.Geometry.Rectangle :=
              (X => Geometry.Dropdown_Origin.X,
               Y => Geometry.Dropdown_Origin.Y,
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
           (Flyology_TUI.Mouse.Relative (Event.Mouse, Origin (Geometry.Tabs)));
         Apply_Result (Item, Page_Navigation, Page_Capture, Result);
         Normalize_Focus (Item);
         return;
      end if;

      case Current_Page (Item) is
      when Basics_Page =>
         if Event.Mouse.Action = Flyology_TUI.Events.Mouse_Click
           and then Event.Mouse.Button = Flyology_TUI.Events.Left_Button
         then
            if Flyology_TUI.Geometry.Contains (Geometry.First, Point) then
               Activate (Item, Text_Field);
            elsif Flyology_TUI.Geometry.Contains (Geometry.Third, Point) then
               Activate (Item, List_Field);
            elsif Flyology_TUI.Geometry.Contains (Geometry.Second, Point)
            then
               Activate (Item, Viewport_Field);
            elsif Flyology_TUI.Geometry.Contains (Geometry.Fourth, Point) then
               Activate (Item, Form_Field);
            end if;
         end if;

         if Flyology_TUI.Geometry.Contains (Geometry.Text_Content, Point) then
            Item.Input.Update
              (Flyology_TUI.Mouse.Localize
                 (Event, Mouse_Region (Geometry.Text_Content)));
         elsif Flyology_TUI.Geometry.Contains
           (Geometry.List_Content, Point)
         then
            Item.Choices.Update
              (Flyology_TUI.Mouse.Localize
                 (Event, Mouse_Region (Geometry.List_Content)));
         elsif Flyology_TUI.Geometry.Contains
           (Geometry.Viewport_Content, Point)
         then
            Item.Viewport.Update
              (Flyology_TUI.Mouse.Localize
                 (Event, Mouse_Region (Geometry.Viewport_Content)));
         elsif Flyology_TUI.Geometry.Contains
           (Geometry.Form_Content, Point)
         then
            Item.Form.Update
              (Flyology_TUI.Mouse.Localize
                 (Event, Mouse_Region (Geometry.Form_Content)));
         end if;
      when Controls_Page =>
         Handle_Controls_Mouse (Item, Event.Mouse, Geometry);
      when Telemetry_Page =>
         Handle_Telemetry_Mouse (Item, Event.Mouse, Geometry);
      when Navigation_Page =>
         Handle_Navigation_Mouse (Item, Event.Mouse, Geometry);
      when Editors_Page =>
         Handle_Editors_Mouse (Item, Event.Mouse, Geometry);
      when Chat_Page =>
         Handle_Chat_Mouse (Item, Event.Mouse, Geometry);
      when Panels_Page =>
         Handle_Panels_Mouse (Item, Event.Mouse, Geometry);
      when Windows_Page =>
         Handle_Windows_Mouse (Item, Event.Mouse, Geometry);
      end case;
   end Handle_Mouse;

   procedure Handle_Focused_Key
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Terminal_Event;
      Geometry : Layout_Snapshot) is
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
         when Breadcrumb_Field =>
            Result := Item.Breadcrumb.Handle (Event);
            Apply_Result (Item, Breadcrumb_Field, No_Capture, Result);
         when Table_Field =>
            Result := Item.Table.Handle (Event);
            Apply_Result (Item, Table_Field, No_Capture, Result);
         when Tree_Field =>
            Result := Item.Tree.Handle (Event);
            Apply_Result (Item, Tree_Field, No_Capture, Result);
         when Accordion_Field =>
            Result := Item.Accordion.Handle (Event);
            Apply_Result
              (Item, Accordion_Field, Accordion_Capture, Result);
         when Text_Area_Field =>
            Result := Item.Text_Area.Handle (Event);
            Apply_Result
              (Item, Text_Area_Field, Text_Area_Capture, Result);
         when Syntax_Field =>
            Result := Item.Syntax.Handle (Event);
            Apply_Result (Item, Syntax_Field, Syntax_Capture, Result);
            if Result.Changed then
               Item.Syntax.Advance_Highlighting (4);
            end if;
         when Telemetry_Field =>
            Result := Item.Work.Handle (Event);
            Apply_Result (Item, Telemetry_Field, No_Capture, Result);
         when Chat_Field =>
            Result := Item.Chat.Handle (Event);
            Apply_Result (Item, Chat_Field, No_Capture, Result);
         when Chat_Stream_Field =>
            Result := Item.Chat_Stream.Handle (Event);
            Apply_Result (Item, Chat_Stream_Field, No_Capture, Result);
         when Horizontal_Group_Field =>
            Result := Item.Horizontal_Group.Handle (Event);
            Apply_Result
              (Item, Horizontal_Group_Field,
               Horizontal_Group_Capture, Result);
         when Vertical_Group_Field =>
            Result := Item.Vertical_Group.Handle (Event);
            Apply_Result
              (Item, Vertical_Group_Field, Vertical_Group_Capture, Result);
         when Window_Field =>
            if Item.Focused_Window = Window_A
              and then Item.Window_A_Visible
            then
               Result := Item.Window_A_Model.Handle
                 (Event, Geometry.Window_Workspace);
               Apply_Window_Result (Item, Window_A, Result);
            elsif Item.Focused_Window = Window_B
              and then Item.Window_B_Visible
            then
               Result := Item.Window_B_Model.Handle
                 (Event, Geometry.Window_Workspace);
               Apply_Window_Result (Item, Window_B, Result);
            elsif Item.Window_A_Visible then
               Item.Focused_Window := Window_A;
               Activate (Item, Window_Field);
               Result := Item.Window_A_Model.Handle
                 (Event, Geometry.Window_Workspace);
               Apply_Window_Result (Item, Window_A, Result);
            elsif Item.Window_B_Visible then
               Item.Focused_Window := Window_B;
               Activate (Item, Window_Field);
               Result := Item.Window_B_Model.Handle
                 (Event, Geometry.Window_Workspace);
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
         Item.Syntax.Advance_Highlighting (2);
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
         Advance_Chat_Stream (Item);
         Transitions.Run (Next, Wait_For_Tick);
         return;
      end if;

      if Event.Terminal.Kind = Flyology_TUI.Events.Interrupt
        or else Is_Control_C (Event.Terminal)
      then
         Transitions.Quit (Next);
      elsif Event.Terminal.Kind = Flyology_TUI.Events.Resize then
         Set_Terminal_Size
           (Item, Event.Terminal.Width, Event.Terminal.Height);
         Normalize_Focus (Item);
      elsif Event.Terminal.Kind = Flyology_TUI.Events.Key_Press
        and then Event.Terminal.Key.Kind = Flyology_TUI.Events.Tab_Key
        and then not Item.Dropdown.Is_Open
      then
         Next_Focus (Item, Event.Terminal.Key.Modified.Shift);
      elsif Event.Terminal.Kind = Flyology_TUI.Events.Mouse_Input then
         Handle_Mouse (Item, Event.Terminal);
      else
         Handle_Focused_Key (Item, Event.Terminal, Layout (Item));
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

   procedure Overlay_Region
     (Canvas   : in out Flyology_TUI.Surfaces.Surface;
      Content  : Flyology_TUI.Surfaces.Surface;
      Region   : Flyology_TUI.Geometry.Rectangle;
      Geometry : Layout_Snapshot)
   is
      Slot : Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.Create (Region.Width, Region.Height);
   begin
      Slot.Overlay_Clipped (Content, 0, 0);
      Canvas.Overlay_Clipped
        (Slot, Region.X - Geometry.Content.X,
         Region.Y - Geometry.Content.Y);
   end Overlay_Region;

   function Basics_View
     (Item : Model; Geometry : Layout_Snapshot)
      return Flyology_TUI.Surfaces.Surface is
      Canvas : Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.Create
          (Geometry.Content.Width, Geometry.Content.Height);
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
      Overlay_Region (Canvas, Input_Panel, Geometry.First, Geometry);
      Overlay_Region (Canvas, List_View, Geometry.Third, Geometry);
      Overlay_Region (Canvas, Viewport_View, Geometry.Second, Geometry);
      Overlay_Region (Canvas, Form_View, Geometry.Fourth, Geometry);
      return Canvas;
   end Basics_View;

   function Controls_View
     (Item : Model; Geometry : Layout_Snapshot)
      return Flyology_TUI.Surfaces.Surface
   is
      Canvas : Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.Create
          (Geometry.Content.Width, Geometry.Content.Height);
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
      Overlay_Region (Canvas, Action_View, Geometry.First, Geometry);
      Overlay_Region (Canvas, Radio_View, Geometry.Second, Geometry);
      Overlay_Region (Canvas, Selector_View, Geometry.Third, Geometry);
      Overlay_Region (Canvas, Dropdown_View, Geometry.Fourth, Geometry);
      return Canvas;
   end Controls_View;

   function Telemetry_View
     (Item : Model; Geometry : Layout_Snapshot)
      return Flyology_TUI.Surfaces.Surface
   is
      package Indicators renames Flyology_TUI.Components.Indicators;
      Canvas : Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.Create
          (Geometry.Content.Width, Geometry.Content.Height);
      Work_View : constant Flyology_TUI.Surfaces.Surface :=
        Panel
          ("Work progress", Item.Work.Render (Visual),
           Item.Focus = Telemetry_Field, Visual.Border, Visual.Muted);
      Spark_View : constant Flyology_TUI.Surfaces.Surface :=
        Panel
          ("Bounded series",
           Sparklines.Render
             (Item.Samples,
              Inset_Panel (Geometry.Second).Width,
              Sparklines.Automatic, Visual),
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
           Geometry.Content.Width,
           Visual);
      Indicator_Content : constant Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Layouts.Join_Vertically
          (Indicators.Divider
             (Geometry.Content.Width, "telemetry", Visual),
           Flyology_TUI.Layouts.Join_Vertically
             (Summary,
              Flyology_TUI.Layouts.Join_Vertically
                (Item.Work.Render_Segments
                   (Geometry.Content.Width, Visual), Status),
              Gap => 1));
      Indicator_View : constant Flyology_TUI.Surfaces.Surface :=
        Panel
          ("Immediate indicators", Indicator_Content,
           False, Visual.Border, Visual.Muted);
   begin
      Overlay_Region (Canvas, Work_View, Geometry.First, Geometry);
      Overlay_Region (Canvas, Spark_View, Geometry.Second, Geometry);
      Overlay_Region
        (Canvas, Indicator_View,
         (X => Geometry.Third.X,
          Y => Geometry.Third.Y,
          Width => Geometry.Content.Width,
          Height => Geometry.Third.Height),
         Geometry);
      return Canvas;
   end Telemetry_View;

   function Navigation_View
     (Item : Model; Geometry : Layout_Snapshot)
      return Flyology_TUI.Surfaces.Surface
   is
      Canvas : Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.Create
          (Geometry.Content.Width, Geometry.Content.Height);
      Breadcrumb_View : constant Flyology_TUI.Surfaces.Surface :=
        Panel
          ("Breadcrumbs",
           Item.Breadcrumb.Render
             (Visual, Item.Focus = Breadcrumb_Field),
           Item.Focus = Breadcrumb_Field, Visual.Border, Visual.Muted);
      Table_View : constant Flyology_TUI.Surfaces.Surface :=
        Panel
          ("Sortable typed table",
           Item.Table.Render (Visual, Item.Focus = Table_Field),
           Item.Focus = Table_Field, Visual.Border, Visual.Muted);
      Tree_View : constant Flyology_TUI.Surfaces.Surface :=
        Panel
          ("Collapsible tree",
           Item.Tree.Render (Visual, Item.Focus = Tree_Field),
           Item.Focus = Tree_Field, Visual.Border, Visual.Muted);
      Accordion_Layout : constant Accordions.Presentation :=
        Accordion_Presentation (Item, Inset_Panel (Geometry.Fourth).Width);
      Accordion_View : constant Flyology_TUI.Surfaces.Surface :=
        Panel
          ("External accordion bodies",
           Accordions.Frame (Accordion_Layout),
           Item.Focus = Accordion_Field, Visual.Border, Visual.Muted);
   begin
      Overlay_Region (Canvas, Breadcrumb_View, Geometry.First, Geometry);
      Overlay_Region (Canvas, Table_View, Geometry.Third, Geometry);
      Overlay_Region (Canvas, Tree_View, Geometry.Second, Geometry);
      Overlay_Region (Canvas, Accordion_View, Geometry.Fourth, Geometry);
      return Canvas;
   end Navigation_View;

   function Text_Area_Look
     return Flyology_TUI.Components.Text_Areas.Appearance
   is
      Result : Flyology_TUI.Components.Text_Areas.Appearance :=
        Flyology_TUI.Components.Text_Areas.From_Theme (Visual);
   begin
      Result.Current_Line := Visual.Input;
      Result.Cursor := Visual.Focused;
      return Result;
   end Text_Area_Look;

   function Syntax_Look return Ada_Editors.Appearance is
      Result : Ada_Editors.Appearance := Ada_Editors.From_Theme (Visual);
   begin
      Result.Editor.Current_Line := Visual.Input;
      Result.Editor.Cursor := Visual.Focused;
      Result.Tokens (Ada_Keyword) := Visual.Focused;
      Result.Tokens (Ada_String) := Visual.Success;
      Result.Tokens (Ada_Comment) := Visual.Muted;
      Result.Tokens (Ada_Identifier) := Visual.Primary;
      return Result;
   end Syntax_Look;

   function Editors_View
     (Item : Model; Geometry : Layout_Snapshot)
      return Flyology_TUI.Surfaces.Surface
   is
      Canvas : Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.Create
          (Geometry.Content.Width, Geometry.Content.Height);
      Text_View : constant Flyology_TUI.Surfaces.Surface :=
        Panel
          ("Text area · no wrap",
           Item.Text_Area.Render (Text_Area_Look),
           Item.Focus = Text_Area_Field, Visual.Border, Visual.Muted);
      Code_View : constant Flyology_TUI.Surfaces.Surface :=
        Panel
          ("Syntax editor · soft wrap",
           Item.Syntax.Render (Syntax_Look),
           Item.Focus = Syntax_Field, Visual.Border, Visual.Muted);
   begin
      if Geometry.Right_Full.Width > 0 then
         Overlay_Region (Canvas, Text_View, Geometry.Left_Full, Geometry);
         Overlay_Region (Canvas, Code_View, Geometry.Right_Full, Geometry);
      else
         Overlay_Region (Canvas, Text_View, Geometry.Top_Full, Geometry);
         Overlay_Region (Canvas, Code_View, Geometry.Bottom_Full, Geometry);
      end if;
      return Canvas;
   end Editors_View;

   function Chat_View
     (Item : Model; Geometry : Layout_Snapshot)
      return Flyology_TUI.Surfaces.Surface
   is
      Presentation : constant Chats.Presentation :=
        Chat_Presentation (Item, Geometry);
   begin
      return Chats.Frame (Presentation);
   end Chat_View;

   function Panels_View
     (Item : Model; Geometry : Layout_Snapshot)
      return Flyology_TUI.Surfaces.Surface
   is
      Canvas : Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.Create
          (Geometry.Content.Width, Geometry.Content.Height);
      Horizontal_View : constant Flyology_TUI.Surfaces.Surface :=
        Item.Horizontal_Group.Render
          ([Flyology_TUI.Surfaces.From_Text
              ("NAVIGATION" & Wide_Wide_Character'Val (10)
               & "shared vertical boundaries"),
            Flyology_TUI.Surfaces.From_Text
              ("WORKSPACE" & Wide_Wide_Character'Val (10)
               & "drag a divider with the mouse"),
            Flyology_TUI.Surfaces.From_Text
              ("INSPECTOR" & Wide_Wide_Character'Val (10)
               & "tab selects a boundary")],
           Visual);
      Vertical_View : constant Flyology_TUI.Surfaces.Surface :=
        Item.Vertical_Group.Render
          ([Flyology_TUI.Surfaces.From_Text
              ("TIMELINE · weighted growth"),
            Flyology_TUI.Surfaces.From_Text
              ("DETAILS · arrows resize the focused boundary"),
            Flyology_TUI.Surfaces.From_Text
              ("STATUS · pane minimums remain bounded")],
           Visual);
   begin
      Overlay_Region
        (Canvas, Horizontal_View,
         Geometry.Horizontal_Group_Region, Geometry);
      Overlay_Region
        (Canvas, Vertical_View,
         Geometry.Vertical_Group_Region, Geometry);
      return Canvas;
   end Panels_View;

   function Windows_View
     (Item : Model; Geometry : Layout_Snapshot)
      return Flyology_TUI.Surfaces.Surface
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
        (Geometry.Content.Width,
         Geometry.Content.Height,
         [(Content => Base, X => 0, Y => 0,
           Transparent_Spaces => False),
          (Content => Vertical_Bar,
           X => Geometry.Vertical_Scroll_Origin.X, Y => 0,
           Transparent_Spaces => True),
          (Content => Horizontal_Bar, X => 0,
           Y => Geometry.Horizontal_Scroll_Origin.Y,
           Transparent_Spaces => True),
          (Content => Lower_Window, X => Lower_Bounds.X, Y => Lower_Bounds.Y,
           Transparent_Spaces => False),
          (Content => Upper_Window, X => Upper_Bounds.X, Y => Upper_Bounds.Y,
           Transparent_Spaces => False)]);
   end Windows_View;

   function Present (Item : Model) return Flyology_TUI.Views.View is
      Geometry : constant Layout_Snapshot := Layout (Item);
      procedure Place_Text_Cursor
        (Target : in out Flyology_TUI.Views.View)
      is
         Here : constant Flyology_TUI.Components.Text_Areas.Position :=
           Item.Text_Area.Cursor_Position;
         Offset : constant Natural := Item.Text_Area.Cursor_Offset;
         Gutter : constant Positive := Item.Text_Area.Gutter_Columns;
      begin
         for Row in 0 .. Item.Text_Area.Height - 1 loop
            declare
               Line, Next_Line : Positive;
               First, Last, Next_First, Next_Last : Natural;
               Exists, Next_Exists : Boolean;
            begin
               Item.Text_Area.Visible_Segment
                 (Row, Line, First, Last, Exists);
               exit when not Exists;
               Item.Text_Area.Visible_Segment
                 (Row + 1, Next_Line, Next_First, Next_Last, Next_Exists);
               if Line = Here.Line
                 and then Offset >= First
                 and then
                   (Offset < Last
                    or else
                      (Offset = Last
                       and then not
                         (Next_Exists
                          and then Next_Line = Line
                          and then Next_First = Last)))
                 and then Here.Cell_Column >= Item.Text_Area.Viewport_Cell
               then
                  declare
                     Relative : constant Natural :=
                       Here.Cell_Column - Item.Text_Area.Viewport_Cell;
                  begin
                     if Gutter + Relative < Item.Text_Area.Width then
                        Target.Cursor :=
                          (Visible => True,
                           X       => Geometry.Text_Area_Origin.X
                             + Gutter + Relative,
                           Y       => Geometry.Text_Area_Origin.Y + Row,
                           Shape   => Flyology_TUI.Views.Cursor_Bar,
                           Blink   => False);
                     end if;
                  end;
                  return;
               end if;
            end;
         end loop;
      end Place_Text_Cursor;

      procedure Place_Syntax_Cursor
        (Target : in out Flyology_TUI.Views.View)
      is
         Here : constant Flyology_TUI.Components.Text_Areas.Position :=
           Item.Syntax.Cursor_Position;
         Offset : constant Natural := Item.Syntax.Cursor_Offset;
         Gutter : constant Positive := Item.Syntax.Gutter_Columns;
      begin
         for Row in 0 .. Item.Syntax.Height - 1 loop
            declare
               Line, Next_Line : Positive;
               First, Last, Next_First, Next_Last : Natural;
               Exists, Next_Exists : Boolean;
            begin
               Item.Syntax.Visible_Segment
                 (Row, Line, First, Last, Exists);
               exit when not Exists;
               Item.Syntax.Visible_Segment
                 (Row + 1, Next_Line, Next_First, Next_Last, Next_Exists);
               if Line = Here.Line
                 and then Offset >= First
                 and then
                   (Offset < Last
                    or else
                      (Offset = Last
                       and then not
                         (Next_Exists
                          and then Next_Line = Line
                          and then Next_First = Last)))
               then
                  declare
                     Start_Cell : constant Natural :=
                       Item.Syntax.Position_At_Offset (First).Cell_Column;
                  begin
                     if Here.Cell_Column >= Start_Cell then
                        declare
                           Relative : constant Natural :=
                             Here.Cell_Column - Start_Cell;
                        begin
                           if Gutter + Relative < Item.Syntax.Width then
                              Target.Cursor :=
                                (Visible => True,
                                 X       =>
                                   Geometry.Syntax_Origin.X
                                     + Gutter + Relative,
                                 Y       => Geometry.Syntax_Origin.Y + Row,
                                 Shape   => Flyology_TUI.Views.Cursor_Bar,
                                 Blink   => False);
                           end if;
                        end;
                     end if;
                  end;
                  return;
               end if;
            end;
         end loop;
      end Place_Syntax_Cursor;

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
            when Basics_Page   => Basics_View (Item, Geometry),
            when Controls_Page => Controls_View (Item, Geometry),
            when Navigation_Page => Navigation_View (Item, Geometry),
            when Editors_Page => Editors_View (Item, Geometry),
            when Telemetry_Page => Telemetry_View (Item, Geometry),
            when Chat_Page       => Chat_View (Item, Geometry),
            when Panels_Page     => Panels_View (Item, Geometry),
            when Windows_Page   => Windows_View (Item, Geometry));
      Help : constant Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Components.Help.Render
          ([(Key => U ("tab"),
             Description => U ("focus"), Enabled => True),
            (Key => U ("arrows"),
             Description => U ("choose"), Enabled => True),
            (Key => U ("mouse"),
             Description => U ("activate"), Enabled => True),
            (Key => U ("ctrl-c"), Description => U ("quit"), Enabled => True)],
           Width => Geometry.Width, Vertical => False, Theme => Visual);
      Canvas : Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.Create (Geometry.Width, Geometry.Height);
      Result : Flyology_TUI.Views.View;
   begin
      if Geometry.Header.Height > 0 then
         Canvas.Overlay_Clipped (Header, Geometry.Header.X, Geometry.Header.Y);
         Canvas.Overlay_Clipped
           (Meter,
            Integer'Max
              (Geometry.Header.X,
               Integer (Geometry.Width) - Integer (Meter.Width)),
            Geometry.Header.Y);
      end if;
      if Geometry.Tabs.Height > 0 then
         Canvas.Overlay_Clipped (Page_Bar, Geometry.Tabs.X, Geometry.Tabs.Y);
      end if;
      Canvas.Overlay_Clipped
        (Page, Geometry.Content.X, Geometry.Content.Y);
      if Geometry.Help.Height > 0 then
         Canvas.Overlay_Clipped (Help, Geometry.Help.X, Geometry.Help.Y);
      end if;
      Result := Flyology_TUI.Views.From_Surface (Canvas);
      Result.Alternate_Screen := True;
      Result.Mouse := Flyology_TUI.Views.Button_Events;
      Result.Report_Focus := True;
      Result.Bracketed_Paste := True;
      Result.Window_Title := U ("Flyology TUI kitchen sink");
      if Current_Page (Item) = Basics_Page
        and then Item.Focus = Text_Field
      then
         if Geometry.Text_Content.Y < Integer (Geometry.Height)
           and then Geometry.Text_Content.X + Item.Input.Cursor_Column
             < Integer (Geometry.Width)
         then
            Result.Cursor.Visible := True;
            Result.Cursor.X :=
              Geometry.Text_Content.X + Item.Input.Cursor_Column;
            Result.Cursor.Y := Geometry.Text_Content.Y;
            Result.Cursor.Shape := Flyology_TUI.Views.Cursor_Bar;
            Result.Cursor.Blink := False;
         end if;
      elsif Current_Page (Item) = Basics_Page
        and then Item.Focus = Form_Field
        and then not Item.Form.Submitted
        and then not Item.Form.Cancelled
      then
         declare
            X, Y : Natural;
         begin
            Item.Form.Cursor_Position (X, Y);
            if Geometry.Form_Content.X + X < Integer (Geometry.Width)
              and then Geometry.Form_Content.Y + Y < Integer (Geometry.Height)
            then
               Result.Cursor.Visible := True;
               Result.Cursor.X := Geometry.Form_Content.X + X;
               Result.Cursor.Y := Geometry.Form_Content.Y + Y;
               Result.Cursor.Shape := Flyology_TUI.Views.Cursor_Bar;
               Result.Cursor.Blink := False;
            end if;
         end;
      elsif Current_Page (Item) = Editors_Page
        and then Item.Focus = Text_Area_Field
      then
         Place_Text_Cursor (Result);
      elsif Current_Page (Item) = Editors_Page
        and then Item.Focus = Syntax_Field
      then
         Place_Syntax_Cursor (Result);
      end if;
      if Result.Cursor.Visible
        and then
          (Result.Cursor.X >= Geometry.Width
           or else Result.Cursor.Y >= Geometry.Height)
      then
         Result.Cursor.Visible := False;
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
