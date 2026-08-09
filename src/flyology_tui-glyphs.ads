with Ada.Strings.Wide_Wide_Unbounded;

package Flyology_TUI.Glyphs is
   package Text renames Ada.Strings.Wide_Wide_Unbounded;

   subtype Cell_Width is Natural range 0 .. 2;

   function Is_Extender (Item : Wide_Wide_Character) return Boolean;
   function Width_Of (Item : Wide_Wide_Character) return Cell_Width;
   function Width_Of (Item : Wide_Wide_String) return Natural;

   --  Return the last code-point position belonging to the grapheme-like
   --  cluster beginning at First. This implements terminal-oriented combining
   --  marks, variation selectors, emoji modifiers, and ZWJ sequences.
   function Cluster_Last
     (Item  : Wide_Wide_String;
      First : Positive) return Natural
     with Pre => First in Item'Range;
end Flyology_TUI.Glyphs;
