with Flyology_TUI.Glyphs;

package body Flyology_TUI.Components.Markdown_Viewers is
   use type Flyology_TUI.Events.Key_Kind;
   use type Flyology_TUI.Events.Mouse_Action;
   use type Flyology_TUI.Events.Mouse_Button;
   use type Flyology_TUI.Events.Terminal_Event_Kind;

   LF : constant Wide_Wide_Character := Wide_Wide_Character'Val (10);

   function From_Theme
     (Theme : Flyology_TUI.Themes.Theme) return Appearance
   is
      Headings : Heading_Appearance := (others => Theme.Primary);
      Strong   : Flyology_TUI.Styles.Style := Theme.Primary;
      Emphasis : Flyology_TUI.Styles.Style := Theme.Primary;
      Link     : Flyology_TUI.Styles.Style := Theme.Input;
   begin
      for Level in Headings'Range loop
         Headings (Level).Bold := True;
      end loop;
      Strong.Bold := True;
      Emphasis.Italic := True;
      Link.Underline := True;
      return
        (Text           => Theme.Primary,
         Heading        => Headings,
         Emphasis       => Emphasis,
         Strong         => Strong,
         Inline_Code    => Theme.Input,
         Code_Block     => Theme.Muted,
         Quote          => Theme.Muted,
         List_Marker    => Theme.Border,
         Task_Unchecked => Theme.Muted,
         Task_Checked   => Theme.Success,
         Link           => Link,
         Focused_Link   => Theme.Focused,
         Thematic_Break => Theme.Border,
         Diagnostic     => Theme.Error,
         Selection      => Theme.Selected);
   end From_Theme;

   procedure Validate_Size (Width, Height : Positive) is
   begin
      if Height > Natural'Last / Width then
         raise Flyology_TUI.Components.Capacity_Error;
      end if;
   end Validate_Size;

   function Create
     (Max_Code_Points : Positive;
      Max_Lines       : Positive;
      Max_Links       : Positive;
      Width           : Positive := 60;
      Height          : Positive := 20) return Model
   is
   begin
      Validate_Size (Width, Height);
      return Result : Model (Max_Code_Points, Max_Lines, Max_Links) do
         Result.Columns := Width;
         Result.Rows := Height;
         Result.Source_Core.Set_Size (Width, Height);
         Result.Source_Core.Set_Read_Only (True);
         Result.Source_Core.Set_Wrap
           (Flyology_TUI.Components.Text_Areas.Soft_Wrap);
      end return;
   end Create;

   procedure Reset_Parsing (Item : in out Model) is
   begin
      Item.Line_Count := 0;
      Item.Link_Length := 0;
      Item.Next_Offset := 0;
      Item.State := Parsing_Dirty;
      Item.Unsupported_Items := (others => False);
      Item.In_Fence := False;
      Item.Fence_Char := '`';
      Item.Top_Row := 0;
      Item.Focus_Link := No_Link;
      for Line of Item.Lines loop
         Line := (others => <>);
      end loop;
      for Link of Item.Links loop
         Link := (others => <>);
      end loop;
   end Reset_Parsing;

   procedure Try_Set_Source
     (Item    : in out Model;
      Value   : Wide_Wide_String;
      Success : out Boolean) is
   begin
      if Item.Revision = Natural'Last then
         raise Flyology_TUI.Components.Capacity_Error;
      end if;
      Item.Source_Core.Try_Set_Text (Value, Success);
      if Success then
         Item.Revision := Item.Revision + 1;
         Reset_Parsing (Item);
      end if;
   end Try_Set_Source;

   function Source (Item : Model) return Wide_Wide_String is
     (Item.Source_Core.Value);

   function Starts_With
     (Value : Wide_Wide_String;
      First : Natural;
      Prefix : Wide_Wide_String) return Boolean
   is
   begin
      if Prefix'Length > Value'Length - Natural'Min (First, Value'Length) then
         return False;
      end if;
      for Offset in 0 .. Prefix'Length - 1 loop
         if Value (Value'First + First + Offset) /=
           Prefix (Prefix'First + Offset)
         then
            return False;
         end if;
      end loop;
      return True;
   end Starts_With;

   function Find_Char
     (Value : Wide_Wide_String;
      Char  : Wide_Wide_Character;
      From, Before : Natural) return Natural
   is
   begin
      if From >= Before or else From >= Value'Length then
         return Natural'Last;
      end if;
      for Offset in From .. Natural'Min (Before, Value'Length) - 1 loop
         if Value (Value'First + Offset) = Char then
            return Offset;
         end if;
      end loop;
      return Natural'Last;
   end Find_Char;

   function Is_Thematic
     (Value : Wide_Wide_String; First, Last : Natural) return Boolean
   is
      Marker : Wide_Wide_Character := Wide_Wide_Character'Val (0);
      Count  : Natural := 0;
   begin
      if Last <= First then
         return False;
      end if;
      for Offset in First .. Last - 1 loop
         declare
            Char : constant Wide_Wide_Character :=
              Value (Value'First + Offset);
         begin
            if Char /= ' ' then
               if Char /= '-' and then Char /= '*' and then Char /= '_' then
                  return False;
               elsif Marker = Wide_Wide_Character'Val (0) then
                  Marker := Char;
               elsif Char /= Marker then
                  return False;
               end if;
               Count := Count + 1;
            end if;
         end;
      end loop;
      return Count >= 3;
   end Is_Thematic;

   function Ordered_Prefix_End
     (Value : Wide_Wide_String; First, Last : Natural) return Natural
   is
      Cursor : Natural := First;
   begin
      while Cursor < Last
        and then Value (Value'First + Cursor) in '0' .. '9'
      loop
         Cursor := Cursor + 1;
      end loop;
      if Cursor > First and then Cursor + 1 < Last
        and then Value (Value'First + Cursor) = '.'
        and then Value (Value'First + Cursor + 1) = ' '
      then
         return Cursor + 2;
      end if;
      return First;
   end Ordered_Prefix_End;

   procedure Note_Unsupported
     (Items : in out Unsupported_Set;
      Line  : Wide_Wide_String)
   is
      First_Nonblank : Natural := 0;
      Pipe_Count : Natural := 0;
      Cursor : Natural := 0;
      In_Inline_Code : Boolean := False;
   begin
      while Cursor < Line'Length loop
         if Line (Line'First + Cursor) = '`' then
            In_Inline_Code := not In_Inline_Code;
         elsif not In_Inline_Code then
            if Starts_With (Line, Cursor, "![") then
               Items (Images) := True;
            end if;
            if Starts_With (Line, Cursor, "[^") then
               Items (Footnotes) := True;
            end if;
            if Starts_With (Line, Cursor, "::") then
               Items (Definition_Lists) := True;
            end if;
            if Line (Line'First + Cursor) = '|' then
               Pipe_Count := Pipe_Count + 1;
            end if;
         end if;
         Cursor := Cursor + 1;
      end loop;
      if Pipe_Count >= 2 then
         Items (Tables) := True;
      end if;
      while First_Nonblank < Line'Length
        and then Line (Line'First + First_Nonblank) = ' '
      loop
         First_Nonblank := First_Nonblank + 1;
      end loop;
      if First_Nonblank >= 4 then
         Items (Nested_Block_Containers) := True;
      elsif First_Nonblank < Line'Length
        and then Line (Line'First + First_Nonblank) = '<'
      then
         Items (Raw_HTML) := True;
      end if;
   end Note_Unsupported;

   procedure Scan_Links
     (Item       : in out Model;
      Value      : Wide_Wide_String;
      Line_First : Natural;
      Line_Last  : Natural;
      Failed     : out Boolean)
   is
      Cursor : Natural := Line_First;
      Close_Label, Close_Target : Natural;
      Staged : Link_Array (1 .. Item.Max_Links);
      Staged_Count : Natural := 0;
      In_Inline_Code : Boolean := False;
   begin
      Failed := False;
      while Cursor < Line_Last loop
         if Value (Value'First + Cursor) = '`' then
            In_Inline_Code := not In_Inline_Code;
            Cursor := Cursor + 1;
         elsif not In_Inline_Code
           and then Value (Value'First + Cursor) = '['
           and then (Cursor = 0
                     or else Value (Value'First + Cursor - 1) /= '!')
         then
            Close_Label := Find_Char (Value, ']', Cursor + 1, Line_Last);
            if Close_Label /= Natural'Last
              and then Close_Label + 1 < Line_Last
              and then Value (Value'First + Close_Label + 1) = '('
            then
               Close_Target :=
                 Find_Char (Value, ')', Close_Label + 2, Line_Last);
               if Close_Target /= Natural'Last then
                  if Staged_Count = Item.Max_Links - Item.Link_Length then
                     Item.State := Parsing_Capacity_Limited;
                     Failed := True;
                     return;
                  end if;
                  Staged_Count := Staged_Count + 1;
                  Staged (Staged_Count) :=
                    (Syntax_First => Cursor,
                     Label_First  => Cursor + 1,
                     Label_Last   => Close_Label,
                     Target       => Text.To_Unbounded_Wide_Wide_String
                       (Value
                          (Value'First + Close_Label + 2 ..
                           Value'First + Close_Target - 1)));
                  Cursor := Close_Target + 1;
               else
                  Item.State := Parsing_Malformed;
                  Failed := True;
                  return;
               end if;
            else
               Cursor := Cursor + 1;
            end if;
         else
            Cursor := Cursor + 1;
         end if;
      end loop;
      if Staged_Count > 0 then
         for Position in 1 .. Staged_Count loop
            Item.Links (Item.Link_Length + Position) := Staged (Position);
         end loop;
         Item.Link_Length := Item.Link_Length + Staged_Count;
      end if;
   end Scan_Links;

   procedure Parse_Line
     (Item       : in out Model;
      Value      : Wide_Wide_String;
      Line_First : Natural;
      Line_Last  : Natural;
      Failed     : out Boolean)
   is
      Info : Line_Info :=
        (First => Line_First,
         Last => Line_Last,
         Content_First => Line_First,
         others => <>);
      Heading_Level : Natural := 0;
      Ordered_End : Natural;
      Relative : constant Wide_Wide_String :=
        (if Line_Last > Line_First
         then Value (Value'First + Line_First .. Value'First + Line_Last - 1)
         else "");
      Previous_In_Fence : constant Boolean := Item.In_Fence;
      Previous_Fence_Char : constant Wide_Wide_Character := Item.Fence_Char;
   begin
      Failed := False;

      if Line_Last = Line_First then
         Info.Kind := Blank_Line;
      elsif Item.In_Fence then
         if Line_Last - Line_First >= 3
           and then Value (Value'First + Line_First) = Item.Fence_Char
           and then Value (Value'First + Line_First + 1) = Item.Fence_Char
           and then Value (Value'First + Line_First + 2) = Item.Fence_Char
         then
            Info.Kind := Fence_Delimiter;
            Item.In_Fence := False;
         else
            Info.Kind := Code_Block;
         end if;
      elsif Line_Last - Line_First >= 3
        and then
          (Value (Value'First + Line_First) = '`'
           or else Value (Value'First + Line_First) = '~')
        and then Value (Value'First + Line_First + 1) =
          Value (Value'First + Line_First)
        and then Value (Value'First + Line_First + 2) =
          Value (Value'First + Line_First)
      then
         Info.Kind := Fence_Delimiter;
         Item.In_Fence := True;
         Item.Fence_Char := Value (Value'First + Line_First);
      elsif Is_Thematic (Value, Line_First, Line_Last) then
         Info.Kind := Thematic_Break;
      else
         while Heading_Level < 6
           and then Line_First + Heading_Level < Line_Last
           and then Value (Value'First + Line_First + Heading_Level) = '#'
         loop
            Heading_Level := Heading_Level + 1;
         end loop;
         if Heading_Level > 0
           and then Line_First + Heading_Level < Line_Last
           and then Value (Value'First + Line_First + Heading_Level) = ' '
         then
            Info.Kind := Heading;
            Info.Level := Heading_Level;
            Info.Content_First := Line_First + Heading_Level + 1;
         elsif Line_Last - Line_First >= 2
           and then Value (Value'First + Line_First) = '>'
           and then Value (Value'First + Line_First + 1) = ' '
         then
            Info.Kind := Quote;
            Info.Content_First := Line_First + 2;
         elsif Line_Last - Line_First >= 2
           and then Value (Value'First + Line_First) in '-' | '*' | '+'
           and then Value (Value'First + Line_First + 1) = ' '
         then
            Info.Kind := Unordered_Item;
            Info.Content_First := Line_First + 2;
            if Line_Last - Info.Content_First >= 4
              and then Value (Value'First + Info.Content_First) = '['
              and then Value (Value'First + Info.Content_First + 2) = ']'
              and then Value (Value'First + Info.Content_First + 3) = ' '
              and then Value (Value'First + Info.Content_First + 1)
                in ' ' | 'x' | 'X'
            then
               Info.Kind := Task_Item;
               Info.Checked :=
                 Value (Value'First + Info.Content_First + 1) /= ' ';
               Info.Content_First := Info.Content_First + 4;
            end if;
         else
            Ordered_End := Ordered_Prefix_End (Value, Line_First, Line_Last);
            if Ordered_End > Line_First then
               Info.Kind := Ordered_Item;
               Info.Content_First := Ordered_End;
            else
               Info.Kind := Paragraph;
            end if;
         end if;
      end if;

      if Info.Kind not in Code_Block | Fence_Delimiter then
         Scan_Links (Item, Value, Info.Content_First, Line_Last, Failed);
      end if;
      if Failed then
         Item.In_Fence := Previous_In_Fence;
         Item.Fence_Char := Previous_Fence_Char;
         return;
      end if;
      if Info.Kind not in Code_Block | Fence_Delimiter then
         Note_Unsupported (Item.Unsupported_Items, Relative);
      end if;
      Item.Line_Count := Item.Line_Count + 1;
      Item.Lines (Item.Line_Count) := Info;
   end Parse_Line;

   procedure Advance_Parsing
     (Item : in out Model; Line_Budget : Natural)
   is
      Value : constant Wide_Wide_String := Source (Item);
      Budget : Natural := Line_Budget;
      Line_Last : Natural;
      Failed : Boolean;
   begin
      if Item.State in Parsing_Current | Parsing_Capacity_Limited |
        Parsing_Malformed
        or else Budget = 0
      then
         return;
      end if;
      while Budget > 0 loop
         if Item.Next_Offset >= Value'Length then
            Item.State :=
              (if Item.In_Fence then Parsing_Malformed else Parsing_Current);
            return;
         elsif Item.Line_Count = Item.Max_Lines then
            Item.State := Parsing_Capacity_Limited;
            return;
         end if;
         Line_Last := Item.Next_Offset;
         while Line_Last < Value'Length
           and then Value (Value'First + Line_Last) /= LF
         loop
            Line_Last := Line_Last + 1;
         end loop;
         Parse_Line (Item, Value, Item.Next_Offset, Line_Last, Failed);
         if Failed then
            return;
         end if;
         Item.Next_Offset :=
           (if Line_Last < Value'Length then Line_Last + 1 else Line_Last);
         Budget := Budget - 1;
         if Item.Next_Offset >= Value'Length then
            Item.State :=
              (if Item.In_Fence then Parsing_Malformed else Parsing_Current);
            return;
         end if;
      end loop;
   end Advance_Parsing;

   function Parsing (Item : Model) return Parsing_State is (Item.State);
   function Parsed_Line_Count (Item : Model) return Natural is
     (Item.Line_Count);
   function Unsupported (Item : Model) return Unsupported_Set is
     (Item.Unsupported_Items);

   function Has_Unsupported (Item : Model) return Boolean is
   begin
      for Present of Item.Unsupported_Items loop
         if Present then
            return True;
         end if;
      end loop;
      return False;
   end Has_Unsupported;

   function Link_Count (Item : Model) return Natural is (Item.Link_Length);
   function Link_Target
     (Item : Model; Id : Link_Id) return Wide_Wide_String is
     (Text.To_Wide_Wide_String (Item.Links (Natural (Id)).Target));
   function Focused_Link (Item : Model) return Link_Id is (Item.Focus_Link);

   procedure Set_Size (Item : in out Model; Width, Height : Positive) is
   begin
      Validate_Size (Width, Height);
      Item.Columns := Width;
      Item.Rows := Height;
      Item.Source_Core.Set_Size (Width, Height);
   end Set_Size;
   function Width (Item : Model) return Positive is (Item.Columns);
   function Height (Item : Model) return Positive is (Item.Rows);
   procedure Focus (Item : in out Model) is
   begin
      Item.Has_Focus := True;
      Item.Source_Core.Focus;
   end Focus;
   procedure Blur (Item : in out Model) is
   begin
      Item.Has_Focus := False;
      Item.Source_Core.Blur;
   end Blur;
   function Focused (Item : Model) return Boolean is (Item.Has_Focus);
   procedure Select_All (Item : in out Model) is
   begin
      Item.Source_Core.Select_All;
   end Select_All;
   procedure Clear_Selection (Item : in out Model) is
   begin
      Item.Source_Core.Clear_Selection;
   end Clear_Selection;
   function Has_Selection (Item : Model) return Boolean is
     (Item.Source_Core.Has_Selection);
   procedure Selection_Range
     (Item : Model; First, Last : out Natural) is
   begin
      Item.Source_Core.Selection_Range (First, Last);
   end Selection_Range;
   function First_Visible_Row (Item : Model) return Natural is (Item.Top_Row);

   function Saturating_Add (Left, Right : Natural) return Natural is
     (if Right > Natural'Last - Left then Natural'Last else Left + Right);

   function Scroll_Bound (Item : Model) return Natural is
      Snapshot : constant Presentation :=
        Present (Item, Flyology_TUI.Themes.Default);
      Extent : constant Natural := Content_Height (Snapshot);
   begin
      return Extent - Natural'Min (Extent, Item.Rows);
   end Scroll_Bound;

   function Negated_Triple (Value : Integer) return Integer is
   begin
      if Value > Integer'Last / 3 then
         return Integer'First;
      elsif Value < Integer'First / 3 then
         return Integer'Last;
      else
         return -3 * Value;
      end if;
   end Negated_Triple;

   procedure Scroll_Rows
     (Item : in out Model; Amount : Integer; Changed : out Boolean)
   is
      Before : constant Natural := Item.Top_Row;
      Magnitude : Natural;
   begin
      if Amount < 0 then
         Magnitude :=
           (if Amount = Integer'First then Natural'Last
            else Natural (-Amount));
         Item.Top_Row := Item.Top_Row - Natural'Min (Item.Top_Row, Magnitude);
      else
         Magnitude := Natural (Amount);
         Item.Top_Row := Natural'Min
           (Scroll_Bound (Item), Saturating_Add (Item.Top_Row, Magnitude));
      end if;
      Changed := Item.Top_Row /= Before;
   end Scroll_Rows;

   function Frame
     (Item : Presentation) return Flyology_TUI.Surfaces.Surface is
     (Item.Rendered);
   function Content_Height (Item : Presentation) return Natural is
     (Item.Document_Rows);
   function Rendered_Line_Count (Item : Presentation) return Natural is
     (Item.Rendered_Lines);
   function Rendering_Complete (Item : Presentation) return Boolean is
     (Item.Complete);

   function Has_Link (Item : Presentation; Id : Link_Id) return Boolean is
   begin
      if Id = No_Link or else Item.Hit_Count = 0 then
         return False;
      end if;
      for Position in 1 .. Item.Hit_Count loop
         if Item.Hits (Position).Id = Id then
            return True;
         end if;
      end loop;
      return False;
   end Has_Link;

   function Link_Region_Count
     (Item : Presentation; Id : Link_Id) return Natural
   is
      Result : Natural := 0;
   begin
      for Position in 1 .. Item.Hit_Count loop
         if Item.Hits (Position).Id = Id then
            Result := Result + 1;
         end if;
      end loop;
      return Result;
   end Link_Region_Count;

   function Link_Region
     (Item     : Presentation;
      Id       : Link_Id;
      Position : Positive)
      return Flyology_TUI.Geometry.Rectangle
   is
      Seen : Natural := 0;
   begin
      for Candidate in 1 .. Item.Hit_Count loop
         if Item.Hits (Candidate).Id = Id then
            Seen := Seen + 1;
            if Seen = Position then
               return Item.Hits (Candidate).Region;
            end if;
         end if;
      end loop;
      raise Program_Error;
   end Link_Region;

   function Present
     (Item        : Model;
      Look        : Appearance;
      Line_Budget : Natural := Natural'Last) return Presentation
   is
      Result : Presentation (Item.Columns * Item.Rows) :=
        (Hit_Capacity => Item.Columns * Item.Rows,
         Rendered => Flyology_TUI.Surfaces.Create
           (Item.Columns, Item.Rows, Look.Text),
         Revision => Item.Revision,
         others => <>);
      Value : constant Wide_Wide_String := Source (Item);
      Visual_Row : Natural := 0;
      X : Natural := 0;
      Indent : Natural := 0;

      function Visible_Row return Boolean is
        (Visual_Row >= Item.Top_Row
         and then Visual_Row - Item.Top_Row < Item.Rows);

      function Link_At (Syntax_First : Natural) return Link_Id is
      begin
         if Item.Link_Length > 0 then
            for Position in 1 .. Item.Link_Length loop
               if Item.Links (Position).Syntax_First = Syntax_First then
                  return Link_Id (Position);
               end if;
            end loop;
         end if;
         return No_Link;
      end Link_At;

      procedure Note_Hit
        (Id : Link_Id; Cell_X, Cell_Y, Cell_Width : Natural)
      is
         Previous_Right : Natural;
      begin
         if Id = No_Link or else not Visible_Row then
            return;
         end if;
         if Result.Hit_Count > 0 then
            declare
               Previous : Hit_Entry renames
                 Result.Hits (Result.Hit_Count);
            begin
               Previous_Right :=
                 Natural (Previous.Region.X) + Previous.Region.Width;
               if Previous.Id = Id
                 and then Previous.Region.Y = Integer (Cell_Y)
                 and then Previous_Right = Cell_X
               then
                  Previous.Region.Width :=
                    Previous.Region.Width + Cell_Width;
                  return;
               end if;
            end;
         end if;
         if Result.Hit_Count = Result.Hit_Capacity then
            raise Program_Error with "visible link hit capacity exhausted";
         end if;
         Result.Hit_Count := Result.Hit_Count + 1;
         Result.Hits (Result.Hit_Count) :=
           (Id => Id,
            Region =>
              (X => Integer (Cell_X), Y => Integer (Cell_Y),
               Width => Cell_Width, Height => 1));
      end Note_Hit;

      procedure Emit
        (Glyph : Wide_Wide_String;
         Style : Flyology_TUI.Styles.Style;
         Id    : Link_Id := No_Link)
      is
         Cell_Width : constant Natural :=
           Natural'Max (1, Flyology_TUI.Glyphs.Width_Of (Glyph));
         Applied : Flyology_TUI.Styles.Style := Style;
         Fits : Boolean;
      begin
         if X >= Item.Columns
           or else Cell_Width > Item.Columns - X
         then
            if X > Indent then
               Visual_Row := Saturating_Add (Visual_Row, 1);
               X := Indent;
            end if;
         end if;
         Fits := X < Item.Columns
           and then Cell_Width <= Item.Columns - X;
         if not Fits and then X > Indent then
            Visual_Row := Saturating_Add (Visual_Row, 1);
            X := Indent;
            Fits := X < Item.Columns
              and then Cell_Width <= Item.Columns - X;
         end if;
         if Id /= No_Link
           and then Id = Item.Focus_Link
           and then Item.Has_Focus
         then
            Applied := Look.Focused_Link;
         elsif Item.Has_Selection then
            Applied := Look.Selection;
         end if;
         if Visible_Row and then Fits then
            Result.Rendered.Put
              (X, Visual_Row - Item.Top_Row, Glyph, Applied);
            Note_Hit (Id, X, Visual_Row - Item.Top_Row,
                      Cell_Width);
         end if;
         X := Saturating_Add (X, Cell_Width);
      end Emit;

      procedure Emit_Range
        (First, Last : Natural;
         Style       : Flyology_TUI.Styles.Style;
         Id          : Link_Id := No_Link)
      is
         Cursor : Natural := First;
         Cluster_Last : Natural;
      begin
         while Cursor < Last loop
            Cluster_Last := Flyology_TUI.Glyphs.Cluster_Last
              (Value, Value'First + Cursor) - Value'First;
            Emit
              (Value
                 (Value'First + Cursor ..
                  Value'First + Natural'Min (Cluster_Last, Last - 1)),
               Style, Id);
            Cursor := Natural'Min (Cluster_Last + 1, Last);
         end loop;
      end Emit_Range;

      procedure Emit_Literal
        (Content : Wide_Wide_String;
         Style   : Flyology_TUI.Styles.Style)
      is
         Cursor : Natural := Content'First;
         Last   : Natural;
      begin
         while Cursor <= Content'Last loop
            Last := Flyology_TUI.Glyphs.Cluster_Last (Content, Cursor);
            Emit (Content (Cursor .. Last), Style);
            Cursor := Last + 1;
         end loop;
      end Emit_Literal;

      function Find_Delimiter
        (From, Before : Natural; Delimiter : Wide_Wide_String) return Natural
      is
      begin
         if Delimiter'Length = 0
           or else Before <= From
           or else Delimiter'Length > Before - From
         then
            return Natural'Last;
         end if;
         for Candidate in From .. Before - Delimiter'Length loop
            if Starts_With (Value, Candidate, Delimiter) then
               return Candidate;
            end if;
         end loop;
         return Natural'Last;
      end Find_Delimiter;

      procedure Emit_Inline
        (First, Last : Natural;
         Base : Flyology_TUI.Styles.Style)
      is
         Cursor : Natural := First;
         Close : Natural;
         Target_Close : Natural;
         Id : Link_Id;
      begin
         while Cursor < Last loop
            if Starts_With (Value, Cursor, "**") then
               Close := Find_Delimiter (Cursor + 2, Last, "**");
               if Close /= Natural'Last then
                  Emit_Range (Cursor + 2, Close, Look.Strong);
                  Cursor := Close + 2;
               else
                  Emit_Range (Cursor, Cursor + 1, Base);
                  Cursor := Cursor + 1;
               end if;
            elsif Value (Value'First + Cursor) = '*'
              or else Value (Value'First + Cursor) = '_'
            then
               Close := Find_Char
                 (Value, Value (Value'First + Cursor), Cursor + 1, Last);
               if Close /= Natural'Last then
                  Emit_Range (Cursor + 1, Close, Look.Emphasis);
                  Cursor := Close + 1;
               else
                  Emit_Range (Cursor, Cursor + 1, Base);
                  Cursor := Cursor + 1;
               end if;
            elsif Value (Value'First + Cursor) = '`' then
               Close := Find_Char (Value, '`', Cursor + 1, Last);
               if Close /= Natural'Last then
                  Emit_Range (Cursor + 1, Close, Look.Inline_Code);
                  Cursor := Close + 1;
               else
                  Emit_Range (Cursor, Cursor + 1, Base);
                  Cursor := Cursor + 1;
               end if;
            elsif Value (Value'First + Cursor) = '[' then
               Close := Find_Char (Value, ']', Cursor + 1, Last);
               if Close /= Natural'Last and then Close + 1 < Last
                 and then Value (Value'First + Close + 1) = '('
               then
                  Target_Close := Find_Char (Value, ')', Close + 2, Last);
                  Id := Link_At (Cursor);
                  if Target_Close /= Natural'Last and then Id /= No_Link then
                     Emit_Range (Cursor + 1, Close, Look.Link, Id);
                     Cursor := Target_Close + 1;
                  else
                     Emit_Range (Cursor, Cursor + 1, Base);
                     Cursor := Cursor + 1;
                  end if;
               else
                  Emit_Range (Cursor, Cursor + 1, Base);
                  Cursor := Cursor + 1;
               end if;
            else
               declare
                  Cluster_Last : constant Natural :=
                    Flyology_TUI.Glyphs.Cluster_Last
                      (Value, Value'First + Cursor) - Value'First;
               begin
                  Emit_Range
                    (Cursor, Natural'Min (Cluster_Last + 1, Last), Base);
                  Cursor := Natural'Min (Cluster_Last + 1, Last);
               end;
            end if;
         end loop;
      end Emit_Inline;

      procedure Begin_Line (Prefix_Width : Natural := 0) is
      begin
         X := 0;
         Indent := Natural'Min (Prefix_Width, Item.Columns - 1);
      end Begin_Line;

      procedure End_Line is
      begin
         Visual_Row := Saturating_Add (Visual_Row, 1);
         X := 0;
         Indent := 0;
      end End_Line;
   begin
      Result.Rendered_Lines := Natural'Min (Item.Line_Count, Line_Budget);
      Result.Complete := Result.Rendered_Lines = Item.Line_Count;
      if Result.Rendered_Lines > 0 then
         for Position in 1 .. Result.Rendered_Lines loop
            declare
               Info : constant Line_Info := Item.Lines (Position);
               Base : Flyology_TUI.Styles.Style := Look.Text;
            begin
               Begin_Line;
               case Info.Kind is
                  when Blank_Line | Fence_Delimiter =>
                     null;
                  when Heading =>
                     Base := Look.Heading (Info.Level);
                     Emit_Inline (Info.Content_First, Info.Last, Base);
                  when Quote =>
                     Emit
                       ((1 => Wide_Wide_Character'Val (16#2502#)), Look.Quote);
                     Emit (" ", Look.Quote);
                     Indent := Natural'Min (2, Item.Columns - 1);
                     Emit_Inline (Info.Content_First, Info.Last, Look.Quote);
                  when Unordered_Item =>
                     Emit
                       ((1 => Wide_Wide_Character'Val (16#2022#)),
                        Look.List_Marker);
                     Emit (" ", Look.List_Marker);
                     Indent := Natural'Min (2, Item.Columns - 1);
                     Emit_Inline (Info.Content_First, Info.Last, Base);
                  when Ordered_Item =>
                     Emit_Range
                       (Info.First, Info.Content_First, Look.List_Marker);
                     Indent := Natural'Min
                       (Info.Content_First - Info.First, Item.Columns - 1);
                     Emit_Inline (Info.Content_First, Info.Last, Base);
                  when Task_Item =>
                     if Info.Checked then
                        Emit_Literal ("[x] ", Look.Task_Checked);
                     else
                        Emit_Literal ("[ ] ", Look.Task_Unchecked);
                     end if;
                     Indent := Natural'Min (4, Item.Columns - 1);
                     Emit_Inline (Info.Content_First, Info.Last, Base);
                  when Code_Block =>
                     Emit_Range
                       (Info.Content_First, Info.Last, Look.Code_Block);
                  when Thematic_Break =>
                     for Column in 1 .. Item.Columns loop
                        Emit
                          ((1 => Wide_Wide_Character'Val (16#2500#)),
                           Look.Thematic_Break);
                     end loop;
                  when Paragraph =>
                     Emit_Inline (Info.Content_First, Info.Last, Base);
               end case;
               End_Line;
            end;
         end loop;
      end if;
      Result.Document_Rows := Visual_Row;
      return Result;
   end Present;

   function Present
     (Item        : Model;
      Theme       : Flyology_TUI.Themes.Theme;
      Line_Budget : Natural := Natural'Last) return Presentation is
     (Present (Item, From_Theme (Theme), Line_Budget));

   function Base_Result return Action_Result is
     ((Update => Flyology_TUI.Components.Interactions.Ignored,
       others => <>));

   function Handle
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Terminal_Event) return Action_Result
   is
      Result : Action_Result := Base_Result;
      Changed : Boolean := False;
      Before : constant Link_Id := Item.Focus_Link;
      Select_Result : Flyology_TUI.Components.Interactions.Update_Result;
   begin
      if Event.Kind = Flyology_TUI.Events.Resize then
         if Event.Width > 0 and then Event.Height > 0 then
            Set_Size (Item, Event.Width, Event.Height);
            Result.Update := (Handled => True, Changed => True, others => <>);
         end if;
         return Result;
      elsif Event.Kind /= Flyology_TUI.Events.Key_Press then
         return Result;
      end if;

      case Event.Key.Kind is
         when Flyology_TUI.Events.Arrow_Up_Key =>
            Scroll_Rows (Item, -1, Changed);
         when Flyology_TUI.Events.Arrow_Down_Key =>
            Scroll_Rows (Item, 1, Changed);
         when Flyology_TUI.Events.Page_Up_Key =>
            Scroll_Rows (Item, -Integer (Item.Rows), Changed);
         when Flyology_TUI.Events.Page_Down_Key =>
            Scroll_Rows (Item, Integer (Item.Rows), Changed);
         when Flyology_TUI.Events.Home_Key =>
            Changed := Item.Top_Row /= 0;
            Item.Top_Row := 0;
         when Flyology_TUI.Events.End_Key =>
            Changed := Item.Top_Row /= Scroll_Bound (Item);
            Item.Top_Row := Scroll_Bound (Item);
         when Flyology_TUI.Events.Tab_Key |
              Flyology_TUI.Events.Arrow_Left_Key |
              Flyology_TUI.Events.Arrow_Right_Key =>
            if Item.Link_Length > 0 then
               if Item.Focus_Link = No_Link then
                  Item.Focus_Link := 1;
               elsif Event.Key.Kind = Flyology_TUI.Events.Arrow_Left_Key
                 or else Event.Key.Modified.Shift
               then
                  Item.Focus_Link :=
                    (if Item.Focus_Link = 1
                     then Link_Id (Item.Link_Length)
                     else Item.Focus_Link - 1);
               else
                  Item.Focus_Link :=
                    (if Natural (Item.Focus_Link) = Item.Link_Length
                     then 1 else Item.Focus_Link + 1);
               end if;
               Changed := Item.Focus_Link /= Before;
            end if;
         when Flyology_TUI.Events.Enter_Key =>
            if Item.Focus_Link /= No_Link then
               Result.Action := Link_Activated;
               Result.Link := Item.Focus_Link;
               Result.Update :=
                 (Handled => True, Activated => True, others => <>);
               return Result;
            end if;
         when Flyology_TUI.Events.Text_Key =>
            if Event.Key.Modified.Control then
               Select_Result := Item.Source_Core.Handle (Event);
               Result.Update := Select_Result;
               return Result;
            end if;
         when others => null;
      end case;
      Result.Update :=
        (Handled => Changed, Changed => Changed, others => <>);
      return Result;
   end Handle;

   function Handle
     (Item   : in out Model;
      Event  : Flyology_TUI.Mouse.Local_Event;
      Layout : Presentation) return Action_Result
   is
      Result : Action_Result := Base_Result;
      Changed : Boolean := False;
      Point : constant Flyology_TUI.Geometry.Point :=
        (X => Event.X, Y => Event.Y);
   begin
      if Layout.Revision /= Item.Revision then
         return Result;
      end if;
      if Event.Action = Flyology_TUI.Events.Mouse_Wheel then
         Scroll_Rows (Item, Negated_Triple (Event.Wheel_Y), Changed);
         Result.Update :=
           (Handled => Changed, Changed => Changed, others => <>);
         return Result;
      elsif Event.Action /= Flyology_TUI.Events.Mouse_Click
        or else Event.Button /= Flyology_TUI.Events.Left_Button
      then
         return Result;
      end if;
      if Layout.Hit_Count > 0 then
         for Position in 1 .. Layout.Hit_Count loop
            if Flyology_TUI.Geometry.Contains
              (Layout.Hits (Position).Region, Point)
            then
               Changed := Item.Focus_Link /= Layout.Hits (Position).Id;
               Item.Focus_Link := Layout.Hits (Position).Id;
               Result.Action := Link_Activated;
               Result.Link := Item.Focus_Link;
               Result.Update :=
                 (Handled => True,
                  Focus_Requested => True,
                  Activated => True,
                  Changed => Changed,
                  others => <>);
               return Result;
            end if;
         end loop;
      end if;
      return Result;
   end Handle;

end Flyology_TUI.Components.Markdown_Viewers;
