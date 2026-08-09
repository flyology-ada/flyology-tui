with Ada.Strings.Wide_Wide_Unbounded;
with Flyology_TUI.Styles;
with Flyology_TUI.Surfaces;
with Flyology_TUI.Themes;

package Flyology_TUI.Components.Indicators is
   package Text renames Ada.Strings.Wide_Wide_Unbounded;

   type Tone is (Neutral, Success_Tone, Warning_Tone, Error_Tone);

   type Appearance is record
      Primary   : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Muted     : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Success   : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Warning   : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Error     : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Separator : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
   end record;

   function From_Theme
     (Theme : Flyology_TUI.Themes.Theme) return Appearance;

   function Badge
     (Label      : Wide_Wide_String;
      Kind       : Tone := Neutral;
      Appearance : Indicators.Appearance := (others => <>))
      return Flyology_TUI.Surfaces.Surface;

   function Badge
     (Label : Wide_Wide_String;
      Kind  : Tone := Neutral;
      Theme : Flyology_TUI.Themes.Theme)
      return Flyology_TUI.Surfaces.Surface;

   --  The label, when present, is centered as " label ". At tiny widths it is
   --  clipped from the right; the returned surface always has exactly Width
   --  cells.
   function Divider
     (Width      : Natural;
      Label      : Wide_Wide_String := "";
      Appearance : Indicators.Appearance := (others => <>))
      return Flyology_TUI.Surfaces.Surface;

   function Divider
     (Width : Natural;
      Label : Wide_Wide_String := "";
      Theme : Flyology_TUI.Themes.Theme)
      return Flyology_TUI.Surfaces.Surface;

   subtype Ratio is Long_Float range 0.0 .. 1.0;

   function Gauge
     (Value      : Ratio;
      Width      : Natural;
      Appearance : Indicators.Appearance := (others => <>))
      return Flyology_TUI.Surfaces.Surface;

   function Gauge
     (Value : Ratio;
      Width : Natural;
      Theme : Flyology_TUI.Themes.Theme)
      return Flyology_TUI.Surfaces.Surface;

   --  Value has shrink priority. If it fits, it remains right aligned while
   --  Key is clipped into the cells to its left. If Value alone is wider than
   --  Width, it is clipped from the right starting at column zero.
   function Key_Value
     (Key, Value : Wide_Wide_String;
      Width      : Natural;
      Appearance : Indicators.Appearance := (others => <>))
      return Flyology_TUI.Surfaces.Surface;

   function Key_Value
     (Key, Value : Wide_Wide_String;
      Width      : Natural;
      Theme      : Flyology_TUI.Themes.Theme)
      return Flyology_TUI.Surfaces.Surface;

   type Segment_Priority is (Low, Normal, High, Critical);

   type Status_Segment is record
      Label    : Text.Unbounded_Wide_Wide_String;
      Priority : Segment_Priority := Normal;
      Kind     : Tone := Neutral;
   end record;

   function Make_Segment
     (Label    : Wide_Wide_String;
      Priority : Segment_Priority := Normal;
      Kind     : Tone := Neutral) return Status_Segment;

   type Segment_Array is array (Positive range <>) of Status_Segment;
   Maximum_Segments : constant Positive := 32;

   --  Segments that do not fit are removed from lowest priority to highest;
   --  equal-priority ties remove the rightmost segment first. Remaining
   --  segments retain source order. One final oversized segment is clipped.
   function Status_Line
     (Segments   : Segment_Array;
      Width      : Natural;
      Appearance : Indicators.Appearance := (others => <>))
      return Flyology_TUI.Surfaces.Surface;

   function Status_Line
     (Segments : Segment_Array;
      Width    : Natural;
      Theme    : Flyology_TUI.Themes.Theme)
      return Flyology_TUI.Surfaces.Surface;
end Flyology_TUI.Components.Indicators;
