with Flyology_TUI.Colors;
with Flyology_TUI.Geometry;
with Flyology_TUI.Surfaces;

package Flyology_TUI.Components.Gradients is
   type Direction is (Horizontal, Vertical);
   type Color_Application is
     (Apply_Foreground, Apply_Background, Apply_Both);
   type Interpolation_Mode is (SRGB_Channels, Linear_Light);

   type RGB_Color is record
      Red, Green, Blue : Flyology_TUI.Colors.Channel := 0;
   end record;

   Stop_Scale : constant := 1_000_000;
   subtype Stop_Offset is Natural range 0 .. Stop_Scale;

   type Stop is record
      Offset : Stop_Offset := 0;
      Color  : RGB_Color;
   end record;
   type Stop_Array is array (Natural range <>) of Stop;

   --  A model owns at most Max_Stops values and no animation clock, task, or
   --  process state. Create starts as a solid gradient at Initial_Color.
   type Model (Max_Stops : Positive) is tagged private;

   function Create
     (Max_Stops    : Positive;
      Initial_Color : RGB_Color := (others => 0);
      Flow          : Direction := Horizontal;
      Application   : Color_Application := Apply_Foreground;
      Interpolation : Interpolation_Mode := SRGB_Channels) return Model;

   --  Replace all stops only when Values is nonempty, fits Max_Stops, and has
   --  strictly increasing offsets. Duplicate and descending offsets reject
   --  the complete replacement; the previous gradient remains unchanged.
   procedure Try_Set_Stops
     (Item    : in out Model;
      Values  : Stop_Array;
      Success : out Boolean);

   procedure Set_Solid (Item : in out Model; Color : RGB_Color);
   function Stop_Count (Item : Model) return Positive;
   function Stop_At (Item : Model; Position : Positive) return Stop
     with Pre => Position <= Stop_Count (Item);

   procedure Set_Direction (Item : in out Model; Flow : Direction);
   function Flow (Item : Model) return Direction;
   procedure Set_Application
     (Item : in out Model; Application : Color_Application);
   function Application (Item : Model) return Color_Application;
   procedure Set_Interpolation
     (Item : in out Model; Interpolation : Interpolation_Mode);
   function Interpolation (Item : Model) return Interpolation_Mode;

   --  Sample the normalized offset. SRGB_Channels linearly interpolates the
   --  encoded 8-bit channels. Linear_Light decodes and encodes with the IEC
   --  61966-2-1 sRGB transfer function. Coordinate, channel, and final 8-bit
   --  rounding is nearest with an exact half choosing the larger value.
   function Sample (Item : Model; Offset : Stop_Offset) return RGB_Color;

   --  Clamp Value to Minimum .. Maximum and sample that normalized position.
   --  Minimum must be strictly below Maximum.
   function Heatmap
     (Item : Model;
      Value, Minimum, Maximum : Long_Float) return RGB_Color
     with Pre => Minimum < Maximum;

   --  Apply semantic RGB colors to complete cells inside Region. Region uses
   --  surface coordinates and may be signed or clipped. A wide glyph is
   --  recolored only when both its lead and continuation cells are in Region;
   --  both cells retain one appearance, so clipping cannot orphan it. Existing
   --  glyphs, non-target colors, and every non-color style attribute survive.
   --  Terminal profile degradation remains the Renderer's responsibility.
   procedure Apply
     (Item   : Model;
      Target : in out Flyology_TUI.Surfaces.Surface;
      Region : Flyology_TUI.Geometry.Rectangle);

private
   type Stored_Stop_Array is array (Positive range <>) of Stop;

   type Model (Max_Stops : Positive) is tagged record
      Stops       : Stored_Stop_Array (1 .. Max_Stops);
      Length      : Positive := 1;
      Current_Flow : Direction := Horizontal;
      Paint       : Color_Application := Apply_Foreground;
      Mode        : Interpolation_Mode := SRGB_Channels;
   end record;
end Flyology_TUI.Components.Gradients;
