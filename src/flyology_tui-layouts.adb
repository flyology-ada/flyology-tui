package body Flyology_TUI.Layouts is

   function Horizontal_Offset
     (Outer, Inner : Natural;
      Alignment    : Horizontal_Alignment) return Natural
   is
      Spare : constant Natural := Outer - Natural'Min (Outer, Inner);
   begin
      case Alignment is
         when Align_Left   => return 0;
         when Align_Center => return Spare / 2;
         when Align_Right  => return Spare;
      end case;
   end Horizontal_Offset;

   function Vertical_Offset
     (Outer, Inner : Natural;
      Alignment    : Vertical_Alignment) return Natural
   is
      Spare : constant Natural := Outer - Natural'Min (Outer, Inner);
   begin
      case Alignment is
         when Align_Top    => return 0;
         when Align_Middle => return Spare / 2;
         when Align_Bottom => return Spare;
      end case;
   end Vertical_Offset;

   procedure Border_Glyphs
     (Kind                   : Border_Kind;
      Top_Left, Horizontal,
      Top_Right, Vertical,
      Bottom_Left, Bottom_Right : out Wide_Wide_Character)
   is
   begin
      case Kind is
         when No_Border | Square =>
            Top_Left := '┌';
            Horizontal := '─';
            Top_Right := '┐';
            Vertical := '│';
            Bottom_Left := '└';
            Bottom_Right := '┘';
         when Rounded =>
            Top_Left := '╭';
            Horizontal := '─';
            Top_Right := '╮';
            Vertical := '│';
            Bottom_Left := '╰';
            Bottom_Right := '╯';
         when Double_Line =>
            Top_Left := '╔';
            Horizontal := '═';
            Top_Right := '╗';
            Vertical := '║';
            Bottom_Left := '╚';
            Bottom_Right := '╝';
      end case;
   end Border_Glyphs;

   function Render
     (Item    : Block;
      Content : Flyology_TUI.Surfaces.Surface)
      return Flyology_TUI.Surfaces.Surface
   is
      Border_Size : constant Natural :=
        (if Item.Border = No_Border then 0 else 2);
      Natural_Width : constant Natural :=
        Flyology_TUI.Surfaces.Width (Content)
        + Item.Padding.Left + Item.Padding.Right + Border_Size;
      Natural_Height : constant Natural :=
        Flyology_TUI.Surfaces.Height (Content)
        + Item.Padding.Top + Item.Padding.Bottom + Border_Size;
      Result_Width : constant Natural :=
        (if Item.Width = 0 then Natural_Width else Item.Width);
      Result_Height : constant Natural :=
        (if Item.Height = 0 then Natural_Height else Item.Height);
      Result : Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.Create
          (Result_Width, Result_Height, Item.Appearance);
      Inset : constant Natural :=
        (if Item.Border = No_Border then 0 else 1);
      Inner_Width : constant Natural :=
        Result_Width
        - Natural'Min
            (Result_Width, Item.Padding.Left + Item.Padding.Right + 2 * Inset);
      Inner_Height : constant Natural :=
        Result_Height
        - Natural'Min
            (Result_Height,
             Item.Padding.Top + Item.Padding.Bottom + 2 * Inset);
      Content_X : constant Natural :=
        Inset + Item.Padding.Left
        + Horizontal_Offset
            (Inner_Width,
             Flyology_TUI.Surfaces.Width (Content),
             Item.Horizontal);
      Content_Y : constant Natural :=
        Inset + Item.Padding.Top
        + Vertical_Offset
            (Inner_Height,
             Flyology_TUI.Surfaces.Height (Content),
             Item.Vertical);
   begin
      if Item.Border /= No_Border
        and then Result_Width >= 2
        and then Result_Height >= 2
      then
         declare
            TL, H, TR, V, BL, BR : Wide_Wide_Character;
         begin
            Border_Glyphs (Item.Border, TL, H, TR, V, BL, BR);
            Result.Put (0, 0, (1 => TL), Item.Appearance);
            Result.Put (Result_Width - 1, 0, (1 => TR), Item.Appearance);
            Result.Put (0, Result_Height - 1, (1 => BL), Item.Appearance);
            Result.Put
              (Result_Width - 1,
               Result_Height - 1,
               (1 => BR),
               Item.Appearance);
            for X in 1 .. Result_Width - 2 loop
               Result.Put (X, 0, (1 => H), Item.Appearance);
               Result.Put (X, Result_Height - 1, (1 => H), Item.Appearance);
            end loop;
            for Y in 1 .. Result_Height - 2 loop
               Result.Put (0, Y, (1 => V), Item.Appearance);
               Result.Put (Result_Width - 1, Y, (1 => V), Item.Appearance);
            end loop;
         end;
      end if;

      Result.Overlay (Content, Content_X, Content_Y);
      return Result;
   end Render;

   function Join_Horizontally
     (Left, Right : Flyology_TUI.Surfaces.Surface;
      Gap         : Natural := 0;
      Alignment   : Vertical_Alignment := Align_Top)
      return Flyology_TUI.Surfaces.Surface
   is
      Left_Width : constant Natural :=
        Flyology_TUI.Surfaces.Width (Left);
      Right_Width : constant Natural :=
        Flyology_TUI.Surfaces.Width (Right);
      Height : constant Natural :=
        Natural'Max
          (Flyology_TUI.Surfaces.Height (Left),
           Flyology_TUI.Surfaces.Height (Right));
      Result : Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.Create (Left_Width + Gap + Right_Width, Height);
   begin
      Result.Overlay
        (Left,
         0,
         Vertical_Offset
           (Height, Flyology_TUI.Surfaces.Height (Left), Alignment));
      Result.Overlay
        (Right,
         Left_Width + Gap,
         Vertical_Offset
           (Height, Flyology_TUI.Surfaces.Height (Right), Alignment));
      return Result;
   end Join_Horizontally;

   function Join_Vertically
     (Top, Bottom : Flyology_TUI.Surfaces.Surface;
      Gap         : Natural := 0;
      Alignment   : Horizontal_Alignment := Align_Left)
      return Flyology_TUI.Surfaces.Surface
   is
      Top_Height : constant Natural := Flyology_TUI.Surfaces.Height (Top);
      Bottom_Height : constant Natural :=
        Flyology_TUI.Surfaces.Height (Bottom);
      Width : constant Natural :=
        Natural'Max
          (Flyology_TUI.Surfaces.Width (Top),
           Flyology_TUI.Surfaces.Width (Bottom));
      Result : Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.Create
          (Width, Top_Height + Gap + Bottom_Height);
   begin
      Result.Overlay
        (Top,
         Horizontal_Offset
           (Width, Flyology_TUI.Surfaces.Width (Top), Alignment),
         0);
      Result.Overlay
        (Bottom,
         Horizontal_Offset
           (Width, Flyology_TUI.Surfaces.Width (Bottom), Alignment),
         Top_Height + Gap);
      return Result;
   end Join_Vertically;

end Flyology_TUI.Layouts;
