with Ada.Strings;
with Ada.Strings.Fixed;

package body Flyology_TUI.Components.Progress is

   function Create
     (Width      : Positive := 40;
      Show_Value : Boolean := True) return Model
   is (Current => 0.0, Columns => Width, Show_Value => Show_Value);

   procedure Set (Item : in out Model; Value : Fraction) is
   begin
      Item.Current := Value;
   end Set;

   function Value (Item : Model) return Fraction is (Item.Current);

   function Render
     (Item       : Model;
      Complete   : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Remaining  : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default)
      return Flyology_TUI.Surfaces.Surface
   is
      Label_Width : constant Natural := (if Item.Show_Value then 5 else 0);
      Bar_Width : constant Natural :=
        Item.Columns - Natural'Min (Item.Columns, Label_Width);
      Filled : constant Natural :=
        Natural (Long_Float'Floor (Item.Current * Long_Float (Bar_Width)));
      Result : Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.Create (Item.Columns, 1);
   begin
      if Bar_Width > 0 then
         for X in 0 .. Bar_Width - 1 loop
            if X < Filled then
               Result.Put (X, 0, "█", Complete);
            else
               Result.Put (X, 0, "░", Remaining);
            end if;
         end loop;
      end if;
      if Item.Show_Value and then Item.Columns >= Label_Width then
         declare
            Percent : constant Natural := Natural (Item.Current * 100.0);
            Image : constant String := Ada.Strings.Fixed.Trim
              (Natural'Image (Percent), Ada.Strings.Both);
            Label : Wide_Wide_String (1 .. 5) := "    %";
            Start : constant Positive := 5 - Image'Length;
         begin
            for Index in Image'Range loop
               Label (Start + Index - Image'First) :=
                 Wide_Wide_Character'Val (Character'Pos (Image (Index)));
            end loop;
            Result.Write (Bar_Width, 0, Label, Remaining);
         end;
      end if;
      return Result;
   end Render;

end Flyology_TUI.Components.Progress;
