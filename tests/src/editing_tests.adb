with Ada.Strings.Wide_Wide_Unbounded;
with Ada.Text_IO;
with Flyology_TUI.Colors;
with Flyology_TUI.Components.Interactions;
with Flyology_TUI.Components.Syntax_Editors;
with Flyology_TUI.Components.Text_Areas;
with Flyology_TUI.Events;
with Flyology_TUI.Mouse;
with Flyology_TUI.Styles;
with Flyology_TUI.Surfaces;
with Flyology_TUI.Themes;

procedure Editing_Tests is
   package Text renames Ada.Strings.Wide_Wide_Unbounded;
   package Areas renames Flyology_TUI.Components.Text_Areas;

   use type Flyology_TUI.Components.Interactions.Capture_Action;
   use type Flyology_TUI.Styles.Style;

   procedure Assert (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         raise Program_Error with Message;
      end if;
   end Assert;

   function Key
     (Kind      : Flyology_TUI.Events.Key_Kind;
      Shift     : Boolean := False;
      Control   : Boolean := False)
      return Flyology_TUI.Events.Terminal_Event
   is
      Value : Flyology_TUI.Events.Key_Event (Kind);
   begin
      Value.Modified :=
        (Shift => Shift, Control => Control, Alt | Super => False);
      return Flyology_TUI.Events.Pressed (Value);
   end Key;

   function Character_Key
     (Value     : Wide_Wide_String;
      Shift     : Boolean := False;
      Control   : Boolean := False)
      return Flyology_TUI.Events.Terminal_Event is
     (Flyology_TUI.Events.Pressed
        ((Kind     => Flyology_TUI.Events.Text_Key,
          Modified =>
            (Shift => Shift, Control => Control, Alt | Super => False),
          Repeated => False,
          Value    => Text.To_Unbounded_Wide_Wide_String (Value))));

   function Paste (Value : Wide_Wide_String)
      return Flyology_TUI.Events.Terminal_Event is
     ((Kind => Flyology_TUI.Events.Paste,
       Pasted_Text => Text.To_Unbounded_Wide_Wide_String (Value)));

   function Mouse
     (X, Y : Integer;
      Action : Flyology_TUI.Events.Mouse_Action;
      Wheel_X : Integer := 0;
      Wheel_Y : Integer := 0;
      Button : Flyology_TUI.Events.Mouse_Button :=
        Flyology_TUI.Events.Left_Button)
      return Flyology_TUI.Mouse.Local_Event is
     (X        => X,
      Y        => Y,
      Button   => Button,
      Action   => Action,
      Modified => (others => False),
      Wheel_X  => Wheel_X,
      Wheel_Y  => Wheel_Y);

   type Token is (Word, Comment);
   type State is record
      In_Comment : Boolean := False;
      Steps      : Natural := 0;
   end record;

   type Lexer_Behavior is
     (Normal,
      Two_Tokens,
      Too_Many,
      Overlap,
      Out_Of_Range,
      Raise_Error);
   Behavior : Lexer_Behavior := Normal;

   procedure Lex
     (Line          : Wide_Wide_String;
      Initial       : State;
      From          : Natural;
      Kind          : out Token;
      First, Last   : out Natural;
      Final         : out State;
      Has_Token     : out Boolean)
   is
      Opened : Boolean := Initial.In_Comment;
   begin
      if Behavior = Raise_Error then
         raise Program_Error with "injected lexer failure";
      end if;
      for Char of Line loop
         if Char = '{' then
            Opened := True;
         elsif Char = '}' then
            Opened := False;
         end if;
      end loop;
      Final := (In_Comment => Opened, Steps => Initial.Steps);
      Kind :=
        (if Initial.In_Comment or else Initial.Steps > 0
         then Comment else Word);
      First := From;
      Last := From;
      Has_Token := From < Line'Length;
      if not Has_Token then
         return;
      elsif Behavior = Two_Tokens then
         Last := From + 1;
         Final.Steps := Initial.Steps + 1;
      elsif Behavior = Out_Of_Range then
         Last := Line'Length + 1;
      elsif Behavior = Overlap then
         if From = 0 then
            Last := 1;
         else
            First := 0;
            Last := 1;
         end if;
      elsif Behavior = Too_Many then
         Last := From + 1;
      else
         Last := Line'Length;
      end if;
   end Lex;

   package Editors is new Flyology_TUI.Components.Syntax_Editors
     (Token_Kind              => Token,
      Lexer_State             => State,
      Initial_State           => (In_Comment => False, Steps => 0),
      Maximum_Tokens_Per_Line => 2,
      Next_Token              => Lex);

   use type Editors.Highlight_State;

   procedure Test_Capacity_And_Normalization is
      Item : Areas.Model := Areas.Create (12, 3, 3, 24, 10, 3, "empty");
      Success : Boolean;
      Result : Flyology_TUI.Components.Interactions.Update_Result;
   begin
      Item.Try_Set_Text ("a" & Wide_Wide_Character'Val (13)
                         & Wide_Wide_Character'Val (10) & "b"
                         & Wide_Wide_Character'Val (13) & "c", Success);
      Assert (Success and then Item.Value = "a" & Wide_Wide_Character'Val (10)
              & "b" & Wide_Wide_Character'Val (10) & "c",
              "CRLF/CR normalization did not converge to LF");
      Item.Try_Set_Text ("one" & Wide_Wide_Character'Val (10) & "two"
                         & Wide_Wide_Character'Val (10) & "three"
                         & Wide_Wide_Character'Val (10) & "four", Success);
      Assert
        (not Success
         and then Item.Value = "a" & Wide_Wide_Character'Val (10)
           & "b" & Wide_Wide_Character'Val (10) & "c",
         "line-capacity failure was not atomic");
      Item.Try_Set_Text
        ("a" & Wide_Wide_Character'Val (13)
         & Wide_Wide_Character'Val (10) & "b"
         & Wide_Wide_Character'Val (13)
         & Wide_Wide_Character'Val (10) & "c"
         & Wide_Wide_Character'Val (13)
         & Wide_Wide_Character'Val (10) & "d", Success);
      Assert (not Success,
              "oversized normalized set was not rejected");
      Item.Focus;
      Result := Item.Handle (Paste ("012345678901"));
      Assert (Result.Handled and then Result.Rejected
              and then not Result.Changed,
              "over-capacity paste was not rejected atomically");
      Item.Try_Set_Text ("abcdef", Success);
      Item.Set_Cursor_Offset (3);
      Result := Item.Handle
        (Key (Flyology_TUI.Events.Arrow_Left_Key, Shift => True));
      Result := Item.Handle
        (Paste
           ("12" & Wide_Wide_Character'Val (13)
            & Wide_Wide_Character'Val (10) & "345678"));
      Assert
        (Result.Rejected and then Item.Value = "abcdef",
         "oversized normalized selection replacement was not atomic");
      Item.Select_All;
      Result := Item.Handle
        (Paste ("0123456789012"));
      Assert
        (Result.Rejected and then Item.Value = "abcdef",
         "oversized full replacement was not rejected atomically");
      Item.Set_Read_Only (True);
      Result := Item.Handle (Character_Key ("x"));
      Assert (not Result.Changed, "read-only area accepted text");
      Item.Set_Read_Only (False);
      Item.Set_Enabled (False);
      Result := Item.Handle (Character_Key ("x"));
      Assert (not Result.Handled, "disabled area handled a key");
   end Test_Capacity_And_Normalization;

   procedure Test_Graphemes_And_Navigation is
      Acute : constant Wide_Wide_String :=
        (1 => 'e', 2 => Wide_Wide_Character'Val (16#0301#));
      ZWJ : constant Wide_Wide_String :=
        (1 => Wide_Wide_Character'Val (16#1F469#),
         2 => Wide_Wide_Character'Val (16#200D#),
         3 => Wide_Wide_Character'Val (16#1F4BB#));
      Wide : constant Wide_Wide_String :=
        (1 => Wide_Wide_Character'Val (16#754C#));
      Variation : constant Wide_Wide_String :=
        (1 => Wide_Wide_Character'Val (16#2764#),
         2 => Wide_Wide_Character'Val (16#FE0F#));
      Item : Areas.Model := Areas.Create (40, 4, 4, 80, 12, 3);
      Success : Boolean;
      Result : Flyology_TUI.Components.Interactions.Update_Result;
   begin
      Item.Try_Set_Text (Acute & ZWJ & Wide, Success);
      Item.Focus;
      Item.Set_Cursor_Offset (1);
      Assert (Item.Cursor_Offset = 0,
              "cursor setter entered a combining cluster");
      Item.Set_Cursor_Offset (Acute'Length + ZWJ'Length);
      Result := Item.Handle (Key (Flyology_TUI.Events.Backspace_Key));
      Assert (Result.Changed and then Item.Value = Acute & Wide,
              "backspace split a ZWJ cluster");
      Result := Item.Handle (Key (Flyology_TUI.Events.Delete_Key));
      Assert (Result.Changed and then Item.Value = Acute,
              "delete split a double-width cluster");
      Item.Try_Set_Text (Variation, Success);
      Item.Set_Cursor_Offset (1);
      Assert (Item.Cursor_Offset = 0,
              "cursor setter entered a variation-selector cluster");
      Item.Set_Cursor_Offset (Variation'Length);
      Result := Item.Handle (Key (Flyology_TUI.Events.Backspace_Key));
      Assert (Item.Value = "",
              "backspace split a variation-selector cluster");

      Item.Try_Set_Text
        ("a" & Wide_Wide_Character'Val (9) & "b"
         & Wide_Wide_Character'Val (10) & "123456"
         & Wide_Wide_Character'Val (10) & "x", Success);
      Item.Set_Cursor_Offset (3);
      Result := Item.Handle (Key (Flyology_TUI.Events.Arrow_Down_Key));
      Assert (Item.Cursor_Position.Line = 2
              and then Item.Cursor_Position.Cell_Column = 5,
              "vertical movement did not preserve the preferred cell");
      Result := Item.Handle (Key (Flyology_TUI.Events.Arrow_Down_Key));
      Assert (Item.Cursor_Position.Line = 3
              and then Item.Cursor_Position.Cell_Column = 1,
              "vertical movement did not clamp a short line");
      Result := Item.Handle
        (Key (Flyology_TUI.Events.Arrow_Up_Key, Shift => True));
      Assert (Item.Has_Selection,
              "shift navigation did not extend selection");
      Result := Item.Handle (Character_Key ("a", Control => True));
      Assert (Item.Has_Selection, "Ctrl+A did not select all");
   end Test_Graphemes_And_Navigation;

   procedure Test_History_Mouse_And_Render is
      Item : Areas.Model := Areas.Create (20, 5, 2, 20, 10, 2, "hint");
      Success : Boolean;
      Result : Flyology_TUI.Components.Interactions.Update_Result;
      Selected : constant Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.With_Background
          (Flyology_TUI.Styles.Default,
           Flyology_TUI.Colors.Basic (Flyology_TUI.Colors.Blue));
      Look : Areas.Appearance := Areas.From_Theme (Flyology_TUI.Themes.Charm);
   begin
      Item.Try_Set_Text ("abc", Success);
      Item.Focus;
      Result := Item.Handle (Character_Key ("d"));
      Result := Item.Handle (Character_Key ("e"));
      Result := Item.Handle (Character_Key ("f"));
      Item.Undo;
      Assert (Item.Value = "abcde", "undo did not restore the latest edit");
      Item.Undo;
      Assert (Item.Value = "abcd", "undo-entry eviction retained wrong state");
      Item.Redo;
      Assert
        (Item.Value = "abcde",
         "redo did not restore an evicted-window edit");
      declare
         Bounded : Areas.Model := Areas.Create (10, 2, 5, 3, 8, 2);
      begin
         Bounded.Try_Set_Text ("a", Success);
         Bounded.Focus;
         Result := Bounded.Handle (Character_Key ("b"));
         Result := Bounded.Handle (Character_Key ("c"));
         Result := Bounded.Handle (Character_Key ("d"));
         Bounded.Undo;
         Bounded.Undo;
         Assert (Bounded.Value = "abc",
                 "history-codepoint eviction retained too much history");
      end;

      Result := Item.Handle
        (Mouse (3, 0, Flyology_TUI.Events.Mouse_Click));
      Assert (Result.Focus_Requested
              and then Result.Capture =
                Flyology_TUI.Components.Interactions.Acquire_Capture,
              "mouse press did not acquire selection capture");
      Result := Item.Handle
        (Mouse (8, 0, Flyology_TUI.Events.Mouse_Drag));
      Assert (Item.Has_Selection, "mouse drag did not extend selection");
      Item.Set_Size (8, 1);
      Item.Set_Enabled (False);
      Result := Item.Handle
        (Mouse (-2, 0, Flyology_TUI.Events.Mouse_Release));
      Assert (Result.Capture =
                Flyology_TUI.Components.Interactions.Release_Capture,
              "resize/disable stranded mouse capture");
      Item.Set_Enabled (True);
      Result := Item.Handle
        (Mouse (2, 0, Flyology_TUI.Events.Mouse_Wheel, Wheel_Y => -1));
      Assert (Result.Handled, "local wheel input was ignored");

      Look.Selection := Selected;
      Item.Select_All;
      declare
         Frame : constant Flyology_TUI.Surfaces.Surface := Item.Render (Look);
      begin
         Assert (Frame.Width = 8 and then Frame.Height = 1,
                 "render did not follow resized geometry");
         Assert (Frame.Element (2, 0).Appearance = Selected,
                 "explicit selection appearance was not rendered");
      end;
      Item.Set_Wrap (Areas.Soft_Wrap);
      Item.Set_Viewport (1, 7);
      Assert (Item.Viewport_Cell = 0,
              "soft wrapping retained horizontal scroll");
      Item.Set_Size (6, 2);
      Item.Try_Set_Text ("abcde", Success);
      declare
         Frame : constant Flyology_TUI.Surfaces.Surface := Item.Render (Look);
      begin
         Assert
           (Text.To_Wide_Wide_String (Frame.Element (5, 0).Glyph) = "d"
            and then
              Text.To_Wide_Wide_String (Frame.Element (2, 1).Glyph) = "e",
            "soft wrapping did not break after the exact cell edge");
      end;
      declare
         Scrolled : Areas.Model := Areas.Create (10, 5, 2, 20, 6, 2);
      begin
         Scrolled.Try_Set_Text ("abcde", Success);
         Scrolled.Focus;
         Result := Scrolled.Handle (Key (Flyology_TUI.Events.End_Key));
         Assert (Scrolled.Viewport_Cell = 2,
                 "horizontal scroll ignored the rendered gutter width");
      end;
   end Test_History_Mouse_And_Render;

   procedure Test_Wrap_Extremes_And_Input_States is
      Item : Areas.Model := Areas.Create (40, 3, 3, 80, 6, 2);
      Success : Boolean;
      Result : Flyology_TUI.Components.Interactions.Update_Result;
      Line : Positive;
      First, Last : Natural;
      Exists : Boolean;
      Cursor_Style : constant Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.With_Foreground
          (Flyology_TUI.Styles.Default,
           Flyology_TUI.Colors.Basic (Flyology_TUI.Colors.Bright_Red));
      Line_Style : constant Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.With_Background
          (Flyology_TUI.Styles.Default,
           Flyology_TUI.Colors.Basic (Flyology_TUI.Colors.Bright_Blue));
      Look : Areas.Appearance := Areas.From_Theme (Flyology_TUI.Themes.Charm);

      procedure Check_Read_Only
        (Event : Flyology_TUI.Events.Terminal_Event;
         Message : String)
      is
         Outcome : constant
           Flyology_TUI.Components.Interactions.Update_Result :=
             Item.Handle (Event);
      begin
         Assert
           (Outcome.Handled
            and then not Outcome.Changed
            and then not Outcome.Rejected,
            Message);
      end Check_Read_Only;
   begin
      declare
         Raised : Boolean := False;
      begin
         begin
            declare
               Oversized : Areas.Model :=
                 Areas.Create
                   (40, 3, 3, 80, Positive'Last, 2);
               pragma Unreferenced (Oversized);
            begin
               null;
            end;
         exception
            when Flyology_TUI.Components.Capacity_Error => Raised := True;
         end;
         Assert (Raised,
                 "constructor did not preflight surface cell capacity");
         Raised := False;
         begin
            Item.Set_Size (Positive'Last, 2);
         exception
            when Flyology_TUI.Components.Capacity_Error => Raised := True;
         end;
         Assert
           (Raised and then Item.Width = 6 and then Item.Height = 2,
            "size-capacity failure mutated component geometry");
         declare
            Frame : constant Flyology_TUI.Surfaces.Surface :=
              Item.Render (Look);
         begin
            Assert (Frame.Width = 6 and then Frame.Height = 2,
                    "render lost pre-failure geometry");
         end;
      end;
      Item.Try_Set_Text ("abcdefghijkl", Success);
      Item.Set_Wrap (Areas.Soft_Wrap);
      Item.Set_Cursor_Offset (0);
      Item.Focus;
      Item.Visible_Segment (0, Line, First, Last, Exists);
      Assert (Exists and then First = 0 and then Last = 4,
              "wrapped viewport did not begin at the first segment");
      Result := Item.Handle (Key (Flyology_TUI.Events.Arrow_Down_Key));
      Assert (Item.Cursor_Offset = 4,
              "Down did not enter the next wrapped visual row");
      Result := Item.Handle (Key (Flyology_TUI.Events.Arrow_Down_Key));
      Assert (Item.Cursor_Offset = 8,
              "Down did not navigate beyond one wrapped viewport");
      Item.Visible_Segment (0, Line, First, Last, Exists);
      Assert (First = 8 and then Last = 12,
              "cursor visibility did not advance wrapped viewport origin");
      Result := Item.Handle (Key (Flyology_TUI.Events.Arrow_Up_Key));
      Assert (Item.Cursor_Offset = 4,
              "Up did not return to the previous wrapped visual row");
      Result := Item.Handle
        (Mouse (2, 0, Flyology_TUI.Events.Mouse_Wheel, Wheel_Y => 1));
      Assert (Result.Handled and then Result.Changed,
              "wheel did not scroll a wrapped visual row");

      Item.Set_Tab_Width (Positive'Last);
      Item.Try_Set_Text
        ((1 => Wide_Wide_Character'Val (9), 2 => 'x'), Success);
      Item.Set_Wrap (Areas.Soft_Wrap);
      Item.Set_Cursor_Offset (0);
      Result := Item.Handle (Key (Flyology_TUI.Events.Arrow_Down_Key));
      Assert (Item.Cursor_Offset = 1,
              "saturated tab endpoint collapsed wrapped Down navigation");
      Item.Set_Cursor_Offset (0);
      Result := Item.Handle
        (Mouse (2, 1, Flyology_TUI.Events.Mouse_Click));
      Assert (Item.Cursor_Offset = 1,
              "saturated tab endpoint collapsed wrapped mouse origin");
      Result := Item.Handle
        (Mouse (2, 1, Flyology_TUI.Events.Mouse_Release));
      Item.Set_Cursor_Offset (1);
      Assert (Item.Cursor_Position.Cell_Column = Natural'Last,
              "extreme tab width did not saturate cell position");
      Item.Set_Wrap (Areas.No_Wrap);
      Item.Set_Viewport (1, Natural'Last);
      declare
         Frame : constant Flyology_TUI.Surfaces.Surface := Item.Render (Look);
         pragma Unreferenced (Frame);
      begin
         Result := Item.Handle
           (Mouse
              (2,
               0,
               Flyology_TUI.Events.Mouse_Wheel,
               Wheel_X => Integer'First));
         Assert (Result.Handled and then not Result.Changed,
                 "saturated horizontal wheel reported a viewport change");
         Result := Item.Handle
           (Mouse (5, 0, Flyology_TUI.Events.Mouse_Click));
         Result := Item.Handle
           (Mouse (5, 0, Flyology_TUI.Events.Mouse_Release));
      end;

      Item.Try_Set_Text ("abc", Success);
      Result := Item.Handle
        (Mouse (2, 0, Flyology_TUI.Events.Mouse_Click));
      Result := Item.Handle
        (Mouse
           (2,
            0,
            Flyology_TUI.Events.Mouse_Release,
            Button => Flyology_TUI.Events.Right_Button));
      Assert
        (not Result.Handled
         and then Result.Capture =
           Flyology_TUI.Components.Interactions.No_Capture_Change,
         "non-left release ended left-button capture");
      Result := Item.Handle
        (Mouse (2, 0, Flyology_TUI.Events.Mouse_Release));
      Assert (Result.Capture =
                Flyology_TUI.Components.Interactions.Release_Capture,
              "left release did not end capture after unrelated release");
      Result := Item.Handle
        (Mouse (2, 0, Flyology_TUI.Events.Mouse_Click));
      Item.Try_Set_Text ("replacement", Success);
      Result := Item.Handle
        (Mouse (5, 0, Flyology_TUI.Events.Mouse_Release));
      Assert
        (Result.Capture =
           Flyology_TUI.Components.Interactions.Release_Capture
         and then Item.Value = "replacement"
         and then not Item.Has_Selection,
         "text replacement retained stale drag semantics or capture");

      Result := Item.Handle
        (Mouse (2, 0, Flyology_TUI.Events.Mouse_Wheel));
      Assert (not Result.Handled and then not Result.Changed,
              "zero wheel event reported work");
      Item.Set_Viewport (1, 0);
      Result := Item.Handle
        (Mouse (2, 0, Flyology_TUI.Events.Mouse_Wheel, Wheel_Y => 1));
      Assert (Result.Handled and then not Result.Changed,
              "wheel boundary reported a viewport change");

      Item.Set_Read_Only (True);
      Check_Read_Only (Character_Key ("z"),
                       "read-only text key result was inconsistent");
      Check_Read_Only (Key (Flyology_TUI.Events.Enter_Key),
                       "read-only Enter result was inconsistent");
      Check_Read_Only (Key (Flyology_TUI.Events.Tab_Key),
                       "read-only Tab result was inconsistent");
      Check_Read_Only (Key (Flyology_TUI.Events.Backspace_Key),
                       "read-only Backspace result was inconsistent");
      Check_Read_Only (Key (Flyology_TUI.Events.Delete_Key),
                       "read-only Delete result was inconsistent");
      Check_Read_Only (Paste ("paste"),
                       "read-only paste result was inconsistent");
      Check_Read_Only (Character_Key ("z", Control => True),
                       "read-only undo result was inconsistent");
      Check_Read_Only (Character_Key ("y", Control => True),
                       "read-only redo result was inconsistent");

      Item.Set_Read_Only (False);
      Item.Set_Tab_Width (4);
      Item.Try_Set_Text ("a", Success);
      Item.Set_Size (8, 1);
      Item.Set_Cursor_Offset (0);
      Look.Cursor := Cursor_Style;
      Look.Current_Line := Line_Style;
      declare
         Frame : constant Flyology_TUI.Surfaces.Surface := Item.Render (Look);
      begin
         Assert (Frame.Element (2, 0).Appearance = Cursor_Style,
                 "explicit cursor appearance was not rendered");
         Assert (Frame.Element (7, 0).Appearance = Line_Style,
                 "explicit current-line appearance was not rendered");
      end;
   end Test_Wrap_Extremes_And_Input_States;

   procedure Test_Syntax is
      Item : Editors.Model := Editors.Create (40, 4, 3, 80, 12, 3);
      Success : Boolean;
      Result : Flyology_TUI.Components.Interactions.Update_Result;
      Accent : constant Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.With_Foreground
          (Flyology_TUI.Styles.Default,
           Flyology_TUI.Colors.Basic (Flyology_TUI.Colors.Bright_Yellow));
      Look : Editors.Appearance :=
        Editors.From_Theme (Flyology_TUI.Themes.Charm);
   begin
      Item.Try_Set_Text
        ("{" & Wide_Wide_Character'Val (10) & "body"
         & Wide_Wide_Character'Val (10) & "}", Success);
      Assert (Success and then Item.Highlighting = Editors.Highlight_Dirty,
              "new syntax text was not marked dirty");
      Item.Advance_Highlighting (1);
      Assert (Item.First_Dirty_Line = 2,
              "highlight budget did not stop after one line");
      Item.Advance_Highlighting (2);
      Assert (Item.Highlighting = Editors.Highlight_Current,
              "highlighting did not converge after sufficient budget");
      Look.Tokens (Comment) := Accent;
      declare
         Frame : constant Flyology_TUI.Surfaces.Surface := Item.Render (Look);
      begin
         Assert (Frame.Element (2, 1).Appearance = Accent,
                 "multiline lexer state did not style the following line");
      end;
      Look.Editor.Selection := Flyology_TUI.Themes.Charm.Selected;
      Item.Select_All;
      declare
         Frame : constant Flyology_TUI.Surfaces.Surface := Item.Render (Look);
      begin
         Assert
           (Frame.Element (2, 1).Appearance = Look.Editor.Selection,
            "syntax token style overrode selection appearance");
      end;
      Item.Clear_Selection;

      Item.Focus;
      Result := Item.Handle (Character_Key ("x"));
      Assert (Result.Changed and then Item.First_Dirty_Line = 3,
              "edit did not invalidate from its first changed line");

      Behavior := Two_Tokens;
      Item.Try_Set_Text
        ("ab" & Wide_Wide_Character'Val (10) & "q", Success);
      Item.Advance_Highlighting (2);
      declare
         Frame : constant Flyology_TUI.Surfaces.Surface := Item.Render (Look);
      begin
         Assert
           (Frame.Element (2, 0).Appearance = Look.Tokens (Word)
            and then Frame.Element (3, 0).Appearance = Look.Tokens (Comment)
            and then Frame.Element (2, 1).Appearance = Look.Tokens (Comment),
            "token-to-token lexer state was not threaded through the line");
      end;

      Behavior := Too_Many;
      Item.Try_Set_Text ("abc", Success);
      Item.Advance_Highlighting (1);
      Assert (Item.Highlighting = Editors.Highlight_Capacity_Limited,
              "token capacity overflow was not reported");
      Behavior := Overlap;
      Item.Try_Set_Text ("ab", Success);
      Item.Advance_Highlighting (1);
      Assert (Item.Highlighting = Editors.Highlight_Structure_Invalid,
              "overlapping token spans were accepted");
      Behavior := Out_Of_Range;
      Item.Try_Set_Text ("ab", Success);
      Item.Advance_Highlighting (1);
      Assert (Item.Highlighting = Editors.Highlight_Structure_Invalid,
              "out-of-range token span was accepted");
      Behavior := Raise_Error;
      Item.Try_Set_Text ("ab", Success);
      Item.Advance_Highlighting (1);
      Assert (Item.Highlighting = Editors.Highlight_Lexer_Failed,
              "lexer exception did not leave an explicit safe state");
      declare
         Frame : constant Flyology_TUI.Surfaces.Surface := Item.Render (Look);
      begin
         Assert (Frame.Element (2, 0).Appearance /= Look.Tokens (Word),
                 "failed dirty line rendered stale token styles");
      end;
   end Test_Syntax;

begin
   Test_Capacity_And_Normalization;
   Test_Graphemes_And_Navigation;
   Test_History_Mouse_And_Render;
   Test_Wrap_Extremes_And_Input_States;
   Test_Syntax;
   Ada.Text_IO.Put_Line ("editing tests passed");
end Editing_Tests;
