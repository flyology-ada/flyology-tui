with Ada.Strings.Wide_Wide_Unbounded;
with Flyology_TUI.Colors;
with Flyology_TUI.Glyphs;

package body Flyology_TUI.Components.Markdown_Editors is

   package Text renames Ada.Strings.Wide_Wide_Unbounded;
   use type Flyology_TUI.Colors.Color_Kind;

   function From_Theme
     (Theme : Flyology_TUI.Themes.Theme) return Appearance is
     (Source  => Flyology_TUI.Components.Text_Areas.From_Theme (Theme),
      Preview => Flyology_TUI.Components.Markdown_Viewers.From_Theme (Theme));

   function With_Bold
     (Value : Flyology_TUI.Styles.Style) return Flyology_TUI.Styles.Style
   is
      Result : Flyology_TUI.Styles.Style := Value;
   begin
      Result.Bold := True;
      return Result;
   end With_Bold;

   function With_Italic
     (Value : Flyology_TUI.Styles.Style) return Flyology_TUI.Styles.Style
   is
      Result : Flyology_TUI.Styles.Style := Value;
   begin
      Result.Italic := True;
      return Result;
   end With_Italic;

   function Annotations_From_Theme
     (Theme : Flyology_TUI.Themes.Theme) return Annotation_Appearance
   is
     (Marker   => Theme.Muted,
      Heading  => With_Bold (Theme.Primary),
      Strong   => With_Bold (Theme.Primary),
      Emphasis => With_Italic (Theme.Primary),
      Code     => Theme.Success,
      Link     => Theme.Focused,
      Task_Marker => Theme.Success,
      Quote    => With_Italic (Theme.Muted),
      Rule     => Theme.Border);

   procedure Validate_Size (Width, Height : Positive) is
   begin
      if Height > Natural'Last / Width then
         raise Flyology_TUI.Components.Capacity_Error;
      end if;
   end Validate_Size;

   function Portion
     (Available  : Positive;
      Percentage : Positive) return Positive
   is
      Raw : constant Natural :=
        (Available / 100) * Percentage
        + ((Available mod 100) * Percentage) / 100;
   begin
      return Positive'Max (1, Natural'Min (Available - 1, Raw));
   end Portion;

   function Layout (Item : Model) return Layout_Snapshot is
      Result : Layout_Snapshot;
      Available : Positive;
      Source_Span : Positive;
   begin
      case Item.Current_Mode is
         when Source_Only =>
            Result.Source_Visible := True;
            Result.Source_Box :=
              (X => 0, Y => 0, Width => Item.Columns, Height => Item.Rows);
         when Preview_Only =>
            Result.Preview_Visible := True;
            Result.Preview_Box :=
              (X => 0, Y => 0, Width => Item.Columns, Height => Item.Rows);
         when Split_Horizontally =>
            if Item.Columns < 3 then
               Result.Source_Visible := True;
               Result.Source_Box :=
                 (X => 0, Y => 0,
                  Width => Item.Columns, Height => Item.Rows);
            else
               Available := Item.Columns - 1;
               Source_Span := Portion (Available, Item.Source_Share);
               Result.Source_Visible := True;
               Result.Preview_Visible := True;
               Result.Source_Box :=
                 (X => 0, Y => 0,
                  Width => Source_Span, Height => Item.Rows);
               Result.Preview_Box :=
                 (X => Integer (Source_Span + 1), Y => 0,
                  Width => Available - Source_Span, Height => Item.Rows);
            end if;
         when Split_Vertically =>
            if Item.Rows < 3 then
               Result.Source_Visible := True;
               Result.Source_Box :=
                 (X => 0, Y => 0,
                  Width => Item.Columns, Height => Item.Rows);
            else
               Available := Item.Rows - 1;
               Source_Span := Portion (Available, Item.Source_Share);
               Result.Source_Visible := True;
               Result.Preview_Visible := True;
               Result.Source_Box :=
                 (X => 0, Y => 0,
                  Width => Item.Columns, Height => Source_Span);
               Result.Preview_Box :=
                 (X => 0, Y => Integer (Source_Span + 1),
                  Width => Item.Columns, Height => Available - Source_Span);
            end if;
      end case;
      return Result;
   end Layout;

   procedure Apply_Layout (Item : in out Model) is
      Plan : constant Layout_Snapshot := Layout (Item);
   begin
      if Plan.Source_Visible then
         Item.Source_Core.Set_Size
           (Positive (Plan.Source_Box.Width),
            Positive (Plan.Source_Box.Height));
      else
         Item.Source_Core.Set_Size (1, 1);
      end if;
      if Plan.Preview_Visible then
         Item.Preview_Core.Set_Size
           (Positive (Plan.Preview_Box.Width),
            Positive (Plan.Preview_Box.Height));
      else
         Item.Preview_Core.Set_Size (1, 1);
      end if;
   end Apply_Layout;

   function Create
     (Max_Code_Points        : Positive;
      Max_Lines              : Positive;
      Max_Undo_Entries       : Positive;
      Max_History_Codepoints : Positive;
      Max_Links              : Positive;
      Width                  : Positive := 80;
      Height                 : Positive := 20;
      Mode                   : Presentation_Mode := Split_Horizontally)
      return Model
   is
   begin
      Validate_Size (Width, Height);
      return Result : Model
        (Max_Code_Points,
         Max_Lines,
         Max_Undo_Entries,
         Max_History_Codepoints,
         Max_Links)
      do
         Result.Columns := Width;
         Result.Rows := Height;
         Result.Current_Mode := Mode;
         Result.Source_Core.Set_Wrap
           (Flyology_TUI.Components.Text_Areas.Soft_Wrap);
         Apply_Layout (Result);
      end return;
   end Create;

   procedure Try_Set_Source
     (Item    : in out Model;
      Value   : Wide_Wide_String;
      Success : out Boolean)
   is
      Preview_Success : Boolean;
   begin
      Item.Source_Core.Try_Set_Text (Value, Success);
      if Success then
         Item.Preview_Core.Try_Set_Source
           (Item.Source_Core.Value, Preview_Success);
         if not Preview_Success then
            raise Program_Error with "matching preview bounds rejected source";
         end if;
      end if;
   end Try_Set_Source;

   function Source (Item : Model) return Wide_Wide_String is
     (Item.Source_Core.Value);

   procedure Set_Mode (Item : in out Model; Mode : Presentation_Mode) is
   begin
      Item.Current_Mode := Mode;
      Apply_Layout (Item);
   end Set_Mode;
   function Mode (Item : Model) return Presentation_Mode is
     (Item.Current_Mode);

   procedure Set_Source_Percentage
     (Item : in out Model; Percentage : Source_Percentage_Range) is
   begin
      Item.Source_Share := Percentage;
      Apply_Layout (Item);
   end Set_Source_Percentage;
   function Source_Percentage
     (Item : Model) return Source_Percentage_Range is
     (Item.Source_Share);

   procedure Set_Size (Item : in out Model; Width, Height : Positive) is
   begin
      Validate_Size (Width, Height);
      Item.Columns := Width;
      Item.Rows := Height;
      Apply_Layout (Item);
   end Set_Size;
   function Width (Item : Model) return Positive is (Item.Columns);
   function Height (Item : Model) return Positive is (Item.Rows);

   function Has_Source (Item : Layout_Snapshot) return Boolean is
     (Item.Source_Visible);
   function Has_Preview (Item : Layout_Snapshot) return Boolean is
     (Item.Preview_Visible);
   function Source_Region
     (Item : Layout_Snapshot) return Flyology_TUI.Geometry.Rectangle is
     (Item.Source_Box);
   function Preview_Region
     (Item : Layout_Snapshot) return Flyology_TUI.Geometry.Rectangle is
     (Item.Preview_Box);

   procedure Focus_Source (Item : in out Model) is
   begin
      Item.Focus := Source_Focus;
      Item.Preview_Core.Blur;
      Item.Source_Core.Focus;
   end Focus_Source;

   procedure Focus_Preview (Item : in out Model) is
   begin
      Item.Focus := Preview_Focus;
      Item.Source_Core.Blur;
      Item.Preview_Core.Focus;
   end Focus_Preview;

   procedure Blur (Item : in out Model) is
   begin
      Item.Focus := No_Focus;
      Item.Source_Core.Blur;
      Item.Preview_Core.Blur;
   end Blur;

   procedure Synchronize_Preview (Item : in out Model) is
      Success : Boolean;
   begin
      Item.Preview_Core.Try_Set_Source (Item.Source_Core.Value, Success);
      if not Success then
         raise Program_Error with "matching preview bounds rejected edit";
      end if;
   end Synchronize_Preview;

   function Handle_Source
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Terminal_Event)
      return Flyology_TUI.Components.Interactions.Update_Result
   is
      Before : constant Wide_Wide_String := Item.Source_Core.Value;
      Result : Flyology_TUI.Components.Interactions.Update_Result;
   begin
      Result := Item.Source_Core.Handle (Event);
      if Item.Source_Core.Value /= Before then
         Synchronize_Preview (Item);
      end if;
      return Result;
   end Handle_Source;

   function Handle_Source
     (Item  : in out Model;
      Event : Flyology_TUI.Mouse.Local_Event)
      return Flyology_TUI.Components.Interactions.Update_Result
   is
      Before : constant Wide_Wide_String := Item.Source_Core.Value;
      Result : Flyology_TUI.Components.Interactions.Update_Result;
   begin
      Result := Item.Source_Core.Handle (Event);
      if Item.Source_Core.Value /= Before then
         Synchronize_Preview (Item);
      end if;
      return Result;
   end Handle_Source;

   function Handle_Preview
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Terminal_Event)
      return Flyology_TUI.Components.Markdown_Viewers.Action_Result is
     (Item.Preview_Core.Handle (Event));

   function Handle_Preview
     (Item   : in out Model;
      Event  : Flyology_TUI.Mouse.Local_Event;
      Layout : Flyology_TUI.Components.Markdown_Viewers.Presentation)
      return Flyology_TUI.Components.Markdown_Viewers.Action_Result is
     (Item.Preview_Core.Handle (Event, Layout));

   procedure Advance_Preview
     (Item : in out Model; Line_Budget : Natural) is
   begin
      Item.Preview_Core.Advance_Parsing (Line_Budget);
   end Advance_Preview;

   function Preview_Parsing
     (Item : Model)
      return Flyology_TUI.Components.Markdown_Viewers.Parsing_State is
     (Item.Preview_Core.Parsing);

   function Preview_Unsupported
     (Item : Model)
      return Flyology_TUI.Components.Markdown_Viewers.Unsupported_Set is
     (Item.Preview_Core.Unsupported);

   function Preview_First_Visible_Row (Item : Model) return Natural is
     (Item.Preview_Core.First_Visible_Row);

   function Preview_Focused_Link
     (Item : Model) return Flyology_TUI.Components.Markdown_Viewers.Link_Id is
     (Item.Preview_Core.Focused_Link);

   function Merged
     (Base, Annotation : Flyology_TUI.Styles.Style)
      return Flyology_TUI.Styles.Style
   is
      Result : Flyology_TUI.Styles.Style := Base;
   begin
      if Annotation.Foreground.Kind /= Flyology_TUI.Colors.Default_Color then
         Result.Foreground := Annotation.Foreground;
      end if;
      if Annotation.Background.Kind /= Flyology_TUI.Colors.Default_Color then
         Result.Background := Annotation.Background;
      end if;
      Result.Bold := Result.Bold or else Annotation.Bold;
      Result.Faint := Result.Faint or else Annotation.Faint;
      Result.Italic := Result.Italic or else Annotation.Italic;
      Result.Underline := Result.Underline or else Annotation.Underline;
      Result.Blink := Result.Blink or else Annotation.Blink;
      Result.Reverse_Video :=
        Result.Reverse_Video or else Annotation.Reverse_Video;
      Result.Strikethrough :=
        Result.Strikethrough or else Annotation.Strikethrough;
      return Result;
   end Merged;

   function Is_Fence_Line
     (Content : Wide_Wide_String;
      First, Last : Natural) return Boolean
   is
      Position : Natural := First;
      Spaces : Natural := 0;
   begin
      while Position < Last
        and then Spaces < 3
        and then Content (Content'First + Position) = ' '
      loop
         Position := Position + 1;
         Spaces := Spaces + 1;
      end loop;
      return Last - Position >= 3
        and then
          (Content (Content'First + Position .. Content'First + Position + 2)
             = "```"
           or else
             Content
               (Content'First + Position .. Content'First + Position + 2)
                 = "~~~");
   end Is_Fence_Line;

   function Inside_Fence
     (Item : Model; Line : Positive; Content : Wide_Wide_String)
      return Boolean
   is
      Result : Boolean := False;
   begin
      if Line = 1 then
         return False;
      end if;
      for Candidate in 1 .. Line - 1 loop
         declare
            First : constant Natural :=
              Item.Source_Core.Line_Start_Offset (Candidate);
            Last : constant Natural :=
              Item.Source_Core.Line_End_Offset (Candidate);
         begin
            if Is_Fence_Line (Content, First, Last) then
               Result := not Result;
            end if;
         end;
      end loop;
      return Result;
   end Inside_Fence;

   type Annotation_Cell is record
      Active : Boolean := False;
      Kind   : Annotation_Kind := Marker;
   end record;
   type Annotation_Cell_Array is
     array (Natural range <>) of Annotation_Cell;

   procedure Classify_Line
     (Content  : Wide_Wide_String;
      First    : Natural;
      Last     : Natural;
      In_Fence : Boolean;
      Cells    : in out Annotation_Cell_Array)
   is
      Length : constant Natural := Last - First;

      function Character_At (Offset : Natural) return Wide_Wide_Character is
        (Content (Content'First + First + Offset));

      procedure Paint
        (From, Through : Natural; Kind : Annotation_Kind)
      is
      begin
         if Length = 0 or else From >= Length then
            return;
         end if;
         for Position in From .. Natural'Min (Through, Length - 1) loop
            Cells (Position) := (True, Kind);
         end loop;
      end Paint;

      function Closing
        (From : Natural; Value : Wide_Wide_Character) return Natural
      is
      begin
         if From >= Length then
            return Length;
         end if;
         for Position in From .. Length - 1 loop
            if Character_At (Position) = Value then
               return Position;
            end if;
         end loop;
         return Length;
      end Closing;

      First_Text : Natural := 0;
      Position : Natural := 0;
   begin
      if Length = 0 then
         return;
      end if;
      while First_Text < Length and then Character_At (First_Text) = ' ' loop
         First_Text := First_Text + 1;
      end loop;

      if Is_Fence_Line (Content, First, Last) then
         Paint (First_Text, Natural'Min (First_Text + 2, Length - 1), Marker);
         if First_Text + 3 < Length then
            Paint (First_Text + 3, Length - 1, Code);
         end if;
         return;
      elsif In_Fence then
         Paint (0, Length - 1, Code);
         return;
      end if;

      if First_Text < Length and then Character_At (First_Text) = '#' then
         declare
            End_Marker : Natural := First_Text;
         begin
            while End_Marker + 1 < Length
              and then Character_At (End_Marker + 1) = '#'
            loop
               End_Marker := End_Marker + 1;
            end loop;
            if End_Marker - First_Text < 6
              and then End_Marker + 1 < Length
              and then Character_At (End_Marker + 1) = ' '
            then
               Paint (First_Text, End_Marker, Marker);
               Paint (End_Marker + 2, Length - 1, Heading);
            end if;
         end;
      elsif First_Text < Length
        and then Character_At (First_Text) = '>'
      then
         Paint (First_Text, First_Text, Marker);
         if First_Text + 1 < Length then
            Paint (First_Text + 1, Length - 1, Quote);
         end if;
      end if;

      if First_Text + 4 < Length
        and then Character_At (First_Text) in '-' | '*' | '+'
        and then Character_At (First_Text + 1) = ' '
        and then Character_At (First_Text + 2) = '['
        and then Character_At (First_Text + 4) = ']'
        and then Character_At (First_Text + 3) in ' ' | 'x' | 'X'
      then
         Paint (First_Text, First_Text + 4, Task_Marker);
      end if;

      if Length - First_Text >= 3
        and then Character_At (First_Text) in '-' | '*' | '_'
      then
         declare
            Is_Rule : Boolean := True;
            Marks : Natural := 0;
         begin
            for Offset in First_Text .. Length - 1 loop
               if Character_At (Offset) = Character_At (First_Text) then
                  Marks := Marks + 1;
               elsif Character_At (Offset) /= ' ' then
                  Is_Rule := False;
               end if;
            end loop;
            if Is_Rule and then Marks >= 3 then
               Paint (First_Text, Length - 1, Rule);
               return;
            end if;
         end;
      end if;

      while Position < Length loop
         if Character_At (Position) = '`' then
            declare
               Close : constant Natural := Closing (Position + 1, '`');
            begin
               if Close < Length then
                  Paint (Position, Position, Marker);
                  if Close > Position + 1 then
                     Paint (Position + 1, Close - 1, Code);
                  end if;
                  Paint (Close, Close, Marker);
                  Position := Close + 1;
               else
                  Position := Position + 1;
               end if;
            end;
         elsif Position + 1 < Length
           and then
             ((Character_At (Position) = '*'
               and then Character_At (Position + 1) = '*')
              or else
                (Character_At (Position) = '_'
                 and then Character_At (Position + 1) = '_'))
         then
            declare
               Mark : constant Wide_Wide_Character := Character_At (Position);
               Close : Natural := Position + 2;
            begin
               while Close + 1 < Length
                 and then
                   not (Character_At (Close) = Mark
                        and then Character_At (Close + 1) = Mark)
               loop
                  Close := Close + 1;
               end loop;
               if Close + 1 < Length then
                  Paint (Position, Position + 1, Marker);
                  if Close > Position + 2 then
                     Paint (Position + 2, Close - 1, Strong);
                  end if;
                  Paint (Close, Close + 1, Marker);
                  Position := Close + 2;
               else
                  Position := Position + 2;
               end if;
            end;
         elsif Character_At (Position) in '*' | '_' then
            declare
               Mark : constant Wide_Wide_Character := Character_At (Position);
               Close : constant Natural := Closing (Position + 1, Mark);
            begin
               if Close < Length then
                  Paint (Position, Position, Marker);
                  if Close > Position + 1 then
                     Paint (Position + 1, Close - 1, Emphasis);
                  end if;
                  Paint (Close, Close, Marker);
                  Position := Close + 1;
               else
                  Position := Position + 1;
               end if;
            end;
         elsif Character_At (Position) = '[' then
            declare
               Label_End : constant Natural := Closing (Position + 1, ']');
               URL_End : Natural := Length;
            begin
               if Label_End + 1 < Length
                 and then Character_At (Label_End + 1) = '('
               then
                  URL_End := Closing (Label_End + 2, ')');
               end if;
               if URL_End < Length then
                  Paint (Position, Position, Marker);
                  if Label_End > Position + 1 then
                     Paint (Position + 1, Label_End - 1, Link);
                  end if;
                  Paint (Label_End, Label_End + 1, Marker);
                  if URL_End > Label_End + 2 then
                     Paint (Label_End + 2, URL_End - 1, Link);
                  end if;
                  Paint (URL_End, URL_End, Marker);
                  Position := URL_End + 1;
               else
                  Position := Position + 1;
               end if;
            end;
         else
            Position := Position + 1;
         end if;
      end loop;
   end Classify_Line;

   function Render_Source
     (Item : Model; Look : Appearance)
      return Flyology_TUI.Surfaces.Surface is
     (Item.Source_Core.Render (Look.Source));

   function Render_Source
     (Item        : Model;
      Look        : Appearance;
      Annotations : Annotation_Appearance)
      return Flyology_TUI.Surfaces.Surface
   is
      Result : Flyology_TUI.Surfaces.Surface :=
        Item.Source_Core.Render (Look.Source);
      Content : constant Wide_Wide_String := Item.Source_Core.Value;
      Gutter : constant Positive := Item.Source_Core.Gutter_Columns;
      Selection_First, Selection_Last : Natural := 0;
      Has_Selection : constant Boolean := Item.Source_Core.Has_Selection;
      Cursor : constant Natural := Item.Source_Core.Cursor_Offset;
   begin
      if Has_Selection then
         Item.Source_Core.Selection_Range
           (Selection_First, Selection_Last);
      end if;
      for Row in 0 .. Result.Height - 1 loop
         declare
            Line : Positive;
            Segment_First, Segment_Last : Natural;
            Exists : Boolean;
         begin
            Item.Source_Core.Visible_Segment
              (Row, Line, Segment_First, Segment_Last, Exists);
            exit when not Exists;
            declare
               Line_First : constant Natural :=
                 Item.Source_Core.Line_Start_Offset (Line);
               Line_Last : constant Natural :=
                 Item.Source_Core.Line_End_Offset (Line);
               Kinds : Annotation_Cell_Array
                 (0 .. Natural'Max (1, Line_Last - Line_First) - 1);
               Origin : constant Natural :=
                 Item.Source_Core.Position_At_Offset
                   (Segment_First).Cell_Column;
               Position : Natural := Segment_First;
            begin
               Classify_Line
                 (Content, Line_First, Line_Last,
                  Inside_Fence (Item, Line, Content), Kinds);
               while Position < Segment_Last loop
                  declare
                     Last : constant Natural :=
                       Flyology_TUI.Glyphs.Cluster_Last
                         (Content, Content'First + Position)
                       - Content'First;
                     Local : constant Natural := Position - Line_First;
                     Cell_Column : constant Natural :=
                       Item.Source_Core.Position_At_Offset
                         (Position).Cell_Column;
                     Relative : constant Natural := Cell_Column - Origin;
                     X : constant Natural :=
                       (if Relative > Natural'Last - Gutter
                        then Natural'Last else Gutter + Relative);
                     Selected : constant Boolean :=
                       Has_Selection
                       and then Position < Selection_Last
                       and then Last + 1 > Selection_First;
                  begin
                     if Local in Kinds'Range
                       and then Kinds (Local).Active
                       and then X < Result.Width
                       and then not Selected
                       and then
                         (not Item.Source_Core.Focused
                          or else Cursor < Position
                          or else Cursor > Last)
                     then
                        declare
                           Existing : constant Flyology_TUI.Surfaces.Cell :=
                             Result.Element (X, Row);
                        begin
                           if not Existing.Continuation then
                              Result.Put
                                (X, Row,
                                 Text.To_Wide_Wide_String (Existing.Glyph),
                                 Merged
                                   (Existing.Appearance,
                                    Annotations (Kinds (Local).Kind)));
                           end if;
                        end;
                     end if;
                     Position := Last + 1;
                  end;
               end loop;
            end;
         end;
      end loop;
      return Result;
   end Render_Source;

   function Present_Preview
     (Item        : Model;
      Look        : Appearance;
      Line_Budget : Natural := Natural'Last)
      return Flyology_TUI.Components.Markdown_Viewers.Presentation is
     (Item.Preview_Core.Present (Look.Preview, Line_Budget));

   function Render_Source
     (Item : Model; Theme : Flyology_TUI.Themes.Theme)
      return Flyology_TUI.Surfaces.Surface is
     (Render_Source
        (Item, From_Theme (Theme), Annotations_From_Theme (Theme)));

   function Present_Preview
     (Item        : Model;
      Theme       : Flyology_TUI.Themes.Theme;
      Line_Budget : Natural := Natural'Last)
      return Flyology_TUI.Components.Markdown_Viewers.Presentation is
     (Present_Preview (Item, From_Theme (Theme), Line_Budget));

end Flyology_TUI.Components.Markdown_Editors;
