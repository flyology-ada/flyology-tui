package body Flyology_TUI.Components.Sparklines is
   --  Converted IEEE special values must reach Is_Finite so the component can
   --  report Structure_Error consistently even in validation builds.
   pragma Suppress (Validity_Check);

   function Is_Finite (Value : Long_Float) return Boolean is
     (Value = Value
      and then Value >= -Long_Float'Last
      and then Value <= Long_Float'Last);

   function Converted (Value : Samples.Value_Type) return Long_Float is
      Result : constant Long_Float := To_Long_Float (Value);
   begin
      if not Is_Finite (Result) then
         raise Flyology_TUI.Components.Structure_Error;
      end if;
      return Result;
   end Converted;

   function From_Theme
     (Theme : Flyology_TUI.Themes.Theme) return Appearance
   is (Low    => Theme.Muted,
       Medium => Theme.Primary,
       High   => Theme.Success);

   function Fixed
     (Minimum, Maximum : Long_Float) return Scale is
   begin
      if not Is_Finite (Minimum)
        or else not Is_Finite (Maximum)
        or else Minimum >= Maximum
      then
         raise Flyology_TUI.Components.Structure_Error;
      end if;
      return (Mode => Fixed_Range, Minimum => Minimum, Maximum => Maximum);
   end Fixed;

   function Normalized
     (Value, Minimum, Maximum : Long_Float) return Long_Float
   is
   begin
      if Value <= Minimum then
         return 0.0;
      elsif Value >= Maximum then
         return 1.0;
      elsif Minimum < 0.0 and then Maximum > 0.0 then
         declare
            Scale_By : constant Long_Float :=
              Long_Float'Max (-Minimum, Maximum);
         begin
            return
              (Value / Scale_By - Minimum / Scale_By)
              / (Maximum / Scale_By - Minimum / Scale_By);
         end;
      else
         return (Value - Minimum) / (Maximum - Minimum);
      end if;
   end Normalized;

   function Bar (Index : Natural) return Wide_Wide_String is
   begin
      case Index is
         when 0 => return "▁";
         when 1 => return "▂";
         when 2 => return "▃";
         when 3 => return "▄";
         when 4 => return "▅";
         when 5 => return "▆";
         when 6 => return "▇";
         when others => return "█";
      end case;
   end Bar;

   function Render
     (Item       : Samples.Series;
      Width      : Natural;
      Scaling    : Scale := Automatic;
      Appearance : Sparklines.Appearance := (others => <>))
      return Flyology_TUI.Surfaces.Surface
   is
      Result : Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.Create (Width, 1);
      Count : constant Natural := Samples.Length (Item);
   begin
      --  Validate every stored value, including samples outside the visible
      --  suffix, so a narrower render cannot conceal invalid input.
      for Index in 1 .. Count loop
         declare
            Discard : constant Long_Float :=
              Converted (Samples.Element (Item, Index));
            pragma Unreferenced (Discard);
         begin
            null;
         end;
      end loop;

      if Width = 0 or else Count = 0 then
         return Result;
      end if;

      declare
         Visible : constant Natural := Natural'Min (Width, Count);
         First   : constant Positive := Count - Visible + 1;
         Minimum : Long_Float;
         Maximum : Long_Float;
      begin
         if Scaling.Mode = Fixed_Range then
            if not Is_Finite (Scaling.Minimum)
              or else not Is_Finite (Scaling.Maximum)
              or else Scaling.Minimum >= Scaling.Maximum
            then
               raise Flyology_TUI.Components.Structure_Error;
            end if;
            Minimum := Scaling.Minimum;
            Maximum := Scaling.Maximum;
         else
            Minimum := Converted (Samples.Element (Item, First));
            Maximum := Minimum;
            if First < Count then
               for Index in First + 1 .. Count loop
                  declare
                     Value : constant Long_Float :=
                       Converted (Samples.Element (Item, Index));
                  begin
                     Minimum := Long_Float'Min (Minimum, Value);
                     Maximum := Long_Float'Max (Maximum, Value);
                  end;
               end loop;
            end if;
         end if;

         for Offset in 0 .. Visible - 1 loop
            declare
               Value : constant Long_Float :=
                 Converted (Samples.Element (Item, First + Offset));
               Ratio : constant Long_Float :=
                 (if Maximum = Minimum
                  then 0.5
                  else Normalized (Value, Minimum, Maximum));
               Level : constant Natural := Natural'Min
                 (7, Natural (Long_Float'Floor (Ratio * 7.0)));
               Style : constant Flyology_TUI.Styles.Style :=
                 (if Level <= 2 then Appearance.Low
                  elsif Level <= 5 then Appearance.Medium
                  else Appearance.High);
            begin
               Result.Put (Offset, 0, Bar (Level), Style);
            end;
         end loop;
      end;
      return Result;
   end Render;

   function Render
     (Item    : Samples.Series;
      Width   : Natural;
      Scaling : Scale := Automatic;
      Theme   : Flyology_TUI.Themes.Theme)
      return Flyology_TUI.Surfaces.Surface
   is (Render (Item, Width, Scaling, From_Theme (Theme)));

end Flyology_TUI.Components.Sparklines;
