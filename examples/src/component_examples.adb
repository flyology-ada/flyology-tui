with Ada.Command_Line;
with Ada.Characters.Conversions;
with Ada.Exceptions;
with Ada.Strings.Unbounded;
with Ada.Strings.Wide_Wide_Unbounded;
with Ada.Text_IO;
with Component_Capture_Support;
with Flyology_TUI.Components;
with Flyology_TUI.Components.Accordions;
with Flyology_TUI.Components.Breadcrumbs;
with Flyology_TUI.Components.Buttons;
with Flyology_TUI.Components.Chats;
with Flyology_TUI.Components.Check_Boxes;
with Flyology_TUI.Components.Dock_Workspaces;
with Flyology_TUI.Components.Dropdowns;
with Flyology_TUI.Components.Forms;
with Flyology_TUI.Components.Gradients;
with Flyology_TUI.Components.Help;
with Flyology_TUI.Components.Indicators;
with Flyology_TUI.Components.Interactions;
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
with Flyology_TUI.Geometry;
with Flyology_TUI.Layouts;
with Flyology_TUI.Layouts.Boxes;
with Flyology_TUI.Numeric_Series;
with Flyology_TUI.Skins;
with Flyology_TUI.Styles;
with Flyology_TUI.Surfaces;
with Flyology_TUI.Themes;

procedure Component_Examples is
   package Text renames Ada.Strings.Wide_Wide_Unbounded;
   package Narrow_Text renames Ada.Strings.Unbounded;

   function U (Value : Wide_Wide_String)
      return Text.Unbounded_Wide_Wide_String
   is (Text.To_Unbounded_Wide_Wide_String (Value));

   function Label_Of (Value : Text.Unbounded_Wide_Wide_String)
      return Wide_Wide_String
   is (Text.To_Wide_Wide_String (Value));

   package Lists is new Flyology_TUI.Components.Lists
     (Item_Type => Text.Unbounded_Wide_Wide_String,
      Label     => Label_Of);

   type Choice_Id is (Alpha, Beta, Gamma);
   function Choice_Identity (Item : Choice_Id) return Choice_Id is (Item);
   function Choice_Label (Item : Choice_Id) return Wide_Wide_String is
     (case Item is
         when Alpha => "Alpha",
         when Beta  => "Beta",
         when Gamma => "Gamma");

   package Radios is new Flyology_TUI.Components.Radio_Groups
     (Item_Type => Choice_Id, Id_Type => Choice_Id,
      Id_Of => Choice_Identity, Label => Choice_Label, Capacity => 8);
   package Selectors is new Flyology_TUI.Components.Selectors
     (Item_Type => Choice_Id, Id_Type => Choice_Id,
      Id_Of => Choice_Identity, Label => Choice_Label, Capacity => 8);
   package Dropdowns is new Flyology_TUI.Components.Dropdowns
     (Item_Type => Choice_Id, Id_Type => Choice_Id,
      Id_Of => Choice_Identity, Label => Choice_Label, Capacity => 8);
   package Tabs is new Flyology_TUI.Components.Tabs
     (Item_Type => Choice_Id, Id_Type => Choice_Id,
      Id_Of => Choice_Identity, Label => Choice_Label, Capacity => 8);

   type Path_Id is (Root_Path, Components_Path, Examples_Path, Current_Path);
   function Path_Identity (Item : Path_Id) return Path_Id is (Item);
   function Path_Label (Item : Path_Id) return Wide_Wide_String is
     (case Item is
         when Root_Path       => "flyology-tui",
         when Components_Path => "components",
         when Examples_Path   => "examples",
         when Current_Path    => "tables");
   package Breadcrumbs is new Flyology_TUI.Components.Breadcrumbs
     (Item_Type => Path_Id, Id_Type => Path_Id,
      Id_Of => Path_Identity, Label => Path_Label, Capacity => 8);

   type Row_Id is (Ada_Row, Unicode_Row, Mouse_Row, Skin_Row);
   type Column_Id is (Feature_Column, Status_Column);
   type Table_Row is record
      Id    : Row_Id;
      Ready : Boolean;
   end record;
   function Row_Identity (Item : Table_Row) return Row_Id is (Item.Id);
   function Row_Cell
     (Item : Table_Row; Column : Column_Id) return Wide_Wide_String is
     (case Column is
         when Feature_Column =>
           (case Item.Id is
               when Ada_Row     => "Typed Ada",
               when Unicode_Row => "Unicode cells",
               when Mouse_Row   => "Mouse capture",
               when Skin_Row    => "Render skins"),
         when Status_Column => (if Item.Ready then "ready" else "planned"));
   function Row_Less
     (Left, Right : Table_Row; Column : Column_Id) return Boolean is
     (case Column is
         when Feature_Column => Left.Id < Right.Id,
         when Status_Column => Left.Ready < Right.Ready);
   package Tables is new Flyology_TUI.Components.Tables
     (Item_Type => Table_Row, Id_Type => Row_Id, Column_Id => Column_Id,
      Id_Of => Row_Identity, Cell => Row_Cell, Less => Row_Less,
      Capacity => 8);
   Table_Columns : constant Tables.Column_Definitions :=
     [Feature_Column =>
        (Heading => U ("Feature"), Width => 18, Minimum_Width => 10,
         Align => Tables.Align_Left, Sortable => True),
      Status_Column =>
        (Heading => U ("Status"), Width => 10, Minimum_Width => 7,
         Align => Tables.Align_Left, Sortable => True)];

   type Tree_Id is
     (Root_Node, Source_Node, Components_Node, Tables_Node, Trees_Node,
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
         when Tables_Node     => "tables",
         when Trees_Node      => "trees",
         when Examples_Node   => "examples");
   function Tree_Depth (Item : Tree_Entry) return Natural is (Item.Depth);
   package Trees is new Flyology_TUI.Components.Trees
     (Item_Type => Tree_Entry, Id_Type => Tree_Id,
      Id_Of => Tree_Identity, Label => Tree_Label, Depth_Of => Tree_Depth,
      Capacity => 8);

   type Section_Id is (Overview_Section, Ownership_Section, Input_Section);
   function Section_Identity (Item : Section_Id) return Section_Id is (Item);
   function Section_Label (Item : Section_Id) return Wide_Wide_String is
     (case Item is
         when Overview_Section  => "Overview",
         when Ownership_Section => "State and ownership",
         when Input_Section     => "Keyboard and mouse");
   package Accordions is new Flyology_TUI.Components.Accordions
     (Section_Type => Section_Id, Id_Type => Section_Id,
      Id_Of => Section_Identity, Label => Section_Label, Capacity => 6);

   package Samples is new Flyology_TUI.Numeric_Series
     (Sample_Type => Integer, Maximum_Capacity => 32);
   function Sample_Value (Value : Integer) return Long_Float is
     (Long_Float (Value));
   package Sparklines is new Flyology_TUI.Components.Sparklines
     (Samples => Samples, To_Long_Float => Sample_Value);

   type Work_Id is (Build_Work, Test_Work, Deploy_Work);
   package Work_Progress is new Flyology_TUI.Components.Progress_Groups
     (Item_Id => Work_Id, Maximum_Items => 6);

   type Message_Id is (User_Message, Assistant_Message, Tool_Message);
   type Author_Id is (You, Assistant, Tool);
   function Author_Label (Author : Author_Id) return Wide_Wide_String is
     (case Author is
         when You => "you",
         when Assistant => "assistant",
         when Tool => "build tool");
   package Chats is new Flyology_TUI.Components.Chats
     (Message_Id => Message_Id, Author_Id => Author_Id,
      Author_Label => Author_Label, Capacity => 6);

   package Streams is new Flyology_TUI.Components.Streaming_Texts
     (Max_Code_Points => 512, Max_Lines => 32,
      Max_Viewport_Cells => 2_048);
   use type Streams.Operation_Result;

   type Dock_Id is (Explorer_Dock, Output_Dock, Inspector_Dock);
   function Dock_Label (Id : Dock_Id) return Wide_Wide_String is
     (case Id is
         when Explorer_Dock => "Explorer",
         when Output_Dock => "Output",
         when Inspector_Dock => "Inspector");
   package Docks is new Flyology_TUI.Components.Dock_Workspaces
     (Pane_Id => Dock_Id, Maximum_Panes => 3, Label => Dock_Label);

   type Menu_Id is (File_Menu, View_Menu, Density_Menu);
   type Menu_Item_Id is
     (New_Item, Save_Item, Separator_Item, Quit_Item,
      Status_Item, Density_Item, Compact_Item, Comfortable_Item);
   function Menu_Label (Id : Menu_Id) return Wide_Wide_String is
     (case Id is
         when File_Menu => "File",
         when View_Menu => "View",
         when Density_Menu => "Density");
   function Menu_Item_Label (Id : Menu_Item_Id) return Wide_Wide_String is
     (case Id is
         when New_Item => "New",
         when Save_Item => "Save",
         when Separator_Item => "separator",
         when Quit_Item => "Quit",
         when Status_Item => "Status bar",
         when Density_Item => "Density",
         when Compact_Item => "Compact",
         when Comfortable_Item => "Comfortable");
   function Shortcut_Label (Id : Menu_Item_Id) return Wide_Wide_String is
     (case Id is
         when New_Item => "Ctrl+N",
         when Save_Item => "Ctrl+S",
         when Quit_Item => "Ctrl+Q",
         when others => "");
   function Menu_Mnemonic (Id : Menu_Id) return Wide_Wide_Character is
     (Menu_Label (Id) (1));
   function Item_Mnemonic (Id : Menu_Item_Id) return Wide_Wide_Character is
     (Menu_Item_Label (Id) (1));
   package Menus is new Flyology_TUI.Components.Menubars
     (Menu_Id => Menu_Id, Item_Id => Menu_Item_Id,
      Menu_Label => Menu_Label, Item_Label => Menu_Item_Label,
      Shortcut_Label => Shortcut_Label, Menu_Mnemonic => Menu_Mnemonic,
      Item_Mnemonic => Item_Mnemonic, Maximum_Menus => 3,
      Maximum_Items => 10, Maximum_Depth => 2);

   type Token_Kind is (Keyword, String_Literal, Comment, Identifier);
   type Lexer_State is (Normal);

   function Is_Name_Character (Value : Wide_Wide_Character) return Boolean is
     (Value in 'a' .. 'z' or else Value in 'A' .. 'Z'
      or else Value = '_');

   procedure Next_Token
     (Line          : Wide_Wide_String;
      Initial       : Lexer_State;
      From          : Natural;
      Kind          : out Token_Kind;
      First, Last   : out Natural;
      Final         : out Lexer_State;
      Has_Token     : out Boolean)
   is
      pragma Unreferenced (Initial);
      Position : Natural := From;
   begin
      Final := Normal;
      Kind := Identifier;
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
      elsif Line (Line'First + Position) = '-' then
         Kind := Comment;
         Last := Line'Length;
      elsif Line (Line'First + Position) = '"' then
         Kind := String_Literal;
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
         if Line (Line'First + First .. Line'First + Last - 1) in
           "with" | "procedure" | "is" | "begin" | "end"
         then
            Kind := Keyword;
         end if;
      end if;
   end Next_Token;

   package Syntax is new Flyology_TUI.Components.Syntax_Editors
     (Token_Kind => Token_Kind, Lexer_State => Lexer_State,
      Initial_State => Normal, Maximum_Tokens_Per_Line => 20,
      Next_Token => Next_Token);

   function Skin_From_Name (Value : String)
      return Flyology_TUI.Skins.Skin_Id is
     (if Value = "charm-default" then Flyology_TUI.Skins.Charm_Default
      elsif Value = "charm-dark" then Flyology_TUI.Skins.Charm_Dark
      elsif Value = "charm-light" then Flyology_TUI.Skins.Charm_Light
      elsif Value = "turbo-vision" then Flyology_TUI.Skins.Turbo_Vision
      else raise Constraint_Error with "unknown component-example skin");

   function Theme_For (Skin : Flyology_TUI.Skins.Skin)
      return Flyology_TUI.Themes.Theme is
     (Flyology_TUI.Themes.To_Theme (Skin.Palette));

   function Stack
     (Top, Bottom : Flyology_TUI.Surfaces.Surface;
      Gap         : Natural := 1) return Flyology_TUI.Surfaces.Surface is
     (Flyology_TUI.Layouts.Join_Vertically (Top, Bottom, Gap));

   function Stage
     (Name    : Wide_Wide_String;
      Content : Flyology_TUI.Surfaces.Surface;
      Skin    : Flyology_TUI.Skins.Skin) return Flyology_TUI.Surfaces.Surface
   is
      Heading : constant Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.From_Text (Name, Skin.Palette.Title);
      Stage_Body : constant Flyology_TUI.Surfaces.Surface :=
        Stack (Heading, Content, 1).Inherit_Colors (Skin.Dialog);
      Width : constant Natural := Natural'Max (48, Content.Width + 4);
      Height : constant Natural := Natural'Max (8, Content.Height + 5);
      Box : constant Flyology_TUI.Layouts.Block :=
        (Width => Width, Height => Height,
         Padding => (Top => 1, Right => 1, Bottom => 1, Left => 1),
         Border => Flyology_TUI.Layouts.Rounded,
         Appearance => Skin.Palette.Border,
         others => <>);
   begin
      return Flyology_TUI.Layouts.Render (Box, Stage_Body, Skin.Panel.Frame);
   end Stage;

   function Example_Button (Skin : Flyology_TUI.Skins.Skin)
      return Flyology_TUI.Surfaces.Surface
   is
      Item : Flyology_TUI.Components.Buttons.Model :=
        Flyology_TUI.Components.Buttons.Create ("Run command");
   begin
      return Flyology_TUI.Components.Buttons.Render
        (Item, Skin, Has_Focus => True);
   end Example_Button;

   function Example_Check_Box (Skin : Flyology_TUI.Skins.Skin)
      return Flyology_TUI.Surfaces.Surface
   is
      Item : Flyology_TUI.Components.Check_Boxes.Model :=
        Flyology_TUI.Components.Check_Boxes.Create
          ("Enable telemetry", Flyology_TUI.Components.Check_Boxes.Checked);
   begin
      return Flyology_TUI.Components.Check_Boxes.Render
        (Item, Skin, Has_Focus => True);
   end Example_Check_Box;

   function Example_Radios (Skin : Flyology_TUI.Skins.Skin)
      return Flyology_TUI.Surfaces.Surface
   is
      Item : Radios.Model := Radios.Create ([Alpha, Beta, Gamma]);
   begin
      Item.Select_Id (Beta);
      return Radios.Render (Item, Skin, Has_Focus => True);
   end Example_Radios;

   function Example_Selector (Skin : Flyology_TUI.Skins.Skin)
      return Flyology_TUI.Surfaces.Surface
   is
      Item : Selectors.Model := Selectors.Create
        ([Alpha, Beta, Gamma], Flyology_TUI.Components.Multiple_Selection);
   begin
      Item.Set_Selected (Beta);
      Item.Set_Selected (Gamma);
      return Selectors.Render
        (Item, Selectors.From_Palette (Skin.Palette), Has_Focus => True);
   end Example_Selector;

   function Example_Dropdown (Skin : Flyology_TUI.Skins.Skin)
      return Flyology_TUI.Surfaces.Surface
   is
      Item : Dropdowns.Model := Dropdowns.Create ([Alpha, Beta, Gamma]);
   begin
      Item.Open;
      return Dropdowns.Render
        (Item, Dropdowns.From_Palette (Skin.Palette), Has_Focus => True);
   end Example_Dropdown;

   function Example_Tabs (Skin : Flyology_TUI.Skins.Skin)
      return Flyology_TUI.Surfaces.Surface
   is
      Item : Tabs.Model := Tabs.Create ([Alpha, Beta, Gamma]);
   begin
      Item.Activate (Beta);
      return Tabs.Frame (Tabs.Present (Item, 38, Skin, Has_Focus => True));
   end Example_Tabs;

   function Example_Text_Input (Skin : Flyology_TUI.Skins.Skin)
      return Flyology_TUI.Surfaces.Surface
   is
      Item : Flyology_TUI.Components.Text_Inputs.Model :=
        Flyology_TUI.Components.Text_Inputs.Create (32, "Project name");
   begin
      Item.Set_Value ("Flyology TUI");
      Item.Focus;
      return Item.Render (Theme_For (Skin));
   end Example_Text_Input;

   function Example_List (Skin : Flyology_TUI.Skins.Skin)
      return Flyology_TUI.Surfaces.Surface
   is
      Item : Lists.Model := Lists.Create (30, 5);
   begin
      Item.Set_Items
        ([U ("Typed messages"), U ("Declarative views"),
          U ("Bounded storage"), U ("Headless tests"), U ("Render skins")]);
      return Item.Render (Theme_For (Skin));
   end Example_List;

   function Example_Form (Skin : Flyology_TUI.Skins.Skin)
      return Flyology_TUI.Surfaces.Surface
   is
      Item : Flyology_TUI.Components.Forms.Model :=
        Flyology_TUI.Components.Forms.Create
          ([(Label => U ("Name"), Initial => U ("Ada programmer"),
             Placeholder => U ("Your name")),
            (Label => U ("Project"), Initial => U ("Flyology TUI"),
             Placeholder => U ("Project name"))],
           Input_Width => 22);
   begin
      return Item.Render (Theme_For (Skin));
   end Example_Form;

   function Example_Help (Skin : Flyology_TUI.Skins.Skin)
      return Flyology_TUI.Surfaces.Surface is
     (Flyology_TUI.Components.Help.Render
        ([(U ("Tab"), U ("next control"), True),
          (U ("Enter"), U ("activate"), True),
          (U ("Esc"), U ("cancel"), True)],
         Width => 34, Theme => Theme_For (Skin), Vertical => True));

   function Example_Indicators (Skin : Flyology_TUI.Skins.Skin)
      return Flyology_TUI.Surfaces.Surface
   is
      Theme : constant Flyology_TUI.Themes.Theme := Theme_For (Skin);
      Top : constant Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Layouts.Join_Horizontally
          (Flyology_TUI.Components.Indicators.Badge
             ("bounded", Flyology_TUI.Components.Indicators.Success_Tone,
              Theme),
           Flyology_TUI.Components.Indicators.Key_Value
             ("messages", "24", 20, Theme), Gap => 2);
      Gauge : constant Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Components.Indicators.Gauge (0.64, 34, Theme);
      Status : constant Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Components.Indicators.Status_Line
          ([Flyology_TUI.Components.Indicators.Make_Segment
             ("RUNNING", Flyology_TUI.Components.Indicators.High,
              Flyology_TUI.Components.Indicators.Success_Tone),
            Flyology_TUI.Components.Indicators.Make_Segment
             ("mouse ready"),
            Flyology_TUI.Components.Indicators.Make_Segment
             ("utf-8")],
           42, Theme);
   begin
      return Stack (Stack (Top, Gauge), Status);
   end Example_Indicators;

   function Example_Progress (Skin : Flyology_TUI.Skins.Skin)
      return Flyology_TUI.Surfaces.Surface
   is
      Item : Flyology_TUI.Components.Progress.Model :=
        Flyology_TUI.Components.Progress.Create (38, True);
   begin
      Item.Set (0.64);
      return Item.Render (Theme_For (Skin));
   end Example_Progress;

   function Example_Spinner (Skin : Flyology_TUI.Skins.Skin)
      return Flyology_TUI.Surfaces.Surface
   is
      Item : Flyology_TUI.Components.Spinners.Model :=
        Flyology_TUI.Components.Spinners.Create;
   begin
      Item.Tick;
      Item.Tick;
      return Flyology_TUI.Layouts.Join_Horizontally
        (Item.Render (Theme_For (Skin)),
         Flyology_TUI.Surfaces.From_Text
           (" caller-advanced activity", Skin.Palette.Content));
   end Example_Spinner;

   function Example_Viewport return Flyology_TUI.Surfaces.Surface
   is
      Content : Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.From_Text
          ("viewport row 1 — clipped content"
           & Wide_Wide_Character'Val (10)
           & "viewport row 2 — same retained surface"
           & Wide_Wide_Character'Val (10)
           & "viewport row 3 — horizontal overflow");
      Item : Flyology_TUI.Components.Viewports.Model :=
        Flyology_TUI.Components.Viewports.Create (30, 3);
   begin
      Item.Set_Content (Content);
      Item.Scroll (4, 0);
      return Item.Render;
   end Example_Viewport;

   function Example_Sparkline (Skin : Flyology_TUI.Skins.Skin)
      return Flyology_TUI.Surfaces.Surface
   is
      Item : Samples.Series := Samples.Create (24);
      Values : constant array (Positive range <>) of Integer :=
        [1, 2, 3, 5, 4, 7, 6, 5, 8, 6, 9, 7, 10, 8];
   begin
      for Value of Values loop
         Item.Append (Value);
      end loop;
      return Sparklines.Render (Item, 34, Theme => Theme_For (Skin));
   end Example_Sparkline;

   function Example_Gradient return Flyology_TUI.Surfaces.Surface
   is
      Item : Flyology_TUI.Components.Gradients.Model (4) :=
        Flyology_TUI.Components.Gradients.Create
          (4, Application =>
             Flyology_TUI.Components.Gradients.Apply_Background);
      Result : Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.Create (42, 4);
      Success : Boolean;
   begin
      Item.Try_Set_Stops
        ([(0, (80, 35, 160)), (350_000, (170, 75, 235)),
          (700_000, (35, 185, 210)),
          (Flyology_TUI.Components.Gradients.Stop_Scale, (185, 220, 65))],
         Success);
      if not Success then
         raise Program_Error with "component gradient seed rejected";
      end if;
      Result.Write (2, 1, "semantic truecolor → reduced profiles");
      Item.Apply
        (Result,
         Flyology_TUI.Geometry.Rectangle'
           (0, 0, Result.Width, Result.Height));
      return Result;
   end Example_Gradient;

   function Example_Breadcrumbs (Skin : Flyology_TUI.Skins.Skin)
      return Flyology_TUI.Surfaces.Surface
   is
      Item : Breadcrumbs.Model := Breadcrumbs.Create
        ([Root_Path, Components_Path, Examples_Path, Current_Path], 40);
   begin
      Item.Set_Active (Current_Path);
      return Item.Render (Theme_For (Skin), Has_Focus => True);
   end Example_Breadcrumbs;

   function Example_Table (Skin : Flyology_TUI.Skins.Skin)
      return Flyology_TUI.Surfaces.Surface
   is
      Item : Tables.Model := Tables.Create
        ([(Ada_Row, True), (Unicode_Row, True),
          (Mouse_Row, True), (Skin_Row, True)],
         Table_Columns, Viewport_Rows => 4);
   begin
      Item.Select_Id (Unicode_Row);
      Item.Sort_By (Feature_Column, Tables.Ascending);
      return Item.Render (Theme_For (Skin), Has_Focus => True);
   end Example_Table;

   function Example_Tree (Skin : Flyology_TUI.Skins.Skin)
      return Flyology_TUI.Surfaces.Surface
   is
      Item : Trees.Model := Trees.Create
        ([(Root_Node, 0), (Source_Node, 1), (Components_Node, 2),
          (Tables_Node, 3), (Trees_Node, 3), (Examples_Node, 1)],
         Viewport_Rows => 6);
   begin
      Item.Set_Expanded (Root_Node);
      Item.Set_Expanded (Source_Node);
      Item.Set_Expanded (Components_Node);
      Item.Select_Id (Trees_Node);
      return Item.Render (Theme_For (Skin), Has_Focus => True);
   end Example_Tree;

   function Example_Accordion (Skin : Flyology_TUI.Skins.Skin)
      return Flyology_TUI.Surfaces.Surface
   is
      Item : Accordions.Model := Accordions.Create
        ([Overview_Section, Ownership_Section, Input_Section]);
   begin
      Item.Set_Expanded (Overview_Section);
      return Accordions.Frame
        (Item.Present
           ([1 =>
              (Overview_Section,
               Flyology_TUI.Surfaces.From_Text
                 ("Stable IDs, external bodies, bounded headers.",
                  Skin.Palette.Content))],
            44, Theme_For (Skin), Has_Focus => True));
   end Example_Accordion;

   function Example_Scrollbar (Skin : Flyology_TUI.Skins.Skin)
      return Flyology_TUI.Surfaces.Surface
   is
      Horizontal : Flyology_TUI.Components.Scrollbars.Model :=
        Flyology_TUI.Components.Scrollbars.Create
          (Flyology_TUI.Layouts.Boxes.Horizontal, 38);
      Vertical : Flyology_TUI.Components.Scrollbars.Model :=
        Flyology_TUI.Components.Scrollbars.Create
          (Flyology_TUI.Layouts.Boxes.Vertical, 6);
   begin
      Horizontal.Configure (100, 28, 31);
      Horizontal.Focus;
      Vertical.Configure (80, 18, 22);
      return Flyology_TUI.Layouts.Join_Horizontally
        (Horizontal.Render (Skin), Vertical.Render (Skin), Gap => 2);
   end Example_Scrollbar;

   function Example_Panel_Group (Skin : Flyology_TUI.Skins.Skin)
      return Flyology_TUI.Surfaces.Surface
   is
      Item : Flyology_TUI.Components.Panel_Groups.Model :=
        Flyology_TUI.Components.Panel_Groups.Create
          (Flyology_TUI.Layouts.Boxes.Horizontal, 46, 7,
           [1 => (6, 12, 1), 2 => (8, 18, 2), 3 => (6, 12, 1)]);
   begin
      Item.Focus;
      Item.Focus_Divider (1);
      return Item.Render
        ([1 => Flyology_TUI.Surfaces.From_Text ("navigator"),
          2 => Flyology_TUI.Surfaces.From_Text ("editor"),
          3 => Flyology_TUI.Surfaces.From_Text ("preview")],
         Theme_For (Skin));
   end Example_Panel_Group;

   function Example_Split (Skin : Flyology_TUI.Skins.Skin)
      return Flyology_TUI.Surfaces.Surface
   is
      Item : Flyology_TUI.Components.Split_Panes.Model :=
        Flyology_TUI.Components.Split_Panes.Create
          (Flyology_TUI.Layouts.Boxes.Horizontal, 46, 7, 20, 8, 8);
   begin
      Item.Focus;
      return Item.Render
        (Flyology_TUI.Surfaces.From_Text ("source pane"),
         Flyology_TUI.Surfaces.From_Text ("preview pane"),
         Theme_For (Skin));
   end Example_Split;

   function Example_Window (Skin : Flyology_TUI.Skins.Skin)
      return Flyology_TUI.Surfaces.Surface
   is
      Item : Flyology_TUI.Components.Windows.Model :=
        Flyology_TUI.Components.Windows.Create (4, 2, 36, 10, 18, 6);
      Workspace : constant Flyology_TUI.Geometry.Rectangle := (0, 0, 48, 15);
      Window_Body : constant Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.From_Text
          ("Drag the header to move."
           & Wide_Wide_Character'Val (10)
           & "Drag borders to resize."
           & Wide_Wide_Character'Val (10)
           & "The caller owns this content.");
   begin
      Item.Focus;
      return Item.Render ("Activity", Window_Body, Workspace, Skin);
   end Example_Window;

   function Example_Dock (Skin : Flyology_TUI.Skins.Skin)
      return Flyology_TUI.Surfaces.Surface
   is
      Item : Docks.Model := Docks.Create
        ([1 =>
           (Id => Explorer_Dock, Side => Docks.Dock_Left,
            Dock_Extent => 14, Minimum_Extent => 8,
            Float_X => 2, Float_Y => 2, Float_Width => 24,
            Float_Height => 8, others => <>),
         2 =>
           (Id => Output_Dock, Side => Docks.Dock_Bottom,
            Dock_Extent => 5, Minimum_Extent => 3,
            Float_X => 12, Float_Y => 7, Float_Width => 30,
            Float_Height => 7, others => <>),
         3 =>
           (Id => Inspector_Dock, Side => Docks.Dock_Right,
            Dock_Extent => 14, Minimum_Extent => 8,
            Float_X => 18, Float_Y => 3, Float_Width => 24,
            Float_Height => 8, Initially_Collapsed => True,
            others => <>)],
         48, 16);
   begin
      Item.Focus;
      return Docks.Frame
        (Item.Present
           ([Explorer_Dock => Flyology_TUI.Surfaces.From_Text
               ("src" & Wide_Wide_Character'Val (10) & "examples"),
             Output_Dock => Flyology_TUI.Surfaces.From_Text
               ("build complete"),
             Inspector_Dock => Flyology_TUI.Surfaces.From_Text
               ("selected: component")],
            Skin));
   end Example_Dock;

   function Example_Text_Area (Skin : Flyology_TUI.Skins.Skin)
      return Flyology_TUI.Surfaces.Surface
   is
      Item : Flyology_TUI.Components.Text_Areas.Model (1_024, 64, 16, 4_096) :=
        Flyology_TUI.Components.Text_Areas.Create
          (1_024, 64, 16, 4_096, 44, 7, "Write bounded notes");
      Accepted : Boolean;
   begin
      Item.Try_Set_Text
        ("Unicode-aware multiline editing"
         & Wide_Wide_Character'Val (10)
         & "Selection, undo, paste, and mouse capture"
         & Wide_Wide_Character'Val (10)
         & "Soft wrapping keeps grapheme clusters whole.", Accepted);
      if not Accepted then
         raise Program_Error with "text-area component seed rejected";
      end if;
      Item.Set_Wrap (Flyology_TUI.Components.Text_Areas.Soft_Wrap);
      Item.Focus;
      return Item.Render (Theme_For (Skin));
   end Example_Text_Area;

   function Example_Syntax (Skin : Flyology_TUI.Skins.Skin)
      return Flyology_TUI.Surfaces.Surface
   is
      Item : Syntax.Model (1_024, 64, 16, 4_096) :=
        Syntax.Create (1_024, 64, 16, 4_096, 44, 8, "Ada source");
      Accepted : Boolean;
      Look : Syntax.Appearance := Syntax.From_Theme (Theme_For (Skin));
   begin
      Item.Try_Set_Text
        ("with Ada.Text_IO;" & Wide_Wide_Character'Val (10)
         & "procedure Hello is" & Wide_Wide_Character'Val (10)
         & "begin" & Wide_Wide_Character'Val (10)
         & "   -- caller-budgeted highlighting"
         & Wide_Wide_Character'Val (10)
         & "   Put_Line (""Hello"");" & Wide_Wide_Character'Val (10)
         & "end Hello;", Accepted);
      if not Accepted then
         raise Program_Error with "syntax component seed rejected";
      end if;
      Look.Tokens (Keyword) := Skin.Palette.Interaction;
      Look.Tokens (String_Literal) := Skin.Palette.Success;
      Look.Tokens (Comment) := Skin.Palette.Muted;
      Item.Advance_Highlighting (Natural'Last);
      Item.Focus;
      return Item.Render (Look);
   end Example_Syntax;

   Markdown_Source : constant Wide_Wide_String :=
     "# Component examples" & Wide_Wide_Character'Val (10)
     & Wide_Wide_Character'Val (10)
     & "Render **bounded Markdown** with links and tasks."
     & Wide_Wide_Character'Val (10)
     & "- [x] Exact public API" & Wide_Wide_Character'Val (10)
     & "- [ ] Caller-budgeted parsing" & Wide_Wide_Character'Val (10)
     & "Read [the guide](https://tui.flyology.org/guide/).";

   function Example_Markdown_Viewer (Skin : Flyology_TUI.Skins.Skin)
      return Flyology_TUI.Surfaces.Surface
   is
      Item : Flyology_TUI.Components.Markdown_Viewers.Model (2_048, 64, 16) :=
        Flyology_TUI.Components.Markdown_Viewers.Create
          (2_048, 64, 16, 46, 10);
      Accepted : Boolean;
   begin
      Item.Try_Set_Source (Markdown_Source, Accepted);
      if not Accepted then
         raise Program_Error with "Markdown viewer seed rejected";
      end if;
      Item.Advance_Parsing (Natural'Last);
      Item.Focus;
      return Flyology_TUI.Components.Markdown_Viewers.Frame
        (Item.Present (Theme_For (Skin)));
   end Example_Markdown_Viewer;

   function Example_Markdown_Editor (Skin : Flyology_TUI.Skins.Skin)
      return Flyology_TUI.Surfaces.Surface
   is
      Item : Flyology_TUI.Components.Markdown_Editors.Model
        (2_048, 64, 16, 4_096, 16) :=
        Flyology_TUI.Components.Markdown_Editors.Create
          (2_048, 64, 16, 4_096, 16, 52, 12,
           Flyology_TUI.Components.Markdown_Editors.Split_Horizontally);
      Accepted : Boolean;
      Geometry : Flyology_TUI.Components.Markdown_Editors.Layout_Snapshot;
      Result : Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.Create (52, 12, Skin.Dialog);
   begin
      Item.Try_Set_Source (Markdown_Source, Accepted);
      if not Accepted then
         raise Program_Error with "Markdown editor seed rejected";
      end if;
      Item.Advance_Preview (Natural'Last);
      Item.Focus_Source;
      Geometry := Item.Layout;
      Result.Overlay_Clipped
        (Item.Render_Source
           (Flyology_TUI.Components.Markdown_Editors.From_Theme
              (Theme_For (Skin)),
            Flyology_TUI.Components.Markdown_Editors.Annotations_From_Theme
              (Theme_For (Skin))),
         Flyology_TUI.Components.Markdown_Editors.Source_Region (Geometry).X,
         Flyology_TUI.Components.Markdown_Editors.Source_Region (Geometry).Y);
      Result.Overlay_Clipped
        (Flyology_TUI.Components.Markdown_Viewers.Frame
           (Item.Present_Preview (Theme_For (Skin))),
         Flyology_TUI.Components.Markdown_Editors.Preview_Region (Geometry).X,
         Flyology_TUI.Components.Markdown_Editors.Preview_Region (Geometry).Y);
      return Result;
   end Example_Markdown_Editor;

   function Example_Stream (Skin : Flyology_TUI.Skins.Skin)
      return Flyology_TUI.Surfaces.Surface
   is
      Item : Streams.Model := Streams.Create
        (46, 7, Overflow => Streams.Trim_Oldest);
      Status : Streams.Operation_Result;
   begin
      Status := Item.Append
        ("Connecting to the build worker..." & Wide_Wide_Character'Val (10));
      Status := Item.Append
        ("Compiling component examples" & Wide_Wide_Character'Val (10));
      Status := Item.Append
        ("Rendering four skins" & Wide_Wide_Character'Val (10));
      Status := Item.Append ("Site capture ready");
      if Status /= Streams.Applied then
         raise Program_Error with "stream component seed rejected";
      end if;
      return Item.Render (Theme_For (Skin), Has_Focus => True);
   end Example_Stream;

   function Example_Chat (Skin : Flyology_TUI.Skins.Skin)
      return Flyology_TUI.Surfaces.Surface
   is
      Item : Chats.Model := Chats.Create
        ([(User_Message, You, Chats.User, Chats.Delivered, 1),
          (Assistant_Message, Assistant, Chats.Assistant,
           Chats.Delivered, 2),
          (Tool_Message, Tool, Chats.Tool, Chats.Delivered, 3)],
         Viewport_Rows => 11);
      User_Body : constant Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.From_Text ("Show one exact component.");
      Assistant_Body : constant Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.From_Text
          ("Built from the component's"
           & Wide_Wide_Character'Val (10)
           & "public Ada API.");
      Tool_Body : constant Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.From_Text ("4 skins · deterministic output");
   begin
      Item.Set_Layout (Chats.Conversational_Layout);
      Item.Reconcile_Measurements
        ([(User_Message, 1, 0), (Assistant_Message, 2, 0),
          (Tool_Message, 1, 0)]);
      Item.Select_Id (Assistant_Message);
      return Chats.Frame
        (Item.Present
           ([(User_Message, User_Body, Flyology_TUI.Surfaces.Create (0, 0)),
             (Assistant_Message, Assistant_Body,
              Flyology_TUI.Surfaces.Create (0, 0)),
             (Tool_Message, Tool_Body, Flyology_TUI.Surfaces.Create (0, 0))],
            52,
            Flyology_TUI.Surfaces.From_Text
              ("Enter sends · Shift+Enter adds a line", Skin.Palette.Muted),
            Flyology_TUI.Surfaces.From_Text
              ("Write a message...", Skin.Palette.Placeholder),
            Theme_For (Skin), Has_Focus => True));
   end Example_Chat;

   function Example_Menu (Skin : Flyology_TUI.Skins.Skin)
      return Flyology_TUI.Surfaces.Surface
   is
      Item : Menus.Model := Menus.Create
        ([(File_Menu, True, True), (View_Menu, True, True),
          (Density_Menu, False, True)],
         [Menus.Action (New_Item, File_Menu),
          Menus.Action (Save_Item, File_Menu),
          Menus.Separator (Separator_Item, File_Menu),
          Menus.Action (Quit_Item, File_Menu),
          Menus.Check (Status_Item, View_Menu, Checked => True),
          Menus.Submenu (Density_Item, View_Menu, Density_Menu),
          Menus.Radio
            (Compact_Item, Density_Menu, Compact_Item, Selected => True),
          Menus.Radio
            (Comfortable_Item, Density_Menu, Compact_Item)]);
   begin
      Item.Open_Menu (File_Menu);
      return Menus.Frame
        (Item.Present (48, 10, 0, 0, Theme_For (Skin), Has_Focus => True));
   end Example_Menu;

   function Example_Progress_Group (Skin : Flyology_TUI.Skins.Skin)
      return Flyology_TUI.Surfaces.Surface
   is
      Item : Work_Progress.Model := Work_Progress.Create (42);
   begin
      Item.Add_Determinate (Build_Work, "Build", 3.0, 0.62);
      Item.Add_Determinate
        (Test_Work, "Tests", 2.0, 0.35, Work_Progress.Paused);
      Item.Add_Indeterminate (Deploy_Work, "Deploy", 1.0);
      Item.Select_Item (Build_Work);
      return Stack
        (Item.Render (Theme_For (Skin)),
         Item.Render_Segments (42, Theme_For (Skin)));
   end Example_Progress_Group;

   function Example_Interaction (Skin : Flyology_TUI.Skins.Skin)
      return Flyology_TUI.Surfaces.Surface
   is
      Result : constant Flyology_TUI.Components.Interactions.Update_Result :=
        (Handled => True, Changed => True, Activated => True,
         Focus_Requested => True, Rejected => False,
         Capture => Flyology_TUI.Components.Interactions.Acquire_Capture);
      function Mark (Value : Boolean) return Wide_Wide_String is
        (if Value then "yes" else "no");
      Content : constant Wide_Wide_String :=
        "Update_Result is a detached value"
        & Wide_Wide_Character'Val (10)
        & "handled          " & Mark (Result.Handled)
        & Wide_Wide_Character'Val (10)
        & "changed          " & Mark (Result.Changed)
        & Wide_Wide_Character'Val (10)
        & "activated        " & Mark (Result.Activated)
        & Wide_Wide_Character'Val (10)
        & "focus requested  " & Mark (Result.Focus_Requested)
        & Wide_Wide_Character'Val (10)
        & "capture          acquire";
   begin
      return Flyology_TUI.Surfaces.From_Text (Content, Skin.Palette.Content);
   end Example_Interaction;

   function Render_Component
     (Slug : String; Skin_Id : Flyology_TUI.Skins.Skin_Id)
      return Flyology_TUI.Surfaces.Surface
   is
      Skin : constant Flyology_TUI.Skins.Skin :=
        Flyology_TUI.Skins.Resolve (Skin_Id);
      Content : Flyology_TUI.Surfaces.Surface;
      Name : Text.Unbounded_Wide_Wide_String;
   begin
      if Slug = "accordions" then
         Name := U ("Accordions"); Content := Example_Accordion (Skin);
      elsif Slug = "breadcrumbs" then
         Name := U ("Breadcrumbs"); Content := Example_Breadcrumbs (Skin);
      elsif Slug = "buttons" then
         Name := U ("Buttons"); Content := Example_Button (Skin);
      elsif Slug = "chats" then
         Name := U ("Chats"); Content := Example_Chat (Skin);
      elsif Slug = "check-boxes" then
         Name := U ("Check boxes"); Content := Example_Check_Box (Skin);
      elsif Slug = "dock-workspaces" then
         Name := U ("Dock workspaces"); Content := Example_Dock (Skin);
      elsif Slug = "dropdowns" then
         Name := U ("Dropdowns"); Content := Example_Dropdown (Skin);
      elsif Slug = "forms" then
         Name := U ("Forms"); Content := Example_Form (Skin);
      elsif Slug = "gradients" then
         Name := U ("Gradients"); Content := Example_Gradient;
      elsif Slug = "help" then
         Name := U ("Help"); Content := Example_Help (Skin);
      elsif Slug = "indicators" then
         Name := U ("Indicators"); Content := Example_Indicators (Skin);
      elsif Slug = "interactions" then
         Name := U ("Interaction results");
         Content := Example_Interaction (Skin);
      elsif Slug = "lists" then
         Name := U ("Lists"); Content := Example_List (Skin);
      elsif Slug = "markdown-editors" then
         Name := U ("Markdown editors");
         Content := Example_Markdown_Editor (Skin);
      elsif Slug = "markdown-viewers" then
         Name := U ("Markdown viewers");
         Content := Example_Markdown_Viewer (Skin);
      elsif Slug = "menubars" then
         Name := U ("Menubars"); Content := Example_Menu (Skin);
      elsif Slug = "panel-groups" then
         Name := U ("Panel groups"); Content := Example_Panel_Group (Skin);
      elsif Slug = "progress" then
         Name := U ("Progress"); Content := Example_Progress (Skin);
      elsif Slug = "progress-groups" then
         Name := U ("Progress groups");
         Content := Example_Progress_Group (Skin);
      elsif Slug = "radio-groups" then
         Name := U ("Radio groups"); Content := Example_Radios (Skin);
      elsif Slug = "scrollbars" then
         Name := U ("Scrollbars"); Content := Example_Scrollbar (Skin);
      elsif Slug = "selectors" then
         Name := U ("Selectors"); Content := Example_Selector (Skin);
      elsif Slug = "sparklines" then
         Name := U ("Sparklines"); Content := Example_Sparkline (Skin);
      elsif Slug = "spinners" then
         Name := U ("Spinners"); Content := Example_Spinner (Skin);
      elsif Slug = "split-panes" then
         Name := U ("Split panes"); Content := Example_Split (Skin);
      elsif Slug = "streaming-texts" then
         Name := U ("Streaming texts"); Content := Example_Stream (Skin);
      elsif Slug = "syntax-editors" then
         Name := U ("Syntax editors"); Content := Example_Syntax (Skin);
      elsif Slug = "tables" then
         Name := U ("Tables"); Content := Example_Table (Skin);
      elsif Slug = "tabs" then
         Name := U ("Tabs"); Content := Example_Tabs (Skin);
      elsif Slug = "text-areas" then
         Name := U ("Text areas"); Content := Example_Text_Area (Skin);
      elsif Slug = "text-inputs" then
         Name := U ("Text inputs"); Content := Example_Text_Input (Skin);
      elsif Slug = "trees" then
         Name := U ("Trees"); Content := Example_Tree (Skin);
      elsif Slug = "viewports" then
         Name := U ("Viewports"); Content := Example_Viewport;
      elsif Slug = "windows" then
         Name := U ("Windows"); Content := Example_Window (Skin);
      else
         raise Constraint_Error with "unknown component example: " & Slug;
      end if;
      return Stage (Text.To_Wide_Wide_String (Name), Content, Skin);
   end Render_Component;

   Component_Name : Narrow_Text.Unbounded_String;
   Skin_Name : Narrow_Text.Unbounded_String;
   Output_Path : Narrow_Text.Unbounded_String;
begin
   for Index in 1 .. Ada.Command_Line.Argument_Count loop
      declare
         Argument : constant String := Ada.Command_Line.Argument (Index);
      begin
         if Argument'Length > 12
           and then Argument (Argument'First .. Argument'First + 11) =
             "--component="
         then
            Component_Name := Narrow_Text.To_Unbounded_String
              (Argument (Argument'First + 12 .. Argument'Last));
         elsif Argument'Length > 7
           and then Argument (Argument'First .. Argument'First + 6) =
             "--skin="
         then
            Skin_Name := Narrow_Text.To_Unbounded_String
              (Argument (Argument'First + 7 .. Argument'Last));
         elsif Argument'Length > 9
           and then Argument (Argument'First .. Argument'First + 8) =
             "--output="
         then
            Output_Path := Narrow_Text.To_Unbounded_String
              (Argument (Argument'First + 9 .. Argument'Last));
         else
            raise Constraint_Error with
              "usage: component_examples --component=SLUG --skin=SKIN "
              & "--output=PATH";
         end if;
      end;
   end loop;
   if Narrow_Text.Length (Component_Name) = 0
     or else Narrow_Text.Length (Skin_Name) = 0
     or else Narrow_Text.Length (Output_Path) = 0
   then
      raise Constraint_Error with
        "usage: component_examples --component=SLUG --skin=SKIN "
        & "--output=PATH";
   end if;
   declare
      Slug : constant String :=
        Narrow_Text.To_String (Component_Name);
      Skin_Value : constant String :=
        Narrow_Text.To_String (Skin_Name);
      Skin_Id : constant Flyology_TUI.Skins.Skin_Id :=
        Skin_From_Name (Skin_Value);
   begin
      Component_Capture_Support.Write_SVG
        (Render_Component (Slug, Skin_Id), Skin_Id,
         Ada.Characters.Conversions.To_Wide_Wide_String
           (Narrow_Text.To_String (Component_Name)),
         Narrow_Text.To_String (Output_Path));
   end;
exception
   when Error : others =>
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "component_examples: " & Ada.Exceptions.Exception_Message (Error));
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
end Component_Examples;
