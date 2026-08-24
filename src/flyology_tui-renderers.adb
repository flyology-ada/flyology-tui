with Ada.Characters.Latin_1;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.UTF_Encoding;
with Ada.Strings.UTF_Encoding.Wide_Wide_Strings;
with Ada.Strings.Wide_Wide_Unbounded;
with Flyology_TUI.Colors;
with Flyology_TUI.Glyphs;
with Flyology_TUI.Surfaces;
with Flyology_TUI.Styles;

package body Flyology_TUI.Renderers is
   use type Flyology_TUI.Styles.Style;
   use type Flyology_TUI.Color_Profiles.Profile;
   use type Flyology_TUI.Surfaces.Cell;
   use type Flyology_TUI.Views.Mouse_Mode;
   use type Flyology_TUI.Views.Cursor_Shape;
   use type Flyology_TUI.Views.Cursor_Description;
   use type Ada.Strings.Wide_Wide_Unbounded.Unbounded_Wide_Wide_String;

   package Text renames Ada.Strings.Wide_Wide_Unbounded;

   ESC : constant Character := Ada.Characters.Latin_1.ESC;
   CSI : constant String := ESC & "[";

   function Image (Item : Natural) return String is
     (Ada.Strings.Fixed.Trim (Natural'Image (Item), Ada.Strings.Both));

   procedure Append
     (Target : in out Bytes.Unbounded_String;
      Value  : String) renames Bytes.Append;

   function Position (X, Y : Natural) return String is
     (CSI & Image (Y + 1) & ";" & Image (X + 1) & "H");

   function Color_Code
     (Item       : Renderer;
      Color      : Flyology_TUI.Colors.Color;
      Background : Boolean) return String
   is
      Effective : constant Flyology_TUI.Colors.Color :=
        Flyology_TUI.Color_Profiles.Adapt
          (Color, Item.Configured_Color);
      Base : constant Natural := (if Background then 40 else 30);
      Bright_Base : constant Natural := (if Background then 100 else 90);
      Offset : Natural;
   begin
      case Effective.Kind is
         when Flyology_TUI.Colors.Default_Color =>
            return CSI & (if Background then "49m" else "39m");
         when Flyology_TUI.Colors.ANSI =>
            Offset := Flyology_TUI.Colors.ANSI_Color'Pos (Effective.Name);
            if Offset < 8 then
               return CSI & Image (Base + Offset) & "m";
            else
               return CSI & Image (Bright_Base + Offset - 8) & "m";
            end if;
         when Flyology_TUI.Colors.Indexed =>
            return
              CSI & (if Background then "48;5;" else "38;5;")
              & Image (Effective.Index) & "m";
         when Flyology_TUI.Colors.RGB =>
            return
              CSI & (if Background then "48;2;" else "38;2;")
              & Image (Effective.Red_Value) & ";"
              & Image (Effective.Green_Value) & ";"
              & Image (Effective.Blue_Value) & "m";
      end case;
   end Color_Code;

   function Style_Code
     (Item       : Renderer;
      Appearance : Flyology_TUI.Styles.Style) return String
   is
      Result : Bytes.Unbounded_String :=
        Bytes.To_Unbounded_String (CSI & "0m");
   begin
      if Appearance.Bold then
         Append (Result, CSI & "1m");
      end if;
      if Appearance.Faint then
         Append (Result, CSI & "2m");
      end if;
      if Appearance.Italic then
         Append (Result, CSI & "3m");
      end if;
      if Appearance.Underline then
         Append (Result, CSI & "4m");
      end if;
      if Appearance.Blink then
         Append (Result, CSI & "5m");
      end if;
      if Appearance.Reverse_Video then
         Append (Result, CSI & "7m");
      end if;
      if Appearance.Strikethrough then
         Append (Result, CSI & "9m");
      end if;
      Append (Result, Color_Code (Item, Appearance.Foreground, False));
      Append (Result, Color_Code (Item, Appearance.Background, True));
      return Bytes.To_String (Result);
   end Style_Code;

   procedure Set_Color_Profile
     (Item    : in out Renderer;
      Profile : Flyology_TUI.Color_Profiles.Profile)
   is
   begin
      Item.Configured_Color := Profile;
   end Set_Color_Profile;

   function Color_Profile
     (Item : Renderer) return Flyology_TUI.Color_Profiles.Profile
   is (Item.Configured_Color);

   function UTF_8 (Item : Wide_Wide_String) return String is
      Encoded : constant Ada.Strings.UTF_Encoding.UTF_8_String :=
        Ada.Strings.UTF_Encoding.Wide_Wide_Strings.Encode
          (Item, Output_BOM => False);
   begin
      return String (Encoded);
   end UTF_8;

   function Mouse_Enable
     (Mode : Flyology_TUI.Views.Mouse_Mode) return String
   is
   begin
      case Mode is
         when Flyology_TUI.Views.Mouse_Disabled => return "";
         when Flyology_TUI.Views.Button_Events =>
            return CSI & "?1000h" & CSI & "?1006h";
         when Flyology_TUI.Views.Cell_Motion =>
            return CSI & "?1002h" & CSI & "?1006h";
         when Flyology_TUI.Views.All_Motion =>
            return CSI & "?1003h" & CSI & "?1006h";
      end case;
   end Mouse_Enable;

   function Mouse_Disable return String is
     (CSI & "?1000l"
      & CSI & "?1002l"
      & CSI & "?1003l"
      & CSI & "?1006l");

   function Safe_Title
     (Item : Text.Unbounded_Wide_Wide_String) return Wide_Wide_String
   is
      Result : Text.Unbounded_Wide_Wide_String;
   begin
      for Value of Text.To_Wide_Wide_String (Item) loop
         declare
            Code : constant Natural := Wide_Wide_Character'Pos (Value);
         begin
            if Code >= 32 and then Code not in 127 .. 159 then
               Text.Append (Result, Value);
            end if;
         end;
      end loop;
      return Text.To_Wide_Wide_String (Result);
   end Safe_Title;

   procedure Mode_Changes
     (Item    : Renderer;
      Desired : Flyology_TUI.Views.View;
      Output  : in out Bytes.Unbounded_String)
   is
      First : constant Boolean := not Item.Initialized;
   begin
      if First
        or else Desired.Alternate_Screen /= Item.Previous.Alternate_Screen
      then
         Append
           (Output,
            CSI & (if Desired.Alternate_Screen then "?1049h" else "?1049l"));
      end if;
      if First or else Desired.Mouse /= Item.Previous.Mouse then
         Append (Output, Mouse_Disable);
         Append (Output, Mouse_Enable (Desired.Mouse));
      end if;
      if First or else Desired.Report_Focus /= Item.Previous.Report_Focus then
         Append
           (Output,
            CSI & (if Desired.Report_Focus then "?1004h" else "?1004l"));
      end if;
      if First
        or else Desired.Bracketed_Paste /= Item.Previous.Bracketed_Paste
      then
         Append
           (Output,
            CSI & (if Desired.Bracketed_Paste then "?2004h" else "?2004l"));
      end if;
      if First
        or else Desired.Window_Title /= Item.Previous.Window_Title
      then
         Append
           (Output,
            ESC & "]2;"
            & UTF_8 (Safe_Title (Desired.Window_Title))
            & Ada.Characters.Latin_1.BEL);
      end if;
   end Mode_Changes;

   procedure Frame_Changes
     (Item    : Renderer;
      Desired : Flyology_TUI.Views.View;
      Output  : in out Bytes.Unbounded_String)
   is
      Full : constant Boolean :=
        not Item.Initialized
        or else Item.Configured_Color /= Item.Rendered_Color
        or else Desired.Alternate_Screen
          /= Item.Previous.Alternate_Screen
        or else Flyology_TUI.Surfaces.Width (Desired.Frame)
          /= Flyology_TUI.Surfaces.Width (Item.Previous.Frame)
        or else Flyology_TUI.Surfaces.Height (Desired.Frame)
          /= Flyology_TUI.Surfaces.Height (Item.Previous.Frame);
      Active : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Active_Set : Boolean := False;
      Cursor_Known : Boolean := False;
      Next_X, Next_Y : Natural := 0;
   begin
      if Full then
         Append (Output, CSI & "2J" & CSI & "H");
      end if;
      if Flyology_TUI.Surfaces.Height (Desired.Frame) = 0
        or else Flyology_TUI.Surfaces.Width (Desired.Frame) = 0
      then
         return;
      end if;
      for Y in 0 .. Flyology_TUI.Surfaces.Height (Desired.Frame) - 1 loop
         for X in 0 .. Flyology_TUI.Surfaces.Width (Desired.Frame) - 1 loop
            declare
               Cell : constant Flyology_TUI.Surfaces.Cell :=
                 Desired.Frame.Element (X, Y);
               Changed : constant Boolean :=
                 Full
                 or else Cell /= Item.Previous.Frame.Element (X, Y);
            begin
               if Changed and then not Cell.Continuation then
                  if not Cursor_Known
                    or else X /= Next_X
                    or else Y /= Next_Y
                  then
                     Append (Output, Position (X, Y));
                  end if;
                  if not Active_Set or else Active /= Cell.Appearance then
                     Append (Output, Style_Code (Item, Cell.Appearance));
                     Active := Cell.Appearance;
                     Active_Set := True;
                  end if;
                  Append
                    (Output,
                     UTF_8
                       (Text.To_Wide_Wide_String (Cell.Glyph)));
                  Next_X := X + Natural'Max
                    (1,
                     Flyology_TUI.Glyphs.Width_Of
                       (Text.To_Wide_Wide_String (Cell.Glyph)));
                  Next_Y := Y;
                  Cursor_Known := True;
               end if;
            end;
         end loop;
      end loop;
      if Active_Set then
         Append (Output, CSI & "0m");
      end if;
   end Frame_Changes;

   procedure Cursor_Change
     (Desired : Flyology_TUI.Views.View;
      Output  : in out Bytes.Unbounded_String)
   is
      Shape : Natural;
   begin
      if Desired.Cursor.Visible then
         Shape :=
           (case Desired.Cursor.Shape is
               when Flyology_TUI.Views.Cursor_Block =>
                 (if Desired.Cursor.Blink then 1 else 2),
               when Flyology_TUI.Views.Cursor_Underline =>
                 (if Desired.Cursor.Blink then 3 else 4),
               when Flyology_TUI.Views.Cursor_Bar =>
                 (if Desired.Cursor.Blink then 5 else 6));
         Append (Output, CSI & "?25h" & CSI & Image (Shape) & " q");
         Append (Output, Position (Desired.Cursor.X, Desired.Cursor.Y));
      else
         Append (Output, CSI & "?25l");
      end if;
   end Cursor_Change;

   procedure Render
     (Item    : in out Renderer;
      Desired : Flyology_TUI.Views.View;
      Output  : out Bytes.Unbounded_String)
   is
      Before_Frame  : Natural;
      Frame_Changed : Boolean;
   begin
      Output := Bytes.Null_Unbounded_String;
      Mode_Changes (Item, Desired, Output);
      Before_Frame := Bytes.Length (Output);
      Frame_Changes (Item, Desired, Output);
      Frame_Changed := Bytes.Length (Output) > Before_Frame;
      --  A terminal transition may reveal the hardware cursor independently
      --  of the last declared view, so restate hidden state after repainting.
      if not Item.Initialized
        or else Desired.Cursor /= Item.Previous.Cursor
        or else (Frame_Changed and then not Desired.Cursor.Visible)
        or else Desired.Cursor.Visible
      then
         Cursor_Change (Desired, Output);
      end if;
      Item.Previous := Desired;
      Item.Rendered_Color := Item.Configured_Color;
      Item.Initialized := True;
   end Render;

   procedure Reset
     (Item   : in out Renderer;
      Output : out Bytes.Unbounded_String)
   is
   begin
      if not Item.Initialized then
         Output := Bytes.Null_Unbounded_String;
         return;
      end if;
      Output := Bytes.To_Unbounded_String
        (CSI & "0m"
         & Mouse_Disable
         & CSI & "?1004l"
         & CSI & "?2004l"
         & CSI & "?25h"
         & CSI & "0 q"
         & CSI & "?1049l");
      Item.Initialized := False;
   end Reset;

end Flyology_TUI.Renderers;
