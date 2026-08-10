with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Strings.UTF_Encoding.Wide_Wide_Strings;
with Ada.Strings.Wide_Wide_Unbounded;
with Ada.Streams;
with Ada.Streams.Stream_IO;
with Flyology_TUI.Colors;
with Flyology_TUI.Styles;

package body Component_Capture_Support is
   package Text renames Ada.Strings.Wide_Wide_Unbounded;
   package Narrow_Text renames Ada.Strings.Unbounded;
   use type Flyology_TUI.Skins.Skin_Id;

   function Trimmed (Value : Integer) return String is
     (Ada.Strings.Fixed.Trim (Integer'Image (Value), Ada.Strings.Both));

   function Escape_XML (Value : Wide_Wide_String) return String is
      Encoded : constant String :=
        Ada.Strings.UTF_Encoding.Wide_Wide_Strings.Encode (Value);
      Result : Narrow_Text.Unbounded_String;
   begin
      for Character of Encoded loop
         case Character is
            when '&' => Narrow_Text.Append (Result, "&amp;");
            when '<' => Narrow_Text.Append (Result, "&lt;");
            when '>' => Narrow_Text.Append (Result, "&gt;");
            when '"' => Narrow_Text.Append (Result, "&quot;");
            when others => Narrow_Text.Append (Result, Character);
         end case;
      end loop;
      return Narrow_Text.To_String (Result);
   end Escape_XML;

   function Color_CSS
     (Value         : Flyology_TUI.Colors.Color;
      Default_Value : String) return String
   is
      type RGB_Value is record
         Red, Green, Blue : Natural;
      end record;
      Basic_RGB : constant array
        (Flyology_TUI.Colors.ANSI_Color) of RGB_Value :=
        [Flyology_TUI.Colors.Black          => (0, 0, 0),
         Flyology_TUI.Colors.Red            => (128, 0, 0),
         Flyology_TUI.Colors.Green          => (0, 128, 0),
         Flyology_TUI.Colors.Yellow         => (128, 128, 0),
         Flyology_TUI.Colors.Blue           => (0, 0, 128),
         Flyology_TUI.Colors.Magenta        => (128, 0, 128),
         Flyology_TUI.Colors.Cyan           => (0, 128, 128),
         Flyology_TUI.Colors.White          => (192, 192, 192),
         Flyology_TUI.Colors.Bright_Black   => (128, 128, 128),
         Flyology_TUI.Colors.Bright_Red     => (255, 0, 0),
         Flyology_TUI.Colors.Bright_Green   => (0, 255, 0),
         Flyology_TUI.Colors.Bright_Yellow  => (255, 255, 0),
         Flyology_TUI.Colors.Bright_Blue    => (0, 0, 255),
         Flyology_TUI.Colors.Bright_Magenta => (255, 0, 255),
         Flyology_TUI.Colors.Bright_Cyan    => (0, 255, 255),
         Flyology_TUI.Colors.Bright_White   => (255, 255, 255)];
      Cube_Levels : constant array (Natural range 0 .. 5) of Natural :=
        [0, 95, 135, 175, 215, 255];

      function Indexed_RGB
        (Index : Flyology_TUI.Colors.Channel) return RGB_Value
      is
         Offset : Natural;
         Level  : Natural;
      begin
         if Index < 16 then
            return Basic_RGB
              (Flyology_TUI.Colors.ANSI_Color'Val (Natural (Index)));
         elsif Index < 232 then
            Offset := Natural (Index) - 16;
            return
              (Red   => Cube_Levels (Offset / 36),
               Green => Cube_Levels ((Offset / 6) mod 6),
               Blue  => Cube_Levels (Offset mod 6));
         else
            Level := 8 + 10 * (Natural (Index) - 232);
            return (others => Level);
         end if;
      end Indexed_RGB;

      Resolved : RGB_Value;
   begin
      case Value.Kind is
         when Flyology_TUI.Colors.Default_Color =>
            return Default_Value;
         when Flyology_TUI.Colors.ANSI =>
            Resolved := Basic_RGB (Value.Name);
         when Flyology_TUI.Colors.Indexed =>
            Resolved := Indexed_RGB (Value.Index);
         when Flyology_TUI.Colors.RGB =>
            Resolved :=
              (Value.Red_Value, Value.Green_Value, Value.Blue_Value);
      end case;
      return
        "rgb(" & Trimmed (Resolved.Red) & ","
        & Trimmed (Resolved.Green) & ","
        & Trimmed (Resolved.Blue) & ")";
   end Color_CSS;

   procedure Write_SVG
     (Frame : Flyology_TUI.Surfaces.Surface;
      Skin  : Flyology_TUI.Skins.Skin_Id;
      Title : Wide_Wide_String;
      Path  : String)
   is
      Cell_Width  : constant Natural := 10;
      Cell_Height : constant Natural := 20;
      Margin      : constant Natural := 18;
      Width       : constant Natural :=
        Frame.Width * Cell_Width + Margin * 2;
      Height      : constant Natural :=
        Frame.Height * Cell_Height + Margin * 2;
      Foreground  : constant String :=
        (if Skin = Flyology_TUI.Skins.Charm_Dark
         then "#fffdf5" else "#232323");
      Background  : constant String :=
        (case Skin is
            when Flyology_TUI.Skins.Charm_Dark => "#17171b",
            when Flyology_TUI.Skins.Turbo_Vision => "#00a8a8",
            when others => "#fffdf5");
      Output : Ada.Streams.Stream_IO.File_Type;

      procedure Put (Value : String) is
         Bytes : Ada.Streams.Stream_Element_Array
           (1 .. Ada.Streams.Stream_Element_Offset (Value'Length));
      begin
         for Index in Value'Range loop
            Bytes
              (Ada.Streams.Stream_Element_Offset
                 (Index - Value'First + 1)) :=
              Character'Pos (Value (Index));
         end loop;
         Ada.Streams.Stream_IO.Write (Output, Bytes);
      end Put;
   begin
      Ada.Streams.Stream_IO.Create
        (Output, Ada.Streams.Stream_IO.Out_File, Path);
      Put
        ("<svg xmlns=""http://www.w3.org/2000/svg"" width="""
         & Trimmed (Width) & """ height=""" & Trimmed (Height)
         & """ viewBox=""0 0 " & Trimmed (Width) & " "
         & Trimmed (Height) & """ role=""img"">"
         & "<title>" & Escape_XML (Title) & " rendered in the "
         & Escape_XML (Flyology_TUI.Skins.Label (Skin))
         & " skin</title><desc>Build-generated capture from the dedicated "
         & "Ada component example.</desc><rect width=""100%"" "
         & "height=""100%"" rx=""14"" fill=""" & Background & """/>");
      if Frame.Width > 0 and then Frame.Height > 0 then
         for Y in 0 .. Frame.Height - 1 loop
            for X in 0 .. Frame.Width - 1 loop
               declare
                  Cell : constant Flyology_TUI.Surfaces.Cell :=
                    Frame.Element (X, Y);
                  Glyph : constant Wide_Wide_String :=
                    Text.To_Wide_Wide_String (Cell.Glyph);
                  Look : constant Flyology_TUI.Styles.Style :=
                    Cell.Appearance;
                  Raw_Foreground : constant String :=
                    Color_CSS (Look.Foreground, Foreground);
                  Raw_Background : constant String :=
                    Color_CSS (Look.Background, Background);
                  Cell_Foreground : constant String :=
                    (if Look.Reverse_Video
                     then Raw_Background else Raw_Foreground);
                  Cell_Background : constant String :=
                    (if Look.Reverse_Video
                     then Raw_Foreground else Raw_Background);
               begin
                  if Cell_Background /= Background then
                     Put
                       ("<rect x=""" & Trimmed (Margin + X * Cell_Width)
                        & """ y=""" & Trimmed (Margin + Y * Cell_Height)
                        & """ width=""" & Trimmed (Cell_Width)
                        & """ height=""" & Trimmed (Cell_Height)
                        & """ fill=""" & Cell_Background & """/>");
                  end if;
                  if not Cell.Continuation and then Glyph /= " " then
                     Put
                       ("<text x=""" & Trimmed (Margin + X * Cell_Width)
                        & """ y=""" & Trimmed
                          (Margin + Y * Cell_Height + Cell_Height - 4)
                        & """ fill=""" & Cell_Foreground
                        & """ font-family=""ui-monospace,SFMono-Regular,"
                        & "Menlo,Consolas,monospace"" font-size=""16"""
                        & (if Look.Bold then " font-weight=""700""" else "")
                        & (if Look.Italic
                           then " font-style=""italic""" else "")
                        & (if Look.Faint then " opacity=""0.62""" else "")
                        & ">" & Escape_XML (Glyph) & "</text>");
                     if Look.Underline then
                        Put
                          ("<line x1="""
                           & Trimmed (Margin + X * Cell_Width)
                           & """ x2="""
                           & Trimmed (Margin + (X + 1) * Cell_Width - 1)
                           & """ y1="""
                           & Trimmed (Margin + (Y + 1) * Cell_Height - 2)
                           & """ y2="""
                           & Trimmed (Margin + (Y + 1) * Cell_Height - 2)
                           & """ stroke=""" & Cell_Foreground & """/>");
                     end if;
                  end if;
               end;
            end loop;
         end loop;
      end if;
      Put ("</svg>");
      Ada.Streams.Stream_IO.Close (Output);
   exception
      when others =>
         if Ada.Streams.Stream_IO.Is_Open (Output) then
            Ada.Streams.Stream_IO.Close (Output);
         end if;
         raise;
   end Write_SVG;
end Component_Capture_Support;
