with Ada.Command_Line;
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
with Flyology_TUI.Components.Markdown_Editors;
with Flyology_TUI.Components.Markdown_Viewers;
with Flyology_TUI.Components.Menubars;
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
with Flyology_TUI.Color_Profiles;
with Flyology_TUI.Colors;
with Flyology_TUI.Components.Gradients;
with Flyology_TUI.Events;
with Flyology_TUI.Geometry;
with Flyology_TUI.Glyphs;
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
      Markdown_Page,
      Telemetry_Page,
      Chat_Page,
      Menus_Page,
      Color_Page,
      Panels_Page,
      Windows_Page);

   function Page_Identity (Item : Page_Id) return Page_Id is (Item);

   function Page_Label (Item : Page_Id) return Wide_Wide_String is
     (case Item is
         when Basics_Page   => "Basics",
         when Controls_Page => "Controls",
         when Navigation_Page => "Navigation",
         when Editors_Page => "Editors",
         when Markdown_Page => "Markdown",
         when Telemetry_Page => "Telemetry",
         when Chat_Page      => "Chat",
         when Menus_Page     => "Menus",
         when Color_Page     => "Color",
         when Panels_Page    => "Panels",
         when Windows_Page   => "Windows");

   package Pages is new Flyology_TUI.Components.Tabs
     (Item_Type => Page_Id,
      Id_Type   => Page_Id,
      Id_Of     => Page_Identity,
      Label     => Page_Label,
      Capacity  => 12);

   type Demo_Menu_Id is (File_Menu, View_Menu, Density_Menu, Help_Menu);
   type Demo_Menu_Item_Id is
     (New_Item, Save_Item, Separator_Item, Quit_Item,
      Status_Item, Density_Item, Compact_Item, Comfortable_Item,
      Shortcuts_Item, About_Item);

   function Demo_Menu_Label
     (Id : Demo_Menu_Id) return Wide_Wide_String is
     (case Id is
         when File_Menu    => "File",
         when View_Menu    => "View",
         when Density_Menu => "Density",
         when Help_Menu    => "Help");

   function Demo_Item_Label
     (Id : Demo_Menu_Item_Id) return Wide_Wide_String is
     (case Id is
         when New_Item         => "New",
         when Save_Item        => "Save",
         when Separator_Item   => "separator",
         when Quit_Item        => "Quit",
         when Status_Item      => "Status bar",
         when Density_Item     => "Density",
         when Compact_Item     => "Compact",
         when Comfortable_Item => "Comfortable",
         when Shortcuts_Item    => "Keyboard shortcuts",
         when About_Item        => "About");

   function Demo_Shortcut_Label
     (Id : Demo_Menu_Item_Id) return Wide_Wide_String is
     (case Id is
         when New_Item       => "Ctrl+N",
         when Save_Item      => "Ctrl+S",
         when Quit_Item      => "Ctrl+Q",
         when Shortcuts_Item => "?",
         when others         => "");

   function Demo_Menu_Mnemonic
     (Id : Demo_Menu_Id) return Wide_Wide_Character is
     (Demo_Menu_Label (Id) (1));

   function Demo_Item_Mnemonic
     (Id : Demo_Menu_Item_Id) return Wide_Wide_Character is
     (Demo_Item_Label (Id) (1));

   package Menus is new Flyology_TUI.Components.Menubars
     (Menu_Id          => Demo_Menu_Id,
      Item_Id          => Demo_Menu_Item_Id,
      Menu_Label       => Demo_Menu_Label,
      Item_Label       => Demo_Item_Label,
      Shortcut_Label   => Demo_Shortcut_Label,
      Menu_Mnemonic    => Demo_Menu_Mnemonic,
      Item_Mnemonic    => Demo_Item_Mnemonic,
      Maximum_Menus    => 4,
      Maximum_Items    => 12,
      Maximum_Depth    => 2);

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
      Completion_Message,
      Submitted_Message_1,
      Submitted_Message_2,
      Submitted_Message_3,
      Submitted_Message_4);
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
      Capacity     => 12);

   subtype Submitted_Index is Positive range 1 .. 4;
   type Submitted_Text_Array is array (Submitted_Index) of
     Text.Unbounded_Wide_Wide_String;

   function Submitted_Id
     (Index : Submitted_Index) return Chat_Message_Id is
     (case Index is
         when 1 => Submitted_Message_1,
         when 2 => Submitted_Message_2,
         when 3 => Submitted_Message_3,
         when 4 => Submitted_Message_4);

   function Submitted_Position
     (Id : Chat_Message_Id) return Submitted_Index is
     (case Id is
         when Submitted_Message_1 => 1,
         when Submitted_Message_2 => 2,
         when Submitted_Message_3 => 3,
         when Submitted_Message_4 => 4,
         when others => 1);

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
      Markdown_Source_Field,
      Markdown_Preview_Field,
      Telemetry_Field,
      Chat_Field,
      Chat_Stream_Field,
      Chat_Composer_Field,
      Chat_Send_Field,
      Menu_Field,
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
      Markdown_Source_Capture,
      Menu_Capture,
      Chat_Composer_Capture,
      Chat_Send_Capture,
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
      Chat_Frame, Markdown_Frame, Menu_Frame, Gradient_Frame :
        Flyology_TUI.Geometry.Rectangle;
      Window_Workspace : Flyology_TUI.Geometry.Rectangle;
      Vertical_Scroll_Region : Flyology_TUI.Geometry.Rectangle;
      Horizontal_Scroll_Region : Flyology_TUI.Geometry.Rectangle;
      Vertical_Scroll_Origin : Flyology_TUI.Geometry.Point;
      Horizontal_Scroll_Origin : Flyology_TUI.Geometry.Point;
      Horizontal_Group_Origin : Flyology_TUI.Geometry.Point;
      Vertical_Group_Origin : Flyology_TUI.Geometry.Point;
      Horizontal_Group_Region : Flyology_TUI.Geometry.Rectangle;
      Vertical_Group_Region : Flyology_TUI.Geometry.Rectangle;
      Split_Region : Flyology_TUI.Geometry.Rectangle;
      Split_Origin : Flyology_TUI.Geometry.Point;
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
            Markdown_Page,
            Telemetry_Page,
            Chat_Page,
            Menus_Page,
            Color_Page,
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
      Markdown : Flyology_TUI.Components.Markdown_Editors.Model
        (4_096, 256, 32, 12_288, 32) :=
        Flyology_TUI.Components.Markdown_Editors.Create
          (4_096, 256, 32, 12_288, 32, 80, 20,
           Flyology_TUI.Components.Markdown_Editors.Split_Horizontally);
      Menu : Menus.Model := Menus.Create
        (Menus =>
           [(File_Menu, True, True),
            (View_Menu, True, True),
            (Density_Menu, False, True),
            (Help_Menu, True, True)],
         Items =>
           [Menus.Action (New_Item, File_Menu),
            Menus.Action (Save_Item, File_Menu),
            Menus.Separator (Separator_Item, File_Menu),
            Menus.Action (Quit_Item, File_Menu),
            Menus.Check (Status_Item, View_Menu, Checked => True),
            Menus.Submenu (Density_Item, View_Menu, Density_Menu),
            Menus.Radio
              (Compact_Item, Density_Menu, Compact_Item, Selected => True),
            Menus.Radio
              (Comfortable_Item, Density_Menu, Compact_Item),
            Menus.Action (Shortcuts_Item, Help_Menu),
            Menus.Action (About_Item, Help_Menu)]);
      Deep_Gradient : Flyology_TUI.Components.Gradients.Model (4) :=
        Flyology_TUI.Components.Gradients.Create (4);
      Linear_Gradient : Flyology_TUI.Components.Gradients.Model (4) :=
        Flyology_TUI.Components.Gradients.Create (4);
      Heat_Gradient : Flyology_TUI.Components.Gradients.Model (3) :=
        Flyology_TUI.Components.Gradients.Create (3);
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
      Chat_Composer : Flyology_TUI.Components.Text_Areas.Model
        (1_024, 32, 16, 4_096) :=
        Flyology_TUI.Components.Text_Areas.Create
          (1_024, 32, 16, 4_096, 72, 4,
           "Write a message · Enter sends · Shift+Enter adds a line");
      Chat_Send : Flyology_TUI.Components.Buttons.Model :=
        Flyology_TUI.Components.Buttons.Create ("Send");
      Submitted_Texts : Submitted_Text_Array := [others => U ("")];
      Submitted_Count : Natural range 0 .. 4 := 0;
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
   use type Flyology_TUI.Views.Mouse_Mode;

   Charm_Visual : constant Flyology_TUI.Themes.Palette :=
     Flyology_TUI.Themes.Charm_Palette;
   Visual : constant Flyology_TUI.Themes.Theme :=
     Flyology_TUI.Themes.To_Theme (Charm_Visual);
   Button_Look : constant Flyology_TUI.Components.Buttons.Appearance :=
     Flyology_TUI.Components.Buttons.From_Palette (Charm_Visual);
   Check_Look : constant Flyology_TUI.Components.Check_Boxes.Appearance :=
     Flyology_TUI.Components.Check_Boxes.From_Palette (Charm_Visual);
   Radio_Look : constant Radios.Appearance :=
     Radios.From_Palette (Charm_Visual);
   Selector_Look : constant Selectors.Appearance :=
     Selectors.From_Palette (Charm_Visual);
   Dropdown_Look : constant Dropdowns.Appearance :=
     Dropdowns.From_Palette (Charm_Visual);
   Page_Look : constant Pages.Appearance :=
     Pages.From_Palette (Charm_Visual);

   function Build_Viewport_Demo return Flyology_TUI.Surfaces.Surface is
      Content : Text.Unbounded_Wide_Wide_String;

      procedure Add_Line
        (Value : Wide_Wide_String;
         Final : Boolean := False) is
      begin
         Text.Append (Content, Value);
         if not Final then
            Text.Append (Content, Wide_Wide_Character'Val (10));
         end if;
      end Add_Line;
   begin
      Add_Line
        ("BOUND VIEWPORT · content and scrollbars share these offsets "
         & "----------------------------------------------------");
      Add_Line
        ("Arrow keys move the content; both thumbs follow. "
         & "                                                       | 110");
      Add_Line
        ("Wheel over the content moves the vertical thumb. "
         & "                                                      | 110");
      Add_Line
        ("Shift-wheel moves horizontally; the lower thumb follows. "
         & "                                                 | 110");
      Add_Line
        ("Scrollbar arrows update this same viewport. "
         & "                                                           | 110");
      Add_Line
        ("Track clicks page through the same content. "
         & "                                        "
         & "                    | 110");
      Add_Line
        ("Drag either thumb and watch these cells move. "
         & "                                                           | 110");
      Add_Line
        ("Home, End, Page Up, and Page Down stay synchronized. "
         & "                                                  | 110");
      Add_Line
        ("The application owns this binding; components stay generic. "
         & "                                               | 110");
      Add_Line
        ("Resize recomputes page sizes from one layout snapshot. "
         & "                                                  | 110");
      for Row in 11 .. 23 loop
         Add_Line
           ("Scrollable row " & Natural'Wide_Wide_Image (Row)
            & " ------------------------------------------------"
            & "------------------------------------------ | 110");
      end loop;
      Add_Line
        ("End of the shared scrollable surface. "
         & "----------------------------------------"
         & "------------------------ | 110",
         Final => True);
      return Flyology_TUI.Surfaces.From_Text
        (Text.To_Wide_Wide_String (Content));
   end Build_Viewport_Demo;

   Viewport_Demo_Content : constant Flyology_TUI.Surfaces.Surface :=
     Build_Viewport_Demo;

   function Current_Page (Item : Model) return Page_Id is
     (Item.Pages.Active_Id);

   function Chat_Stream_Height (Item : Model) return Natural;
   procedure Reconcile_Chat (Item : in out Model);
   function Chat_Body
     (Item  : Model;
      Id    : Chat_Message_Id;
      Width : Natural) return Chats.Body_Entry;
   function Text_Area_Look
     return Flyology_TUI.Components.Text_Areas.Appearance;

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

   function Intersect
     (Left, Right : Flyology_TUI.Geometry.Rectangle)
      return Flyology_TUI.Geometry.Rectangle
   is
      Left_X   : constant Long_Long_Integer := Long_Long_Integer (Left.X);
      Left_Y   : constant Long_Long_Integer := Long_Long_Integer (Left.Y);
      Right_X  : constant Long_Long_Integer := Long_Long_Integer (Right.X);
      Right_Y  : constant Long_Long_Integer := Long_Long_Integer (Right.Y);
      First_X  : constant Long_Long_Integer :=
        Long_Long_Integer'Max (Left_X, Right_X);
      First_Y  : constant Long_Long_Integer :=
        Long_Long_Integer'Max (Left_Y, Right_Y);
      Last_X   : constant Long_Long_Integer :=
        Long_Long_Integer'Min
          (Left_X + Long_Long_Integer (Left.Width),
           Right_X + Long_Long_Integer (Right.Width));
      Last_Y   : constant Long_Long_Integer :=
        Long_Long_Integer'Min
          (Left_Y + Long_Long_Integer (Left.Height),
           Right_Y + Long_Long_Integer (Right.Height));
   begin
      return
        (X      => Integer (First_X),
         Y      => Integer (First_Y),
         Width  =>
           (if Last_X > First_X then Natural (Last_X - First_X) else 0),
         Height =>
           (if Last_Y > First_Y then Natural (Last_Y - First_Y) else 0));
   end Intersect;

   function Visible_Dropdown_Bounds
     (Item     : Model;
      Geometry : Layout_Snapshot) return Flyology_TUI.Geometry.Rectangle is
     (Intersect
        ((X      => Geometry.Dropdown_Origin.X,
          Y      => Geometry.Dropdown_Origin.Y,
          Width  => Item.Dropdown.Width,
          Height => Item.Dropdown.Height),
         Inset_Panel (Geometry.Fourth)));

   procedure Editor_Regions
     (Geometry : Layout_Snapshot;
      Text_Region, Syntax_Region : out Flyology_TUI.Geometry.Rectangle) is
   begin
      if Geometry.Right_Full.Width > 0 then
         Text_Region := Inset_Panel (Geometry.Left_Full);
         Syntax_Region := Inset_Panel (Geometry.Right_Full);
      else
         Text_Region := Inset_Panel (Geometry.Top_Full);
         Syntax_Region := Inset_Panel (Geometry.Bottom_Full);
      end if;
   end Editor_Regions;

   function Layout (Item : Model) return Layout_Snapshot is
      Result : Layout_Snapshot;
      Content_Height : Natural;
      Gap : Natural := 1;
      Frame : Flyology_TUI.Geometry.Rectangle;
      Left_Width, Right_Width : Natural := 0;
      Top_Height, Bottom_Height : Natural := 0;

      function Fits
        (Region : Flyology_TUI.Geometry.Rectangle) return Boolean is
        (Region.X >= 0
         and then Region.Y >= 0
         and then Natural (Region.X) <= Result.Width
         and then Natural (Region.Y) <= Result.Height
         and then Region.Width <= Result.Width - Natural (Region.X)
         and then Region.Height <= Result.Height - Natural (Region.Y));

      function Centered
        (Maximum_Width : Natural;
         Maximum_Height : Natural := Natural'Last)
         return Flyology_TUI.Geometry.Rectangle
      is
         Width : constant Natural :=
           Natural'Min (Result.Content.Width, Maximum_Width);
         Height : constant Natural :=
           Natural'Min (Result.Content.Height, Maximum_Height);
      begin
         return
           (X => Result.Content.X
              + Integer ((Result.Content.Width - Width) / 2),
            Y => Result.Content.Y,
            Width => Width,
            Height => Height);
      end Centered;

      procedure Four_Cards (Maximum_Width, Maximum_Height : Natural) is
         Available : Natural;
         First_Height, Second_Height, Third_Height, Fourth_Height : Natural;
      begin
         Frame := Centered (Maximum_Width, Maximum_Height);
         Gap :=
           (if Frame.Width >= 72
              and then Frame.Height > 0
            then Natural'Min (2, Frame.Height)
            elsif Frame.Width > 0 and then Frame.Height >= 7
            then 1 else 0);
         if Frame.Width >= 72 then
            Left_Width := (Frame.Width - Gap) / 2;
            Right_Width := Frame.Width - Gap - Left_Width;
            Top_Height := (Frame.Height - Natural'Min (Gap, Frame.Height)) / 2;
            Bottom_Height := Frame.Height
              - Natural'Min (Gap, Frame.Height) - Top_Height;
            Result.First := (Frame.X, Frame.Y, Left_Width, Top_Height);
            Result.Second :=
              (Frame.X + Integer (Left_Width + Gap), Frame.Y,
               Right_Width, Top_Height);
            Result.Third :=
              (Frame.X, Frame.Y + Integer (Top_Height + Gap),
               Left_Width, Bottom_Height);
            Result.Fourth :=
              (Frame.X + Integer (Left_Width + Gap),
               Frame.Y + Integer (Top_Height + Gap),
               Right_Width, Bottom_Height);
         else
            Available := Frame.Height - Natural'Min (3 * Gap, Frame.Height);
            First_Height := Available / 4;
            Second_Height := Available / 4;
            Third_Height := Available / 4;
            Fourth_Height := Available - First_Height - Second_Height
              - Third_Height;
            Result.First := (Frame.X, Frame.Y, Frame.Width, First_Height);
            Result.Second :=
              (Frame.X, Frame.Y + Integer (First_Height + Gap),
               Frame.Width, Second_Height);
            Result.Third :=
              (Frame.X,
               Frame.Y + Integer (First_Height + Second_Height + 2 * Gap),
               Frame.Width, Third_Height);
            Result.Fourth :=
              (Frame.X,
               Frame.Y + Integer
                 (First_Height + Second_Height + Third_Height + 3 * Gap),
               Frame.Width, Fourth_Height);
         end if;
      end Four_Cards;

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

      case Current_Page (Item) is
         when Basics_Page | Controls_Page =>
            Four_Cards (112, Natural'Min (23, Result.Content.Height));
         when Navigation_Page =>
            Frame := Centered (120, Natural'Min (32, Result.Content.Height));
            Gap := (if Frame.Height > 2 then 1 else 0);
            Top_Height := Natural'Min (6, Frame.Height);
            declare
               After_Top : constant Natural := Frame.Height - Top_Height;
               First_Gap : constant Natural := Natural'Min (Gap, After_Top);
               Available : constant Natural := After_Top - First_Gap;
               Second_Gap : constant Natural :=
                 Natural'Min (Gap, Available);
               Usable : constant Natural := Available - Second_Gap;
               Middle_Height : constant Natural :=
                 (if Usable > 9 then Usable - 9 else Usable / 2);
               Middle_Y : constant Integer :=
                 Frame.Y + Integer (Top_Height + First_Gap);
            begin
               Bottom_Height := Usable - Middle_Height;
               if Frame.Width >= 72 then
                  Gap := Natural'Min (2, Frame.Width);
                  Left_Width := (Frame.Width - Gap) / 2;
                  Right_Width := Frame.Width - Gap - Left_Width;
                  Result.Second :=
                    (Frame.X, Middle_Y, Left_Width, Middle_Height);
                  Result.Third :=
                    (Frame.X + Integer (Left_Width + Gap), Middle_Y,
                     Right_Width, Middle_Height);
               else
                  Result.Second :=
                    (Frame.X, Middle_Y, Frame.Width, Middle_Height / 2);
                  Result.Third :=
                    (Frame.X, Middle_Y + Integer (Middle_Height / 2),
                     Frame.Width, Middle_Height - Middle_Height / 2);
               end if;
               Result.First := (Frame.X, Frame.Y, Frame.Width, Top_Height);
               Result.Fourth :=
                 (Frame.X,
                  Middle_Y + Integer (Middle_Height + Second_Gap),
                  Frame.Width, Bottom_Height);
            end;
         when Editors_Page =>
            Frame := Centered (132);
            Gap :=
              (if Frame.Width > 0 and then Frame.Height > 0 then 1 else 0);
            if Frame.Width >= 96 then
               Left_Width := (Frame.Width - 2) / 2;
               Right_Width := Frame.Width - 2 - Left_Width;
               Result.Left_Full :=
                 (Frame.X, Frame.Y, Left_Width, Frame.Height);
               Result.Right_Full :=
                 (Frame.X + Integer (Left_Width + 2), Frame.Y,
                  Right_Width, Frame.Height);
            else
               Top_Height :=
                 (Frame.Height - Natural'Min (Gap, Frame.Height)) / 2;
               Bottom_Height :=
                 Frame.Height - Natural'Min (Gap, Frame.Height)
                   - Top_Height;
               Result.Left_Full :=
                 (Frame.X, Frame.Y, Frame.Width, Top_Height);
               Result.Right_Full :=
                 (Frame.X, Frame.Y + Integer (Top_Height + Gap),
                  Frame.Width, Bottom_Height);
            end if;
            Result.First := Result.Left_Full;
            Result.Second := Result.Right_Full;
         when Markdown_Page =>
            Result.Markdown_Frame := Centered (120);
            Frame := Result.Markdown_Frame;
         when Telemetry_Page =>
            Frame := Centered (120, Natural'Min (28, Result.Content.Height));
            Gap := (if Frame.Height > 0 then 1 else 0);
            Top_Height := Natural'Min (13, Frame.Height);
            Gap := Natural'Min (Gap, Frame.Height - Top_Height);
            Bottom_Height := Frame.Height - Top_Height - Gap;
            Left_Width := (Frame.Width - Natural'Min (2, Frame.Width)) / 2;
            Right_Width :=
              Frame.Width - Natural'Min (2, Frame.Width) - Left_Width;
            Result.First := (Frame.X, Frame.Y, Left_Width, Top_Height);
            Result.Second :=
              (Frame.X + Integer (Left_Width + Natural'Min (2, Frame.Width)),
               Frame.Y, Right_Width, Top_Height);
            Result.Third :=
              (Frame.X, Frame.Y + Integer (Top_Height + Gap),
               Frame.Width, Bottom_Height);
            Result.Gradient_Frame := Result.Second;
         when Chat_Page =>
            Result.Chat_Frame := Centered (96);
            Frame := Result.Chat_Frame;
         when Menus_Page =>
            Result.Menu_Frame :=
              Centered (96, Natural'Min (24, Result.Content.Height));
            Frame := Result.Menu_Frame;
         when Color_Page =>
            Result.Gradient_Frame :=
              Centered (120, Natural'Min (26, Result.Content.Height));
            Frame := Result.Gradient_Frame;
         when Panels_Page =>
            Frame := Centered (132);
            Gap := (if Frame.Height > 0 then 1 else 0);
            declare
               Used_Gap : constant Natural := Natural'Min (Gap, Frame.Height);
            begin
               Top_Height := (Frame.Height - Used_Gap) / 2;
               Bottom_Height := Frame.Height - Used_Gap - Top_Height;
            end;
            Result.Horizontal_Group_Region :=
              (Frame.X, Frame.Y, Frame.Width, Top_Height);
            if Frame.Width >= 72 then
               Left_Width := (Frame.Width - 2) / 2;
               Result.Vertical_Group_Region :=
                 (Frame.X, Frame.Y + Integer (Top_Height + Gap),
                  Left_Width, Bottom_Height);
               Result.Split_Region :=
                 (Frame.X + Integer (Left_Width + 2),
                  Frame.Y + Integer (Top_Height + Gap),
                  Frame.Width - Left_Width - 2, Bottom_Height);
            else
               Result.Vertical_Group_Region :=
                 (Frame.X, Frame.Y + Integer (Top_Height + Gap),
                  Frame.Width, Bottom_Height / 2);
               Result.Split_Region :=
                 (Frame.X,
                  Frame.Y + Integer (Top_Height + Gap + Bottom_Height / 2),
                  Frame.Width, Bottom_Height - Bottom_Height / 2);
            end if;
         when Windows_Page =>
            Frame := Centered (120, Natural'Min (34, Result.Content.Height));
            Result.Window_Workspace :=
              (X => 0, Y => 0, Width => Frame.Width, Height => Frame.Height);
            Result.Windows_Origin := Origin (Frame);
      end case;

      if Current_Page (Item) /= Editors_Page then
         Result.Left_Full := Result.First;
         Result.Right_Full := Result.Second;
      end if;
      Result.Top_Full := Result.First;
      Result.Bottom_Full := Result.Third;

      Result.Text_Content := Inset_Panel (Result.First);
      Result.Text_Content.Height :=
        Natural'Min (1, Result.Text_Content.Height);
      Result.List_Content := Inset_Panel (Result.Third);
      declare
         Viewport_Frame : constant Flyology_TUI.Geometry.Rectangle :=
           Inset_Panel (Result.Second);
         Has_Bars : constant Boolean :=
           Viewport_Frame.Width >= 3 and then Viewport_Frame.Height >= 3;
         Viewport_Width : constant Natural :=
           Viewport_Frame.Width - (if Has_Bars then 1 else 0);
         Viewport_Height : constant Natural :=
           Viewport_Frame.Height - (if Has_Bars then 1 else 0);
      begin
         Result.Viewport_Content :=
           (Viewport_Frame.X, Viewport_Frame.Y,
            Viewport_Width, Viewport_Height);
         if Has_Bars then
            Result.Vertical_Scroll_Region :=
              (X => Viewport_Frame.X + Integer (Viewport_Width),
               Y => Viewport_Frame.Y,
               Width => 1,
               Height => Viewport_Height);
            Result.Horizontal_Scroll_Region :=
              (X => Viewport_Frame.X,
               Y => Viewport_Frame.Y + Integer (Viewport_Height),
               Width => Viewport_Width,
               Height => 1);
         end if;
         Result.Vertical_Scroll_Origin :=
           Origin (Result.Vertical_Scroll_Region);
         Result.Horizontal_Scroll_Origin :=
           Origin (Result.Horizontal_Scroll_Region);
      end;
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
      if Result.Chat_Frame.Width > 0 then
         Result.Chat_Origin := Origin (Result.Chat_Frame);
      end if;
      if Result.Window_Workspace.Width = 0 then
         Result.Window_Workspace :=
           (X => 0, Y => 0,
            Width => Result.Content.Width, Height => Result.Content.Height);
         Result.Windows_Origin := Origin (Result.Content);
      end if;
      if Result.Horizontal_Group_Region.Width = 0 then
         Result.Horizontal_Group_Region := Result.Top_Full;
         Result.Vertical_Group_Region := Result.Bottom_Full;
      end if;
      Result.Horizontal_Group_Origin :=
        Origin (Result.Horizontal_Group_Region);
      Result.Vertical_Group_Origin := Origin (Result.Vertical_Group_Region);
      Result.Split_Origin := Origin (Result.Split_Region);
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
        or else not Fits (Result.Viewport_Content)
        or else not Fits (Result.Vertical_Scroll_Region)
        or else not Fits (Result.Horizontal_Scroll_Region)
      then
         raise Program_Error with "responsive layout escaped terminal bounds";
      end if;
      return Result;
   end Layout;

   function Chat_Composer_Height
     (Geometry : Layout_Snapshot) return Natural is
     (Natural'Min (5, Geometry.Chat_Frame.Height));

   function Chat_Footer_Height
     (Geometry : Layout_Snapshot) return Natural is
     (if Geometry.Chat_Frame.Height > 5 then 1 else 0);

   function Chat_Body_Width
     (Item : Model; Geometry : Layout_Snapshot) return Natural is
     (Item.Chat.Body_Width_Limit (Geometry.Chat_Frame.Width));

   procedure Sync_Scrollbars_From_Viewport
     (Item : in out Model; Geometry : Layout_Snapshot) is
   begin
      Item.Vertical_Scroll.Resize (Geometry.Vertical_Scroll_Region.Height);
      Item.Vertical_Scroll.Configure
        (Total => Viewport_Demo_Content.Height,
         Page_Size => Geometry.Viewport_Content.Height,
         First => Item.Viewport.Y_Offset);
      Item.Horizontal_Scroll.Resize
        (Geometry.Horizontal_Scroll_Region.Width);
      Item.Horizontal_Scroll.Configure
        (Total => Viewport_Demo_Content.Width,
         Page_Size => Geometry.Viewport_Content.Width,
         First => Item.Viewport.X_Offset);
   end Sync_Scrollbars_From_Viewport;

   procedure Sync_Viewport_From_Scrollbars (Item : in out Model) is
      Delta_X : constant Integer :=
        Integer (Item.Horizontal_Scroll.First)
          - Integer (Item.Viewport.X_Offset);
      Delta_Y : constant Integer :=
        Integer (Item.Vertical_Scroll.First)
          - Integer (Item.Viewport.Y_Offset);
   begin
      Item.Viewport.Scroll (Delta_X, Delta_Y);
   end Sync_Viewport_From_Scrollbars;

   procedure Resize_Components
     (Item : in out Model; Geometry : Layout_Snapshot)
   is
      use type Chat_Streams.Operation_Result;
      Editor_Region, Syntax_Region : Flyology_TUI.Geometry.Rectangle;
      Stream_Height : constant Natural := Chat_Stream_Height (Item);
      Stream_Width : constant Natural :=
        Natural'Min
          (Chat_Body_Width (Item, Geometry),
           Chat_Max_Viewport_Cells /
             Natural'Max (1, Stream_Height));
      Composer_Height : constant Natural := Chat_Composer_Height (Geometry);
      Footer_Height : constant Natural := Chat_Footer_Height (Geometry);
      Result : Chat_Streams.Operation_Result;
   begin
      Editor_Regions (Geometry, Editor_Region, Syntax_Region);
      if Editor_Region.Width > 0 and then Editor_Region.Height > 0 then
         Item.Text_Area.Set_Size
           (Positive (Editor_Region.Width), Positive (Editor_Region.Height));
      end if;
      if Syntax_Region.Width > 0 and then Syntax_Region.Height > 0 then
         Item.Syntax.Set_Size
           (Positive (Syntax_Region.Width), Positive (Syntax_Region.Height));
      end if;
      if Geometry.Markdown_Frame.Width > 0
        and then Geometry.Markdown_Frame.Height > 0
      then
         Item.Markdown.Set_Size
           (Positive (Geometry.Markdown_Frame.Width),
            Positive (Geometry.Markdown_Frame.Height));
         Item.Markdown.Set_Mode
           (if Geometry.Markdown_Frame.Width >= 96
            then Flyology_TUI.Components.Markdown_Editors.Split_Horizontally
            elsif Geometry.Markdown_Frame.Height >= 16
            then Flyology_TUI.Components.Markdown_Editors.Split_Vertically
            else Flyology_TUI.Components.Markdown_Editors.Source_Only);
      else
         Item.Markdown.Set_Mode
           (Flyology_TUI.Components.Markdown_Editors.Source_Only);
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
      Item.Chat.Set_Viewport_Rows
        (Geometry.Chat_Frame.Height - Composer_Height - Footer_Height);
      if Geometry.Chat_Frame.Width > 0 and then Composer_Height > 0 then
         Item.Chat_Composer.Set_Size
           (Positive (Geometry.Chat_Frame.Width),
            Positive (Natural'Min (4, Composer_Height)));
      end if;
      Result := Item.Chat_Stream.Resize
        (Stream_Width, Stream_Height);
      if Result = Chat_Streams.Rejected_Geometry then
         raise Program_Error with "responsive chat geometry was rejected";
      end if;
      Item.Split.Resize
        (Geometry.Split_Region.Width, Geometry.Split_Region.Height);
      Sync_Scrollbars_From_Viewport (Item, Geometry);
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

   procedure Activate_Page (Item : in out Model; Page : Page_Id) is
   begin
      Item.Menu.Close;
      Item.Pages.Activate (Page);
      Resize_Components (Item, Layout (Item));
      Reconcile_Chat (Item);
   end Activate_Page;

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

   function Wrapped_Text
     (Content    : Wide_Wide_String;
      Width      : Natural;
      Appearance : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default)
      return Flyology_TUI.Surfaces.Surface
   is
      Rows : Natural := 1;
      Column : Natural := 0;
      Maximum_Column : Natural := 0;
      Position : Natural := Content'First;
   begin
      if Content'Length = 0 or else Width = 0 then
         return Flyology_TUI.Surfaces.Create (0, 0, Appearance);
      end if;
      while Position <= Content'Last loop
         if Content (Position) = Wide_Wide_Character'Val (10) then
            Maximum_Column := Natural'Max (Maximum_Column, Column);
            Rows := Rows + 1;
            Column := 0;
            Position := Position + 1;
         else
            declare
               Last : constant Natural :=
                 Flyology_TUI.Glyphs.Cluster_Last
                   (Content, Positive (Position));
               Span : constant Natural := Flyology_TUI.Glyphs.Width_Of
                 (Content (Position .. Last));
            begin
               if Column > 0 and then Span > Width - Column then
                  Maximum_Column := Natural'Max (Maximum_Column, Column);
                  Rows := Rows + 1;
                  Column := 0;
               end if;
               Column :=
                 (if Span > Width then Width else Column + Span);
               Position := Last + 1;
            end;
         end if;
      end loop;
      Maximum_Column := Natural'Max (Maximum_Column, Column);

      declare
         Result : Flyology_TUI.Surfaces.Surface :=
           Flyology_TUI.Surfaces.Create
             (Maximum_Column, Rows, Appearance);
         Row : Natural := 0;
      begin
         Position := Content'First;
         Column := 0;
         while Position <= Content'Last loop
            if Content (Position) = Wide_Wide_Character'Val (10) then
               Row := Row + 1;
               Column := 0;
               Position := Position + 1;
            else
               declare
                  Last : constant Natural :=
                    Flyology_TUI.Glyphs.Cluster_Last
                      (Content, Positive (Position));
                  Span : constant Natural := Flyology_TUI.Glyphs.Width_Of
                    (Content (Position .. Last));
               begin
                  if Column > 0 and then Span > Width - Column then
                     Row := Row + 1;
                     Column := 0;
                  end if;
                  if Span <= Width then
                     Result.Put
                       (Column, Row, Content (Position .. Last), Appearance);
                     Column := Column + Span;
                  else
                     Result.Put (Column, Row, "?", Appearance);
                     Column := Width;
                  end if;
                  Position := Last + 1;
               end;
            end if;
         end loop;
         return Result;
      end;
   end Wrapped_Text;

   procedure Set_Chat_Messages
     (Item     : in out Model;
      Delivery : Chats.Delivery_State)
   is
      Notice_Count : constant Natural :=
        (if Item.Chat_Has_Notice then 1 else 0);
      Count : constant Positive :=
        4 + Notice_Count + Item.Submitted_Count;
      Values : Chats.Message_Array (1 .. Count);
      Position : Positive := 1;
   begin
      Values (Position) := Make_Chat_Message
        (Welcome_Message, System_Author, Chats.System);
      Position := Position + 1;
      Values (Position) := Make_Chat_Message
        (User_Request_Message, User_Author, Chats.User);
      Position := Position + 1;
      Values (Position) := Make_Chat_Message
        (Assistant_Message, Assistant_Author, Chats.Assistant,
         Delivery, Item.Telemetry_Tick);
      Position := Position + 1;
      Values (Position) := Make_Chat_Message
        (Tool_Message, Tool_Author, Chats.Tool);
      if Item.Chat_Has_Notice then
         Position := Position + 1;
         Values (Position) := Make_Chat_Message
           (Completion_Message, System_Author, Chats.Notice);
      end if;
      for Index in 1 .. Item.Submitted_Count loop
         Position := Position + 1;
         Values (Position) := Make_Chat_Message
           (Submitted_Id (Index), User_Author, Chats.User);
      end loop;
      Item.Chat.Set_Messages (Values);
   end Set_Chat_Messages;

   procedure Reconcile_Chat (Item : in out Model) is
      Geometry : constant Layout_Snapshot := Layout (Item);
      Width : constant Natural := Chat_Body_Width (Item, Geometry);
      Count : constant Positive := Item.Chat.Length;
      Values : Chats.Measurement_Array (1 .. Count);
   begin
      for Position in Values'Range loop
         declare
            Id : constant Chat_Message_Id :=
              Item.Chat.Message_At (Position).Id;
            Payload : constant Chats.Body_Entry :=
              Chat_Body (Item, Id, Width);
         begin
            Values (Position) :=
              (Id, Payload.Content.Height, Payload.Actions.Height);
         end;
      end loop;
      Item.Chat.Reconcile_Measurements (Values);
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
               Content => Wrapped_Text
                 ("This transcript owns metadata and viewport state."
                  & Wide_Wide_Character'Val (10)
                  & "Every message body remains caller-owned.", Width),
               Actions => Empty);
         when User_Request_Message =>
            return
              (Id      => Id,
               Content => Wrapped_Text
                 ("Build a bounded chat surface."
                  & Wide_Wide_Character'Val (10)
                  & "Keep ordinary, streaming, and component bodies."
                  & Wide_Wide_Character'Val (10)
                  & "Route child input before transcript input.", Width),
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
               Content => Wrapped_Text
                 ("The bounded stream rolled old history, then finished.",
                  Width),
               Actions => Empty);
         when Submitted_Message_1 | Submitted_Message_2
            | Submitted_Message_3 | Submitted_Message_4 =>
            return
              (Id      => Id,
               Content => Wrapped_Text
                 (Text.To_Wide_Wide_String
                    (Item.Submitted_Texts (Submitted_Position (Id))),
                  Width),
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
           (Item, Chats.Required_Body_Id (Layout, Position),
            Width);
      end loop;
      return Result;
   end Chat_Bodies;

   function Chat_Footer
     (Item : Model; Width, Height : Natural)
      return Flyology_TUI.Surfaces.Surface
   is
      package Indicators renames Flyology_TUI.Components.Indicators;
   begin
      if Height = 0 then
         return Flyology_TUI.Surfaces.Create (Width, 0);
      end if;
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
     (Item : Model; Width, Height : Natural)
      return Flyology_TUI.Surfaces.Surface
   is
      Result : Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.Create (Width, Height, Visual.Input);
      Editor : constant Flyology_TUI.Surfaces.Surface :=
        Item.Chat_Composer.Render (Text_Area_Look);
      Send : constant Flyology_TUI.Surfaces.Surface :=
        Item.Chat_Send.Render
          (Visual, Item.Focus = Chat_Send_Field);
   begin
      Result.Overlay_Clipped (Editor, 0, 0);
      if Height > 4 then
         Result.Overlay_Clipped
           (Send, Integer (Width) - Integer (Send.Width), 4);
      end if;
      return Result;
   end Chat_Composer;

   function Is_Blank (Value : Wide_Wide_String) return Boolean is
   begin
      for Character of Value loop
         if Character not in ' ' | Wide_Wide_Character'Val (9)
           | Wide_Wide_Character'Val (10)
           | Wide_Wide_Character'Val (13)
         then
            return False;
         end if;
      end loop;
      return True;
   end Is_Blank;

   procedure Submit_Chat (Item : in out Model) is
      Value : constant Wide_Wide_String := Item.Chat_Composer.Value;
      Accepted : Boolean;
      Index : Submitted_Index;
   begin
      if Is_Blank (Value) or else Item.Submitted_Count = 4 then
         return;
      end if;
      Index := Submitted_Index (Item.Submitted_Count + 1);
      Item.Submitted_Texts (Index) := U (Value);
      Item.Submitted_Count := Item.Submitted_Count + 1;
      Item.Chat_Composer.Try_Set_Text ("", Accepted);
      if not Accepted then
         raise Program_Error with "chat composer clear was rejected";
      end if;
      Set_Chat_Messages
        (Item,
         (if Item.Chat_Stream.State = Chat_Streams.Finished
          then Chats.Delivered else Chats.Streaming));
      Reconcile_Chat (Item);
      Item.Chat.Set_Follow_Tail;
      Item.Chat.Select_Id (Submitted_Id (Index));
   end Submit_Chat;

   function Chat_Presentation
     (Item : Model; Geometry : Layout_Snapshot) return Chats.Presentation
   is
      Width : constant Natural := Geometry.Chat_Frame.Width;
      Body_Width : constant Natural := Chat_Body_Width (Item, Geometry);
      Footer_Height : constant Natural := Chat_Footer_Height (Geometry);
      Composer_Height : constant Natural := Chat_Composer_Height (Geometry);
      Footer : constant Flyology_TUI.Surfaces.Surface :=
        Chat_Footer (Item, Width, Footer_Height);
      Composer : constant Flyology_TUI.Surfaces.Surface :=
        Chat_Composer (Item, Width, Composer_Height);
      Layout : constant Chats.Layout_Plan := Item.Chat.Plan
        (Width, Footer.Height, Composer.Height);
      Bodies : constant Chats.Body_Array :=
        Chat_Bodies (Item, Layout, Body_Width);
   begin
      return Item.Chat.Present
         (Bodies, Width, Footer, Composer, Visual,
         Has_Focus => Item.Focus in
           Chat_Field | Chat_Stream_Field | Chat_Composer_Field
             | Chat_Send_Field);
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
      declare
         Geometry : constant Layout_Snapshot := Layout (Item);
      begin
         Result := Item.Chat_Stream.Resize
           (Natural'Min
              (Chat_Body_Width (Item, Geometry),
               Chat_Max_Viewport_Cells / Natural'Max (1, New_Height)),
            New_Height);
      end;
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
      Item.Markdown.Blur;
      Item.Chat_Composer.Blur;
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
               Item.Focus := Page_Navigation;
            end if;
         when Split_Field => Item.Split.Focus;
         when Vertical_Scroll_Field => Item.Vertical_Scroll.Focus;
         when Horizontal_Scroll_Field => Item.Horizontal_Scroll.Focus;
         when Text_Area_Field => Item.Text_Area.Focus;
         when Syntax_Field => Item.Syntax.Focus;
         when Markdown_Source_Field => Item.Markdown.Focus_Source;
         when Markdown_Preview_Field => Item.Markdown.Focus_Preview;
         when Chat_Composer_Field => Item.Chat_Composer.Focus;
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
      Item.Viewport.Set_Content (Viewport_Demo_Content);
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
         Item.Markdown.Try_Set_Source
           ("# Flyology TUI Markdown" & Wide_Wide_Character'Val (10)
            & Wide_Wide_Character'Val (10)
            & "Edit **bounded source** beside its live preview."
            & Wide_Wide_Character'Val (10)
            & Wide_Wide_Character'Val (10)
            & "- [x] Unicode-aware editing"
            & Wide_Wide_Character'Val (10)
            & "- [x] Caller-budgeted parsing"
            & Wide_Wide_Character'Val (10)
            & "- [ ] Follow [Ada](https://ada-lang.io/) links"
            & Wide_Wide_Character'Val (10)
            & Wide_Wide_Character'Val (10)
            & "```ada" & Wide_Wide_Character'Val (10)
            & "Put_Line (""Hello from Markdown"");"
            & Wide_Wide_Character'Val (10) & "```",
            Accepted);
         if not Accepted then
            raise Program_Error with "kitchen-sink Markdown seed overflow";
         end if;
         Item.Markdown.Advance_Preview (Natural'Last);
         Item.Deep_Gradient.Try_Set_Stops
           ([(0, (80, 35, 160)),
             (350_000, (170, 75, 235)),
             (700_000, (35, 185, 210)),
             (Flyology_TUI.Components.Gradients.Stop_Scale,
              (185, 220, 65))],
            Accepted);
         if not Accepted then
            raise Program_Error with "kitchen-sink deep gradient rejected";
         end if;
         Item.Linear_Gradient.Try_Set_Stops
           ([(0, (80, 35, 160)),
             (350_000, (170, 75, 235)),
             (700_000, (35, 185, 210)),
             (Flyology_TUI.Components.Gradients.Stop_Scale,
              (185, 220, 65))],
            Accepted);
         if not Accepted then
            raise Program_Error with "kitchen-sink linear gradient rejected";
         end if;
         Item.Linear_Gradient.Set_Interpolation
           (Flyology_TUI.Components.Gradients.Linear_Light);
         Item.Heat_Gradient.Try_Set_Stops
           ([(0, (25, 55, 120)),
             (500_000, (210, 75, 160)),
             (Flyology_TUI.Components.Gradients.Stop_Scale,
              (250, 190, 55))],
            Accepted);
         if not Accepted then
            raise Program_Error with "kitchen-sink heat gradient rejected";
         end if;
         Item.Heat_Gradient.Set_Application
           (Flyology_TUI.Components.Gradients.Apply_Background);
      end;
      Item.Chat.Set_Layout (Chats.Conversational_Layout);
      Item.Chat_Composer.Set_Wrap
        (Flyology_TUI.Components.Text_Areas.Soft_Wrap);
      Resize_Components (Item, Layout (Item));
      Transitions.Run (Next, Wait_For_Tick);
   end Initialize;

   procedure Next_Focus (Item : in out Model; Backwards : Boolean) is
      Has_Visible_Window : constant Boolean :=
        Item.Window_A_Visible or else Item.Window_B_Visible;
      Markdown_Preview_Visible : constant Boolean :=
        Flyology_TUI.Components.Markdown_Editors.Has_Preview
          (Item.Markdown.Layout);
      Focus_Geometry : constant Layout_Snapshot := Layout (Item);
      Chat_Frame : constant Flyology_TUI.Geometry.Rectangle :=
        Focus_Geometry.Chat_Frame;
      Chat_Transcript_Visible : constant Boolean :=
        Chat_Frame.Width > 0 and then Item.Chat.Viewport_Rows > 0;
      Chat_Composer_Visible : constant Boolean :=
        Chat_Frame.Width > 0 and then Chat_Frame.Height > 0;
      Chat_Send_Visible : constant Boolean :=
        Chat_Frame.Width > 0 and then Chat_Frame.Height > 4;
      Viewport_Bars_Visible : constant Boolean :=
        Focus_Geometry.Vertical_Scroll_Region.Height > 0
          and then Focus_Geometry.Horizontal_Scroll_Region.Width > 0;
   begin
      case Current_Page (Item) is
      when Basics_Page =>
         if Item.Focus not in
           Page_Navigation .. Form_Field
             | Vertical_Scroll_Field | Horizontal_Scroll_Field
         then
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
                   when Vertical_Scroll_Field => Viewport_Field,
                   when Horizontal_Scroll_Field => Vertical_Scroll_Field,
                   when Form_Field      =>
                     (if Viewport_Bars_Visible
                      then Horizontal_Scroll_Field else Viewport_Field),
                   when others          => Text_Field));
         else
            Activate
              (Item,
               (case Item.Focus is
                   when Page_Navigation => Text_Field,
                   when Text_Field      => List_Field,
                   when List_Field      => Viewport_Field,
                   when Viewport_Field  =>
                     (if Viewport_Bars_Visible
                      then Vertical_Scroll_Field else Form_Field),
                   when Vertical_Scroll_Field => Horizontal_Scroll_Field,
                   when Horizontal_Scroll_Field => Form_Field,
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
      when Markdown_Page =>
         if Item.Focus not in
           Page_Navigation | Markdown_Source_Field | Markdown_Preview_Field
         then
            Activate (Item, Markdown_Source_Field);
            return;
         end if;
         if not Markdown_Preview_Visible then
            Activate
              (Item,
               (if Item.Focus = Page_Navigation
                then Markdown_Source_Field else Page_Navigation));
         else
            Activate
              (Item,
               (if Backwards then
                  (case Item.Focus is
                      when Page_Navigation => Markdown_Preview_Field,
                      when Markdown_Source_Field => Page_Navigation,
                      when others => Markdown_Source_Field)
                else
                  (case Item.Focus is
                      when Page_Navigation => Markdown_Source_Field,
                      when Markdown_Source_Field => Markdown_Preview_Field,
                      when others => Page_Navigation)));
         end if;
      when Chat_Page =>
         if Item.Focus not in
           Page_Navigation | Chat_Field | Chat_Stream_Field
             | Chat_Composer_Field | Chat_Send_Field
         then
            Activate
              (Item,
               (if Chat_Transcript_Visible
                then Chat_Field
                elsif Chat_Composer_Visible
                then Chat_Composer_Field
                else Page_Navigation));
            return;
         end if;
         if not Chat_Transcript_Visible
           and then not Chat_Composer_Visible
         then
            Activate (Item, Page_Navigation);
         elsif not Chat_Transcript_Visible and then not Chat_Send_Visible then
            Activate
              (Item,
               (if Item.Focus = Page_Navigation
                then Chat_Composer_Field else Page_Navigation));
         elsif not Chat_Transcript_Visible then
            Activate
              (Item,
               (if Backwards then
                  (case Item.Focus is
                      when Page_Navigation => Chat_Send_Field,
                      when Chat_Composer_Field => Page_Navigation,
                      when Chat_Send_Field => Chat_Composer_Field,
                      when others => Page_Navigation)
                else
                  (case Item.Focus is
                      when Page_Navigation => Chat_Composer_Field,
                      when Chat_Composer_Field => Chat_Send_Field,
                      when Chat_Send_Field => Page_Navigation,
                      when others => Page_Navigation)));
         elsif Backwards then
            Activate
              (Item,
               (case Item.Focus is
                   when Page_Navigation => Chat_Send_Field,
                   when Chat_Field      => Page_Navigation,
                   when Chat_Stream_Field => Chat_Field,
                   when Chat_Composer_Field => Chat_Stream_Field,
                   when Chat_Send_Field => Chat_Composer_Field,
                   when others          => Chat_Field));
         else
            Activate
              (Item,
               (case Item.Focus is
                   when Page_Navigation => Chat_Field,
                   when Chat_Field      => Chat_Stream_Field,
                   when Chat_Stream_Field => Chat_Composer_Field,
                   when Chat_Composer_Field => Chat_Send_Field,
                   when Chat_Send_Field => Page_Navigation,
                   when others          => Chat_Field));
         end if;
      when Menus_Page =>
         Activate
           (Item,
            (if Item.Focus = Page_Navigation
             then Menu_Field else Page_Navigation));
      when Color_Page =>
         Activate (Item, Page_Navigation);
      when Panels_Page =>
         if Item.Focus not in
           Page_Navigation | Horizontal_Group_Field | Vertical_Group_Field
             | Split_Field
         then
            Activate (Item, Horizontal_Group_Field);
            return;
         end if;
         if Backwards then
            Activate
              (Item,
               (case Item.Focus is
                   when Page_Navigation => Split_Field,
                   when Horizontal_Group_Field => Page_Navigation,
                   when Vertical_Group_Field => Horizontal_Group_Field,
                   when Split_Field => Vertical_Group_Field,
                   when others => Horizontal_Group_Field));
         else
            Activate
              (Item,
               (case Item.Focus is
                   when Page_Navigation => Horizontal_Group_Field,
                   when Horizontal_Group_Field => Vertical_Group_Field,
                   when Vertical_Group_Field => Split_Field,
                   when Split_Field => Page_Navigation,
                   when others => Horizontal_Group_Field));
         end if;
      when Windows_Page =>
         if Item.Focus not in Page_Navigation | Window_Field then
            Activate
              (Item,
               (if Has_Visible_Window then Window_Field else Page_Navigation));
            return;
         end if;
         Activate
           (Item,
            (if Item.Focus = Page_Navigation and then Has_Visible_Window
             then Window_Field else Page_Navigation));
      end case;
   end Next_Focus;

   procedure Normalize_Focus (Item : in out Model) is
   begin
      case Current_Page (Item) is
         when Basics_Page =>
            declare
               Geometry : constant Layout_Snapshot := Layout (Item);
               Bars_Visible : constant Boolean :=
                 Geometry.Vertical_Scroll_Region.Height > 0
                   and then Geometry.Horizontal_Scroll_Region.Width > 0;
            begin
               if Item.Focus not in
                 Page_Navigation .. Form_Field
                   | Vertical_Scroll_Field | Horizontal_Scroll_Field
                 or else
                   (Item.Focus in
                      Vertical_Scroll_Field | Horizontal_Scroll_Field
                    and then not Bars_Visible)
               then
                  Activate (Item, Text_Field);
               end if;
            end;
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
         when Markdown_Page =>
            if Item.Focus not in
              Page_Navigation | Markdown_Source_Field
                | Markdown_Preview_Field
              or else
                (Item.Focus = Markdown_Preview_Field
                 and then not
                   Flyology_TUI.Components.Markdown_Editors.Has_Preview
                     (Item.Markdown.Layout))
            then
               Activate (Item, Markdown_Source_Field);
            end if;
         when Chat_Page =>
            declare
               Frame : constant Flyology_TUI.Geometry.Rectangle :=
                 Layout (Item).Chat_Frame;
               Transcript_Visible : constant Boolean :=
                 Frame.Width > 0 and then Item.Chat.Viewport_Rows > 0;
               Composer_Visible : constant Boolean :=
                 Frame.Width > 0 and then Frame.Height > 0;
               Send_Visible : constant Boolean :=
                 Frame.Width > 0 and then Frame.Height > 4;
            begin
               if Item.Focus not in
                 Page_Navigation | Chat_Field | Chat_Stream_Field
                   | Chat_Composer_Field | Chat_Send_Field
                 or else
                   (Item.Focus in Chat_Field | Chat_Stream_Field
                    and then not Transcript_Visible)
                 or else
                   (Item.Focus = Chat_Composer_Field
                    and then not Composer_Visible)
                 or else
                   (Item.Focus = Chat_Send_Field and then not Send_Visible)
               then
                  Activate
                    (Item,
                     (if Transcript_Visible
                      then Chat_Field
                      elsif Composer_Visible
                      then Chat_Composer_Field
                      else Page_Navigation));
               end if;
            end;
         when Menus_Page =>
            if Item.Focus not in Page_Navigation | Menu_Field then
               Activate (Item, Menu_Field);
            end if;
         when Color_Page =>
            if Item.Focus /= Page_Navigation then
               Activate (Item, Page_Navigation);
            end if;
         when Panels_Page =>
            if Item.Focus not in
              Page_Navigation | Horizontal_Group_Field | Vertical_Group_Field
                | Split_Field
            then
               Activate (Item, Horizontal_Group_Field);
            end if;
         when Windows_Page =>
            if Item.Focus not in Page_Navigation | Window_Field then
               Activate
                 (Item,
                  (if Item.Window_A_Visible or else Item.Window_B_Visible
                   then Window_Field else Page_Navigation));
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
            Activate (Item, Page_Navigation);
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
            declare
               Previous : constant Page_Id := Current_Page (Item);
               Tabs_Layout : constant Pages.Presentation :=
                 Item.Pages.Present
                   (Geometry.Tabs.Width, Page_Look,
                    Item.Focus = Page_Navigation);
            begin
               Result := Item.Pages.Handle
                 (Flyology_TUI.Mouse.Relative
                    (Event, Origin (Geometry.Tabs)), Tabs_Layout);
               Apply_Result (Item, Page_Navigation, Page_Capture, Result);
               Normalize_Focus (Item);
               if Current_Page (Item) /= Previous then
                  Item.Menu.Close;
                  Resize_Components (Item, Layout (Item));
                  Reconcile_Chat (Item);
               end if;
            end;
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
         when Markdown_Source_Capture =>
            declare
               Snapshot : constant
                 Flyology_TUI.Components.Markdown_Editors.Layout_Snapshot :=
                   Item.Markdown.Layout;
               Region : constant Flyology_TUI.Geometry.Rectangle :=
                 Flyology_TUI.Components.Markdown_Editors.Source_Region
                   (Snapshot);
            begin
               Result := Item.Markdown.Handle_Source
                 (Flyology_TUI.Mouse.Relative
                    (Event,
                     Flyology_TUI.Geometry.Point'
                       (Geometry.Markdown_Frame.X + Region.X,
                        Geometry.Markdown_Frame.Y + Region.Y)));
               Apply_Result
                 (Item, Markdown_Source_Field,
                  Markdown_Source_Capture, Result);
               if Result.Changed then
                  Item.Markdown.Advance_Preview (Natural'Last);
               end if;
            end;
         when Menu_Capture =>
            declare
               Presentation : constant Menus.Presentation :=
                 Item.Menu.Present
                   (Geometry.Menu_Frame.Width,
                    Geometry.Menu_Frame.Height,
                    0, 0, Visual, Item.Focus = Menu_Field);
               Menu_Result : constant Menus.Update_Result :=
                 Item.Menu.Handle
                   (Flyology_TUI.Mouse.Relative
                      (Event, Origin (Geometry.Menu_Frame)),
                    Presentation);
            begin
               Apply_Result
                 (Item, Menu_Field, Menu_Capture,
                  Menus.Interaction (Menu_Result));
            end;
         when Chat_Composer_Capture | Chat_Send_Capture =>
            declare
               Presentation : constant Chats.Presentation :=
                 Chat_Presentation (Item, Geometry);
               Plan : constant Chats.Layout_Plan :=
                 Chats.Layout (Presentation);
               Local : constant Flyology_TUI.Mouse.Local_Event :=
                 Flyology_TUI.Mouse.Relative
                   (Event, Geometry.Chat_Origin);
            begin
               if not Chats.Has_Composer (Plan) then
                  Item.Capture := No_Capture;
               else
                  declare
                     Composer_Area : constant
                       Flyology_TUI.Geometry.Rectangle :=
                         Chats.Composer_Region (Plan);
                     Text_Area : constant
                       Flyology_TUI.Geometry.Rectangle :=
                         (Composer_Area.X, Composer_Area.Y,
                          Composer_Area.Width,
                          Natural'Min (4, Composer_Area.Height));
                     Send_Width : constant Natural :=
                       Natural'Min
                         (Item.Chat_Send.Width, Composer_Area.Width);
                     Send_Area : constant
                       Flyology_TUI.Geometry.Rectangle :=
                         (Composer_Area.X
                            + Integer (Composer_Area.Width - Send_Width),
                          Composer_Area.Y + 4,
                          Send_Width,
                          (if Composer_Area.Height > 4 then 1 else 0));
                  begin
                     if Item.Capture = Chat_Composer_Capture
                       and then Text_Area.Width > 0
                       and then Text_Area.Height > 0
                     then
                        Result := Item.Chat_Composer.Handle
                          (Flyology_TUI.Mouse.Relative
                             (Local, Origin (Text_Area)));
                        Apply_Result
                          (Item, Chat_Composer_Field,
                           Chat_Composer_Capture, Result);
                     elsif Item.Capture = Chat_Send_Capture
                       and then Send_Area.Width > 0
                       and then Send_Area.Height > 0
                     then
                        Result := Item.Chat_Send.Handle
                          (Flyology_TUI.Mouse.Relative
                             (Local, Origin (Send_Area)));
                        Apply_Result
                          (Item, Chat_Send_Field,
                           Chat_Send_Capture, Result);
                        if Result.Activated then
                           Submit_Chat (Item);
                        end if;
                     else
                        Item.Capture := No_Capture;
                     end if;
                  end;
               end if;
            end;
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
            Page_Event := Flyology_TUI.Mouse.Relative
              (Event, Geometry.Split_Origin);
            Result := Item.Split.Handle (Page_Event);
            Apply_Result (Item, Split_Field, Split_Capture, Result);
         when Vertical_Scroll_Capture =>
            Result := Item.Vertical_Scroll.Handle
              (Flyology_TUI.Mouse.Relative
                 (Event, Geometry.Vertical_Scroll_Origin));
            Apply_Result
              (Item, Vertical_Scroll_Field,
               Vertical_Scroll_Capture, Result);
            Sync_Viewport_From_Scrollbars (Item);
         when Horizontal_Scroll_Capture =>
            Result := Item.Horizontal_Scroll.Handle
              (Flyology_TUI.Mouse.Relative
                 (Event, Geometry.Horizontal_Scroll_Origin));
            Apply_Result
              (Item, Horizontal_Scroll_Field,
               Horizontal_Scroll_Capture, Result);
            Sync_Viewport_From_Scrollbars (Item);
      end case;
   end Route_Captured_Mouse;

   procedure Handle_Controls_Mouse
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Mouse_Event;
      Geometry : Layout_Snapshot) is
      use Flyology_TUI.Components.Interactions;
      First_Content : constant Flyology_TUI.Geometry.Rectangle :=
        Inset_Panel (Geometry.First);
      Second_Content : constant Flyology_TUI.Geometry.Rectangle :=
        Inset_Panel (Geometry.Second);
      Third_Content : constant Flyology_TUI.Geometry.Rectangle :=
        Inset_Panel (Geometry.Third);
      Button_Bounds : constant Flyology_TUI.Geometry.Rectangle := Intersect
        ((X => Geometry.Button_Origin.X,
          Y => Geometry.Button_Origin.Y,
          Width => Item.Button.Width,
          Height => 1),
         First_Content);
      Check_Bounds : constant Flyology_TUI.Geometry.Rectangle :=
        Intersect
          ((X => Geometry.Check_Origin.X,
            Y => Geometry.Check_Origin.Y,
            Width => Item.Check.Width,
            Height => 1),
           First_Content);
      Radio_View : constant Flyology_TUI.Surfaces.Surface :=
        Item.Radios.Render (Visual, Item.Focus = Radio_Field);
      Radio_Bounds : constant Flyology_TUI.Geometry.Rectangle := Intersect
        ((X => Geometry.Radio_Origin.X,
          Y => Geometry.Radio_Origin.Y,
          Width => Flyology_TUI.Surfaces.Width (Radio_View),
          Height => Flyology_TUI.Surfaces.Height (Radio_View)),
         Second_Content);
      Selector_View : constant Flyology_TUI.Surfaces.Surface :=
        Item.Selector.Render (Visual, Item.Focus = Selector_Field);
      Selector_Bounds : constant Flyology_TUI.Geometry.Rectangle := Intersect
        ((X => Geometry.Selector_Origin.X,
          Y => Geometry.Selector_Origin.Y,
          Width => Flyology_TUI.Surfaces.Width (Selector_View),
          Height => Flyology_TUI.Surfaces.Height (Selector_View)),
         Third_Content);
      Dropdown_Bounds : constant Flyology_TUI.Geometry.Rectangle :=
        Visible_Dropdown_Bounds (Item, Geometry);
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
        Intersect
          ((X => Geometry.Telemetry_Origin.X,
            Y => Geometry.Telemetry_Origin.Y,
            Width => Flyology_TUI.Surfaces.Width (Work_View),
            Height => Flyology_TUI.Surfaces.Height (Work_View)),
           Inset_Panel (Geometry.First));
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
        Intersect
          ((X      => Geometry.Breadcrumb_Origin.X,
            Y      => Geometry.Breadcrumb_Origin.Y,
            Width  => Item.Breadcrumb.Width,
            Height => (if Item.Breadcrumb.Is_Empty then 0 else 1)),
           Inset_Panel (Geometry.First));
      Table_Bounds : constant Flyology_TUI.Geometry.Rectangle :=
        Intersect
          ((X      => Geometry.Table_Origin.X,
            Y      => Geometry.Table_Origin.Y,
            Width  => Item.Table.Width,
            Height => Item.Table.Height),
           Inset_Panel (Geometry.Third));
      Tree_Bounds : constant Flyology_TUI.Geometry.Rectangle :=
        Intersect
          ((X      => Geometry.Tree_Origin.X,
            Y      => Geometry.Tree_Origin.Y,
            Width  => Item.Tree.Width,
            Height => Item.Tree.Height),
           Inset_Panel (Geometry.Second));
      Presentation : constant Accordions.Presentation :=
        Accordion_Presentation (Item, Inset_Panel (Geometry.Fourth).Width);
      Accordion_Frame : constant Flyology_TUI.Surfaces.Surface :=
        Accordions.Frame (Presentation);
      Accordion_Bounds : constant Flyology_TUI.Geometry.Rectangle :=
        Intersect
          ((X      => Geometry.Accordion_Origin.X,
            Y      => Geometry.Accordion_Origin.Y,
            Width  => Accordion_Frame.Width,
            Height => Accordion_Frame.Height),
           Inset_Panel (Geometry.Fourth));
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
      Text_Region, Syntax_Region : Flyology_TUI.Geometry.Rectangle;
      Text_Bounds, Syntax_Bounds : Flyology_TUI.Geometry.Rectangle;
      Result : Update_Result;
   begin
      Editor_Regions (Geometry, Text_Region, Syntax_Region);
      Text_Bounds := Intersect
        ((X      => Geometry.Text_Area_Origin.X,
          Y      => Geometry.Text_Area_Origin.Y,
          Width  => Item.Text_Area.Width,
          Height => Item.Text_Area.Height),
         Text_Region);
      Syntax_Bounds := Intersect
        ((X      => Geometry.Syntax_Origin.X,
          Y      => Geometry.Syntax_Origin.Y,
          Width  => Item.Syntax.Width,
          Height => Item.Syntax.Height),
         Syntax_Region);
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
      if Chats.Has_Composer (Plan) then
         declare
            Composer_Area : constant Flyology_TUI.Geometry.Rectangle :=
              Chats.Composer_Region (Plan);
            Text_Area : constant Flyology_TUI.Geometry.Rectangle :=
              (Composer_Area.X, Composer_Area.Y,
               Composer_Area.Width, Natural'Min (4, Composer_Area.Height));
            Send_Width : constant Natural :=
              Natural'Min (Item.Chat_Send.Width, Composer_Area.Width);
            Send_Area : constant Flyology_TUI.Geometry.Rectangle :=
              (Composer_Area.X
                 + Integer (Composer_Area.Width - Send_Width),
               Composer_Area.Y + 4,
               Send_Width,
               (if Composer_Area.Height > 4 then 1 else 0));
         begin
            if Flyology_TUI.Geometry.Contains (Send_Area, Point) then
               Result := Item.Chat_Send.Handle
                 (Flyology_TUI.Mouse.Relative
                    (Local, Origin (Send_Area)));
               Apply_Result
                 (Item, Chat_Send_Field, Chat_Send_Capture, Result);
               if Result.Activated then
                  Submit_Chat (Item);
               end if;
               return;
            elsif Flyology_TUI.Geometry.Contains (Text_Area, Point) then
               Result := Item.Chat_Composer.Handle
                 (Flyology_TUI.Mouse.Relative
                    (Local, Origin (Text_Area)));
               Apply_Result
                 (Item, Chat_Composer_Field,
                  Chat_Composer_Capture, Result);
               return;
            end if;
         end;
      end if;
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
      elsif Flyology_TUI.Geometry.Contains (Geometry.Split_Region, Point)
      then
         Result := Item.Split.Handle
           (Flyology_TUI.Mouse.Relative (Event, Geometry.Split_Origin));
         Apply_Result (Item, Split_Field, Split_Capture, Result);
      end if;
   end Handle_Panels_Mouse;

   procedure Handle_Markdown_Mouse
     (Item : in out Model;
      Event : Flyology_TUI.Events.Mouse_Event;
      Geometry : Layout_Snapshot)
   is
      package Markdown renames
        Flyology_TUI.Components.Markdown_Editors;
      package Viewers renames
        Flyology_TUI.Components.Markdown_Viewers;
      Snapshot : constant Markdown.Layout_Snapshot := Item.Markdown.Layout;
      Point : constant Flyology_TUI.Geometry.Point :=
        (Integer (Event.X), Integer (Event.Y));
      Result : Flyology_TUI.Components.Interactions.Update_Result;
   begin
      if Markdown.Has_Source (Snapshot) then
         declare
            Local : constant Flyology_TUI.Geometry.Rectangle :=
              Markdown.Source_Region (Snapshot);
            Region : constant Flyology_TUI.Geometry.Rectangle :=
              (Geometry.Markdown_Frame.X + Local.X,
               Geometry.Markdown_Frame.Y + Local.Y,
               Local.Width, Local.Height);
         begin
            if Flyology_TUI.Geometry.Contains (Region, Point) then
               Result := Item.Markdown.Handle_Source
                 (Flyology_TUI.Mouse.Relative (Event, Origin (Region)));
               Apply_Result
                 (Item, Markdown_Source_Field,
                  Markdown_Source_Capture, Result);
               if Result.Changed then
                  Item.Markdown.Advance_Preview (Natural'Last);
               end if;
               return;
            end if;
         end;
      end if;
      if Markdown.Has_Preview (Snapshot) then
         declare
            Local : constant Flyology_TUI.Geometry.Rectangle :=
              Markdown.Preview_Region (Snapshot);
            Region : constant Flyology_TUI.Geometry.Rectangle :=
              (Geometry.Markdown_Frame.X + Local.X,
               Geometry.Markdown_Frame.Y + Local.Y,
               Local.Width, Local.Height);
            Presentation : constant Viewers.Presentation :=
              Item.Markdown.Present_Preview (Visual);
            Action : Viewers.Action_Result;
         begin
            if Flyology_TUI.Geometry.Contains (Region, Point) then
               Action := Item.Markdown.Handle_Preview
                 (Flyology_TUI.Mouse.Relative (Event, Origin (Region)),
                  Presentation);
               Apply_Result
                 (Item, Markdown_Preview_Field,
                  No_Capture, Action.Update);
            end if;
         end;
      end if;
   end Handle_Markdown_Mouse;

   procedure Handle_Menu_Mouse
     (Item : in out Model;
      Event : Flyology_TUI.Events.Mouse_Event;
      Geometry : Layout_Snapshot)
   is
      Presentation : constant Menus.Presentation := Item.Menu.Present
        (Geometry.Menu_Frame.Width, Geometry.Menu_Frame.Height,
         0, 0, Visual, Item.Focus = Menu_Field);
      Result : constant Menus.Update_Result := Item.Menu.Handle
        (Flyology_TUI.Mouse.Relative
           (Event, Origin (Geometry.Menu_Frame)),
         Presentation);
   begin
      Apply_Result
        (Item, Menu_Field, Menu_Capture, Menus.Interaction (Result));
   end Handle_Menu_Mouse;

   procedure Handle_Mouse
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Terminal_Event) is
      use Flyology_TUI.Components.Interactions;
      Geometry : constant Layout_Snapshot := Layout (Item);
      Tabs_Layout : constant Pages.Presentation := Item.Pages.Present
        (Geometry.Tabs.Width, Page_Look, Item.Focus = Page_Navigation);
      Tabs_Bounds : constant Flyology_TUI.Geometry.Rectangle := Geometry.Tabs;
      Point : constant Flyology_TUI.Geometry.Point :=
        (X => Integer (Event.Mouse.X), Y => Integer (Event.Mouse.Y));
      Result : Update_Result;
   begin
      if Item.Capture /= No_Capture then
         Route_Captured_Mouse (Item, Event.Mouse, Geometry);
         return;
      end if;

      if Current_Page (Item) = Menus_Page and then Item.Menu.Is_Open then
         Handle_Menu_Mouse (Item, Event.Mouse, Geometry);
         return;
      end if;

      if Current_Page (Item) = Controls_Page
        and then Item.Dropdown.Is_Open
        and then Event.Mouse.Action = Flyology_TUI.Events.Mouse_Click
        and then Event.Mouse.Button = Flyology_TUI.Events.Left_Button
      then
         declare
            Dropdown_Bounds : constant Flyology_TUI.Geometry.Rectangle :=
              Visible_Dropdown_Bounds (Item, Geometry);
         begin
            if not Flyology_TUI.Geometry.Contains (Dropdown_Bounds, Point) then
               Result := Item.Dropdown.Dismiss;
               Apply_Result
                 (Item, Dropdown_Field, Dropdown_Capture, Result);
            end if;
         end;
      end if;

      if Flyology_TUI.Geometry.Contains (Tabs_Bounds, Point) then
         declare
            Previous : constant Page_Id := Current_Page (Item);
         begin
            Result := Item.Pages.Handle
              (Flyology_TUI.Mouse.Relative
                 (Event.Mouse, Origin (Geometry.Tabs)), Tabs_Layout);
            Apply_Result (Item, Page_Navigation, Page_Capture, Result);
            Normalize_Focus (Item);
            if Current_Page (Item) /= Previous then
               Item.Menu.Close;
               Resize_Components (Item, Layout (Item));
               Reconcile_Chat (Item);
            end if;
         end;
         return;
      end if;

      case Current_Page (Item) is
      when Basics_Page =>
         if Event.Mouse.Action = Flyology_TUI.Events.Mouse_Click
           and then Event.Mouse.Button = Flyology_TUI.Events.Left_Button
         then
            if Flyology_TUI.Geometry.Contains
              (Geometry.Text_Content, Point)
            then
               Activate (Item, Text_Field);
            elsif Flyology_TUI.Geometry.Contains
              (Geometry.List_Content, Point)
            then
               Activate (Item, List_Field);
            elsif Flyology_TUI.Geometry.Contains
              (Geometry.Viewport_Content, Point)
            then
               Activate (Item, Viewport_Field);
            elsif Flyology_TUI.Geometry.Contains
              (Geometry.Form_Content, Point)
            then
               Activate (Item, Form_Field);
            end if;
         end if;

         if Flyology_TUI.Geometry.Contains
           (Geometry.Vertical_Scroll_Region, Point)
         then
            Result := Item.Vertical_Scroll.Handle
              (Flyology_TUI.Mouse.Relative
                 (Event.Mouse, Geometry.Vertical_Scroll_Origin));
            Apply_Result
              (Item, Vertical_Scroll_Field,
               Vertical_Scroll_Capture, Result);
            Sync_Viewport_From_Scrollbars (Item);
         elsif Flyology_TUI.Geometry.Contains
           (Geometry.Horizontal_Scroll_Region, Point)
         then
            Result := Item.Horizontal_Scroll.Handle
              (Flyology_TUI.Mouse.Relative
                 (Event.Mouse, Geometry.Horizontal_Scroll_Origin));
            Apply_Result
              (Item, Horizontal_Scroll_Field,
               Horizontal_Scroll_Capture, Result);
            Sync_Viewport_From_Scrollbars (Item);
         elsif Flyology_TUI.Geometry.Contains
           (Geometry.Text_Content, Point)
         then
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
            Sync_Scrollbars_From_Viewport (Item, Geometry);
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
      when Markdown_Page =>
         Handle_Markdown_Mouse (Item, Event.Mouse, Geometry);
      when Chat_Page =>
         Handle_Chat_Mouse (Item, Event.Mouse, Geometry);
      when Menus_Page =>
         Handle_Menu_Mouse (Item, Event.Mouse, Geometry);
      when Color_Page =>
         null;
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
            declare
               Previous : constant Page_Id := Current_Page (Item);
            begin
               Result := Item.Pages.Handle (Event);
               Apply_Result (Item, Page_Navigation, Page_Capture, Result);
               if Current_Page (Item) /= Previous then
                  Item.Menu.Close;
                  Resize_Components (Item, Layout (Item));
                  Reconcile_Chat (Item);
               end if;
            end;
         when Text_Field => Item.Input.Update (Event);
         when List_Field => Item.Choices.Update (Event);
         when Viewport_Field =>
            Item.Viewport.Update (Event);
            Sync_Scrollbars_From_Viewport (Item, Geometry);
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
         when Markdown_Source_Field =>
            Result := Item.Markdown.Handle_Source (Event);
            Apply_Result
              (Item, Markdown_Source_Field,
               Markdown_Source_Capture, Result);
            if Result.Changed then
               Item.Markdown.Advance_Preview (Natural'Last);
            end if;
         when Markdown_Preview_Field =>
            declare
               Action : constant
                 Flyology_TUI.Components.Markdown_Viewers.Action_Result :=
                   Item.Markdown.Handle_Preview (Event);
            begin
               Apply_Result
                 (Item, Markdown_Preview_Field,
                  No_Capture, Action.Update);
            end;
         when Telemetry_Field =>
            Result := Item.Work.Handle (Event);
            Apply_Result (Item, Telemetry_Field, No_Capture, Result);
         when Chat_Field =>
            Result := Item.Chat.Handle (Event);
            Apply_Result (Item, Chat_Field, No_Capture, Result);
         when Chat_Stream_Field =>
            Result := Item.Chat_Stream.Handle (Event);
            Apply_Result (Item, Chat_Stream_Field, No_Capture, Result);
         when Chat_Composer_Field =>
            if Event.Kind = Flyology_TUI.Events.Key_Press
              and then Event.Key.Kind = Flyology_TUI.Events.Enter_Key
              and then not Event.Key.Modified.Shift
              and then not Event.Key.Modified.Control
              and then not Event.Key.Modified.Alt
              and then not Event.Key.Modified.Super
            then
               Submit_Chat (Item);
            else
               Result := Item.Chat_Composer.Handle (Event);
               Apply_Result
                 (Item, Chat_Composer_Field,
                  Chat_Composer_Capture, Result);
            end if;
         when Chat_Send_Field =>
            Result := Item.Chat_Send.Handle (Event);
            Apply_Result
              (Item, Chat_Send_Field, Chat_Send_Capture, Result);
            if Result.Activated then
               Submit_Chat (Item);
            end if;
         when Menu_Field =>
            declare
               Menu_Result : constant Menus.Update_Result :=
                 Item.Menu.Handle (Event);
            begin
               Apply_Result
                 (Item, Menu_Field, Menu_Capture,
                  Menus.Interaction (Menu_Result));
            end;
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
            Sync_Viewport_From_Scrollbars (Item);
         when Horizontal_Scroll_Field =>
            Result := Item.Horizontal_Scroll.Handle (Event);
            Apply_Result
              (Item, Horizontal_Scroll_Field,
               Horizontal_Scroll_Capture, Result);
            Sync_Viewport_From_Scrollbars (Item);
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
        and then not Item.Menu.Is_Open
      then
         if Current_Page (Item) = Panels_Page
           and then Item.Focus in
             Horizontal_Group_Field | Vertical_Group_Field
           and then not Event.Terminal.Key.Modified.Control
         then
            --  A focused panel group owns plain Tab for divider selection.
            --  Control-Tab remains the application's focus traversal gesture.
            Handle_Focused_Key (Item, Event.Terminal, Layout (Item));
         else
            Next_Focus (Item, Event.Terminal.Key.Modified.Shift);
         end if;
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
      Muted      : Flyology_TUI.Styles.Style;
      Width      : Natural := 0;
      Height     : Natural := 0)
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
        (Width      => Width,
         Height     => Height,
         Padding    => (Top => 1, Right => 1, Bottom => 1, Left => 1),
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

   function Bound_Viewport_View
     (Item : Model; Geometry : Layout_Snapshot)
      return Flyology_TUI.Surfaces.Surface
   is
      Frame : constant Flyology_TUI.Geometry.Rectangle :=
        Inset_Panel (Geometry.Second);
      Result : Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.Create (Frame.Width, Frame.Height);
   begin
      Result.Overlay_Clipped
        (Item.Viewport.Render,
         Geometry.Viewport_Content.X - Frame.X,
         Geometry.Viewport_Content.Y - Frame.Y);
      Result.Overlay_Clipped
        (Item.Vertical_Scroll.Render (Visual),
         Geometry.Vertical_Scroll_Region.X - Frame.X,
         Geometry.Vertical_Scroll_Region.Y - Frame.Y);
      Result.Overlay_Clipped
        (Item.Horizontal_Scroll.Render (Visual),
         Geometry.Horizontal_Scroll_Region.X - Frame.X,
         Geometry.Horizontal_Scroll_Region.Y - Frame.Y);
      return Result;
   end Bound_Viewport_View;

   function Basics_View
     (Item : Model; Geometry : Layout_Snapshot)
      return Flyology_TUI.Surfaces.Surface is
      Canvas : Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.Create
          (Geometry.Content.Width, Geometry.Content.Height);
      Input_Panel : constant Flyology_TUI.Surfaces.Surface :=
        Panel
          ("Text input", Item.Input.Render (Visual),
           Item.Focus = Text_Field, Charm_Visual.Title, Visual.Muted,
           Geometry.First.Width, Geometry.First.Height);
      List_View : constant Flyology_TUI.Surfaces.Surface :=
        Panel
          ("Generic list", Item.Choices.Render (Visual),
           Item.Focus = List_Field, Charm_Visual.Title, Visual.Muted,
           Geometry.Third.Width, Geometry.Third.Height);
      Viewport_View : constant Flyology_TUI.Surfaces.Surface :=
        Panel
          ("Bound viewport", Bound_Viewport_View (Item, Geometry),
           Item.Focus in
             Viewport_Field | Vertical_Scroll_Field
               | Horizontal_Scroll_Field,
           Charm_Visual.Title, Visual.Muted,
           Geometry.Second.Width, Geometry.Second.Height);
      Form_View : constant Flyology_TUI.Surfaces.Surface :=
        Panel
          ((if Item.Form.Submitted then "Form done" else "Form"),
           Item.Form.Render (Visual), Item.Focus = Form_Field,
           Charm_Visual.Title, Visual.Muted,
           Geometry.Fourth.Width, Geometry.Fourth.Height);
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
          (Item.Button.Render (Button_Look, Item.Focus = Button_Field),
           Item.Check.Render (Check_Look, Item.Focus = Check_Field),
           Gap => 1);
      Action_View : constant Flyology_TUI.Surfaces.Surface :=
        Panel
          ("Actions", Action_Content,
           Item.Focus in Button_Field | Check_Field,
           Charm_Visual.Title, Visual.Muted,
           Geometry.First.Width, Geometry.First.Height);
      Radio_View : constant Flyology_TUI.Surfaces.Surface :=
        Panel
          ("Radio group",
           Item.Radios.Render (Radio_Look, Item.Focus = Radio_Field),
           Item.Focus = Radio_Field, Charm_Visual.Title, Visual.Muted,
           Geometry.Second.Width, Geometry.Second.Height);
      Selector_View : constant Flyology_TUI.Surfaces.Surface :=
        Panel
          ("Multi selector",
           Item.Selector.Render (Selector_Look, Item.Focus = Selector_Field),
           Item.Focus = Selector_Field, Charm_Visual.Title, Visual.Muted,
           Geometry.Third.Width, Geometry.Third.Height);
      Dropdown_View : constant Flyology_TUI.Surfaces.Surface :=
        Panel
          ("Dropdown",
           Item.Dropdown.Render (Dropdown_Look, Item.Focus = Dropdown_Field),
           Item.Focus = Dropdown_Field, Charm_Visual.Title, Visual.Muted,
           Geometry.Fourth.Width, Geometry.Fourth.Height);
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
           Item.Focus = Telemetry_Field, Charm_Visual.Title, Visual.Muted,
           Geometry.First.Width, Geometry.First.Height);
      Spark_View : constant Flyology_TUI.Surfaces.Surface :=
        Panel
          ("Bounded series",
           Sparklines.Render
             (Item.Samples,
              Inset_Panel (Geometry.Second).Width,
              Sparklines.Automatic, Visual),
           False, Charm_Visual.Title, Visual.Muted,
           Geometry.Second.Width, Geometry.Second.Height);
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
           Inset_Panel (Geometry.Third).Width,
           Visual);
      Indicator_Content : constant Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Layouts.Join_Vertically
          (Indicators.Divider
             (Inset_Panel (Geometry.Third).Width, "telemetry", Visual),
           Flyology_TUI.Layouts.Join_Vertically
             (Summary,
              Flyology_TUI.Layouts.Join_Vertically
                (Item.Work.Render_Segments
                   (Inset_Panel (Geometry.Third).Width, Visual), Status),
              Gap => 1));
      Indicator_View : constant Flyology_TUI.Surfaces.Surface :=
        Panel
          ("Immediate indicators", Indicator_Content,
           False, Charm_Visual.Title, Visual.Muted,
           Geometry.Third.Width, Geometry.Third.Height);
   begin
      Overlay_Region (Canvas, Work_View, Geometry.First, Geometry);
      Overlay_Region (Canvas, Spark_View, Geometry.Second, Geometry);
      Overlay_Region (Canvas, Indicator_View, Geometry.Third, Geometry);
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
           Item.Focus = Breadcrumb_Field, Charm_Visual.Title, Visual.Muted,
           Geometry.First.Width, Geometry.First.Height);
      Table_View : constant Flyology_TUI.Surfaces.Surface :=
        Panel
          ("Sortable typed table",
           Item.Table.Render (Visual, Item.Focus = Table_Field),
           Item.Focus = Table_Field, Charm_Visual.Title, Visual.Muted,
           Geometry.Third.Width, Geometry.Third.Height);
      Tree_View : constant Flyology_TUI.Surfaces.Surface :=
        Panel
          ("Collapsible tree",
           Item.Tree.Render (Visual, Item.Focus = Tree_Field),
           Item.Focus = Tree_Field, Charm_Visual.Title, Visual.Muted,
           Geometry.Second.Width, Geometry.Second.Height);
      Accordion_Layout : constant Accordions.Presentation :=
        Accordion_Presentation (Item, Inset_Panel (Geometry.Fourth).Width);
      Accordion_View : constant Flyology_TUI.Surfaces.Surface :=
        Panel
          ("External accordion bodies",
           Accordions.Frame (Accordion_Layout),
           Item.Focus = Accordion_Field, Charm_Visual.Title, Visual.Muted,
           Geometry.Fourth.Width, Geometry.Fourth.Height);
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
           Item.Focus = Text_Area_Field, Charm_Visual.Title, Visual.Muted,
           Geometry.Left_Full.Width, Geometry.Left_Full.Height);
      Code_View : constant Flyology_TUI.Surfaces.Surface :=
        Panel
          ("Syntax editor · soft wrap",
           Item.Syntax.Render (Syntax_Look),
           Item.Focus = Syntax_Field, Charm_Visual.Title, Visual.Muted,
           Geometry.Right_Full.Width, Geometry.Right_Full.Height);
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

   function Markdown_View
     (Item : Model; Geometry : Layout_Snapshot)
      return Flyology_TUI.Surfaces.Surface
   is
      package Markdown renames
        Flyology_TUI.Components.Markdown_Editors;
      package Viewers renames
        Flyology_TUI.Components.Markdown_Viewers;
      Canvas : Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.Create
          (Geometry.Content.Width, Geometry.Content.Height);
      Snapshot : constant Markdown.Layout_Snapshot := Item.Markdown.Layout;
   begin
      if Markdown.Has_Source (Snapshot) then
         declare
            Region : constant Flyology_TUI.Geometry.Rectangle :=
              Markdown.Source_Region (Snapshot);
         begin
            Overlay_Region
              (Canvas,
               Item.Markdown.Render_Source (Visual),
               (Geometry.Markdown_Frame.X + Region.X,
                Geometry.Markdown_Frame.Y + Region.Y,
                Region.Width, Region.Height),
               Geometry);
         end;
      end if;
      if Markdown.Has_Preview (Snapshot) then
         declare
            Region : constant Flyology_TUI.Geometry.Rectangle :=
              Markdown.Preview_Region (Snapshot);
            Preview : constant Viewers.Presentation :=
              Item.Markdown.Present_Preview (Visual);
         begin
            Overlay_Region
              (Canvas,
               Viewers.Frame (Preview),
               (Geometry.Markdown_Frame.X + Region.X,
                Geometry.Markdown_Frame.Y + Region.Y,
                Region.Width, Region.Height),
               Geometry);
         end;
      end if;
      return Canvas;
   end Markdown_View;

   function Menus_View
     (Item : Model; Geometry : Layout_Snapshot)
      return Flyology_TUI.Surfaces.Surface
   is
      Canvas : Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.Create
          (Geometry.Content.Width, Geometry.Content.Height);
      Presentation : constant Menus.Presentation := Item.Menu.Present
        (Geometry.Menu_Frame.Width, Geometry.Menu_Frame.Height,
         0, 0, Visual, Item.Focus = Menu_Field);
   begin
      Overlay_Region
        (Canvas, Menus.Frame (Presentation), Geometry.Menu_Frame, Geometry);
      return Canvas;
   end Menus_View;

   function Color_View
     (Item : Model; Geometry : Layout_Snapshot)
      return Flyology_TUI.Surfaces.Surface
   is
      use type Flyology_TUI.Color_Profiles.Profile;
      package Profiles renames Flyology_TUI.Color_Profiles;
      package Colors renames Flyology_TUI.Colors;
      Canvas : Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.Create
          (Geometry.Content.Width, Geometry.Content.Height);
      Demo : Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.Create
          (Geometry.Gradient_Frame.Width, Geometry.Gradient_Frame.Height);
      Profiles_List : constant array (Positive range <>) of Profiles.Profile :=
        [Profiles.Monochrome, Profiles.ANSI_16,
         Profiles.ANSI_256, Profiles.Truecolor];
      function Profile_Label
        (Profile : Profiles.Profile) return Wide_Wide_String is
        (case Profile is
            when Profiles.Monochrome => "monochrome",
            when Profiles.ANSI_16    => "ANSI 16",
            when Profiles.ANSI_256   => "ANSI 256",
            when Profiles.Truecolor  => "truecolor");
   begin
      if Demo.Width = 0 or else Demo.Height = 0 then
         return Canvas;
      end if;
      Demo.Write (0, 0, "Terminal color profiles", Visual.Focused);
      for Index in Profiles_List'Range loop
         exit when Index >= Demo.Height;
         declare
            Profile : constant Profiles.Profile := Profiles_List (Index);
            Style : Flyology_TUI.Styles.Style := Visual.Primary;
            Start : constant Natural := Natural'Min (14, Demo.Width);
         begin
            Style.Foreground := Profiles.Adapt
              (Colors.True_Color (190, 90, 245), Profile);
            Demo.Write (0, Index, Profile_Label (Profile), Visual.Muted);
            if Start < Demo.Width then
               for X in Start .. Demo.Width - 1 loop
                  Demo.Put (X, Index, "█", Style);
               end loop;
            end if;
         end;
      end loop;
      if Demo.Height > 8 then
         Demo.Write (0, 6, "Identical stops, different interpolation",
                     Visual.Focused);
         Demo.Write (0, 7, "sRGB channels", Visual.Muted);
         Demo.Write (0, 8, "linear light", Visual.Muted);
         for X in Natural'Min (14, Demo.Width) .. Demo.Width - 1 loop
            Demo.Put (X, 7, "▄", Visual.Primary);
            Demo.Put (X, 8, "▄", Visual.Primary);
         end loop;
         Item.Deep_Gradient.Apply
           (Demo,
            (Natural'Min (14, Demo.Width), 7,
             Demo.Width - Natural'Min (14, Demo.Width), 1));
         Item.Linear_Gradient.Apply
           (Demo,
            (Natural'Min (14, Demo.Width), 8,
             Demo.Width - Natural'Min (14, Demo.Width), 1));
      end if;
      if Demo.Height > 11 then
         Demo.Write (0, 10, "Background heatmap, profile-safe fallback",
                     Visual.Focused);
         for X in 0 .. Demo.Width - 1 loop
            Demo.Put (X, 11, " ", Visual.Primary);
         end loop;
         Item.Heat_Gradient.Apply (Demo, (0, 11, Demo.Width, 1));
      end if;
      Overlay_Region
        (Canvas, Demo, Geometry.Gradient_Frame, Geometry);
      return Canvas;
   end Color_View;

   function Chat_View
     (Item : Model; Geometry : Layout_Snapshot)
      return Flyology_TUI.Surfaces.Surface
   is
      Presentation : constant Chats.Presentation :=
        Chat_Presentation (Item, Geometry);
      Canvas : Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.Create
          (Geometry.Content.Width, Geometry.Content.Height);
   begin
      Overlay_Region
        (Canvas, Chats.Frame (Presentation), Geometry.Chat_Frame, Geometry);
      return Canvas;
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
          (Flyology_TUI.Components.Panel_Groups.Surface_Array'
             [1 => Flyology_TUI.Surfaces.From_Text
              ("NAVIGATION" & Wide_Wide_Character'Val (10)
               & "shared vertical boundaries"),
              2 => Flyology_TUI.Surfaces.From_Text
              ("WORKSPACE" & Wide_Wide_Character'Val (10)
               & "drag a divider with the mouse"),
              3 => Flyology_TUI.Surfaces.From_Text
              ("INSPECTOR" & Wide_Wide_Character'Val (10)
               & "tab boundary · ctrl-tab focus")],
           Visual);
      Vertical_View : constant Flyology_TUI.Surfaces.Surface :=
        Item.Vertical_Group.Render
          (Flyology_TUI.Components.Panel_Groups.Surface_Array'
             [1 => Flyology_TUI.Surfaces.From_Text
              ("TIMELINE · weighted growth"),
              2 => Flyology_TUI.Surfaces.From_Text
              ("DETAILS · arrows resize the focused boundary"),
              3 => Flyology_TUI.Surfaces.From_Text
              ("STATUS · pane minimums remain bounded")],
           Visual);
      Split_View : constant Flyology_TUI.Surfaces.Surface :=
        Item.Split.Render
          (Flyology_TUI.Surfaces.From_Text
             ("PRIMARY" & Wide_Wide_Character'Val (10)
              & "drag the shared divider"),
           Flyology_TUI.Surfaces.From_Text
             ("SECONDARY" & Wide_Wide_Character'Val (10)
              & "arrows resize when focused"),
           Visual);
   begin
      Overlay_Region
        (Canvas, Horizontal_View,
         Geometry.Horizontal_Group_Region, Geometry);
      Overlay_Region
        (Canvas, Vertical_View,
         Geometry.Vertical_Group_Region, Geometry);
      Overlay_Region (Canvas, Split_View, Geometry.Split_Region, Geometry);
      return Canvas;
   end Panels_View;

   function Windows_View
     (Item : Model; Geometry : Layout_Snapshot)
      return Flyology_TUI.Surfaces.Surface
   is
      Base : constant Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.Create
          (Geometry.Window_Workspace.Width,
           Geometry.Window_Workspace.Height,
           Visual.Input);
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
      declare
         Desktop : constant Flyology_TUI.Surfaces.Surface :=
           Flyology_TUI.Layouts.Layers.Compose
        (Geometry.Window_Workspace.Width,
         Geometry.Window_Workspace.Height,
         [(Content => Base, X => 0, Y => 0,
           Transparent_Spaces => False),
          (Content => Lower_Window, X => Lower_Bounds.X, Y => Lower_Bounds.Y,
           Transparent_Spaces => False),
          (Content => Upper_Window, X => Upper_Bounds.X, Y => Upper_Bounds.Y,
           Transparent_Spaces => False)]);
         Canvas : Flyology_TUI.Surfaces.Surface :=
           Flyology_TUI.Surfaces.Create
             (Geometry.Content.Width, Geometry.Content.Height);
         Region : constant Flyology_TUI.Geometry.Rectangle :=
           (Geometry.Windows_Origin.X, Geometry.Windows_Origin.Y,
            Geometry.Window_Workspace.Width, Geometry.Window_Workspace.Height);
      begin
         Overlay_Region (Canvas, Desktop, Region, Geometry);
         return Canvas;
      end;
   end Windows_View;

   function Present (Item : Model) return Flyology_TUI.Views.View is
      Geometry : constant Layout_Snapshot := Layout (Item);
      Text_Region, Syntax_Region : Flyology_TUI.Geometry.Rectangle;
      procedure Place_Text_Cursor
        (Target : in out Flyology_TUI.Views.View)
      is
         Here : constant Flyology_TUI.Components.Text_Areas.Position :=
           Item.Text_Area.Cursor_Position;
         Offset : constant Natural := Item.Text_Area.Cursor_Offset;
         Gutter : constant Positive := Item.Text_Area.Gutter_Columns;
         Visible_Rows : constant Natural :=
           Natural'Min (Item.Text_Area.Height, Text_Region.Height);
      begin
         if Visible_Rows = 0 or else Text_Region.Width = 0 then
            return;
         end if;
         for Row in 0 .. Visible_Rows - 1 loop
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
                     Position : constant Flyology_TUI.Geometry.Point :=
                       (X => Geometry.Text_Area_Origin.X
                           + Integer (Gutter + Relative),
                        Y => Geometry.Text_Area_Origin.Y + Integer (Row));
                  begin
                     if Gutter + Relative < Item.Text_Area.Width
                       and then Flyology_TUI.Geometry.Contains
                         (Text_Region, Position)
                     then
                        Target.Cursor :=
                          (Visible => True,
                           X       => Natural (Position.X),
                           Y       => Natural (Position.Y),
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
         Visible_Rows : constant Natural :=
           Natural'Min (Item.Syntax.Height, Syntax_Region.Height);
      begin
         if Visible_Rows = 0 or else Syntax_Region.Width = 0 then
            return;
         end if;
         for Row in 0 .. Visible_Rows - 1 loop
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
                           Position : constant
                             Flyology_TUI.Geometry.Point :=
                               (X => Geometry.Syntax_Origin.X
                                   + Integer (Gutter + Relative),
                                Y => Geometry.Syntax_Origin.Y
                                   + Integer (Row));
                        begin
                           if Gutter + Relative < Item.Syntax.Width
                             and then Flyology_TUI.Geometry.Contains
                               (Syntax_Region, Position)
                           then
                              Target.Cursor :=
                                (Visible => True,
                                 X       => Natural (Position.X),
                                 Y       => Natural (Position.Y),
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

      procedure Place_Chat_Composer_Cursor
        (Target : in out Flyology_TUI.Views.View)
      is
         Presentation : constant Chats.Presentation :=
           Chat_Presentation (Item, Geometry);
         Plan : constant Chats.Layout_Plan := Chats.Layout (Presentation);
         function Composer_Or_Empty
           return Flyology_TUI.Geometry.Rectangle is
           (if Chats.Has_Composer (Plan)
            then Chats.Composer_Region (Plan)
            else (0, 0, 0, 0));
         Composer_Area : constant Flyology_TUI.Geometry.Rectangle :=
           Composer_Or_Empty;
         Here : constant Flyology_TUI.Components.Text_Areas.Position :=
           Item.Chat_Composer.Cursor_Position;
         Offset : constant Natural := Item.Chat_Composer.Cursor_Offset;
         Gutter : constant Positive := Item.Chat_Composer.Gutter_Columns;
         Visible_Rows : constant Natural := Natural'Min
           (4, Natural'Min
              (Item.Chat_Composer.Height, Composer_Area.Height));
      begin
         if Visible_Rows = 0 or else Composer_Area.Width = 0 then
            return;
         end if;
         for Row in 0 .. Visible_Rows - 1 loop
            declare
               Line, Next_Line : Positive;
               First, Last, Next_First, Next_Last : Natural;
               Exists, Next_Exists : Boolean;
            begin
               Item.Chat_Composer.Visible_Segment
                 (Row, Line, First, Last, Exists);
               exit when not Exists;
               Item.Chat_Composer.Visible_Segment
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
                       Item.Chat_Composer.Position_At_Offset
                         (First).Cell_Column;
                  begin
                     if Here.Cell_Column >= Start_Cell then
                        declare
                           Relative : constant Natural :=
                             Here.Cell_Column - Start_Cell;
                           Position : constant
                             Flyology_TUI.Geometry.Point :=
                               (Geometry.Chat_Origin.X + Composer_Area.X
                                  + Integer (Gutter + Relative),
                                Geometry.Chat_Origin.Y + Composer_Area.Y
                                  + Integer (Row));
                        begin
                           if Gutter + Relative < Composer_Area.Width
                             and then Flyology_TUI.Geometry.Contains
                               (Geometry.Chat_Frame, Position)
                           then
                              Target.Cursor :=
                                (Visible => True,
                                 X       => Natural (Position.X),
                                 Y       => Natural (Position.Y),
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
      end Place_Chat_Composer_Cursor;

      Header : constant Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Layouts.Join_Horizontally
          (Item.Spinner.Render (Visual),
           Flyology_TUI.Surfaces.From_Text
             ("Flyology TUI kitchen sink", Charm_Visual.Title),
           Gap => 1);
      Meter : constant Flyology_TUI.Surfaces.Surface :=
        Item.Progress.Render (Visual);
      Tabs_Layout : constant Pages.Presentation := Item.Pages.Present
        (Geometry.Tabs.Width, Page_Look, Item.Focus = Page_Navigation);
      Page_Bar : constant Flyology_TUI.Surfaces.Surface :=
        Pages.Frame (Tabs_Layout);
      Page : constant Flyology_TUI.Surfaces.Surface :=
        (case Current_Page (Item) is
            when Basics_Page   => Basics_View (Item, Geometry),
            when Controls_Page => Controls_View (Item, Geometry),
            when Navigation_Page => Navigation_View (Item, Geometry),
            when Editors_Page => Editors_View (Item, Geometry),
            when Markdown_Page => Markdown_View (Item, Geometry),
            when Telemetry_Page => Telemetry_View (Item, Geometry),
            when Chat_Page       => Chat_View (Item, Geometry),
            when Menus_Page      => Menus_View (Item, Geometry),
            when Color_Page      => Color_View (Item, Geometry),
            when Panels_Page     => Panels_View (Item, Geometry),
            when Windows_Page   => Windows_View (Item, Geometry));
      Help : constant Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Components.Help.Render
          ([(Key => U
               ((if Current_Page (Item) = Panels_Page
                 then "ctrl-tab" else "tab")),
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
      Editor_Regions (Geometry, Text_Region, Syntax_Region);
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
      Result.Mouse :=
        (if Current_Page (Item) in Basics_Page | Panels_Page | Windows_Page
         then Flyology_TUI.Views.Cell_Motion
         else Flyology_TUI.Views.Button_Events);
      Result.Report_Focus := True;
      Result.Bracketed_Paste := True;
      Result.Window_Title := U ("Flyology TUI kitchen sink");
      if Current_Page (Item) = Basics_Page
        and then Item.Focus = Text_Field
      then
         if Flyology_TUI.Geometry.Contains
           (Geometry.Text_Content,
            (X => Geometry.Text_Content.X
                + Integer (Item.Input.Cursor_Column),
             Y => Geometry.Text_Content.Y))
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
            Position : Flyology_TUI.Geometry.Point;
         begin
            Item.Form.Cursor_Position (X, Y);
            Position :=
              (X => Geometry.Form_Content.X + Integer (X),
               Y => Geometry.Form_Content.Y + Integer (Y));
            if Flyology_TUI.Geometry.Contains
              (Geometry.Form_Content, Position)
            then
               Result.Cursor.Visible := True;
               Result.Cursor.X := Natural (Position.X);
               Result.Cursor.Y := Natural (Position.Y);
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
      elsif Current_Page (Item) = Chat_Page
        and then Item.Focus = Chat_Composer_Field
      then
         Place_Chat_Composer_Cursor (Result);
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

   procedure Run_Responsive_Self_Test is
      Item : Model;
      Next : Transitions.Transition;

      procedure Assert (Condition : Boolean; Message : String) is
      begin
         if not Condition then
            raise Program_Error with "responsive self-test: " & Message;
         end if;
      end Assert;

      function Pointer
        (X, Y   : Natural;
         Action : Flyology_TUI.Events.Mouse_Action :=
           Flyology_TUI.Events.Mouse_Click)
        return Flyology_TUI.Events.Mouse_Event
      is
        (X        => X,
         Y        => Y,
         Button   => Flyology_TUI.Events.Left_Button,
         Action   => Action,
         Modified => (others => False),
         Wheel_X  => 0,
         Wheel_Y  => 0);

      function Wheel
        (X, Y : Natural;
         Wheel_X, Wheel_Y : Integer;
         Shift : Boolean := False)
         return Flyology_TUI.Events.Mouse_Event
      is
        (X        => X,
         Y        => Y,
         Button   => Flyology_TUI.Events.No_Button,
         Action   => Flyology_TUI.Events.Mouse_Wheel,
         Modified =>
           (Shift => Shift, Control | Alt | Super => False),
         Wheel_X  => Wheel_X,
         Wheel_Y  => Wheel_Y);

      function Key
        (Control : Boolean := False;
         Shift   : Boolean := False)
         return Events.Event
      is
         Value : Flyology_TUI.Events.Key_Event
           (Flyology_TUI.Events.Tab_Key);
      begin
         Value.Modified :=
           (Shift => Shift, Control => Control,
            Alt => False, Super => False);
         return Events.From_Terminal (Flyology_TUI.Events.Pressed (Value));
      end Key;

      function Terminal_Key
        (Kind : Flyology_TUI.Events.Key_Kind;
         Shift : Boolean := False)
         return Flyology_TUI.Events.Terminal_Event
      is
         Value : Flyology_TUI.Events.Key_Event (Kind);
      begin
         Value.Modified :=
           (Shift => Shift, Control | Alt | Super => False);
         return Flyology_TUI.Events.Pressed (Value);
      end Terminal_Key;

      function Fits
        (Outer, Inner : Flyology_TUI.Geometry.Rectangle) return Boolean is
        (Inner.X >= Outer.X
         and then Inner.Y >= Outer.Y
         and then Inner.Width <= Outer.Width
         and then Inner.Height <= Outer.Height
         and then
           Long_Long_Integer (Inner.X) + Long_Long_Integer (Inner.Width)
             <= Long_Long_Integer (Outer.X)
                + Long_Long_Integer (Outer.Width)
         and then
           Long_Long_Integer (Inner.Y) + Long_Long_Integer (Inner.Height)
             <= Long_Long_Integer (Outer.Y)
                + Long_Long_Integer (Outer.Height));

      function Overlaps
        (Left, Right : Flyology_TUI.Geometry.Rectangle) return Boolean is
        (Left.Width > 0
         and then Left.Height > 0
         and then Right.Width > 0
         and then Right.Height > 0
         and then Left.X < Right.X + Integer (Right.Width)
         and then Right.X < Left.X + Integer (Left.Width)
         and then Left.Y < Right.Y + Integer (Right.Height)
         and then Right.Y < Left.Y + Integer (Left.Height));

      type Size_Case is record
         Width, Height : Natural;
      end record;
      Responsive_Sizes : constant array (Positive range <>) of Size_Case :=
        [(1, 1), (20, 6), (40, 12), (71, 24), (72, 24),
         (111, 30), (112, 30), (190, 55)];

      Geometry : Layout_Snapshot;
      Frame : Flyology_TUI.Views.View;
      Before_Divider : Integer;
      Before_Split : Natural;
      Before_Window : Flyology_TUI.Geometry.Rectangle;
      Accepted : Boolean;
   begin
      Initialize (Item, Next);

      declare
         Wide_Glyphs : constant Wide_Wide_String :=
           [Wide_Wide_Character'Val (16#754C#),
            Wide_Wide_Character'Val (16#1F642#)];
         Wrapped : constant Flyology_TUI.Surfaces.Surface :=
           Wrapped_Text (Wide_Glyphs, 1);
      begin
         Assert
           (Wrapped.Width = 1 and then Wrapped.Height = 2
            and then Text.To_Wide_Wide_String
              (Wrapped.Element (0, 0).Glyph) = "?"
            and then Text.To_Wide_Wide_String
              (Wrapped.Element (0, 1).Glyph) = "?",
            "one-cell wrapping dropped CJK or emoji graphemes");
      end;

      for Size of Responsive_Sizes loop
         for Page in Page_Id loop
            Activate_Page (Item, Page);
            Set_Terminal_Size (Item, Size.Width, Size.Height);
            Geometry := Layout (Item);
            Frame := Present (Item);
            Assert
              (Frame.Frame.Width = Size.Width
               and then Frame.Frame.Height = Size.Height,
               "rendered frame did not match responsive terminal size");
            case Page is
               when Basics_Page | Controls_Page =>
                  Assert
                    (Fits (Geometry.Content, Geometry.First)
                     and then Fits (Geometry.Content, Geometry.Second)
                     and then Fits (Geometry.Content, Geometry.Third)
                     and then Fits (Geometry.Content, Geometry.Fourth),
                     "gallery card escaped the content region");
                  Assert
                    (not Overlaps (Geometry.First, Geometry.Second)
                     and then not Overlaps (Geometry.First, Geometry.Third)
                     and then not Overlaps
                       (Geometry.Second, Geometry.Fourth)
                     and then not Overlaps
                       (Geometry.Third, Geometry.Fourth),
                     "gallery cards overlap");
                  if Page = Basics_Page then
                     declare
                        Viewport_Frame : constant
                          Flyology_TUI.Geometry.Rectangle :=
                            Inset_Panel (Geometry.Second);
                        Has_Bars : constant Boolean :=
                          Viewport_Frame.Width >= 3
                            and then Viewport_Frame.Height >= 3;
                     begin
                        Assert
                          (Fits
                             (Viewport_Frame,
                              Geometry.Viewport_Content),
                           "bound viewport geometry escaped its card");
                        if Has_Bars then
                           Assert
                             (Fits
                                (Viewport_Frame,
                                 Geometry.Vertical_Scroll_Region)
                              and then Fits
                                (Viewport_Frame,
                                 Geometry.Horizontal_Scroll_Region)
                              and then Geometry.Viewport_Content.Width + 1
                                = Viewport_Frame.Width
                              and then
                                Geometry.Viewport_Content.Height + 1
                                  = Viewport_Frame.Height
                              and then
                                Geometry.Vertical_Scroll_Region.X
                                  = Geometry.Viewport_Content.X
                                    + Integer
                                        (Geometry.Viewport_Content.Width)
                              and then
                                Geometry.Horizontal_Scroll_Region.Y
                                  = Geometry.Viewport_Content.Y
                                    + Integer
                                        (Geometry.Viewport_Content.Height),
                              "responsive bars did not share viewport edges");
                        else
                           Assert
                             (Geometry.Vertical_Scroll_Region.Width = 0
                              and then
                                Geometry.Horizontal_Scroll_Region.Height = 0,
                              "undersized viewport retained orphan bars");
                        end if;
                     end;
                  end if;
               when Navigation_Page =>
                  Assert
                    (Fits (Geometry.Content, Geometry.First)
                     and then Fits (Geometry.Content, Geometry.Second)
                     and then Fits (Geometry.Content, Geometry.Third)
                     and then Fits (Geometry.Content, Geometry.Fourth)
                     and then not Overlaps
                       (Geometry.First, Geometry.Second)
                     and then not Overlaps
                       (Geometry.Second, Geometry.Fourth),
                     "navigation regions escaped or overlapped");
               when Editors_Page =>
                  Assert
                    (Fits (Geometry.Content, Geometry.Left_Full)
                     and then Fits (Geometry.Content, Geometry.Right_Full)
                     and then not Overlaps
                       (Geometry.Left_Full, Geometry.Right_Full),
                     "editor regions escaped or overlapped");
               when Markdown_Page =>
                  Assert
                    (Fits (Geometry.Content, Geometry.Markdown_Frame)
                     and then Geometry.Markdown_Frame.Width <= 120,
                     "Markdown frame escaped or exceeded its bound");
               when Telemetry_Page =>
                  Assert
                    (Fits (Geometry.Content, Geometry.First)
                     and then Fits (Geometry.Content, Geometry.Second)
                     and then Fits (Geometry.Content, Geometry.Third)
                     and then not Overlaps
                       (Geometry.First, Geometry.Second)
                     and then not Overlaps
                       (Geometry.First, Geometry.Third),
                     "telemetry regions escaped or overlapped");
               when Chat_Page =>
                  Assert
                    (Fits (Geometry.Content, Geometry.Chat_Frame)
                     and then Geometry.Chat_Frame.Width <= 96,
                     "chat frame escaped or exceeded readable width");
               when Menus_Page =>
                  Assert
                    (Fits (Geometry.Content, Geometry.Menu_Frame)
                     and then Geometry.Menu_Frame.Width <= 96,
                     "menu frame escaped or exceeded its bound");
               when Color_Page =>
                  Assert
                    (Fits (Geometry.Content, Geometry.Gradient_Frame)
                     and then Geometry.Gradient_Frame.Width <= 120,
                     "color frame escaped or exceeded its bound");
               when Panels_Page =>
                  Assert
                    (Fits
                       (Geometry.Content,
                        Geometry.Horizontal_Group_Region)
                     and then Fits
                       (Geometry.Content, Geometry.Vertical_Group_Region)
                     and then Fits
                       (Geometry.Content, Geometry.Split_Region)
                     and then not Overlaps
                       (Geometry.Horizontal_Group_Region,
                        Geometry.Vertical_Group_Region)
                     and then not Overlaps
                       (Geometry.Vertical_Group_Region,
                        Geometry.Split_Region),
                     "panel regions escaped or overlapped");
               when Windows_Page =>
                  Assert
                    (Geometry.Window_Workspace.Width <= 120
                     and then Geometry.Window_Workspace.Height <= 34
                     and then Fits
                       (Geometry.Content,
                        (Geometry.Windows_Origin.X,
                         Geometry.Windows_Origin.Y,
                         Geometry.Window_Workspace.Width,
                         Geometry.Window_Workspace.Height)),
                     "window desktop escaped or exceeded its bound");
            end case;
         end loop;
      end loop;

      Activate_Page (Item, Basics_Page);
      Set_Terminal_Size (Item, 190, 55);
      Geometry := Layout (Item);
      Assert
        (Geometry.First.X = 39
         and then Geometry.First.Width + Geometry.Second.Width + 2 = 112
         and then Geometry.First.Height + Geometry.Third.Height + 2 = 23,
         "wide gallery was not centered at its maximum working size");
      Assert
        (Geometry.Vertical_Scroll_Region.Height > 2
         and then Geometry.Horizontal_Scroll_Region.Width > 2
         and then Viewport_Demo_Content.Width
           > Geometry.Viewport_Content.Width
         and then Viewport_Demo_Content.Height
           > Geometry.Viewport_Content.Height
         and then Item.Vertical_Scroll.Maximum_First > 0
         and then Item.Horizontal_Scroll.Maximum_First > 0
         and then Item.Vertical_Scroll.Thumb_Region.Height
           < Geometry.Vertical_Scroll_Region.Height - 2
         and then Item.Horizontal_Scroll.Thumb_Region.Width
           < Geometry.Horizontal_Scroll_Region.Width - 2,
         "bound viewport did not expose two genuinely scrollable thumbs");
      Frame := Present (Item);
      Assert
        (Frame.Mouse = Flyology_TUI.Views.Cell_Motion,
         "bound viewport did not request thumb-drag motion events");
      declare
         Viewport_Frame : constant Flyology_TUI.Geometry.Rectangle :=
           Inset_Panel (Geometry.Second);
         Bound : constant Flyology_TUI.Surfaces.Surface :=
           Bound_Viewport_View (Item, Geometry);
         Vertical : constant Flyology_TUI.Surfaces.Surface :=
           Item.Vertical_Scroll.Render (Visual);
         Horizontal : constant Flyology_TUI.Surfaces.Surface :=
           Item.Horizontal_Scroll.Render (Visual);
      begin
         Assert
           (Bound.Width = Viewport_Frame.Width
            and then Bound.Height = Viewport_Frame.Height
            and then Text.To_Wide_Wide_String
              (Bound.Element
                 (Natural
                    (Geometry.Vertical_Scroll_Region.X
                     - Viewport_Frame.X),
                  0).Glyph)
              = Text.To_Wide_Wide_String (Vertical.Element (0, 0).Glyph)
            and then Text.To_Wide_Wide_String
              (Bound.Element
                 (0,
                  Natural
                    (Geometry.Horizontal_Scroll_Region.Y
                     - Viewport_Frame.Y)).Glyph)
              = Text.To_Wide_Wide_String (Horizontal.Element (0, 0).Glyph),
            "bound viewport omitted its interactive scrollbar renderings");
      end;

      Activate (Item, Viewport_Field);
      Handle_Focused_Key
        (Item, Terminal_Key (Flyology_TUI.Events.Arrow_Right_Key), Geometry);
      Handle_Focused_Key
        (Item, Terminal_Key (Flyology_TUI.Events.Arrow_Down_Key), Geometry);
      Assert
        (Item.Viewport.X_Offset = 1
         and then Item.Viewport.Y_Offset = 1
         and then Item.Horizontal_Scroll.First = 1
         and then Item.Vertical_Scroll.First = 1,
         "viewport keyboard movement did not update both scrollbar models");
      Handle_Mouse
        (Item,
         (Kind => Flyology_TUI.Events.Mouse_Input,
          Mouse => Wheel
            (Natural (Geometry.Viewport_Content.X),
             Natural (Geometry.Viewport_Content.Y), 0, -1)));
      Assert
        (Item.Viewport.Y_Offset = 4
         and then Item.Vertical_Scroll.First = 4,
         "viewport wheel movement did not update the vertical thumb");
      Handle_Mouse
        (Item,
         (Kind => Flyology_TUI.Events.Mouse_Input,
          Mouse => Wheel
            (Natural (Geometry.Viewport_Content.X),
             Natural (Geometry.Viewport_Content.Y), 0, -1,
             Shift => True)));
      Assert
        (Item.Viewport.X_Offset = 4
         and then Item.Horizontal_Scroll.First = 4,
         "viewport Shift-wheel movement did not update the horizontal thumb");

      declare
         Before_X : constant Natural := Item.Viewport.X_Offset;
         Before_Y : constant Natural := Item.Viewport.Y_Offset;
      begin
         Handle_Mouse
           (Item,
            (Kind => Flyology_TUI.Events.Mouse_Input,
             Mouse => Pointer
               (Natural (Geometry.Vertical_Scroll_Region.X),
                Natural
                  (Geometry.Vertical_Scroll_Region.Y
                   + Integer (Geometry.Vertical_Scroll_Region.Height - 1)))));
         Handle_Mouse
           (Item,
            (Kind => Flyology_TUI.Events.Mouse_Input,
             Mouse => Pointer
               (Natural
                  (Geometry.Horizontal_Scroll_Region.X
                   + Integer
                       (Geometry.Horizontal_Scroll_Region.Width - 1)),
                Natural (Geometry.Horizontal_Scroll_Region.Y))));
         Assert
           (Item.Viewport.X_Offset = Before_X + 1
            and then Item.Viewport.Y_Offset = Before_Y + 1
            and then Item.Horizontal_Scroll.First = Item.Viewport.X_Offset
            and then Item.Vertical_Scroll.First = Item.Viewport.Y_Offset,
            "scrollbar arrow clicks did not move the shared viewport");
      end;

      Activate (Item, Vertical_Scroll_Field);
      Handle_Focused_Key
        (Item, Terminal_Key (Flyology_TUI.Events.Home_Key), Geometry);
      Handle_Mouse
        (Item,
         (Kind => Flyology_TUI.Events.Mouse_Input,
          Mouse => Pointer
            (Natural (Geometry.Vertical_Scroll_Region.X),
             Natural
               (Geometry.Vertical_Scroll_Region.Y
                + Integer (Geometry.Vertical_Scroll_Region.Height - 2)))));
      Assert
        (Item.Vertical_Scroll.First
           = Natural'Min
               (Geometry.Viewport_Content.Height,
                Item.Vertical_Scroll.Maximum_First)
         and then Item.Viewport.Y_Offset = Item.Vertical_Scroll.First,
         "vertical track paging did not update the shared viewport");
      Handle_Focused_Key
        (Item, Terminal_Key (Flyology_TUI.Events.Home_Key), Geometry);
      declare
         Thumb : constant Flyology_TUI.Geometry.Rectangle :=
           Item.Vertical_Scroll.Thumb_Region;
         Thumb_X : constant Natural :=
           Natural (Geometry.Vertical_Scroll_Origin.X + Thumb.X);
         Thumb_Y : constant Natural :=
           Natural (Geometry.Vertical_Scroll_Origin.Y + Thumb.Y);
         Drag_Y : constant Natural :=
           Natural
             (Geometry.Vertical_Scroll_Region.Y
              + Integer (Geometry.Vertical_Scroll_Region.Height - 2));
      begin
         Handle_Mouse
           (Item,
            (Kind => Flyology_TUI.Events.Mouse_Input,
             Mouse => Pointer (Thumb_X, Thumb_Y)));
         Assert
           (Item.Capture = Vertical_Scroll_Capture,
            "vertical thumb did not acquire application capture");
         Handle_Mouse
           (Item,
            (Kind => Flyology_TUI.Events.Mouse_Input,
             Mouse => Pointer
               (Thumb_X, Drag_Y, Flyology_TUI.Events.Mouse_Drag)));
         Handle_Mouse
           (Item,
            (Kind => Flyology_TUI.Events.Mouse_Input,
             Mouse => Pointer
               (Thumb_X, Drag_Y, Flyology_TUI.Events.Mouse_Release)));
         Assert
           (Item.Capture = No_Capture
            and then Item.Viewport.Y_Offset
              = Item.Vertical_Scroll.Maximum_First
            and then Item.Vertical_Scroll.First = Item.Viewport.Y_Offset,
            "captured thumb drag did not move the shared viewport to its end");
      end;

      Activate (Item, Horizontal_Scroll_Field);
      Handle_Focused_Key
        (Item, Terminal_Key (Flyology_TUI.Events.End_Key), Geometry);
      Handle_Mouse
        (Item,
         (Kind => Flyology_TUI.Events.Mouse_Input,
          Mouse => Wheel
            (Natural (Geometry.Horizontal_Scroll_Region.X),
             Natural (Geometry.Horizontal_Scroll_Region.Y), 0, 1)));
      Assert
        (Item.Viewport.X_Offset + 1
           = Item.Horizontal_Scroll.Maximum_First
         and then Item.Horizontal_Scroll.First = Item.Viewport.X_Offset,
         "horizontal scrollbar keyboard and wheel input diverged "
         & "from content");
      Handle_Focused_Key
        (Item, Terminal_Key (Flyology_TUI.Events.Home_Key), Geometry);
      declare
         Thumb : constant Flyology_TUI.Geometry.Rectangle :=
           Item.Horizontal_Scroll.Thumb_Region;
         Thumb_X : constant Natural :=
           Natural (Geometry.Horizontal_Scroll_Origin.X + Thumb.X);
         Thumb_Y : constant Natural :=
           Natural (Geometry.Horizontal_Scroll_Origin.Y + Thumb.Y);
         Drag_X : constant Natural :=
           Natural
             (Geometry.Horizontal_Scroll_Region.X
              + Integer (Geometry.Horizontal_Scroll_Region.Width - 2));
      begin
         Handle_Mouse
           (Item,
            (Kind => Flyology_TUI.Events.Mouse_Input,
             Mouse => Pointer (Thumb_X, Thumb_Y)));
         Assert
           (Item.Capture = Horizontal_Scroll_Capture,
            "horizontal thumb did not acquire application capture");
         Handle_Mouse
           (Item,
            (Kind => Flyology_TUI.Events.Mouse_Input,
             Mouse => Pointer
               (Drag_X, Thumb_Y, Flyology_TUI.Events.Mouse_Drag)));
         Handle_Mouse
           (Item,
            (Kind => Flyology_TUI.Events.Mouse_Input,
             Mouse => Pointer
               (Drag_X, Thumb_Y, Flyology_TUI.Events.Mouse_Release)));
         Assert
           (Item.Capture = No_Capture
            and then Item.Viewport.X_Offset
              = Item.Horizontal_Scroll.Maximum_First
            and then Item.Horizontal_Scroll.First = Item.Viewport.X_Offset,
            "captured horizontal thumb drag did not update the viewport");
      end;

      Activate (Item, Viewport_Field);
      Update (Item, Key, Next);
      Assert
        (Item.Focus = Vertical_Scroll_Field,
         "Basics Tab skipped the visible vertical scrollbar");
      Update (Item, Key, Next);
      Assert
        (Item.Focus = Horizontal_Scroll_Field,
         "Basics Tab skipped the visible horizontal scrollbar");
      Update (Item, Key, Next);
      Assert
        (Item.Focus = Form_Field,
         "Basics Tab did not leave the bound viewport group");
      Update (Item, Key (Shift => True), Next);
      Assert
        (Item.Focus = Horizontal_Scroll_Field,
         "Basics Shift-Tab skipped the visible horizontal scrollbar");
      Update
        (Item,
         Events.From_Terminal (Flyology_TUI.Events.Resized (1, 1)),
         Next);
      Geometry := Layout (Item);
      Assert
        (Geometry.Vertical_Scroll_Region.Width = 0
         and then Geometry.Horizontal_Scroll_Region.Height = 0
         and then Item.Focus not in
           Vertical_Scroll_Field | Horizontal_Scroll_Field,
         "tiny resize retained hidden scrollbar focus");

      Activate_Page (Item, Chat_Page);
      Set_Terminal_Size (Item, 190, 55);
      Geometry := Layout (Item);
      declare
         Presentation : constant Chats.Presentation :=
           Chat_Presentation (Item, Geometry);
         Body_Area : constant Flyology_TUI.Geometry.Rectangle :=
           Chats.Body_Region (Presentation, User_Request_Message);
      begin
         Assert
           (Geometry.Chat_Origin.X = 47
            and then Chats.Frame (Presentation).Width = 96
            and then Fits
              ((0, 0, Geometry.Chat_Frame.Width,
                Geometry.Chat_Frame.Height),
               Chats.Bubble_Region
                 (Presentation, User_Request_Message)),
            "wide chat ignored its centered readable frame");
         Handle_Chat_Mouse
           (Item,
            Pointer
              (Natural (Geometry.Chat_Origin.X + Body_Area.X),
               Natural (Geometry.Chat_Origin.Y + Body_Area.Y)),
            Geometry);
         Assert
           (Item.Chat.Selected_Id = User_Request_Message,
            "wide chat hit routing ignored its centered origin");
      end;

      Activate (Item, Chat_Composer_Field);
      Item.Chat_Composer.Try_Set_Text ("   ", Accepted);
      Assert (Accepted, "blank composer seed was rejected");
      Handle_Focused_Key
        (Item, Terminal_Key (Flyology_TUI.Events.Enter_Key), Geometry);
      Assert
        (Item.Submitted_Count = 0
         and then Item.Chat_Composer.Value = "   ",
         "blank composer content was submitted or cleared");
      Item.Chat_Composer.Try_Set_Text ("Hello from the composer", Accepted);
      Handle_Focused_Key
        (Item,
         Terminal_Key (Flyology_TUI.Events.Enter_Key, Shift => True),
         Geometry);
      Assert
        (Item.Submitted_Count = 0
         and then Item.Chat_Composer.Line_Count = 2,
         "Shift-Enter did not insert a composer newline");
      Frame := Present (Item);
      Assert
        (Frame.Cursor.Visible
         and then Frame.Cursor.X >= Natural (Geometry.Chat_Frame.X)
         and then Frame.Cursor.X
           < Natural (Geometry.Chat_Frame.X)
             + Geometry.Chat_Frame.Width,
         "focused chat composer did not project its cursor");
      Handle_Focused_Key
        (Item, Terminal_Key (Flyology_TUI.Events.Enter_Key), Geometry);
      Assert
        (Item.Submitted_Count = 1
         and then Item.Chat_Composer.Value = ""
         and then Item.Chat.Contains (Submitted_Message_1)
         and then Item.Chat.Selected_Id = Submitted_Message_1
         and then Item.Chat.Follows_Tail,
         "Enter did not submit, clear, select, and follow the "
         & "bounded message");
      declare
         Presentation : constant Chats.Presentation :=
           Chat_Presentation (Item, Geometry);
         Bubble : constant Flyology_TUI.Geometry.Rectangle :=
           Chats.Bubble_Region (Presentation, Submitted_Message_1);
      begin
         Assert
           (Chats.Has_Message (Presentation, Submitted_Message_1)
            and then Bubble.X > 0
            and then Bubble.X + Integer (Bubble.Width)
              <= Integer (Geometry.Chat_Frame.Width),
            "submitted user message was not a right-aligned bounded bubble");
      end;

      Item.Chat_Composer.Try_Set_Text
        ("This submitted message is deliberately longer than the readable "
         & "conversational bubble so its caller-owned surface must wrap.",
         Accepted);
      declare
         Presentation : constant Chats.Presentation :=
           Chat_Presentation (Item, Geometry);
         Composer_Area : constant Flyology_TUI.Geometry.Rectangle :=
           Chats.Composer_Region (Chats.Layout (Presentation));
         Send_X : constant Natural := Natural
           (Geometry.Chat_Origin.X + Composer_Area.X
            + Integer (Composer_Area.Width - Item.Chat_Send.Width));
         Send_Y : constant Natural := Natural
           (Geometry.Chat_Origin.Y + Composer_Area.Y + 4);
      begin
         Handle_Chat_Mouse
           (Item, Pointer (Send_X, Send_Y), Geometry);
         Handle_Chat_Mouse
           (Item,
            Pointer
              (Send_X, Send_Y, Flyology_TUI.Events.Mouse_Release),
            Geometry);
      end;
      Assert
        (Item.Submitted_Count = 2
         and then Item.Chat_Composer.Value = "",
         "Send button mouse flow did not submit and clear the composer");
      declare
         Body_Width : constant Natural := Chat_Body_Width (Item, Geometry);
         Payload : constant Chats.Body_Entry :=
           Chat_Body (Item, Submitted_Message_2, Body_Width);
      begin
         Assert
           (Payload.Content.Height > 1
            and then Payload.Content.Width <= Body_Width,
            "long submitted message did not wrap to its bubble width");
      end;
      for Index in 3 .. 4 loop
         Item.Chat_Composer.Try_Set_Text
           ("bounded message" & Integer'Wide_Wide_Image (Index),
            Accepted);
         Submit_Chat (Item);
      end loop;
      Item.Chat_Composer.Try_Set_Text ("capacity retained", Accepted);
      Submit_Chat (Item);
      Assert
        (Item.Submitted_Count = 4
         and then Item.Chat_Composer.Value = "capacity retained",
         "bounded chat capacity did not retain rejected composer input");

      Set_Terminal_Size (Item, 40, 12);
      Geometry := Layout (Item);
      declare
         Body_Width : constant Natural := Chat_Body_Width (Item, Geometry);
         Payload : constant Chats.Body_Entry :=
           Chat_Body (Item, Welcome_Message, Body_Width);
      begin
         Assert
           (Payload.Content.Height > 2
            and then Payload.Content.Width <= Body_Width,
            "narrow initial chat body did not wrap to its bubble width");
      end;

      Activate (Item, Page_Navigation);
      Set_Terminal_Size (Item, 40, 6);
      Geometry := Layout (Item);
      declare
         Presentation : constant Chats.Presentation :=
           Chat_Presentation (Item, Geometry);
         Plan : constant Chats.Layout_Plan := Chats.Layout (Presentation);
         Composer_Area : constant Flyology_TUI.Geometry.Rectangle :=
           Chats.Composer_Region (Plan);
      begin
         Assert
           (Geometry.Chat_Frame.Height = 3
            and then Chats.Frame (Presentation).Height = 3
            and then not Chats.Has_Footer (Plan)
            and then Composer_Area.Height = 3
            and then Fits
              ((0, 0, Geometry.Chat_Frame.Width,
                Geometry.Chat_Frame.Height), Composer_Area),
            "tiny chat composer or footer escaped its exact frame");
         Handle_Chat_Mouse
           (Item,
            Pointer
              (Natural (Geometry.Chat_Frame.X),
               Natural (Geometry.Help.Y)),
            Geometry);
         Assert
           (Item.Focus = Page_Navigation and then Item.Capture = No_Capture,
            "tiny invisible chat controls intercepted the help row");
      end;

      Set_Terminal_Size (Item, 1, 1);
      Geometry := Layout (Item);
      Assert
        (Geometry.Chat_Frame.Height = 0
         and then Item.Chat.Viewport_Rows = 0,
         "one-cell terminal retained hidden chat rows");
      declare
         Hidden_Targets : constant array (Positive range <>) of
           Focus_Target :=
             [Chat_Field, Chat_Stream_Field,
              Chat_Composer_Field, Chat_Send_Field];
      begin
         for Hidden of Hidden_Targets loop
            Activate (Item, Hidden);
            if Hidden = Chat_Composer_Field then
               Frame := Present (Item);
               Assert
                 (not Frame.Cursor.Visible,
                  "zero composer region published a cursor");
            end if;
            Normalize_Focus (Item);
            Assert
              (Item.Focus = Page_Navigation,
               "one-cell chat retained an invisible focus target");
         end loop;
      end;
      Next_Focus (Item, Backwards => False);
      Assert
        (Item.Focus = Page_Navigation,
         "one-cell forward traversal entered an invisible chat target");
      Next_Focus (Item, Backwards => True);
      Assert
        (Item.Focus = Page_Navigation,
         "one-cell reverse traversal entered an invisible chat target");

      Activate_Page (Item, Markdown_Page);
      Set_Terminal_Size (Item, 40, 12);
      Activate (Item, Markdown_Preview_Field);
      Normalize_Focus (Item);
      Assert
        (Item.Focus = Markdown_Source_Field,
         "source-only Markdown retained invisible preview focus");
      Next_Focus (Item, Backwards => False);
      Assert
        (Item.Focus = Page_Navigation,
         "source-only Markdown traversal visited an invisible preview");

      Activate_Page (Item, Menus_Page);
      Set_Terminal_Size (Item, 80, 24);
      Activate (Item, Menu_Field);
      Item.Menu.Open_Menu (File_Menu);
      Geometry := Layout (Item);
      Handle_Mouse
        (Item,
         (Kind => Flyology_TUI.Events.Mouse_Input,
          Mouse => Pointer (2, Natural (Geometry.Tabs.Y))));
      Assert
        (Current_Page (Item) = Menus_Page,
         "open menu allowed a tab click through its modal layer");
      if not Item.Menu.Is_Open then
         Item.Menu.Open_Menu (File_Menu);
      end if;
      Transitions.Reset (Next);
      Update (Item, Key, Next);
      Assert
        (Current_Page (Item) = Menus_Page,
         "open menu allowed global Tab traversal");

      Set_Terminal_Size (Item, 80, 24);
      Activate_Page (Item, Controls_Page);
      Activate (Item, Dropdown_Field);
      Item.Dropdown.Open;
      Assert (Item.Dropdown.Is_Open, "dropdown did not open before resize");

      Set_Terminal_Size (Item, 20, 6);
      Geometry := Layout (Item);
      Assert
        (Visible_Dropdown_Bounds (Item, Geometry).Height = 0
         and then Geometry.Dropdown_Origin.Y = Geometry.Help.Y,
         "small layout did not fully clip the retained dropdown");
      Handle_Mouse
        (Item,
         (Kind  => Flyology_TUI.Events.Mouse_Input,
          Mouse => Pointer
            (Natural (Geometry.Dropdown_Origin.X),
             Natural (Geometry.Dropdown_Origin.Y))));
      Assert
        (not Item.Dropdown.Is_Open,
         "click on a clipped dropdown cell did not dismiss it");
      Transitions.Reset (Next);
      Update (Item, Key, Next);
      Assert
        (Item.Focus = Page_Navigation,
         "dismissed clipped dropdown still blocked focus traversal");

      Assert
        (Fits (Geometry.Window_Workspace, Item.Window_A_Model.Bounds)
         and then Fits
           (Geometry.Window_Workspace, Item.Window_B_Model.Bounds),
         "terminal resize left a window outside the workspace");
      Assert
        (Item.Top_Window = Window_B
         and then Item.Focused_Window = Window_B,
         "terminal resize changed window z-order or focus reachability");

      Activate_Page (Item, Controls_Page);
      Activate (Item, Page_Navigation);
      Handle_Controls_Mouse (Item, Pointer (2, 2), Geometry);
      Assert
        (Item.Focus = Page_Navigation,
         "a zero-height controls slot accepted a mouse event");

      Activate_Page (Item, Editors_Page);
      Activate (Item, Page_Navigation);
      Handle_Editors_Mouse (Item, Pointer (2, 3), Geometry);
      Assert
        (Item.Focus = Page_Navigation,
         "a clipped editor accepted a mouse event");
      Activate (Item, Text_Area_Field);
      Frame := Present (Item);
      Assert
        (not Frame.Cursor.Visible,
         "a clipped editor exposed its retained cursor");

      Activate_Page (Item, Panels_Page);
      Set_Terminal_Size (Item, 80, 24);
      Activate (Item, Horizontal_Group_Field);
      Frame := Present (Item);
      Assert
        (Frame.Mouse = Flyology_TUI.Views.Cell_Motion,
         "panel page did not request drag motion events");
      Assert
        (Item.Horizontal_Group.Has_Focused_Divider,
         "focused panel group had no selected divider");
      Before_Divider := Item.Horizontal_Group.Focused_Divider;
      Transitions.Reset (Next);
      Update (Item, Key, Next);
      Assert
        (Item.Focus = Horizontal_Group_Field
         and then Item.Horizontal_Group.Focused_Divider /= Before_Divider,
         "plain Tab did not stay in the focused panel group");
      Transitions.Reset (Next);
      Update (Item, Key (Control => True), Next);
      Assert
        (Item.Focus = Vertical_Group_Field,
         "Control-Tab did not traverse application focus");

      Geometry := Layout (Item);
      declare
         Divider : constant Flyology_TUI.Geometry.Rectangle :=
           Item.Split.Divider_Region;
         X : constant Natural :=
           Natural (Geometry.Split_Origin.X + Divider.X);
         Y : constant Natural :=
           Natural (Geometry.Split_Origin.Y + Divider.Y);
         Drag_X : Natural;
      begin
         Before_Split := Item.Split.First_Span;
         Drag_X :=
           (if Before_Split > 10 then X - 3 else X + 3);
         Handle_Mouse
           (Item,
            (Kind => Flyology_TUI.Events.Mouse_Input,
             Mouse => Pointer (X, Y)));
         Assert
           (Item.Capture = Split_Capture,
            "split divider click did not acquire kitchen capture");
         Handle_Mouse
           (Item,
            (Kind => Flyology_TUI.Events.Mouse_Input,
             Mouse => Pointer
               (Drag_X, Y, Flyology_TUI.Events.Mouse_Drag)));
         Assert
           (Item.Split.First_Span /= Before_Split,
            "captured split drag did not change its span");
         Handle_Mouse
           (Item,
            (Kind => Flyology_TUI.Events.Mouse_Input,
             Mouse => Pointer
               (Drag_X, Y, Flyology_TUI.Events.Mouse_Release)));
         Assert
           (Item.Split.First_Span /= Before_Split,
            "split divider did not move through kitchen mouse routing");
      end;

      Activate_Page (Item, Windows_Page);
      Set_Terminal_Size (Item, 80, 24);
      Frame := Present (Item);
      Assert
        (Frame.Mouse = Flyology_TUI.Views.Cell_Motion,
         "windows page did not request drag motion events");
      Geometry := Layout (Item);
      Before_Window := Item.Window_B_Model.Bounds;
      Handle_Mouse
        (Item,
         (Kind => Flyology_TUI.Events.Mouse_Input,
          Mouse => Pointer
            (Natural (Geometry.Windows_Origin.X + Before_Window.X + 5),
             Natural (Geometry.Windows_Origin.Y + Before_Window.Y))));
      Handle_Mouse
        (Item,
         (Kind => Flyology_TUI.Events.Mouse_Input,
          Mouse => Pointer
            (Natural (Geometry.Windows_Origin.X + Before_Window.X + 8),
             Natural (Geometry.Windows_Origin.Y + Before_Window.Y + 2),
             Flyology_TUI.Events.Mouse_Drag)));
      Handle_Mouse
        (Item,
         (Kind => Flyology_TUI.Events.Mouse_Input,
          Mouse => Pointer
            (Natural (Geometry.Windows_Origin.X + Before_Window.X + 8),
             Natural (Geometry.Windows_Origin.Y + Before_Window.Y + 2),
             Flyology_TUI.Events.Mouse_Release)));
      Assert
        (Item.Window_B_Model.Bounds.X = Before_Window.X + 3
         and then Item.Window_B_Model.Bounds.Y = Before_Window.Y + 2,
         "window header did not move through kitchen mouse routing");

      Ada.Text_IO.Put_Line ("kitchen responsive self-tests passed");
   end Run_Responsive_Self_Test;

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
   if Ada.Command_Line.Argument_Count = 1
     and then Ada.Command_Line.Argument (1) = "--responsive-self-test"
   then
      Run_Responsive_Self_Test;
   else
      if Ada.Command_Line.Argument_Count > 1 then
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "usage: kitchen_sink [--responsive-self-test|"
            & "--color=auto|mono|ansi16|ansi256|truecolor]");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         return;
      elsif Ada.Command_Line.Argument_Count = 1 then
         declare
            Argument : constant String := Ada.Command_Line.Argument (1);
            Policy : Flyology_TUI.Color_Profiles.Policy;
         begin
            if Argument = "--color=auto" then
               Policy := Flyology_TUI.Color_Profiles.Automatic;
            elsif Argument = "--color=mono" then
               Policy := Flyology_TUI.Color_Profiles.Force_Monochrome;
            elsif Argument = "--color=ansi16" then
               Policy := Flyology_TUI.Color_Profiles.Force_ANSI_16;
            elsif Argument = "--color=ansi256" then
               Policy := Flyology_TUI.Color_Profiles.Force_ANSI_256;
            elsif Argument = "--color=truecolor" then
               Policy := Flyology_TUI.Color_Profiles.Force_Truecolor;
            else
               Ada.Text_IO.Put_Line
                 (Ada.Text_IO.Standard_Error,
                  "usage: kitchen_sink [--responsive-self-test|"
                  & "--color=auto|mono|ansi16|ansi256|truecolor]");
               Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
               return;
            end if;
            Terminal.Set_Color_Policy (Policy);
         end;
      end if;
      Runtime.Run (State, Terminal);
   end if;
exception
   when Error : Flyology_TUI.Backends.Backend_Error =>
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "kitchen_sink: " & Ada.Exceptions.Exception_Message (Error));
end Kitchen_Sink;
