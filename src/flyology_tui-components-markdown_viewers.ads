with Ada.Strings.Wide_Wide_Unbounded;
with Flyology_TUI.Components.Interactions;
with Flyology_TUI.Components.Text_Areas;
with Flyology_TUI.Events;
with Flyology_TUI.Geometry;
with Flyology_TUI.Mouse;
with Flyology_TUI.Styles;
with Flyology_TUI.Surfaces;
with Flyology_TUI.Themes;

package Flyology_TUI.Components.Markdown_Viewers is
   package Text renames Ada.Strings.Wide_Wide_Unbounded;

   type Parsing_State is
     (Parsing_Dirty,
      Parsing_Current,
      Parsing_Capacity_Limited,
      Parsing_Malformed);

   type Unsupported_Construct is
     (Images,
      Tables,
      Raw_HTML,
      Footnotes,
      Definition_Lists,
      Nested_Block_Containers);
   type Unsupported_Set is array (Unsupported_Construct) of Boolean;

   type Link_Id is new Natural;
   No_Link : constant Link_Id := 0;

   type Heading_Appearance is array (Positive range 1 .. 6) of
     Flyology_TUI.Styles.Style;

   type Appearance is record
      Text            : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default;
      Heading         : Heading_Appearance :=
        (others => Flyology_TUI.Styles.Default);
      Emphasis        : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default;
      Strong          : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default;
      Inline_Code     : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default;
      Code_Block      : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default;
      Quote           : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default;
      List_Marker     : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default;
      Task_Unchecked  : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default;
      Task_Checked    : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default;
      Link            : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default;
      Focused_Link    : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default;
      Thematic_Break  : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default;
      Diagnostic      : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default;
      Selection       : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default;
   end record;

   function From_Theme
     (Theme : Flyology_TUI.Themes.Theme) return Appearance;

   --  Parsing is synchronous and caller-budgeted. Model owns bounded source,
   --  line metadata, and link targets; it owns no task, callback, or queue.
   --  The source core is a read-only Text_Area, so selection and Unicode
   --  boundary behavior are shared with the editing components.
   type Model
     (Max_Code_Points : Positive;
      Max_Lines       : Positive;
      Max_Links       : Positive) is tagged limited private;

   function Create
     (Max_Code_Points : Positive;
      Max_Lines       : Positive;
      Max_Links       : Positive;
      Width           : Positive := 60;
      Height          : Positive := 20) return Model;

   --  Normalize line endings and replace the source atomically. A successful
   --  replacement invalidates prior parsing and stable link ids.
   procedure Try_Set_Source
     (Item    : in out Model;
      Value   : Wide_Wide_String;
      Success : out Boolean);
   function Source (Item : Model) return Wide_Wide_String;

   --  Consume at most Line_Budget physical source lines. Zero is a query-safe
   --  no-op. Capacity and malformed input are reported through Parsing.
   procedure Advance_Parsing
     (Item : in out Model; Line_Budget : Natural);
   function Parsing (Item : Model) return Parsing_State;
   function Parsed_Line_Count (Item : Model) return Natural;
   function Unsupported (Item : Model) return Unsupported_Set;
   function Has_Unsupported (Item : Model) return Boolean;

   function Link_Count (Item : Model) return Natural;
   function Link_Target
     (Item : Model; Id : Link_Id) return Wide_Wide_String
     with Pre => Id /= No_Link and then Natural (Id) <= Link_Count (Item);
   function Focused_Link (Item : Model) return Link_Id;

   procedure Set_Size (Item : in out Model; Width, Height : Positive);
   function Width (Item : Model) return Positive;
   function Height (Item : Model) return Positive;
   procedure Focus (Item : in out Model);
   procedure Blur (Item : in out Model);
   function Focused (Item : Model) return Boolean;
   procedure Select_All (Item : in out Model);
   procedure Clear_Selection (Item : in out Model);
   function Has_Selection (Item : Model) return Boolean;
   procedure Selection_Range
     (Item : Model; First, Last : out Natural);
   function First_Visible_Row (Item : Model) return Natural;
   procedure Scroll_Rows
     (Item : in out Model; Amount : Integer; Changed : out Boolean);

   type Action_Kind is (No_Action, Link_Activated);
   type Action_Result is record
      Update : Flyology_TUI.Components.Interactions.Update_Result;
      Action : Action_Kind := No_Action;
      Link   : Link_Id := No_Link;
   end record;

   type Presentation (<>) is private;
   function Present
     (Item        : Model;
      Look        : Appearance;
      Line_Budget : Natural := Natural'Last) return Presentation;
   function Present
     (Item        : Model;
      Theme       : Flyology_TUI.Themes.Theme;
      Line_Budget : Natural := Natural'Last) return Presentation;
   function Frame
     (Item : Presentation) return Flyology_TUI.Surfaces.Surface;
   function Content_Height (Item : Presentation) return Natural;
   function Rendered_Line_Count (Item : Presentation) return Natural;
   function Rendering_Complete (Item : Presentation) return Boolean;
   function Has_Link (Item : Presentation; Id : Link_Id) return Boolean;
   function Link_Region_Count
     (Item : Presentation; Id : Link_Id) return Natural;
   function Link_Region
     (Item     : Presentation;
      Id       : Link_Id;
      Position : Positive)
      return Flyology_TUI.Geometry.Rectangle
     with Pre => Position <= Link_Region_Count (Item, Id);

   function Handle
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Terminal_Event) return Action_Result;
   --  Use the same immutable Presentation that was drawn when routing mouse
   --  input. This keeps hit testing aligned across resize and reparse.
   function Handle
     (Item   : in out Model;
      Event  : Flyology_TUI.Mouse.Local_Event;
      Layout : Presentation) return Action_Result;

private
   type Line_Kind is
     (Blank_Line,
      Paragraph,
      Heading,
      Quote,
      Unordered_Item,
      Ordered_Item,
      Task_Item,
      Fence_Delimiter,
      Code_Block,
      Thematic_Break);

   type Line_Info is record
      Kind          : Line_Kind := Blank_Line;
      First         : Natural := 0;
      Last          : Natural := 0;
      Content_First : Natural := 0;
      Level         : Positive range 1 .. 6 := 1;
      Checked       : Boolean := False;
   end record;
   type Line_Array is array (Positive range <>) of Line_Info;

   type Link_Info is record
      Syntax_First : Natural := 0;
      Label_First  : Natural := 0;
      Label_Last   : Natural := 0;
      Target       : Text.Unbounded_Wide_Wide_String;
   end record;
   type Link_Array is array (Positive range <>) of Link_Info;

   type Model
     (Max_Code_Points : Positive;
      Max_Lines       : Positive;
      Max_Links       : Positive) is
   tagged limited record
      Source_Core : Flyology_TUI.Components.Text_Areas.Model
        (Max_Code_Points, Max_Lines, 1, 1);
      Lines       : Line_Array (1 .. Max_Lines);
      Links       : Link_Array (1 .. Max_Links);
      Line_Count  : Natural := 0;
      Link_Length : Natural := 0;
      Next_Offset : Natural := 0;
      State       : Parsing_State := Parsing_Dirty;
      Unsupported_Items : Unsupported_Set := (others => False);
      In_Fence    : Boolean := False;
      Fence_Char  : Wide_Wide_Character := '`';
      Columns     : Positive := 60;
      Rows        : Positive := 20;
      Top_Row     : Natural := 0;
      Has_Focus   : Boolean := False;
      Focus_Link  : Link_Id := No_Link;
      Revision    : Natural := 0;
   end record;

   type Hit_Entry is record
      Id     : Link_Id := No_Link;
      Region : Flyology_TUI.Geometry.Rectangle;
   end record;
   type Hit_Array is array (Positive range <>) of Hit_Entry;

   type Presentation (Hit_Capacity : Positive) is record
      Rendered       : Flyology_TUI.Surfaces.Surface;
      Hits           : Hit_Array (1 .. Hit_Capacity);
      Hit_Count      : Natural := 0;
      Document_Rows  : Natural := 0;
      Rendered_Lines : Natural := 0;
      Complete       : Boolean := False;
      Revision       : Natural := 0;
   end record;
end Flyology_TUI.Components.Markdown_Viewers;
