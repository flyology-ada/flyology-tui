with Ada.Numerics.Long_Elementary_Functions;
with Ada.Strings.Wide_Wide_Unbounded;
with Flyology_TUI.Styles;

package body Flyology_TUI.Components.Gradients is

   function Create
     (Max_Stops    : Positive;
      Initial_Color : RGB_Color := (others => 0);
      Flow          : Direction := Horizontal;
      Application   : Color_Application := Apply_Foreground;
      Interpolation : Interpolation_Mode := SRGB_Channels) return Model
   is
   begin
      return Result : Model (Max_Stops) do
         Result.Stops (1) := (Offset => 0, Color => Initial_Color);
         Result.Current_Flow := Flow;
         Result.Paint := Application;
         Result.Mode := Interpolation;
      end return;
   end Create;

   procedure Try_Set_Stops
     (Item    : in out Model;
      Values  : Stop_Array;
      Success : out Boolean)
   is
      Previous : Stop_Offset := 0;
      First    : Boolean := True;
      Position : Positive := 1;
   begin
      Success := False;
      if Values'Length = 0 or else Values'Length > Item.Max_Stops then
         return;
      end if;
      for Value of Values loop
         if not First and then Value.Offset <= Previous then
            return;
         end if;
         Previous := Value.Offset;
         First := False;
      end loop;
      for Value of Values loop
         Item.Stops (Position) := Value;
         if Position < Values'Length then
            Position := Position + 1;
         end if;
      end loop;
      Item.Length := Values'Length;
      Success := True;
   end Try_Set_Stops;

   procedure Set_Solid (Item : in out Model; Color : RGB_Color) is
   begin
      Item.Stops (1) := (Offset => 0, Color => Color);
      Item.Length := 1;
   end Set_Solid;

   function Stop_Count (Item : Model) return Positive is (Item.Length);
   function Stop_At (Item : Model; Position : Positive) return Stop is
     (Item.Stops (Position));

   procedure Set_Direction (Item : in out Model; Flow : Direction) is
   begin
      Item.Current_Flow := Flow;
   end Set_Direction;
   function Flow (Item : Model) return Direction is (Item.Current_Flow);

   procedure Set_Application
     (Item : in out Model; Application : Color_Application) is
   begin
      Item.Paint := Application;
   end Set_Application;
   function Application (Item : Model) return Color_Application is
     (Item.Paint);

   procedure Set_Interpolation
     (Item : in out Model; Interpolation : Interpolation_Mode) is
   begin
      Item.Mode := Interpolation;
   end Set_Interpolation;
   function Interpolation (Item : Model) return Interpolation_Mode is
     (Item.Mode);

   function Rounded_Weighted_Channel
     (First, Last : Flyology_TUI.Colors.Channel;
      Numerator, Denominator : Natural)
      return Flyology_TUI.Colors.Channel
   is
      Weighted : constant Long_Long_Integer :=
        Long_Long_Integer (First)
          * Long_Long_Integer (Denominator - Numerator)
        + Long_Long_Integer (Last) * Long_Long_Integer (Numerator);
      Quotient : Long_Long_Integer :=
        Weighted / Long_Long_Integer (Denominator);
      Remainder : constant Long_Long_Integer :=
        Weighted mod Long_Long_Integer (Denominator);
   begin
      if Remainder * 2 >= Long_Long_Integer (Denominator) then
         Quotient := Quotient + 1;
      end if;
      return Flyology_TUI.Colors.Channel (Quotient);
   end Rounded_Weighted_Channel;

   function Decode_SRGB
     (Value : Flyology_TUI.Colors.Channel) return Long_Float
   is
      Encoded : constant Long_Float := Long_Float (Value) / 255.0;
   begin
      if Encoded <= 0.04045 then
         return Encoded / 12.92;
      else
         return Ada.Numerics.Long_Elementary_Functions.Exp
           (2.4
            * Ada.Numerics.Long_Elementary_Functions.Log
                ((Encoded + 0.055) / 1.055));
      end if;
   end Decode_SRGB;

   function Encode_SRGB (Value : Long_Float)
      return Flyology_TUI.Colors.Channel
   is
      Encoded : Long_Float;
      Rounded : Integer;
   begin
      if Value <= 0.0 then
         return 0;
      elsif Value >= 1.0 then
         return 255;
      elsif Value <= 0.003_130_8 then
         Encoded := 12.92 * Value;
      else
         Encoded :=
           1.055
           * Ada.Numerics.Long_Elementary_Functions.Exp
               (Ada.Numerics.Long_Elementary_Functions.Log (Value) / 2.4)
           - 0.055;
      end if;
      Rounded := Integer (Long_Float'Rounding (Encoded * 255.0));
      return Flyology_TUI.Colors.Channel
        (Integer'Max (0, Integer'Min (255, Rounded)));
   end Encode_SRGB;

   function Interpolate_Channel
     (First, Last : Flyology_TUI.Colors.Channel;
      Numerator, Denominator : Natural;
      Mode : Interpolation_Mode) return Flyology_TUI.Colors.Channel
   is
      Ratio : Long_Float;
      Light : Long_Float;
   begin
      if Numerator = 0 then
         return First;
      elsif Numerator = Denominator then
         return Last;
      elsif Mode = SRGB_Channels then
         return Rounded_Weighted_Channel
           (First, Last, Numerator, Denominator);
      end if;
      Ratio := Long_Float (Numerator) / Long_Float (Denominator);
      Light := Decode_SRGB (First)
        + (Decode_SRGB (Last) - Decode_SRGB (First)) * Ratio;
      return Encode_SRGB (Light);
   end Interpolate_Channel;

   function Interpolate
     (First, Last : RGB_Color;
      Numerator, Denominator : Natural;
      Mode : Interpolation_Mode) return RGB_Color is
     (Red => Interpolate_Channel
        (First.Red, Last.Red, Numerator, Denominator, Mode),
      Green => Interpolate_Channel
        (First.Green, Last.Green, Numerator, Denominator, Mode),
      Blue => Interpolate_Channel
        (First.Blue, Last.Blue, Numerator, Denominator, Mode));

   function Sample (Item : Model; Offset : Stop_Offset) return RGB_Color is
   begin
      if Item.Length = 1 or else Offset <= Item.Stops (1).Offset then
         return Item.Stops (1).Color;
      elsif Offset >= Item.Stops (Item.Length).Offset then
         return Item.Stops (Item.Length).Color;
      end if;
      for Position in 1 .. Item.Length - 1 loop
         if Offset <= Item.Stops (Position + 1).Offset then
            return Interpolate
              (Item.Stops (Position).Color,
               Item.Stops (Position + 1).Color,
               Offset - Item.Stops (Position).Offset,
               Item.Stops (Position + 1).Offset
                 - Item.Stops (Position).Offset,
               Item.Mode);
         end if;
      end loop;
      raise Program_Error;
   end Sample;

   function Heatmap
     (Item : Model;
      Value, Minimum, Maximum : Long_Float) return RGB_Color
   is
      Scale   : Long_Float;
      Ratio   : Long_Float;
      Rounded : Long_Float;
   begin
      if Value <= Minimum then
         return Sample (Item, Stop_Offset'First);
      elsif Value >= Maximum then
         return Sample (Item, Stop_Offset'Last);
      end if;
      --  Normalize before subtracting.  For a domain spanning nearly the
      --  complete finite Long_Float range, either unscaled subtraction can
      --  overflow even though the mathematical ratio is in 0.0 .. 1.0.
      Scale := Long_Float'Max (abs Minimum, abs Maximum);
      Ratio :=
        (Value / Scale - Minimum / Scale)
        / (Maximum / Scale - Minimum / Scale);
      Rounded := Long_Float'Rounding (Ratio * Long_Float (Stop_Scale));
      return Sample
        (Item,
         Stop_Offset
           (Long_Float'Max
              (0.0, Long_Float'Min (Long_Float (Stop_Scale), Rounded))));
   end Heatmap;

   function Offset_At (Position, Extent : Natural) return Stop_Offset is
      Denominator : Long_Long_Integer;
      Scaled      : Long_Long_Integer;
   begin
      if Extent <= 1 then
         return 0;
      end if;
      Denominator := Long_Long_Integer (Extent - 1);
      Scaled := Long_Long_Integer (Position) * Long_Long_Integer (Stop_Scale);
      return Stop_Offset
        ((Scaled + Denominator / 2) / Denominator);
   end Offset_At;

   function With_Color
     (Value : Flyology_TUI.Styles.Style;
      Color : RGB_Color;
      Paint : Color_Application) return Flyology_TUI.Styles.Style
   is
      Result : Flyology_TUI.Styles.Style := Value;
      Applied : constant Flyology_TUI.Colors.Color :=
        Flyology_TUI.Colors.True_Color
          (Color.Red, Color.Green, Color.Blue);
   begin
      if Paint in Apply_Foreground | Apply_Both then
         Result.Foreground := Applied;
      end if;
      if Paint in Apply_Background | Apply_Both then
         Result.Background := Applied;
      end if;
      return Result;
   end With_Color;

   procedure Apply
     (Item   : Model;
      Target : in out Flyology_TUI.Surfaces.Surface;
      Region : Flyology_TUI.Geometry.Rectangle)
   is
      subtype Wide_Coordinate is Long_Long_Integer;
      Region_Left : constant Wide_Coordinate := Wide_Coordinate (Region.X);
      Region_Top  : constant Wide_Coordinate := Wide_Coordinate (Region.Y);
      Region_Right : constant Wide_Coordinate :=
        Region_Left + Wide_Coordinate (Region.Width);
      Region_Bottom : constant Wide_Coordinate :=
        Region_Top + Wide_Coordinate (Region.Height);
      Width  : constant Natural := Flyology_TUI.Surfaces.Width (Target);
      Height : constant Natural := Flyology_TUI.Surfaces.Height (Target);
   begin
      if Region.Width = 0 or else Region.Height = 0
        or else Width = 0 or else Height = 0
      then
         return;
      end if;
      for Y in 0 .. Height - 1 loop
         for X in 0 .. Width - 1 loop
            declare
               Cell : constant Flyology_TUI.Surfaces.Cell :=
                 Target.Element (X, Y);
               Span : constant Natural :=
                 (if not Cell.Continuation
                    and then X + 1 < Width
                    and then Target.Element (X + 1, Y).Continuation
                  then 2 else 1);
               Cell_Left : constant Wide_Coordinate := Wide_Coordinate (X);
               Cell_Top  : constant Wide_Coordinate := Wide_Coordinate (Y);
               Inside : constant Boolean :=
                 not Cell.Continuation
                 and then Cell_Left >= Region_Left
                 and then Cell_Left + Wide_Coordinate (Span) <= Region_Right
                 and then Cell_Top >= Region_Top
                 and then Cell_Top < Region_Bottom;
            begin
               if Inside then
                  declare
                     Axis_Position : constant Natural :=
                       (if Item.Current_Flow = Horizontal
                        then Natural (Cell_Left - Region_Left)
                        else Natural (Cell_Top - Region_Top));
                     Axis_Extent : constant Natural :=
                       (if Item.Current_Flow = Horizontal
                        then Region.Width else Region.Height);
                     Color : constant RGB_Color :=
                       Item.Sample (Offset_At (Axis_Position, Axis_Extent));
                  begin
                     Target.Put
                       (X, Y,
                        Ada.Strings.Wide_Wide_Unbounded.To_Wide_Wide_String
                          (Cell.Glyph),
                        With_Color (Cell.Appearance, Color, Item.Paint));
                  end;
               end if;
            end;
         end loop;
      end loop;
   end Apply;

end Flyology_TUI.Components.Gradients;
