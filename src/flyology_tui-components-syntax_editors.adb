with Flyology_TUI.Glyphs;

package body Flyology_TUI.Components.Syntax_Editors is
   use type Flyology_TUI.Components.Text_Areas.Wrap_Mode;

   function From_Theme
     (Theme : Flyology_TUI.Themes.Theme) return Appearance is
     (Editor => Flyology_TUI.Components.Text_Areas.From_Theme (Theme),
      Tokens => (others => Theme.Primary));

   function Create
     (Max_Code_Points        : Positive;
      Max_Lines              : Positive;
      Max_Undo_Entries       : Positive;
      Max_History_Codepoints : Positive;
      Width                  : Positive := 40;
      Height                 : Positive := 8;
      Placeholder            : Wide_Wide_String := "") return Model
   is
   begin
      return Result : Model
        (Max_Code_Points,
         Max_Lines,
         Max_Undo_Entries,
         Max_History_Codepoints)
      do
         Result.Editor.Set_Size (Width, Height);
         Result.Editor.Set_Placeholder (Placeholder);
      end return;
   end Create;

   procedure Invalidate_From (Item : in out Model; Line : Positive) is
   begin
      for Index in Line .. Item.Max_Lines loop
         Item.Cache (Index).Valid := False;
         Item.Cache (Index).Count := 0;
      end loop;
      Item.Dirty_From :=
        (if Item.Dirty_From = 0 then Line
         else Natural'Min (Item.Dirty_From, Line));
      Item.State := Highlight_Dirty;
   end Invalidate_From;

   function Changed_Line
     (Before, After : Wide_Wide_String) return Positive
   is
      Common : Natural := 0;
      Line   : Positive := 1;
      Limit  : constant Natural := Natural'Min (Before'Length, After'Length);
   begin
      while Common < Limit
        and then Before (Before'First + Common) = After (After'First + Common)
      loop
         if Before (Before'First + Common) = Wide_Wide_Character'Val (10) then
            Line := Line + 1;
         end if;
         Common := Common + 1;
      end loop;
      return Line;
   end Changed_Line;

   procedure Try_Set_Text
     (Item    : in out Model;
      Value   : Wide_Wide_String;
      Success : out Boolean)
   is
      Before : constant Wide_Wide_String := Item.Editor.Value;
   begin
      Item.Editor.Try_Set_Text (Value, Success);
      if Success and then Item.Editor.Value /= Before then
         Invalidate_From (Item, Changed_Line (Before, Item.Editor.Value));
      end if;
   end Try_Set_Text;

   function Value (Item : Model) return Wide_Wide_String is
     (Item.Editor.Value);

   function Cursor_Position
     (Item : Model) return Flyology_TUI.Components.Text_Areas.Position is
     (Item.Editor.Cursor_Position);

   function Position_At_Offset (Item : Model; Offset : Natural)
      return Flyology_TUI.Components.Text_Areas.Position is
     (Item.Editor.Position_At_Offset (Offset));

   function Cursor_Offset (Item : Model) return Natural is
     (Item.Editor.Cursor_Offset);

   procedure Set_Cursor_Offset (Item : in out Model; Offset : Natural) is
   begin
      Item.Editor.Set_Cursor_Offset (Offset);
   end Set_Cursor_Offset;

   procedure Set_Size (Item : in out Model; Width, Height : Positive) is
   begin
      Item.Editor.Set_Size (Width, Height);
   end Set_Size;

   function Width (Item : Model) return Positive is (Item.Editor.Width);
   function Height (Item : Model) return Positive is (Item.Editor.Height);

   procedure Set_Wrap
     (Item : in out Model;
      Mode : Flyology_TUI.Components.Text_Areas.Wrap_Mode) is
   begin
      Item.Editor.Set_Wrap (Mode);
   end Set_Wrap;

   procedure Set_Tab_Width (Item : in out Model; Width : Positive) is
   begin
      Item.Editor.Set_Tab_Width (Width);
   end Set_Tab_Width;

   procedure Focus (Item : in out Model) is
   begin
      Item.Editor.Focus;
   end Focus;

   procedure Blur (Item : in out Model) is
   begin
      Item.Editor.Blur;
   end Blur;

   function Focused (Item : Model) return Boolean is (Item.Editor.Focused);

   procedure Set_Enabled (Item : in out Model; Enabled : Boolean) is
   begin
      Item.Editor.Set_Enabled (Enabled);
   end Set_Enabled;

   function Is_Enabled (Item : Model) return Boolean is
     (Item.Editor.Is_Enabled);

   procedure Set_Read_Only (Item : in out Model; Read_Only : Boolean) is
   begin
      Item.Editor.Set_Read_Only (Read_Only);
   end Set_Read_Only;

   function Is_Read_Only (Item : Model) return Boolean is
     (Item.Editor.Is_Read_Only);

   function Has_Selection (Item : Model) return Boolean is
     (Item.Editor.Has_Selection);

   procedure Selection_Range
     (Item : Model; First, Last : out Natural) is
   begin
      Item.Editor.Selection_Range (First, Last);
   end Selection_Range;

   procedure Select_All (Item : in out Model) is
   begin
      Item.Editor.Select_All;
   end Select_All;

   procedure Clear_Selection (Item : in out Model) is
   begin
      Item.Editor.Clear_Selection;
   end Clear_Selection;

   procedure Set_Viewport
     (Item : in out Model; First_Line : Positive; First_Cell : Natural := 0)
   is
   begin
      Item.Editor.Set_Viewport (First_Line, First_Cell);
   end Set_Viewport;

   function Viewport_Line (Item : Model) return Positive is
     (Item.Editor.Viewport_Line);

   function Viewport_Cell (Item : Model) return Natural is
     (Item.Editor.Viewport_Cell);

   function Gutter_Columns (Item : Model) return Positive is
     (Item.Editor.Gutter_Columns);

   procedure Visible_Segment
     (Item          : Model;
      Row           : Natural;
      Line          : out Positive;
      Segment_First : out Natural;
      Segment_Last  : out Natural;
      Exists        : out Boolean) is
   begin
      Item.Editor.Visible_Segment
        (Row, Line, Segment_First, Segment_Last, Exists);
   end Visible_Segment;

   function Can_Undo (Item : Model) return Boolean is
     (Item.Editor.Can_Undo);

   function Can_Redo (Item : Model) return Boolean is
     (Item.Editor.Can_Redo);

   procedure Undo (Item : in out Model) is
      Before : constant Wide_Wide_String := Item.Editor.Value;
   begin
      Item.Editor.Undo;
      if Item.Editor.Value /= Before then
         Invalidate_From (Item, Changed_Line (Before, Item.Editor.Value));
      end if;
   end Undo;

   procedure Redo (Item : in out Model) is
      Before : constant Wide_Wide_String := Item.Editor.Value;
   begin
      Item.Editor.Redo;
      if Item.Editor.Value /= Before then
         Invalidate_From (Item, Changed_Line (Before, Item.Editor.Value));
      end if;
   end Redo;

   function Handle
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Terminal_Event)
      return Flyology_TUI.Components.Interactions.Update_Result
   is
      Before : constant Wide_Wide_String := Item.Editor.Value;
      Result : constant Flyology_TUI.Components.Interactions.Update_Result :=
        Item.Editor.Handle (Event);
   begin
      if Item.Editor.Value /= Before then
         Invalidate_From (Item, Changed_Line (Before, Item.Editor.Value));
      end if;
      return Result;
   end Handle;

   function Handle
     (Item  : in out Model;
      Event : Flyology_TUI.Mouse.Local_Event)
      return Flyology_TUI.Components.Interactions.Update_Result is
     (Item.Editor.Handle (Event));

   procedure Update
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Terminal_Event)
   is
      Discard : constant Flyology_TUI.Components.Interactions.Update_Result :=
        Handle (Item, Event);
      pragma Unreferenced (Discard);
   begin
      null;
   end Update;

   procedure Update
     (Item  : in out Model;
      Event : Flyology_TUI.Mouse.Local_Event)
   is
      Discard : constant Flyology_TUI.Components.Interactions.Update_Result :=
        Handle (Item, Event);
      pragma Unreferenced (Discard);
   begin
      null;
   end Update;

   function Cluster_Boundary
     (Line : Wide_Wide_String; Offset : Natural) return Boolean
   is
      Position : Natural := 0;
   begin
      if Offset = 0 or else Offset = Line'Length then
         return True;
      end if;
      while Position < Line'Length loop
         if Position = Offset then
            return True;
         end if;
         Position :=
           Flyology_TUI.Glyphs.Cluster_Last
             (Line, Line'First + Position) - Line'First + 1;
      end loop;
      return False;
   end Cluster_Boundary;

   procedure Advance_Highlighting
     (Item : in out Model; Line_Budget : Natural)
   is
      Remaining : Natural := Line_Budget;
   begin
      while Remaining > 0 and then Item.Dirty_From /= 0 loop
         declare
            Line_Number : constant Positive := Positive (Item.Dirty_From);
            Start : constant Natural :=
              Item.Editor.Line_Start_Offset (Line_Number);
            Stop : constant Natural :=
              Item.Editor.Line_End_Offset (Line_Number);
            Source : constant Wide_Wide_String := Item.Editor.Value;
            Line : constant Wide_Wide_String :=
              (if Start = Stop then ""
               else Source (Source'First + Start .. Source'First + Stop - 1));
            Candidate : Line_Cache;
            Initial : constant Lexer_State :=
              (if Line_Number = 1 then Initial_State
               else Item.Cache (Line_Number - 1).Final);
            Token_State : Lexer_State := Initial;
            Scan_From : Natural := 0;
            Kind : Token_Kind;
            First, Last : Natural;
            Final : Lexer_State := Initial;
            Has_Token : Boolean;
            Failed : Boolean := False;
            Capacity_Limited : Boolean := False;
         begin
            if Line_Number > 1
              and then not Item.Cache (Line_Number - 1).Valid
            then
               return;
            end if;
            begin
               loop
                  Next_Token
                    (Line,
                     Token_State,
                     Scan_From,
                     Kind,
                     First,
                     Last,
                     Final,
                     Has_Token);
                  exit when not Has_Token;
                  if First < Scan_From or else First >= Last
                    or else Last > Line'Length
                    or else not Cluster_Boundary (Line, First)
                    or else not Cluster_Boundary (Line, Last)
                  then
                     raise Flyology_TUI.Components.Structure_Error;
                  elsif Candidate.Count = Maximum_Tokens_Per_Line then
                     Capacity_Limited := True;
                     exit;
                  end if;
                  Candidate.Count := Candidate.Count + 1;
                  Candidate.Spans (Candidate.Count) :=
                    (Kind => Kind, First => First, Last => Last);
                  Scan_From := Last;
                  Token_State := Final;
               end loop;
            exception
               when Flyology_TUI.Components.Structure_Error =>
                  Item.State := Highlight_Structure_Invalid;
                  return;
               when others =>
                  Failed := True;
            end;
            if Failed then
               Item.State := Highlight_Lexer_Failed;
               return;
            elsif Capacity_Limited then
               Item.State := Highlight_Capacity_Limited;
               return;
            end if;
            Candidate.Final := Final;
            Candidate.Valid := True;
            Item.Cache (Line_Number) := Candidate;
            Remaining := Remaining - 1;
            if Line_Number = Item.Editor.Line_Count then
               Item.Dirty_From := 0;
               Item.State := Highlight_Current;
            else
               Item.Dirty_From := Line_Number + 1;
               Item.State := Highlight_Dirty;
            end if;
         end;
      end loop;
   end Advance_Highlighting;

   function Highlighting (Item : Model) return Highlight_State is
     (Item.State);

   function First_Dirty_Line (Item : Model) return Natural is
     (Item.Dirty_From);

   function Render
     (Item : Model; Look : Appearance)
      return Flyology_TUI.Surfaces.Surface
   is
      Result : Flyology_TUI.Surfaces.Surface :=
        Item.Editor.Render (Look.Editor);
      Source : constant Wide_Wide_String := Item.Editor.Value;
      First_Selected, Last_Selected : Natural;
      Gutter : constant Positive := Item.Editor.Gutter_Columns;
   begin
      Item.Editor.Selection_Range (First_Selected, Last_Selected);
      for Row in 0 .. Item.Editor.Height - 1 loop
         declare
            Line_Number : Positive;
            Segment_First, Segment_Last : Natural;
            Exists : Boolean;
         begin
            Item.Editor.Visible_Segment
              (Row,
               Line_Number,
               Segment_First,
               Segment_Last,
               Exists);
            exit when not Exists;
            if Item.Editor.Is_Enabled
              and then Item.Cache (Line_Number).Valid
            then
               for Span_Index in 1 .. Item.Cache (Line_Number).Count loop
                  declare
                     Span : constant Token_Span :=
                       Item.Cache (Line_Number).Spans (Span_Index);
                     Line_Start : constant Natural :=
                       Item.Editor.Line_Start_Offset (Line_Number);
                     Absolute : Natural := Line_Start + Span.First;
                     Stop : constant Natural := Line_Start + Span.Last;
                  begin
                     while Absolute < Stop loop
                        declare
                           Last : constant Natural :=
                             Flyology_TUI.Glyphs.Cluster_Last
                               (Source, Source'First + Absolute)
                             - Source'First;
                           Position : constant
                             Flyology_TUI.Components.Text_Areas.Position :=
                               Item.Editor.Position_At_Offset (Absolute);
                           Segment_Position : constant
                             Flyology_TUI.Components.Text_Areas.Position :=
                               Item.Editor.Position_At_Offset
                                 (Segment_First);
                           Origin : constant Natural :=
                             (if Item.Editor.Wrapping =
                                Flyology_TUI.Components.Text_Areas.Soft_Wrap
                              then Segment_Position.Cell_Column
                              else Item.Editor.Viewport_Cell);
                           Is_Visible : constant Boolean :=
                             Position.Cell_Column >= Origin;
                           Relative_Cell : constant Natural :=
                             (if Is_Visible
                              then Position.Cell_Column - Origin else 0);
                           X : constant Natural :=
                             (if Relative_Cell <= Natural'Last - Gutter
                              then Gutter + Relative_Cell else Natural'Last);
                        begin
                           if not
                             (Absolute < Last_Selected
                              and then Last + 1 > First_Selected)
                             and then not
                               (Item.Editor.Focused
                                and then Absolute =
                                  Item.Editor.Cursor_Offset)
                             and then Absolute >= Segment_First
                             and then Last < Segment_Last
                             and then Is_Visible
                             and then X >= Gutter
                             and then X < Item.Editor.Width
                             and then Source (Source'First + Absolute) /=
                               Wide_Wide_Character'Val (9)
                           then
                              declare
                                 Glyph : constant Wide_Wide_String :=
                                   Source
                                     (Source'First + Absolute ..
                                      Source'First + Last);
                              begin
                                 if Flyology_TUI.Glyphs.Width_Of (Glyph)
                                   <= Item.Editor.Width - X
                                 then
                                    Result.Put
                                      (X,
                                       Row,
                                       Glyph,
                                       Look.Tokens (Span.Kind));
                                 end if;
                              end;
                           end if;
                           Absolute := Last + 1;
                        end;
                     end loop;
                  end;
               end loop;
            end if;
         end;
      end loop;
      return Result;
   end Render;

   function Render
     (Item : Model; Theme : Flyology_TUI.Themes.Theme)
      return Flyology_TUI.Surfaces.Surface is
     (Render (Item, From_Theme (Theme)));

end Flyology_TUI.Components.Syntax_Editors;
