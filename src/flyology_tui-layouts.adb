with Flyology_TUI.Components;

package body Flyology_TUI.Layouts is

   use type Flyology_TUI.Skins.Title_Placement;

   type Frame_Measurement is record
      Result_Width  : Natural;
      Result_Height : Natural;
      Frame_Width   : Natural;
      Frame_Height  : Natural;
      Content       : Flyology_TUI.Geometry.Rectangle;
   end record;

   function Checked_Add (Left, Right : Natural) return Natural is
   begin
      if Right > Natural'Last - Left then
         raise Flyology_TUI.Components.Capacity_Error with
           "layout chrome exceeds surface capacity";
      end if;
      return Left + Right;
   end Checked_Add;

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

   function Measure
     (Item           : Block;
      Intrinsic_Width, Intrinsic_Height : Natural;
      Chrome         : Flyology_TUI.Skins.Frame_Chrome;
      Exact_Outer    : Boolean := False)
      return Frame_Measurement
   is
      Border_Size : constant Natural :=
        (if Item.Border = No_Border then 0 else 2);
      Natural_Width : constant Natural :=
        (if Exact_Outer then 0
         else Intrinsic_Width
           + Item.Padding.Left + Item.Padding.Right + Border_Size);
      Natural_Height : constant Natural :=
        (if Exact_Outer then 0
         else Intrinsic_Height
           + Item.Padding.Top + Item.Padding.Bottom + Border_Size);
      Shadow_Width : constant Natural :=
        (if Item.Border = No_Border then 0 else Chrome.Shadow_X);
      Shadow_Height : constant Natural :=
        (if Item.Border = No_Border then 0 else Chrome.Shadow_Y);
      Result_Width : constant Natural :=
        (if Exact_Outer then Item.Width
         elsif Item.Width = 0
         then Checked_Add (Natural_Width, Shadow_Width)
         else Item.Width);
      Result_Height : constant Natural :=
        (if Exact_Outer then Item.Height
         elsif Item.Height = 0
         then Checked_Add (Natural_Height, Shadow_Height)
         else Item.Height);
      Frame_Width : constant Natural :=
        Result_Width - Natural'Min (Result_Width, Shadow_Width);
      Frame_Height : constant Natural :=
        Result_Height - Natural'Min (Result_Height, Shadow_Height);
      Inset : constant Natural :=
        (if Item.Border = No_Border then 0 else 1);
      Horizontal_Chrome : constant Natural :=
        Item.Padding.Left + Item.Padding.Right + 2 * Inset;
      Vertical_Chrome : constant Natural :=
        Item.Padding.Top + Item.Padding.Bottom + 2 * Inset;
      Inner_Width : constant Natural :=
        Frame_Width - Natural'Min (Frame_Width, Horizontal_Chrome);
      Inner_Height : constant Natural :=
        Frame_Height - Natural'Min (Frame_Height, Vertical_Chrome);
      Content_X : constant Natural :=
        Natural'Min (Frame_Width, Inset + Item.Padding.Left);
      Content_Y : constant Natural :=
        Natural'Min (Frame_Height, Inset + Item.Padding.Top);
   begin
      return
        (Result_Width  => Result_Width,
         Result_Height => Result_Height,
         Frame_Width   => Frame_Width,
         Frame_Height  => Frame_Height,
         Content       =>
           (X      => Integer (Content_X),
            Y      => Integer (Content_Y),
            Width  => Inner_Width,
            Height => Inner_Height));
   end Measure;

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

   function Default_Chrome (Kind : Border_Kind)
      return Flyology_TUI.Skins.Frame_Chrome
   is
      TL, H, TR, V, BL, BR : Wide_Wide_Character;
   begin
      Border_Glyphs (Kind, TL, H, TR, V, BL, BR);
      return
        (Border =>
           (Top_Left => TL, Horizontal => H, Top_Right => TR,
            Vertical => V, Bottom_Left => BL, Bottom_Right => BR),
         others => <>);
   end Default_Chrome;

   function Render
     (Item    : Block;
      Content : Flyology_TUI.Surfaces.Surface)
      return Flyology_TUI.Surfaces.Surface is
     (Render (Item, Content, Default_Chrome (Item.Border)));

   function Render
     (Item    : Block;
      Content : Flyology_TUI.Surfaces.Surface;
      Chrome  : Flyology_TUI.Skins.Frame_Chrome)
      return Flyology_TUI.Surfaces.Surface
   is
      Measurement : constant Frame_Measurement :=
        Measure
          (Item,
           Flyology_TUI.Surfaces.Width (Content),
           Flyology_TUI.Surfaces.Height (Content),
           Chrome);
      Result_Width : constant Natural := Measurement.Result_Width;
      Result_Height : constant Natural := Measurement.Result_Height;
      Frame_Width : constant Natural := Measurement.Frame_Width;
      Frame_Height : constant Natural := Measurement.Frame_Height;
      Result : Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.Create
          (Result_Width, Result_Height, Item.Appearance);
      Frame : Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.Create
          (Frame_Width, Frame_Height, Item.Appearance);
      Content_Window : Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.Create
          (Measurement.Content.Width,
           Measurement.Content.Height,
           Item.Appearance);
      Content_X : constant Natural :=
        Horizontal_Offset
          (Measurement.Content.Width,
           Flyology_TUI.Surfaces.Width (Content),
           Item.Horizontal);
      Content_Y : constant Natural :=
        Vertical_Offset
          (Measurement.Content.Height,
           Flyology_TUI.Surfaces.Height (Content),
           Item.Vertical);
   begin
      if Item.Border /= No_Border then
         if Frame_Width < Result_Width and then Result_Height > 0 then
            for X in Frame_Width .. Result_Width - 1 loop
               for Y in Natural'Min (Chrome.Shadow_Y, Result_Height - 1)
                 .. Result_Height - 1
               loop
                  Result.Put (X, Y, " ", Chrome.Shadow);
               end loop;
            end loop;
         end if;
         if Frame_Height < Result_Height and then Result_Width > 0 then
            for Y in Frame_Height .. Result_Height - 1 loop
               for X in Natural'Min (Chrome.Shadow_X, Result_Width - 1)
                 .. Result_Width - 1
               loop
                  Result.Put (X, Y, " ", Chrome.Shadow);
               end loop;
            end loop;
         end if;
      end if;

      if Item.Border /= No_Border
        and then Frame_Width >= 2
        and then Frame_Height >= 2
      then
         declare
            Glyphs : constant Flyology_TUI.Skins.Border_Glyphs :=
              Chrome.Border;
         begin
            Frame.Put (0, 0, (1 => Glyphs.Top_Left), Item.Appearance);
            Frame.Put
              (Frame_Width - 1, 0, (1 => Glyphs.Top_Right), Item.Appearance);
            Frame.Put
              (0, Frame_Height - 1,
               (1 => Glyphs.Bottom_Left), Item.Appearance);
            Frame.Put
              (Frame_Width - 1,
               Frame_Height - 1,
               (1 => Glyphs.Bottom_Right),
               Item.Appearance);
            for X in 1 .. Frame_Width - 2 loop
               Frame.Put (X, 0, (1 => Glyphs.Horizontal), Item.Appearance);
               Frame.Put
                 (X, Frame_Height - 1,
                  (1 => Glyphs.Horizontal), Item.Appearance);
            end loop;
            for Y in 1 .. Frame_Height - 2 loop
               Frame.Put (0, Y, (1 => Glyphs.Vertical), Item.Appearance);
               Frame.Put
                 (Frame_Width - 1, Y,
                  (1 => Glyphs.Vertical), Item.Appearance);
            end loop;
         end;
      end if;

      Content_Window.Overlay (Content, Content_X, Content_Y);
      Frame.Overlay
        (Content_Window,
         Natural (Measurement.Content.X),
         Natural (Measurement.Content.Y));
      Result.Overlay (Frame, 0, 0);
      return Result;
   end Render;

   function Content_Region
     (Item   : Block;
      Chrome : Flyology_TUI.Skins.Frame_Chrome)
      return Flyology_TUI.Geometry.Rectangle
   is
      Measurement : constant Frame_Measurement :=
        Measure (Item, 0, 0, Chrome, Exact_Outer => True);
   begin
      return Measurement.Content;
   end Content_Region;

   function Panel_Content_Region
     (Item   : Block;
      Chrome : Flyology_TUI.Skins.Panel_Chrome)
      return Flyology_TUI.Geometry.Rectangle
   is
      Result : Flyology_TUI.Geometry.Rectangle :=
        Content_Region (Item, Chrome.Frame);
      Title_Rows : constant Natural :=
        (if Chrome.Title = Flyology_TUI.Skins.Leading_Title then 2 else 0);
      Reserved : constant Natural := Natural'Min (Result.Height, Title_Rows);
   begin
      Result.Y := Result.Y + Integer (Reserved);
      Result.Height := Result.Height - Reserved;
      return Result;
   end Panel_Content_Region;

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
