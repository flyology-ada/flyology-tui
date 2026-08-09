with Flyology_TUI.Glyphs;

package body Flyology_TUI.Components.Help is

   function Render
     (Bindings          : Binding_Array;
      Width             : Positive;
      Vertical          : Boolean := True;
      Key_Appearance    : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default;
      Detail_Appearance : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default)
      return Flyology_TUI.Surfaces.Surface
   is
      Result : Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.Create
          (Width, (if Vertical then Bindings'Length else 1));
      Row : Natural := 0;
      Column : Natural := 0;
   begin
      for Item of Bindings loop
         if Item.Enabled then
            declare
               Key : constant Wide_Wide_String :=
                 Text.To_Wide_Wide_String (Item.Key);
               Description : constant Wide_Wide_String :=
                 Text.To_Wide_Wide_String (Item.Description);
               Key_Width : constant Natural :=
                 Flyology_TUI.Glyphs.Width_Of (Key);
               Detail_Width : constant Natural :=
                 Flyology_TUI.Glyphs.Width_Of (Description);
               Detail_X : constant Natural := Column + Key_Width + 2;
            begin
               Result.Write (Column, Row, Key, Key_Appearance);
               if Detail_X < Width then
                  Result.Write
                    (Detail_X, Row, Description, Detail_Appearance);
               end if;
               if Vertical then
                  Row := Row + 1;
               else
                  Column := Detail_X + Detail_Width + 3;
               end if;
            end;
         end if;
      end loop;
      return Result;
   end Render;

end Flyology_TUI.Components.Help;
