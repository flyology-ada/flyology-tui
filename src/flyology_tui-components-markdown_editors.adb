package body Flyology_TUI.Components.Markdown_Editors is

   function From_Theme
     (Theme : Flyology_TUI.Themes.Theme) return Appearance is
     (Source  => Flyology_TUI.Components.Text_Areas.From_Theme (Theme),
      Preview => Flyology_TUI.Components.Markdown_Viewers.From_Theme (Theme));

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
      Result : constant Flyology_TUI.Components.Interactions.Update_Result :=
        Item.Source_Core.Handle (Event);
   begin
      if Result.Changed then
         Synchronize_Preview (Item);
      end if;
      return Result;
   end Handle_Source;

   function Handle_Source
     (Item  : in out Model;
      Event : Flyology_TUI.Mouse.Local_Event)
      return Flyology_TUI.Components.Interactions.Update_Result
   is
      Result : constant Flyology_TUI.Components.Interactions.Update_Result :=
        Item.Source_Core.Handle (Event);
   begin
      if Result.Changed then
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

   function Render_Source
     (Item : Model; Look : Appearance)
      return Flyology_TUI.Surfaces.Surface is
     (Item.Source_Core.Render (Look.Source));

   function Present_Preview
     (Item        : Model;
      Look        : Appearance;
      Line_Budget : Natural := Natural'Last)
      return Flyology_TUI.Components.Markdown_Viewers.Presentation is
     (Item.Preview_Core.Present (Look.Preview, Line_Budget));

   function Render_Source
     (Item : Model; Theme : Flyology_TUI.Themes.Theme)
      return Flyology_TUI.Surfaces.Surface is
     (Render_Source (Item, From_Theme (Theme)));

   function Present_Preview
     (Item        : Model;
      Theme       : Flyology_TUI.Themes.Theme;
      Line_Budget : Natural := Natural'Last)
      return Flyology_TUI.Components.Markdown_Viewers.Presentation is
     (Present_Preview (Item, From_Theme (Theme), Line_Budget));

end Flyology_TUI.Components.Markdown_Editors;
