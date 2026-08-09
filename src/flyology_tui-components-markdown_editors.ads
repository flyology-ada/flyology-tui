with Flyology_TUI.Components.Interactions;
with Flyology_TUI.Components.Markdown_Viewers;
with Flyology_TUI.Components.Text_Areas;
with Flyology_TUI.Events;
with Flyology_TUI.Geometry;
with Flyology_TUI.Mouse;
with Flyology_TUI.Surfaces;
with Flyology_TUI.Themes;

package Flyology_TUI.Components.Markdown_Editors is
   type Presentation_Mode is
     (Source_Only,
      Preview_Only,
      Split_Horizontally,
      Split_Vertically);
   subtype Source_Percentage_Range is Positive range 10 .. 90;

   type Appearance is record
      Source  : Flyology_TUI.Components.Text_Areas.Appearance;
      Preview : Flyology_TUI.Components.Markdown_Viewers.Appearance;
   end record;

   function From_Theme
     (Theme : Flyology_TUI.Themes.Theme) return Appearance;

   --  Source editing delegates to Text_Areas. Preview parsing and link state
   --  delegate to Markdown_Viewers. This model only synchronizes those two
   --  bounded, task-free cores and computes responsive presentation regions.
   type Model
     (Max_Code_Points        : Positive;
      Max_Lines              : Positive;
      Max_Undo_Entries       : Positive;
      Max_History_Codepoints : Positive;
      Max_Links              : Positive) is tagged limited private;

   function Create
     (Max_Code_Points        : Positive;
      Max_Lines              : Positive;
      Max_Undo_Entries       : Positive;
      Max_History_Codepoints : Positive;
      Max_Links              : Positive;
      Width                  : Positive := 80;
      Height                 : Positive := 20;
      Mode                   : Presentation_Mode := Split_Horizontally)
      return Model;

   procedure Try_Set_Source
     (Item    : in out Model;
      Value   : Wide_Wide_String;
      Success : out Boolean);
   function Source (Item : Model) return Wide_Wide_String;

   procedure Set_Mode (Item : in out Model; Mode : Presentation_Mode);
   function Mode (Item : Model) return Presentation_Mode;
   --  Percentage of the available span assigned to source in split modes.
   procedure Set_Source_Percentage
     (Item : in out Model; Percentage : Source_Percentage_Range);
   function Source_Percentage
     (Item : Model) return Source_Percentage_Range;
   procedure Set_Size (Item : in out Model; Width, Height : Positive);
   function Width (Item : Model) return Positive;
   function Height (Item : Model) return Positive;

   type Layout_Snapshot is private;
   function Layout (Item : Model) return Layout_Snapshot;
   function Has_Source (Item : Layout_Snapshot) return Boolean;
   function Has_Preview (Item : Layout_Snapshot) return Boolean;
   function Source_Region
     (Item : Layout_Snapshot) return Flyology_TUI.Geometry.Rectangle
     with Pre => Has_Source (Item);
   function Preview_Region
     (Item : Layout_Snapshot) return Flyology_TUI.Geometry.Rectangle
     with Pre => Has_Preview (Item);

   procedure Focus_Source (Item : in out Model);
   procedure Focus_Preview (Item : in out Model);
   procedure Blur (Item : in out Model);

   function Handle_Source
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Terminal_Event)
      return Flyology_TUI.Components.Interactions.Update_Result;
   function Handle_Source
     (Item  : in out Model;
      Event : Flyology_TUI.Mouse.Local_Event)
      return Flyology_TUI.Components.Interactions.Update_Result;

   function Handle_Preview
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Terminal_Event)
      return Flyology_TUI.Components.Markdown_Viewers.Action_Result;
   function Handle_Preview
     (Item   : in out Model;
      Event  : Flyology_TUI.Mouse.Local_Event;
      Layout : Flyology_TUI.Components.Markdown_Viewers.Presentation)
      return Flyology_TUI.Components.Markdown_Viewers.Action_Result;

   procedure Advance_Preview
     (Item : in out Model; Line_Budget : Natural);
   function Preview_Parsing
     (Item : Model)
      return Flyology_TUI.Components.Markdown_Viewers.Parsing_State;
   function Preview_Unsupported
     (Item : Model)
      return Flyology_TUI.Components.Markdown_Viewers.Unsupported_Set;
   function Preview_First_Visible_Row (Item : Model) return Natural;
   function Preview_Focused_Link
     (Item : Model) return Flyology_TUI.Components.Markdown_Viewers.Link_Id;

   function Render_Source
     (Item : Model; Look : Appearance)
      return Flyology_TUI.Surfaces.Surface;
   function Present_Preview
     (Item        : Model;
      Look        : Appearance;
      Line_Budget : Natural := Natural'Last)
      return Flyology_TUI.Components.Markdown_Viewers.Presentation;
   function Render_Source
     (Item : Model; Theme : Flyology_TUI.Themes.Theme)
      return Flyology_TUI.Surfaces.Surface;
   function Present_Preview
     (Item        : Model;
      Theme       : Flyology_TUI.Themes.Theme;
      Line_Budget : Natural := Natural'Last)
      return Flyology_TUI.Components.Markdown_Viewers.Presentation;

private
   type Focus_Target is (No_Focus, Source_Focus, Preview_Focus);

   type Model
     (Max_Code_Points        : Positive;
      Max_Lines              : Positive;
      Max_Undo_Entries       : Positive;
      Max_History_Codepoints : Positive;
      Max_Links              : Positive) is
   tagged limited record
      Source_Core : Flyology_TUI.Components.Text_Areas.Model
        (Max_Code_Points,
         Max_Lines,
         Max_Undo_Entries,
         Max_History_Codepoints);
      Preview_Core : Flyology_TUI.Components.Markdown_Viewers.Model
        (Max_Code_Points, Max_Lines, Max_Links);
      Columns       : Positive := 80;
      Rows          : Positive := 20;
      Current_Mode  : Presentation_Mode := Split_Horizontally;
      Source_Share  : Source_Percentage_Range := 50;
      Focus         : Focus_Target := No_Focus;
   end record;

   type Layout_Snapshot is record
      Source_Visible  : Boolean := False;
      Preview_Visible : Boolean := False;
      Source_Box      : Flyology_TUI.Geometry.Rectangle;
      Preview_Box     : Flyology_TUI.Geometry.Rectangle;
   end record;
end Flyology_TUI.Components.Markdown_Editors;
