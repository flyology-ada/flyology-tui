with Ada.Strings.Wide_Wide_Unbounded;
with Ada.Text_IO;
with Flyology_TUI.Colors;
with Flyology_TUI.Components;
with Flyology_TUI.Components.Interactions;
with Flyology_TUI.Components.Markdown_Editors;
with Flyology_TUI.Components.Markdown_Viewers;
with Flyology_TUI.Events;
with Flyology_TUI.Geometry;
with Flyology_TUI.Mouse;
with Flyology_TUI.Styles;
with Flyology_TUI.Surfaces;
with Flyology_TUI.Themes;

procedure Markdown_Components_Tests is
   package Text renames Ada.Strings.Wide_Wide_Unbounded;
   package Viewers renames Flyology_TUI.Components.Markdown_Viewers;
   package Editors renames Flyology_TUI.Components.Markdown_Editors;

   use type Flyology_TUI.Components.Markdown_Viewers.Action_Kind;
   use type Flyology_TUI.Components.Markdown_Viewers.Link_Id;
   use type Flyology_TUI.Components.Markdown_Viewers.Parsing_State;
   use type Flyology_TUI.Colors.Color;
   use type Text.Unbounded_Wide_Wide_String;
   use type Flyology_TUI.Styles.Style;

   LF : constant Wide_Wide_String :=
     (1 => Wide_Wide_Character'Val (10));

   procedure Assert (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         raise Program_Error with Message;
      end if;
   end Assert;

   function Key
     (Kind : Flyology_TUI.Events.Key_Kind;
      Shift : Boolean := False;
      Control : Boolean := False) return Flyology_TUI.Events.Terminal_Event
   is
      Value : Flyology_TUI.Events.Key_Event (Kind);
   begin
      Value.Modified :=
        (Shift => Shift, Control => Control, Alt | Super => False);
      return Flyology_TUI.Events.Pressed (Value);
   end Key;

   function Character_Key
     (Value : Wide_Wide_String;
      Control : Boolean := False) return Flyology_TUI.Events.Terminal_Event is
     (Flyology_TUI.Events.Pressed
        ((Kind => Flyology_TUI.Events.Text_Key,
          Modified =>
            (Shift => False, Control => Control, Alt | Super => False),
          Repeated => False,
          Value => Text.To_Unbounded_Wide_Wide_String (Value))));

   function Mouse
     (X, Y : Integer;
      Action : Flyology_TUI.Events.Mouse_Action;
      Wheel_Y : Integer := 0) return Flyology_TUI.Mouse.Local_Event is
     (X => X,
      Y => Y,
      Button => Flyology_TUI.Events.Left_Button,
      Action => Action,
      Modified => (others => False),
      Wheel_X => 0,
      Wheel_Y => Wheel_Y);

   procedure Test_Parsing_And_Rendering is
      Item : Viewers.Model := Viewers.Create (600, 40, 8, 24, 12);
      Success : Boolean;
      Result : Viewers.Action_Result;
      Look : Viewers.Appearance := Viewers.From_Theme
        (Flyology_TUI.Themes.Charm);
      Heading_Style : constant Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.With_Foreground
          (Flyology_TUI.Styles.Default,
           Flyology_TUI.Colors.Basic (Flyology_TUI.Colors.Bright_Green));
      Document : constant Wide_Wide_String :=
        "# Heading" & LF &
        "Paragraph with **strong**, *emphasis*, `code`, and [Ada](ada.dev)." &
        LF & "> quote" & LF & "- bullet" & LF & "1. ordered" & LF &
        "- [x] finished" & LF & "---" & LF & "```ada" & LF &
        "Put_Line (Message);" & LF & "```";
   begin
      Item.Try_Set_Source (Document, Success);
      Assert (Success, "valid bounded Markdown source was rejected");
      Item.Advance_Parsing (2);
      Assert
        (Item.Parsing = Viewers.Parsing_Dirty
         and then Item.Parsed_Line_Count = 2,
         "line budget did not stop incremental parsing");
      Item.Advance_Parsing (Natural'Last);
      Assert
        (Item.Parsing = Viewers.Parsing_Current
         and then Item.Parsed_Line_Count = 10,
         "supported Markdown subset did not parse to completion");
      Assert
        (Item.Link_Count = 1 and then Item.Link_Target (1) = "ada.dev",
         "typed link table did not preserve its target");

      Look.Heading (1) := Heading_Style;
      declare
         Budgeted : constant Viewers.Presentation :=
           Item.Present (Look, Line_Budget => 1);
      begin
         Assert
           (Viewers.Rendered_Line_Count (Budgeted) = 1
            and then not Viewers.Rendering_Complete (Budgeted),
            "render line budget did not bound presentation work");
      end;
      declare
         Layout : constant Viewers.Presentation := Item.Present (Look);
         Region : Flyology_TUI.Geometry.Rectangle;
      begin
         Assert
           (Viewers.Frame (Layout).Element (0, 0).Appearance = Heading_Style,
            "external heading appearance was not applied");
         Assert
           (Viewers.Has_Link (Layout, 1),
            "visible link has no hit region");
         Region := Viewers.Link_Region (Layout, 1, 1);
         Result := Item.Handle
           (Mouse (Region.X, Region.Y, Flyology_TUI.Events.Mouse_Click),
            Layout);
         Assert
           (Result.Action = Viewers.Link_Activated
            and then Result.Link = 1
            and then Result.Update.Activated,
            "mouse did not return a typed link activation");
      end;

      Item.Focus;
      Result := Item.Handle (Key (Flyology_TUI.Events.Tab_Key));
      Result := Item.Handle (Key (Flyology_TUI.Events.Enter_Key));
      Assert
        (Result.Action = Viewers.Link_Activated and then Result.Link = 1,
         "keyboard link focus did not activate the stable id");
   end Test_Parsing_And_Rendering;

   procedure Test_Unsupported_And_Malformed is
      Item : Viewers.Model := Viewers.Create (300, 20, 3, 30, 6);
      Success : Boolean;
      Flags : Viewers.Unsupported_Set;
   begin
      Item.Try_Set_Source
        ("![image](x)" & LF & "| a | b |" & LF & "<tag>" & LF &
         "[^note]" & LF & "term:: value" & LF & "    > nested",
         Success);
      Item.Advance_Parsing (20);
      Flags := Item.Unsupported;
      Assert
        (Item.Has_Unsupported
         and then Flags (Viewers.Images)
         and then Flags (Viewers.Tables)
         and then Flags (Viewers.Raw_HTML)
         and then Flags (Viewers.Footnotes)
         and then Flags (Viewers.Definition_Lists)
         and then Flags (Viewers.Nested_Block_Containers),
         "unsupported constructs were not reported explicitly");

      Item.Try_Set_Source ("```ada" & LF & "unterminated", Success);
      Item.Advance_Parsing (20);
      Assert
        (Item.Parsing = Viewers.Parsing_Malformed,
         "unterminated fenced block was not reported as malformed");

      declare
         Bounded : Viewers.Model := Viewers.Create (100, 8, 1, 20, 4);
         Result : Viewers.Action_Result;
      begin
         Bounded.Try_Set_Source
           ("[one](1) and [two](2)", Success);
         Bounded.Advance_Parsing (8);
         Assert
           (Bounded.Parsing = Viewers.Parsing_Capacity_Limited
            and then Bounded.Link_Count = 0
            and then Bounded.Parsed_Line_Count = 0,
            "capacity failure published a partial line or link");
         Bounded.Focus;
         Result := Bounded.Handle (Key (Flyology_TUI.Events.Tab_Key));
         Result := Bounded.Handle (Key (Flyology_TUI.Events.Enter_Key));
         Assert
           (Result.Action = Viewers.No_Action,
            "capacity-rejected link remained keyboard activatable");
      end;

      declare
         Atomic : Viewers.Model := Viewers.Create (120, 8, 3, 20, 4);
      begin
         Atomic.Try_Set_Source
           ("[kept](one)" & LF & "[partial](two) [broken](missing",
            Success);
         Atomic.Advance_Parsing (8);
         Assert
           (Atomic.Parsing = Viewers.Parsing_Malformed
            and then Atomic.Link_Count = 1
            and then Atomic.Parsed_Line_Count = 1
            and then Atomic.Link_Target (1) = "one",
            "malformed line published staged link or line state");
      end;
   end Test_Unsupported_And_Malformed;

   procedure Test_Exact_Link_Hits_And_Code_Literals is
      Item : Viewers.Model := Viewers.Create (240, 12, 4, 6, 6);
      Success : Boolean;
      Result : Viewers.Action_Result;
   begin
      Item.Try_Set_Source ("[abcdefgh](target)", Success);
      Item.Advance_Parsing (4);
      declare
         Layout : constant Viewers.Presentation :=
           Item.Present (Flyology_TUI.Themes.Charm);
         First : constant Flyology_TUI.Geometry.Rectangle :=
           Viewers.Link_Region (Layout, 1, 1);
         Second : constant Flyology_TUI.Geometry.Rectangle :=
           Viewers.Link_Region (Layout, 1, 2);
      begin
         Assert
           (Viewers.Link_Region_Count (Layout, 1) = 2
            and then First.Height = 1
            and then Second.Height = 1
            and then First.Y /= Second.Y,
            "wrapped link did not expose exact per-row segments");
         Result := Item.Handle
           (Mouse (Second.X + 1, Second.Y,
                   Flyology_TUI.Events.Mouse_Click),
            Layout);
         Assert
           (Result.Action = Viewers.Link_Activated,
            "wrapped link segment was not clickable");
         Result := Item.Handle
           (Mouse (4, Second.Y, Flyology_TUI.Events.Mouse_Click), Layout);
         Assert
           (Result.Action = Viewers.No_Action,
            "empty cell inside the former bounding box activated a link");
      end;

      Item.Try_Set_Source
        ("```" & LF &
         "![image](x) | a | <tag> [^note] :: [link](target)" & LF &
         "```" & LF &
         "`![image](x) | a | <tag> [^note] :: [link](target)`",
         Success);
      Item.Advance_Parsing (12);
      Assert
        (not Item.Has_Unsupported and then Item.Link_Count = 0,
         "literal fenced or inline code was classified as Markdown syntax");
   end Test_Exact_Link_Hits_And_Code_Literals;

   procedure Test_Task_Marker_Clipping is
      Item : Viewers.Model := Viewers.Create (80, 4, 2, 1, 6);
      Success : Boolean;
      Wide : constant Wide_Wide_String :=
        (1 => Wide_Wide_Character'Val (16#754C#));
   begin
      Item.Try_Set_Source ("- [x] " & Wide, Success);
      Item.Advance_Parsing (4);
      declare
         Layout : constant Viewers.Presentation :=
           Item.Present (Flyology_TUI.Themes.Charm);
         Surface : constant Flyology_TUI.Surfaces.Surface :=
           Viewers.Frame (Layout);
      begin
         Assert
           (Surface.Element (0, 0).Glyph =
              Text.To_Unbounded_Wide_Wide_String ("[")
            and then Surface.Element (0, 1).Glyph =
              Text.To_Unbounded_Wide_Wide_String ("x")
            and then Surface.Element (0, 2).Glyph =
              Text.To_Unbounded_Wide_Wide_String ("]")
            and then not Surface.Element (0, 3).Continuation,
            "task marker was not emitted cluster-by-cluster in tiny geometry");
      end;
   end Test_Task_Marker_Clipping;

   procedure Test_Bounds_Read_Only_And_Unicode is
      Item : Viewers.Model := Viewers.Create (16, 3, 2, 8, 3);
      Success : Boolean;
      Result : Viewers.Action_Result;
      First, Last : Natural;
      Lambda : constant Wide_Wide_String :=
        (1 => Wide_Wide_Character'Val (16#03BB#));
      CJK : constant Wide_Wide_String :=
        (1 => Wide_Wide_Character'Val (16#754C#));
      Unicode_Source : constant Wide_Wide_String :=
        "# " & Lambda & LF & CJK;
   begin
      Item.Try_Set_Source (Unicode_Source, Success);
      Assert
        (Success and then Item.Source = Unicode_Source,
         "Unicode code points did not survive the bounded source core");
      Item.Advance_Parsing (3);
      declare
         Layout : constant Viewers.Presentation :=
           Item.Present (Flyology_TUI.Themes.Charm);
      begin
         Assert
           (Viewers.Frame (Layout).Element (0, 0).Glyph =
              Text.To_Unbounded_Wide_Wide_String (Lambda),
            "Unicode heading glyph was not rendered intact");
      end;

      Item.Focus;
      Result := Item.Handle (Character_Key ("x"));
      Assert
        (not Result.Update.Changed and then Item.Source = Unicode_Source,
         "read-only viewer accepted text input");
      Result := Item.Handle (Character_Key ("a", Control => True));
      Assert
        (Item.Has_Selection,
         "read-only viewer did not support selection");
      Item.Selection_Range (First, Last);
      Assert
        (First = 0 and then Last = Unicode_Source'Length,
         "source selection range was not preserved");

      Item.Try_Set_Source ("01234567890123456", Success);
      Assert
        (not Success and then Item.Source = Unicode_Source,
         "source capacity failure was not atomic");
      Item.Try_Set_Source ("a" & LF & "b" & LF & "c" & LF & "d", Success);
      Assert (not Success, "line capacity was not enforced");

      declare
         Raised : Boolean := False;
      begin
         begin
            Item.Set_Size (Positive'Last, 2);
         exception
            when Flyology_TUI.Components.Capacity_Error => Raised := True;
         end;
         Assert (Raised, "geometry multiplication overflow was accepted");
      end;
   end Test_Bounds_Read_Only_And_Unicode;

   procedure Test_Resize_Scroll_And_Stale_Layout is
      Item : Viewers.Model := Viewers.Create (300, 20, 4, 8, 3);
      Success : Boolean;
      Result : Viewers.Action_Result;
   begin
      Item.Try_Set_Source
        ("[old](old-target) with a line long enough to wrap repeatedly" & LF &
         "second line" & LF & "third line", Success);
      Item.Advance_Parsing (20);
      declare
         Old_Layout : constant Viewers.Presentation :=
           Item.Present (Flyology_TUI.Themes.Charm);
         Old_Region : constant Flyology_TUI.Geometry.Rectangle :=
           Viewers.Link_Region (Old_Layout, 1, 1);
      begin
         Result := Item.Handle (Key (Flyology_TUI.Events.Page_Down_Key));
         Assert
           (Result.Update.Changed and then Item.First_Visible_Row > 0,
            "keyboard scrolling did not move the viewport");
         Result := Item.Handle
           (Mouse (0, 0, Flyology_TUI.Events.Mouse_Wheel, Wheel_Y => 1),
            Old_Layout);
         Assert
           (Item.First_Visible_Row = 0,
            "mouse wheel did not scroll toward the document start");

         Item.Try_Set_Source ("[new](new-target)", Success);
         Item.Advance_Parsing (5);
         Result := Item.Handle
           (Mouse (Old_Region.X, Old_Region.Y,
                   Flyology_TUI.Events.Mouse_Click),
            Old_Layout);
         Assert
           (Result.Action = Viewers.No_Action,
            "stale presentation activated a link from a replaced source");
      end;

      Result := Item.Handle (Flyology_TUI.Events.Resized (20, 5));
      Assert
        (Result.Update.Handled
         and then Item.Width = 20
         and then Item.Height = 5,
         "terminal resize did not update responsive viewer geometry");
      Result := Item.Handle (Flyology_TUI.Events.Resized (0, 0));
      Assert
        (not Result.Update.Handled and then Item.Width = 20,
         "unknown zero resize corrupted viewer geometry");
   end Test_Resize_Scroll_And_Stale_Layout;

   procedure Test_Editor_Composition is
      Item : Editors.Model := Editors.Create
        (300, 20, 8, 600, 6, 80, 20, Editors.Split_Horizontally);
      Success : Boolean;
      Update : Flyology_TUI.Components.Interactions.Update_Result;
      Action : Viewers.Action_Result;
      Plan : Editors.Layout_Snapshot;
      Look : Editors.Appearance := Editors.From_Theme
        (Flyology_TUI.Themes.Charm);
      Custom : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
   begin
      Item.Try_Set_Source
        ("# Draft" & LF & "[a very long link label](target)", Success);
      Item.Focus_Source;
      Update := Item.Handle_Source (Character_Key ("!"));
      Assert
        (Update.Changed and then Item.Source = "# Draft" & LF &
           "[a very long link label](target)!",
         "Markdown editor did not delegate source edits to Text_Areas");
      Assert
        (Item.Preview_Parsing = Viewers.Parsing_Dirty,
         "source edit did not invalidate preview parsing");
      Item.Advance_Preview (20);
      Assert
        (Item.Preview_Parsing = Viewers.Parsing_Current,
         "editor preview did not advance within caller budget");

      Item.Set_Mode (Editors.Split_Horizontally);
      Item.Set_Size (20, 2);
      Item.Focus_Preview;
      Action := Item.Handle_Preview
        (Key (Flyology_TUI.Events.Page_Down_Key));
      Action := Item.Handle_Preview (Key (Flyology_TUI.Events.Tab_Key));
      declare
         Top_Before : constant Natural := Item.Preview_First_Visible_Row;
         Link_Before : constant Viewers.Link_Id :=
           Item.Preview_Focused_Link;
      begin
         Item.Focus_Source;
         Update := Item.Handle_Source
           (Mouse (0, 0, Flyology_TUI.Events.Mouse_Click));
         Update := Item.Handle_Source
           (Mouse (1, 1, Flyology_TUI.Events.Mouse_Drag));
         Assert
           (Item.Preview_Parsing = Viewers.Parsing_Current
            and then Item.Preview_First_Visible_Row = Top_Before
            and then Item.Preview_Focused_Link = Link_Before,
            "source selection reset unchanged preview state");
      end;

      Item.Set_Size (80, 20);
      Plan := Item.Layout;
      Assert
        (Editors.Has_Source (Plan) and then Editors.Has_Preview (Plan)
         and then Editors.Source_Region (Plan).Width
           + Editors.Preview_Region (Plan).Width + 1 = 80,
         "horizontal split did not partition the responsive width");
      Item.Set_Mode (Editors.Split_Vertically);
      Plan := Item.Layout;
      Assert
        (Editors.Source_Region (Plan).Height
           + Editors.Preview_Region (Plan).Height + 1 = 20,
         "vertical split did not partition the responsive height");
      Item.Set_Source_Percentage (70);
      Plan := Item.Layout;
      Assert
        (Editors.Source_Region (Plan).Height
           > Editors.Preview_Region (Plan).Height,
         "split percentage did not favor the source pane");
      Item.Set_Size (2, 2);
      Plan := Item.Layout;
      Assert
        (Editors.Has_Source (Plan) and then not Editors.Has_Preview (Plan),
         "tiny geometry did not degrade to one usable pane");

      Item.Set_Mode (Editors.Preview_Only);
      Item.Set_Size (30, 5);
      Item.Focus_Preview;
      Action := Item.Handle_Preview (Character_Key ("x"));
      Assert
         (not Action.Update.Changed
         and then Item.Source = "# Draft" & LF &
           "[a very long link label](target)!",
         "preview-only mode mutated source text");
      Action := Item.Handle_Preview (Key (Flyology_TUI.Events.Home_Key));

      Custom.Bold := True;
      Custom.Underline := True;
      Look.Preview.Heading (1) := Custom;
      declare
         Preview : constant Viewers.Presentation :=
           Item.Present_Preview (Look);
      begin
         Assert
           (Viewers.Frame (Preview).Element (0, 0).Appearance = Custom,
            "editor preview ignored external appearance");
      end;
   end Test_Editor_Composition;

   procedure Test_Source_Annotations is
      Item : Editors.Model := Editors.Create
        (500, 20, 8, 1_000, 8, 60, 12, Editors.Source_Only);
      Look : constant Editors.Appearance :=
        Editors.From_Theme (Flyology_TUI.Themes.Default);
      Annotations : Editors.Annotation_Appearance :=
        (others => Flyology_TUI.Styles.Default);
      Success : Boolean;

      function Cell_With
        (Surface    : Flyology_TUI.Surfaces.Surface;
         Row        : Natural;
         Glyph      : Wide_Wide_String;
         Occurrence : Positive := 1) return Flyology_TUI.Surfaces.Cell
      is
         Seen : Natural := 0;
      begin
         for X in 0 .. Surface.Width - 1 loop
            if Text.To_Wide_Wide_String (Surface.Element (X, Row).Glyph)
              = Glyph
            then
               Seen := Seen + 1;
               if Seen = Occurrence then
                  return Surface.Element (X, Row);
               end if;
            end if;
         end loop;
         raise Program_Error with "expected annotated glyph was not rendered";
      end Cell_With;

      function Has_Bold_Cell
        (Surface : Flyology_TUI.Surfaces.Surface;
         Row     : Natural) return Boolean
      is
      begin
         for X in 0 .. Surface.Width - 1 loop
            if Surface.Element (X, Row).Appearance.Bold then
               return True;
            end if;
         end loop;
         return False;
      end Has_Bold_Cell;
   begin
      Item.Try_Set_Source
        ("# Heading" & LF
         & "**bold** *italics* `code`" & LF
         & "- [x] task [link](target)" & LF
         & "> quoted" & LF
         & "---" & LF
         & "```ada" & LF
         & "body" & LF
         & "```",
         Success);
      Assert (Success, "Markdown annotation source was rejected");

      Annotations (Editors.Marker).Foreground :=
        Flyology_TUI.Colors.Basic (Flyology_TUI.Colors.Red);
      Annotations (Editors.Heading).Bold := True;
      Annotations (Editors.Strong).Bold := True;
      Annotations (Editors.Emphasis).Italic := True;
      Annotations (Editors.Code).Foreground :=
        Flyology_TUI.Colors.Basic (Flyology_TUI.Colors.Green);
      Annotations (Editors.Link).Underline := True;
      Annotations (Editors.Task_Marker).Strikethrough := True;
      Annotations (Editors.Quote).Faint := True;
      Annotations (Editors.Rule).Reverse_Video := True;

      declare
         Plain : constant Flyology_TUI.Surfaces.Surface :=
           Item.Render_Source (Look);
         Styled : constant Flyology_TUI.Surfaces.Surface :=
           Item.Render_Source (Look, Annotations);
         Themed : constant Flyology_TUI.Surfaces.Surface :=
           Item.Render_Source (Flyology_TUI.Themes.Charm);
      begin
         Assert
           (not Cell_With (Plain, 0, "H").Appearance.Bold,
            "plain explicit source rendering gained implicit annotations");
         Assert
           (Cell_With (Styled, 0, "#").Appearance.Foreground =
              Annotations (Editors.Marker).Foreground,
            "Markdown marker annotation was not rendered");
         Assert (Cell_With (Styled, 0, "H").Appearance.Bold,
                 "Markdown heading annotation was not rendered");
         Assert (Cell_With (Styled, 1, "b").Appearance.Bold,
                 "Markdown strong annotation was not rendered");
         Assert (Cell_With (Styled, 1, "i").Appearance.Italic,
                 "Markdown emphasis annotation was not rendered");
         Assert
           (Cell_With (Styled, 1, "c", 2).Appearance.Foreground =
              Annotations (Editors.Code).Foreground,
            "Markdown inline-code annotation was not rendered");
         Assert (Cell_With (Styled, 2, "x").Appearance.Strikethrough,
                 "Markdown task annotation was not rendered");
         Assert (Cell_With (Styled, 2, "l").Appearance.Underline,
                 "Markdown link annotation was not rendered");
         Assert (Cell_With (Styled, 3, "q").Appearance.Faint,
                 "Markdown quote annotation was not rendered");
         Assert (Cell_With (Styled, 4, "-").Appearance.Reverse_Video,
                 "Markdown rule annotation was not rendered");
         Assert
           (Cell_With (Styled, 6, "b").Appearance.Foreground =
              Annotations (Editors.Code).Foreground,
            "Markdown fenced-code annotation was not rendered");
         Assert
           (Cell_With (Themed, 0, "H").Appearance.Bold,
            "theme source rendering omitted semantic annotations");
      end;

      Item.Focus_Source;
      declare
         Press : constant Flyology_TUI.Components.Interactions.Update_Result :=
           Item.Handle_Source
             (Mouse (3, 0, Flyology_TUI.Events.Mouse_Click));
         Release : constant
           Flyology_TUI.Components.Interactions.Update_Result :=
             Item.Handle_Source
               (Mouse (3, 0, Flyology_TUI.Events.Mouse_Release));
         pragma Unreferenced (Press, Release);
      begin
         null;
      end;
      declare
         Focused : constant Flyology_TUI.Surfaces.Surface :=
           Item.Render_Source (Look, Annotations);
      begin
         Assert
           (Focused.Element (3, 0).Appearance = Look.Source.Cursor,
            "Markdown annotation overwrote the source cursor style");
      end;
      Item.Blur;
      Item.Set_Size (10, 12);
      declare
         Wrapped : constant Flyology_TUI.Surfaces.Surface :=
           Item.Render_Source (Look, Annotations);
      begin
         Assert
           (Has_Bold_Cell (Wrapped, 1),
            "wrapped Markdown heading lost its source annotation");
      end;
   end Test_Source_Annotations;

begin
   Test_Parsing_And_Rendering;
   Test_Unsupported_And_Malformed;
   Test_Exact_Link_Hits_And_Code_Literals;
   Test_Task_Marker_Clipping;
   Test_Bounds_Read_Only_And_Unicode;
   Test_Resize_Scroll_And_Stale_Layout;
   Test_Editor_Composition;
   Test_Source_Annotations;
   Ada.Text_IO.Put_Line ("markdown component tests passed");
end Markdown_Components_Tests;
