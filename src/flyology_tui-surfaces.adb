with Flyology_TUI.Glyphs;

package body Flyology_TUI.Surfaces is

   function Index_Of (Item : Surface; X, Y : Natural) return Natural is
     (Y * Item.Columns + X);

   function Blank (Fill : Flyology_TUI.Styles.Style) return Cell is
     (Glyph        => Text.To_Unbounded_Wide_Wide_String (" "),
      Appearance   => Fill,
      Continuation => False);

   function Create
     (Width, Height : Natural;
      Fill          : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default)
      return Surface
   is
      Result : Surface;
   begin
      Result.Columns := Width;
      Result.Rows := Height;
      for Index in 1 .. Width * Height loop
         Result.Cells.Append (Blank (Fill));
      end loop;
      return Result;
   end Create;

   function From_Text
     (Content : Wide_Wide_String;
      Appearance : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default)
      return Surface
   is
      Width  : Natural := 0;
      Height : Natural := 1;
      Start  : Natural := Content'First;
   begin
      if Content'Length = 0 then
         Height := 0;
      else
         for Pos in Content'Range loop
            if Content (Pos) = Wide_Wide_Character'Val (10) then
               if Pos > Start then
                  Width := Natural'Max
                    (Width,
                     Flyology_TUI.Glyphs.Width_Of
                       (Content (Start .. Pos - 1)));
               end if;
               Height := Height + 1;
               Start := Pos + 1;
            end if;
         end loop;
         if Start <= Content'Last then
            Width := Natural'Max
              (Width,
               Flyology_TUI.Glyphs.Width_Of
                 (Content (Start .. Content'Last)));
         end if;
      end if;

      declare
         Result : Surface := Create (Width, Height, Appearance);
      begin
         Result.Write (0, 0, Content, Appearance);
         return Result;
      end;
   end From_Text;

   function Width (Item : Surface) return Natural is (Item.Columns);
   function Height (Item : Surface) return Natural is (Item.Rows);

   function Element (Item : Surface; X, Y : Natural) return Cell is
     (Item.Cells.Element (Index_Of (Item, X, Y)));

   procedure Clear_Cell (Item : in out Surface; X, Y : Natural) is
      Index : Natural;
      Value : Cell;
   begin
      if X >= Item.Columns or else Y >= Item.Rows then
         return;
      end if;

      Index := Index_Of (Item, X, Y);
      Value := Item.Cells.Element (Index);
      if Value.Continuation and then X > 0 then
         Item.Cells.Replace_Element
           (Index - 1, Blank (Flyology_TUI.Styles.Default));
      elsif X + 1 < Item.Columns
        and then Item.Cells.Element (Index + 1).Continuation
      then
         Item.Cells.Replace_Element
           (Index + 1, Blank (Flyology_TUI.Styles.Default));
      end if;
      Item.Cells.Replace_Element (Index, Blank (Flyology_TUI.Styles.Default));
   end Clear_Cell;

   procedure Clear
     (Item : in out Surface;
      Fill : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default)
   is
   begin
      if Item.Cells.Is_Empty then
         return;
      end if;
      for Index in Item.Cells.First_Index .. Item.Cells.Last_Index loop
         Item.Cells.Replace_Element (Index, Blank (Fill));
      end loop;
   end Clear;

   procedure Put
     (Item       : in out Surface;
      X, Y       : Natural;
      Glyph      : Wide_Wide_String;
      Appearance : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default)
   is
      Cell_Columns : Natural := Flyology_TUI.Glyphs.Width_Of (Glyph);
      Value        : Cell;
      Index        : Natural;
   begin
      if Glyph'Length = 0 or else X >= Item.Columns or else Y >= Item.Rows then
         return;
      end if;
      Cell_Columns := Natural'Min (2, Cell_Columns);
      if Cell_Columns = 0 or else X + Cell_Columns > Item.Columns then
         return;
      end if;

      Clear_Cell (Item, X, Y);
      if Cell_Columns = 2 then
         Clear_Cell (Item, X + 1, Y);
      end if;

      Index := Index_Of (Item, X, Y);
      Value :=
        (Glyph        => Text.To_Unbounded_Wide_Wide_String (Glyph),
         Appearance   => Appearance,
         Continuation => False);
      Item.Cells.Replace_Element (Index, Value);
      if Cell_Columns = 2 then
         Item.Cells.Replace_Element
           (Index + 1,
            (Glyph        => Text.Null_Unbounded_Wide_Wide_String,
             Appearance   => Appearance,
             Continuation => True));
      end if;
   end Put;

   procedure Write
     (Item       : in out Surface;
      X, Y       : Natural;
      Content    : Wide_Wide_String;
      Appearance : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default)
   is
      Column : Natural := X;
      Row    : Natural := Y;
      Pos    : Natural := Content'First;
   begin
      while Pos <= Content'Last and then Row < Item.Rows loop
         if Content (Pos) = Wide_Wide_Character'Val (10) then
            Row := Row + 1;
            Column := X;
            Pos := Pos + 1;
         else
            declare
               Last : constant Natural :=
                 Flyology_TUI.Glyphs.Cluster_Last (Content, Pos);
               Glyph : constant Wide_Wide_String := Content (Pos .. Last);
               Columns : constant Natural :=
                 Natural'Min (2, Flyology_TUI.Glyphs.Width_Of (Glyph));
            begin
               if Columns > 0 then
                  Put (Item, Column, Row, Glyph, Appearance);
                  Column := Column + Columns;
               end if;
               Pos := Last + 1;
            end;
         end if;
      end loop;
   end Write;

   procedure Overlay
     (Target             : in out Surface;
      Source             : Surface;
      X, Y               : Natural;
      Transparent_Spaces : Boolean := False)
   is
   begin
      if Source.Rows = 0 or else Source.Columns = 0 then
         return;
      end if;
      for Row in 0 .. Source.Rows - 1 loop
         exit when Y + Row >= Target.Rows;
         for Column in 0 .. Source.Columns - 1 loop
            exit when X + Column >= Target.Columns;
            declare
               Value : constant Cell := Source.Element (Column, Row);
            begin
               if not Value.Continuation
                 and then (not Transparent_Spaces
                           or else
                             Text.To_Wide_Wide_String (Value.Glyph) /= " ")
               then
                  Target.Put
                    (X + Column,
                     Y + Row,
                     Text.To_Wide_Wide_String (Value.Glyph),
                     Value.Appearance);
               end if;
            end;
         end loop;
      end loop;
   end Overlay;

end Flyology_TUI.Surfaces;
