with Flyology_TUI.Components.Interactions;
with Flyology_TUI.Components.Text_Areas;
with Flyology_TUI.Events;
with Flyology_TUI.Mouse;
with Flyology_TUI.Styles;
with Flyology_TUI.Surfaces;
with Flyology_TUI.Themes;

generic
   type Token_Kind is (<>);
   type Lexer_State is private;
   Initial_State : Lexer_State;
   Maximum_Tokens_Per_Line : Positive;
   with procedure Next_Token
     (Line          : Wide_Wide_String;
      Initial       : Lexer_State;
      From          : Natural;
      Kind          : out Token_Kind;
      First, Last   : out Natural;
      Final         : out Lexer_State;
      Has_Token     : out Boolean);
package Flyology_TUI.Components.Syntax_Editors is
   type Highlight_State is
     (Highlight_Current,
      Highlight_Dirty,
      Highlight_Capacity_Limited,
      Highlight_Structure_Invalid,
      Highlight_Lexer_Failed);

   type Token_Appearance is array (Token_Kind) of Flyology_TUI.Styles.Style;

   type Appearance is record
      Editor : Flyology_TUI.Components.Text_Areas.Appearance;
      Tokens : Token_Appearance := (others => Flyology_TUI.Styles.Default);
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

   procedure Try_Set_Text
     (Item    : in out Model;
      Value   : Wide_Wide_String;
      Success : out Boolean);
   function Value (Item : Model) return Wide_Wide_String;
   function Cursor_Position
     (Item : Model) return Flyology_TUI.Components.Text_Areas.Position;
   function Cursor_Offset (Item : Model) return Natural;
   procedure Set_Cursor_Offset (Item : in out Model; Offset : Natural);

   procedure Set_Size (Item : in out Model; Width, Height : Positive);
   function Width (Item : Model) return Positive;
   function Height (Item : Model) return Positive;
   procedure Set_Wrap
     (Item : in out Model;
      Mode : Flyology_TUI.Components.Text_Areas.Wrap_Mode);
   procedure Set_Tab_Width (Item : in out Model; Width : Positive);
   procedure Focus (Item : in out Model);
   procedure Blur (Item : in out Model);
   function Focused (Item : Model) return Boolean;
   procedure Set_Enabled (Item : in out Model; Enabled : Boolean);
   function Is_Enabled (Item : Model) return Boolean;
   procedure Set_Read_Only (Item : in out Model; Read_Only : Boolean);
   function Is_Read_Only (Item : Model) return Boolean;
   function Has_Selection (Item : Model) return Boolean;
   procedure Selection_Range
     (Item : Model; First, Last : out Natural);
   procedure Select_All (Item : in out Model);
   procedure Clear_Selection (Item : in out Model);
   procedure Set_Viewport
     (Item : in out Model; First_Line : Positive; First_Cell : Natural := 0);
   function Viewport_Line (Item : Model) return Positive;
   function Viewport_Cell (Item : Model) return Natural;
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

   procedure Advance_Highlighting
     (Item : in out Model; Line_Budget : Natural);
   function Highlighting (Item : Model) return Highlight_State;
   function First_Dirty_Line (Item : Model) return Natural;

   function Render
     (Item : Model; Look : Appearance)
      return Flyology_TUI.Surfaces.Surface;

   function Render
     (Item : Model; Theme : Flyology_TUI.Themes.Theme)
      return Flyology_TUI.Surfaces.Surface;

private
   type Token_Span is record
      Kind  : Token_Kind := Token_Kind'First;
      First : Natural := 0;
      Last  : Natural := 0;
   end record;

   type Span_Array is
     array (Positive range 1 .. Maximum_Tokens_Per_Line) of Token_Span;

   type Line_Cache is record
      Valid : Boolean := False;
      Count : Natural := 0;
      Spans : Span_Array;
      Final : Lexer_State := Initial_State;
   end record;

   type Cache_Array is array (Positive range <>) of Line_Cache;

   type Model
     (Max_Code_Points        : Positive;
      Max_Lines              : Positive;
      Max_Undo_Entries       : Positive;
      Max_History_Codepoints : Positive) is
   tagged record
      Editor     : Flyology_TUI.Components.Text_Areas.Model
        (Max_Code_Points,
         Max_Lines,
         Max_Undo_Entries,
         Max_History_Codepoints);
      Cache      : Cache_Array (1 .. Max_Lines);
      Dirty_From : Natural := 1;
      State      : Highlight_State := Highlight_Dirty;
   end record;
end Flyology_TUI.Components.Syntax_Editors;
