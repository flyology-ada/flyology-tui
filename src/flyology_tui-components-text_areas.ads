with Ada.Strings.Wide_Wide_Unbounded;
with Flyology_TUI.Components.Interactions;
with Flyology_TUI.Events;
with Flyology_TUI.Mouse;
with Flyology_TUI.Styles;
with Flyology_TUI.Surfaces;
with Flyology_TUI.Themes;

package Flyology_TUI.Components.Text_Areas is
   package Text renames Ada.Strings.Wide_Wide_Unbounded;

   type Wrap_Mode is (No_Wrap, Soft_Wrap);

   type Position is record
      Line        : Positive := 1;
      Code_Point  : Natural := 0;
      Cell_Column : Natural := 0;
   end record;

   type Appearance is record
      Text         : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Selection    : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Current_Line : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Gutter       : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Placeholder  : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Cursor       : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Read_Only    : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Disabled     : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
   end record;

   function From_Theme
     (Theme : Flyology_TUI.Themes.Theme) return Appearance;

   type Model
     (Max_Code_Points        : Positive;
      Max_Lines              : Positive;
      Max_Undo_Entries       : Positive;
      Max_History_Codepoints : Positive) is tagged private;

   function Create
     (Max_Code_Points        : Positive;
      Max_Lines              : Positive;
      Max_Undo_Entries       : Positive;
      Max_History_Codepoints : Positive;
      Width                  : Positive := 40;
      Height                 : Positive := 8;
      Placeholder            : Wide_Wide_String := "") return Model;

   --  Normalize CRLF and CR to LF. Failure leaves the complete model intact.
   procedure Try_Set_Text
     (Item    : in out Model;
      Value   : Wide_Wide_String;
      Success : out Boolean);

   function Value (Item : Model) return Wide_Wide_String;
   function Line_Count (Item : Model) return Positive;

   procedure Set_Size (Item : in out Model; Width, Height : Positive);
   function Width (Item : Model) return Positive;
   function Height (Item : Model) return Positive;
   procedure Set_Wrap (Item : in out Model; Mode : Wrap_Mode);
   function Wrapping (Item : Model) return Wrap_Mode;
   procedure Set_Tab_Width (Item : in out Model; Width : Positive);
   function Tab_Width (Item : Model) return Positive;

   procedure Focus (Item : in out Model);
   procedure Blur (Item : in out Model);
   function Focused (Item : Model) return Boolean;
   procedure Set_Enabled (Item : in out Model; Enabled : Boolean);
   function Is_Enabled (Item : Model) return Boolean;
   procedure Set_Read_Only (Item : in out Model; Read_Only : Boolean);
   function Is_Read_Only (Item : Model) return Boolean;

   function Cursor_Position (Item : Model) return Position;
   function Position_At_Offset (Item : Model; Offset : Natural)
      return Position;
   function Cursor_Offset (Item : Model) return Natural;
   procedure Set_Cursor_Offset (Item : in out Model; Offset : Natural);
   function Has_Selection (Item : Model) return Boolean;
   procedure Selection_Range
     (Item : Model; First, Last : out Natural);
   procedure Select_All (Item : in out Model);
   procedure Clear_Selection (Item : in out Model);

   procedure Set_Viewport
     (Item : in out Model; First_Line : Positive; First_Cell : Natural := 0);
   function Viewport_Line (Item : Model) return Positive;
   function Viewport_Cell (Item : Model) return Natural;
   function Gutter_Columns (Item : Model) return Positive;
   function Line_Start_Offset (Item : Model; Line : Positive) return Natural;
   function Line_End_Offset (Item : Model; Line : Positive) return Natural;
   procedure Visible_Segment
     (Item          : Model;
      Row           : Natural;
      Line          : out Positive;
      Segment_First : out Natural;
      Segment_Last  : out Natural;
      Exists        : out Boolean);

   function Can_Undo (Item : Model) return Boolean;
   function Can_Redo (Item : Model) return Boolean;
   procedure Undo (Item : in out Model);
   procedure Redo (Item : in out Model);

   function Handle
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Terminal_Event)
      return Flyology_TUI.Components.Interactions.Update_Result;

   function Handle
     (Item  : in out Model;
      Event : Flyology_TUI.Mouse.Local_Event)
      return Flyology_TUI.Components.Interactions.Update_Result;

   procedure Update
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Terminal_Event);

   procedure Update
     (Item  : in out Model;
      Event : Flyology_TUI.Mouse.Local_Event);

   function Render
     (Item : Model; Look : Appearance)
      return Flyology_TUI.Surfaces.Surface;

   function Render
     (Item : Model; Theme : Flyology_TUI.Themes.Theme)
      return Flyology_TUI.Surfaces.Surface;

private
   type Snapshot is record
      Content : Text.Unbounded_Wide_Wide_String;
      Cursor  : Natural := 0;
      Anchor  : Natural := 0;
   end record;

   type Snapshot_Array is array (Positive range <>) of Snapshot;

   type Model
     (Max_Code_Points        : Positive;
      Max_Lines              : Positive;
      Max_Undo_Entries       : Positive;
      Max_History_Codepoints : Positive) is
   tagged record
      Content        : Text.Unbounded_Wide_Wide_String;
      Placeholder    : Text.Unbounded_Wide_Wide_String;
      Cursor         : Natural := 0;
      Anchor         : Natural := 0;
      Columns        : Positive := 40;
      Rows           : Positive := 8;
      Tabs           : Positive := 4;
      Wrap           : Wrap_Mode := No_Wrap;
      First_Line     : Positive := 1;
      First_Cell     : Natural := 0;
      Preferred_Cell : Natural := 0;
      Has_Preferred  : Boolean := False;
      Has_Focus      : Boolean := False;
      Enabled        : Boolean := True;
      Read_Only      : Boolean := False;
      Capturing      : Boolean := False;
      Undo_Items     : Snapshot_Array (1 .. Max_Undo_Entries);
      Undo_Count     : Natural := 0;
      Redo_Items     : Snapshot_Array (1 .. Max_Undo_Entries);
      Redo_Count     : Natural := 0;
   end record;
end Flyology_TUI.Components.Text_Areas;
