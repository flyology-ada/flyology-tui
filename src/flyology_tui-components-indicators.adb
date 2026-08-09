with Flyology_TUI.Glyphs;

package body Flyology_TUI.Components.Indicators is

   function From_Theme
     (Theme : Flyology_TUI.Themes.Theme) return Appearance
   is (Primary   => Theme.Primary,
       Muted     => Theme.Muted,
       Success   => Theme.Success,
       Warning   => Theme.Focused,
       Error     => Theme.Error,
       Separator => Theme.Border);

   function Style_For
     (Kind : Tone;
      Value : Appearance) return Flyology_TUI.Styles.Style
   is (case Kind is
          when Neutral      => Value.Primary,
          when Success_Tone => Value.Success,
          when Warning_Tone => Value.Warning,
          when Error_Tone   => Value.Error);

   function Badge
     (Label      : Wide_Wide_String;
      Kind       : Tone := Neutral;
      Appearance : Indicators.Appearance := (others => <>))
      return Flyology_TUI.Surfaces.Surface
   is
      Label_Width : constant Natural := Flyology_TUI.Glyphs.Width_Of (Label);
   begin
      if Label_Width > Natural'Last - 2 then
         raise Flyology_TUI.Components.Capacity_Error;
      end if;
      declare
         Result : Flyology_TUI.Surfaces.Surface :=
           Flyology_TUI.Surfaces.Create (Label_Width + 2, 1);
      begin
         Result.Write (0, 0, "[" & Label & "]", Style_For (Kind, Appearance));
         return Result;
      end;
   end Badge;

   function Badge
     (Label : Wide_Wide_String;
      Kind  : Tone := Neutral;
      Theme : Flyology_TUI.Themes.Theme)
      return Flyology_TUI.Surfaces.Surface
   is (Badge (Label, Kind, From_Theme (Theme)));

   function Divider
     (Width      : Natural;
      Label      : Wide_Wide_String := "";
      Appearance : Indicators.Appearance := (others => <>))
      return Flyology_TUI.Surfaces.Surface
   is
      Result : Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.Create (Width, 1);
   begin
      if Width > 0 then
         for Column in 0 .. Width - 1 loop
            Result.Put (Column, 0, "─", Appearance.Separator);
         end loop;
      end if;
      if Label'Length > 0 and then Width > 0 then
         declare
            Content : constant Wide_Wide_String := " " & Label & " ";
            Content_Width : constant Natural :=
              Flyology_TUI.Glyphs.Width_Of (Content);
            Start : constant Natural :=
              (if Content_Width >= Width then 0
               else (Width - Content_Width) / 2);
         begin
            Result.Write (Start, 0, Content, Appearance.Primary);
         end;
      end if;
      return Result;
   end Divider;

   function Divider
     (Width : Natural;
      Label : Wide_Wide_String := "";
      Theme : Flyology_TUI.Themes.Theme)
      return Flyology_TUI.Surfaces.Surface
   is (Divider (Width, Label, From_Theme (Theme)));

   function Gauge
     (Value      : Ratio;
      Width      : Natural;
      Appearance : Indicators.Appearance := (others => <>))
      return Flyology_TUI.Surfaces.Surface
   is
      Result : Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.Create (Width, 1);
      Filled : constant Natural :=
        Natural (Long_Float'Floor (Value * Long_Float (Width)));
   begin
      if Width > 0 then
         for Column in 0 .. Width - 1 loop
            if Column < Filled then
               Result.Put (Column, 0, "█", Appearance.Success);
            else
               Result.Put (Column, 0, "░", Appearance.Muted);
            end if;
         end loop;
      end if;
      return Result;
   end Gauge;

   function Gauge
     (Value : Ratio;
      Width : Natural;
      Theme : Flyology_TUI.Themes.Theme)
      return Flyology_TUI.Surfaces.Surface
   is (Gauge (Value, Width, From_Theme (Theme)));

   function Key_Value
     (Key, Value : Wide_Wide_String;
      Width      : Natural;
      Appearance : Indicators.Appearance := (others => <>))
      return Flyology_TUI.Surfaces.Surface
   is
      Result : Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.Create (Width, 1);
      Value_Width : constant Natural := Flyology_TUI.Glyphs.Width_Of (Value);
   begin
      if Width = 0 then
         return Result;
      elsif Value_Width >= Width then
         Result.Write (0, 0, Value, Appearance.Primary);
      else
         Result.Write (0, 0, Key, Appearance.Muted);
         Result.Write (Width - Value_Width, 0, Value, Appearance.Primary);
      end if;
      return Result;
   end Key_Value;

   function Key_Value
     (Key, Value : Wide_Wide_String;
      Width      : Natural;
      Theme      : Flyology_TUI.Themes.Theme)
      return Flyology_TUI.Surfaces.Surface
   is (Key_Value (Key, Value, Width, From_Theme (Theme)));

   function Make_Segment
     (Label    : Wide_Wide_String;
      Priority : Segment_Priority := Normal;
      Kind     : Tone := Neutral) return Status_Segment
   is (Label    => Text.To_Unbounded_Wide_Wide_String (Label),
       Priority => Priority,
       Kind     => Kind);

   function Status_Line
     (Segments   : Segment_Array;
      Width      : Natural;
      Appearance : Indicators.Appearance := (others => <>))
      return Flyology_TUI.Surfaces.Surface
   is
      Included : array (1 .. Maximum_Segments) of Boolean := (others => False);
      Count : constant Natural := Segments'Length;
      Separator_Width : constant Natural := 3;

      function Segment_At (Offset : Positive) return Status_Segment is
        (Segments (Segments'First + (Offset - 1)));

      function Fits return Boolean is
         Used : Natural := 0;
         Seen : Boolean := False;
      begin
         for Offset in 1 .. Count loop
            if Included (Offset) then
               declare
                  Label_Width : constant Natural :=
                    Flyology_TUI.Glyphs.Width_Of
                      (Text.To_Wide_Wide_String
                         (Segment_At (Offset).Label));
               begin
                  if Seen then
                     if Used > Width
                       or else Separator_Width > Width - Used
                     then
                        return False;
                     end if;
                     Used := Used + Separator_Width;
                  end if;
                  if Used > Width or else Label_Width > Width - Used then
                     return False;
                  end if;
                  Used := Used + Label_Width;
                  Seen := True;
               end;
            end if;
         end loop;
         return True;
      end Fits;

      function Included_Count return Natural is
         Result : Natural := 0;
      begin
         for Offset in 1 .. Count loop
            if Included (Offset) then
               Result := Result + 1;
            end if;
         end loop;
         return Result;
      end Included_Count;

      Result : Flyology_TUI.Surfaces.Surface;
   begin
      if Count > Maximum_Segments then
         raise Flyology_TUI.Components.Capacity_Error;
      end if;

      Result := Flyology_TUI.Surfaces.Create (Width, 1);
      for Offset in 1 .. Count loop
         Included (Offset) := True;
      end loop;

      while not Fits and then Included_Count > 1 loop
         declare
            Candidate : Positive := 1;
            Found : Boolean := False;
         begin
            --  Ascending iteration plus <= makes equal-priority ties choose
            --  the rightmost segment.
            for Offset in 1 .. Count loop
               if Included (Offset)
                 and then
                   (not Found
                    or else
                      Segment_At (Offset).Priority <=
                        Segment_At (Candidate).Priority)
               then
                  Candidate := Offset;
                  Found := True;
               end if;
            end loop;
            Included (Candidate) := False;
         end;
      end loop;

      declare
         Column : Natural := 0;
         Seen : Boolean := False;
      begin
         for Offset in 1 .. Count loop
            if Included (Offset) then
               if Seen and then Column < Width then
                  Result.Write
                    (Column, 0, " │ ", Appearance.Separator);
                  declare
                     Consumed : constant Natural :=
                       Natural'Min (Width - Column, Separator_Width);
                  begin
                     Column := Column + Consumed;
                  end;
               end if;
               if Column < Width then
                  declare
                     Label : constant Wide_Wide_String :=
                       Text.To_Wide_Wide_String (Segment_At (Offset).Label);
                  begin
                     Result.Write
                       (Column,
                        0,
                        Label,
                        Style_For (Segment_At (Offset).Kind, Appearance));
                     declare
                        Consumed : constant Natural := Natural'Min
                          (Width - Column,
                           Flyology_TUI.Glyphs.Width_Of (Label));
                     begin
                        Column := Column + Consumed;
                     end;
                  end;
               end if;
               Seen := True;
            end if;
         end loop;
      end;
      return Result;
   end Status_Line;

   function Status_Line
     (Segments : Segment_Array;
      Width    : Natural;
      Theme    : Flyology_TUI.Themes.Theme)
      return Flyology_TUI.Surfaces.Surface
   is (Status_Line (Segments, Width, From_Theme (Theme)));

end Flyology_TUI.Components.Indicators;
