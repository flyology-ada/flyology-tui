with Flyology_TUI.Numeric_Series;
with Flyology_TUI.Styles;
with Flyology_TUI.Surfaces;
with Flyology_TUI.Themes;

generic
   with package Samples is new Flyology_TUI.Numeric_Series (<>);
   with function To_Long_Float
     (Value : Samples.Value_Type) return Long_Float;
package Flyology_TUI.Components.Sparklines is
   type Appearance is record
      Low    : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Medium : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      High   : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
   end record;

   function From_Theme
     (Theme : Flyology_TUI.Themes.Theme) return Appearance;

   type Scale_Mode is (Automatic_Range, Fixed_Range);
   type Scale (Mode : Scale_Mode := Automatic_Range) is record
      case Mode is
         when Automatic_Range =>
            null;
         when Fixed_Range =>
            Minimum : Long_Float;
            Maximum : Long_Float;
      end case;
   end record;

   Automatic : constant Scale := (Mode => Automatic_Range);

   --  Both bounds must be finite and Minimum must be less than Maximum.
   --  Invalid bounds raise Components.Structure_Error.
   function Fixed
     (Minimum, Maximum : Long_Float) return Scale;

   --  Render at most Width newest samples from left to right. Empty cells stay
   --  blank. Automatic constant series use the middle (fourth) bar as their
   --  baseline. A zero Width is valid and returns a 0-by-1 surface.
   --  A non-finite converted sample raises Components.Structure_Error before
   --  any sample is mapped to a glyph index.
   function Render
     (Item       : Samples.Series;
      Width      : Natural;
      Scaling    : Scale := Automatic;
      Appearance : Sparklines.Appearance := (others => <>))
      return Flyology_TUI.Surfaces.Surface;

   function Render
     (Item    : Samples.Series;
      Width   : Natural;
      Scaling : Scale := Automatic;
      Theme   : Flyology_TUI.Themes.Theme)
      return Flyology_TUI.Surfaces.Surface;
end Flyology_TUI.Components.Sparklines;
