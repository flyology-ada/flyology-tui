with Flyology_TUI.Components.Interactions;
with Flyology_TUI.Events;
with Flyology_TUI.Mouse;
with Flyology_TUI.Styles;
with Flyology_TUI.Surfaces;
with Flyology_TUI.Themes;

generic
   Max_Code_Points    : Positive;
   Max_Lines          : Positive;
   Max_Viewport_Cells : Positive := 1_000_000;
package Flyology_TUI.Components.Streaming_Texts is
   type Overflow_Policy is (Reject, Trim_Oldest);
   type Stream_State is (Streaming, Finished, Failed, Cancelled);

   type Operation_Result is
     (Applied,
      Unchanged,
      Rejected_Capacity,
      Rejected_State,
      Rejected_Geometry);

   subtype Tab_Stop_Width is Positive range 1 .. 16;

   type Appearance is record
      Streaming_Text : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default;
      Finished_Text  : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default;
      Failed_Text    : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default;
      Cancelled_Text : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default;
      Focused_Text   : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default;
      Background     : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default;
   end record;

   function From_Theme
     (Theme : Flyology_TUI.Themes.Theme) return Appearance;

   type Model is tagged private;

   --  Create owns no task or clock. Width and Height are accepted only when
   --  their product is within Max_Viewport_Cells; otherwise Capacity_Error is
   --  raised before the model is constructed.
   function Create
     (Width     : Natural;
      Height    : Natural;
      Overflow  : Overflow_Policy := Reject;
      Tab_Stop  : Tab_Stop_Width := 4;
      Follow_Tail : Boolean := True) return Model;

   function Fits_Viewport (Width, Height : Natural) return Boolean;

   --  Resize is atomic. A rejected geometry leaves dimensions, scrolling,
   --  follow-tail state, and unseen counters unchanged.
   function Resize
     (Item : in out Model;
      Width, Height : Natural) return Operation_Result;

   --  These operations synchronously copy detached caller data. They never
   --  start tasks, retain callbacks, or perform I/O. Terminal states reject
   --  further text mutation. Reject preflights the complete input before any
   --  copy; Trim_Oldest removes complete logical lines first and then complete
   --  terminal-oriented grapheme clusters until both bounds hold.
   function Append
     (Item  : in out Model;
      Chunk : Wide_Wide_String) return Operation_Result;

   function Replace
     (Item    : in out Model;
      Content : Wide_Wide_String) return Operation_Result;

   function Finish (Item : in out Model) return Operation_Result;
   function Fail (Item : in out Model) return Operation_Result;
   function Cancel (Item : in out Model) return Operation_Result;

   function Content (Item : Model) return Wide_Wide_String;
   function Code_Point_Count (Item : Model) return Natural;
   function Logical_Line_Count (Item : Model) return Positive;
   function Visual_Row_Count (Item : Model) return Natural;
   function State (Item : Model) return Stream_State;
   function Overflow_Mode (Item : Model) return Overflow_Policy;
   function Viewport_Width (Item : Model) return Natural;
   function Viewport_Height (Item : Model) return Natural;
   function First_Visible_Row (Item : Model) return Natural;
   function Is_Following_Tail (Item : Model) return Boolean;
   function Unseen_Row_Count (Item : Model) return Natural;
   function Unseen_Chunk_Count (Item : Model) return Natural;

   --  Enabling follow-tail moves to the current end and acknowledges all
   --  unseen content. Disabling it preserves the current viewport.
   procedure Set_Follow_Tail (Item : in out Model; Enabled : Boolean);

   function Scroll
     (Item  : in out Model;
      Amount : Integer)
      return Flyology_TUI.Components.Interactions.Update_Result;

   function Handle
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Terminal_Event)
      return Flyology_TUI.Components.Interactions.Update_Result;

   --  Coordinates are relative to Render. Wheel scrolling and a left click
   --  inside the viewport request focus; this component never captures input.
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
     (Item       : Model;
      Appearance : Streaming_Texts.Appearance := (others => <>);
      Has_Focus  : Boolean := False)
      return Flyology_TUI.Surfaces.Surface;

   function Render
     (Item      : Model;
      Theme     : Flyology_TUI.Themes.Theme;
      Has_Focus : Boolean := False)
      return Flyology_TUI.Surfaces.Surface;

private
   subtype Code_Point_Buffer is Wide_Wide_String (1 .. Max_Code_Points);

   type Model is tagged record
      Buffer       : Code_Point_Buffer :=
        (others => Wide_Wide_Character'Val (0));
      Used         : Natural range 0 .. Max_Code_Points := 0;
      Current_State : Stream_State := Streaming;
      Policy       : Overflow_Policy := Reject;
      Columns      : Natural := 0;
      Rows         : Natural := 0;
      Tab_Columns  : Tab_Stop_Width := 4;
      First_Row    : Natural := 0;
      Follow       : Boolean := True;
      Unseen_Rows  : Natural := 0;
      Unseen_Chunks : Natural := 0;
   end record;
end Flyology_TUI.Components.Streaming_Texts;
