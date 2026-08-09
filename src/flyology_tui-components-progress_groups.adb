with Flyology_TUI.Glyphs;

package body Flyology_TUI.Components.Progress_Groups is
   use type Flyology_TUI.Events.Key_Kind;
   use type Flyology_TUI.Events.Mouse_Action;
   use type Flyology_TUI.Events.Mouse_Button;
   use type Flyology_TUI.Events.Terminal_Event_Kind;

   function From_Theme
     (Theme : Flyology_TUI.Themes.Theme) return Appearance
   is (Label         => Theme.Muted,
       Selected      => Theme.Selected,
       Complete      => Theme.Success,
       Remaining     => Theme.Muted,
       Indeterminate => Theme.Primary);

   function Create (Width : Natural := 40) return Model is
      Result : Model;
   begin
      Result.Columns := Width;
      return Result;
   end Create;

   function Index_Of (Item : Model; Id : Item_Id) return Natural is
   begin
      for Index in 1 .. Item.Count loop
         if Item.Entries (Index).Id = Id then
            return Index;
         end if;
      end loop;
      return 0;
   end Index_Of;

   function Contains (Item : Model; Id : Item_Id) return Boolean is
     (Index_Of (Item, Id) /= 0);

   procedure Validate_New
     (Item : Model;
      Id   : Item_Id;
      Relative_Weight : Weight)
   is
   begin
      if Contains (Item, Id)
        or else Relative_Weight /= Relative_Weight
        or else Relative_Weight > Long_Float'Last
      then
         raise Flyology_TUI.Components.Structure_Error;
      elsif Item.Count = Maximum_Items then
         raise Flyology_TUI.Components.Capacity_Error;
      end if;
   end Validate_New;

   procedure Add_Determinate
     (Item          : in out Model;
      Id            : Item_Id;
      Label         : Wide_Wide_String;
      Relative_Weight : Weight := 1.0;
      Value         : Fraction := 0.0)
   is
      New_Entry : Row_Entry;
   begin
      Validate_New (Item, Id, Relative_Weight);
      if Value /= Value then
         raise Flyology_TUI.Components.Structure_Error;
      end if;
      New_Entry :=
        (Id              => Id,
         Label           => Text.To_Unbounded_Wide_Wide_String (Label),
         Kind            => Determinate,
         Current         => Value,
         Relative_Weight => Relative_Weight,
         Phase           => 0);
      Item.Entries (Item.Count + 1) := New_Entry;
      Item.Count := Item.Count + 1;
      if Item.Selected = 0 then
         Item.Selected := 1;
      end if;
   end Add_Determinate;

   procedure Add_Indeterminate
     (Item          : in out Model;
      Id            : Item_Id;
      Label         : Wide_Wide_String;
      Relative_Weight : Weight := 1.0)
   is
      New_Entry : Row_Entry;
   begin
      Validate_New (Item, Id, Relative_Weight);
      New_Entry :=
        (Id              => Id,
         Label           => Text.To_Unbounded_Wide_Wide_String (Label),
         Kind            => Indeterminate,
         Current         => 0.0,
         Relative_Weight => Relative_Weight,
         Phase           => 0);
      Item.Entries (Item.Count + 1) := New_Entry;
      Item.Count := Item.Count + 1;
      if Item.Selected = 0 then
         Item.Selected := 1;
      end if;
   end Add_Indeterminate;

   procedure Remove (Item : in out Model; Id : Item_Id) is
      Index : constant Natural := Index_Of (Item, Id);
   begin
      if Index = 0 then
         raise Flyology_TUI.Components.Structure_Error;
      end if;

      for Position in Index .. Item.Count - 1 loop
         Item.Entries (Position) := Item.Entries (Position + 1);
      end loop;
      Item.Count := Item.Count - 1;

      if Item.Count = 0 then
         Item.Selected := 0;
      elsif Item.Selected > Index then
         Item.Selected := Item.Selected - 1;
      elsif Item.Selected = Index then
         Item.Selected := Natural'Min (Index, Item.Count);
      end if;
   end Remove;

   procedure Set_Value
     (Item : in out Model;
      Id   : Item_Id;
      Value : Fraction)
   is
      Index : constant Natural := Index_Of (Item, Id);
   begin
      if Index = 0 then
         raise Flyology_TUI.Components.Structure_Error;
      elsif Value /= Value then
         raise Flyology_TUI.Components.Structure_Error;
      end if;
      Item.Entries (Index).Kind := Determinate;
      Item.Entries (Index).Current := Value;
      Item.Entries (Index).Phase := 0;
   end Set_Value;

   procedure Set_Indeterminate (Item : in out Model; Id : Item_Id) is
      Index : constant Natural := Index_Of (Item, Id);
   begin
      if Index = 0 then
         raise Flyology_TUI.Components.Structure_Error;
      end if;
      Item.Entries (Index).Kind := Indeterminate;
      Item.Entries (Index).Phase := 0;
   end Set_Indeterminate;

   procedure Advance (Item : in out Model; Steps : Positive := 1) is
      Phase_Step : constant Natural := Steps mod 4;
   begin
      for Index in 1 .. Item.Count loop
         if Item.Entries (Index).Kind = Indeterminate then
            Item.Entries (Index).Phase :=
              (Item.Entries (Index).Phase + Phase_Step) mod 4;
         end if;
      end loop;
   end Advance;

   function Length (Item : Model) return Natural is (Item.Count);
   function Is_Empty (Item : Model) return Boolean is (Item.Count = 0);

   function State (Item : Model; Id : Item_Id) return Progress_State is
      Index : constant Natural := Index_Of (Item, Id);
   begin
      if Index = 0 then
         raise Flyology_TUI.Components.Structure_Error;
      end if;
      return Item.Entries (Index).Kind;
   end State;

   function Value (Item : Model; Id : Item_Id) return Fraction is
      Index : constant Natural := Index_Of (Item, Id);
   begin
      if Index = 0 or else Item.Entries (Index).Kind /= Determinate then
         raise Flyology_TUI.Components.Structure_Error;
      end if;
      return Item.Entries (Index).Current;
   end Value;

   function Has_Selection (Item : Model) return Boolean is
     (Item.Selected in 1 .. Item.Count);

   function Selected_Id (Item : Model) return Item_Id is
     (Item.Entries (Item.Selected).Id);

   procedure Select_Item (Item : in out Model; Id : Item_Id) is
      Index : constant Natural := Index_Of (Item, Id);
   begin
      if Index = 0 then
         raise Flyology_TUI.Components.Structure_Error;
      end if;
      Item.Selected := Index;
   end Select_Item;

   function Weighted_Total (Item : Model) return Fraction is
      Largest : Long_Float := 0.0;
   begin
      for Index in 1 .. Item.Count loop
         if Item.Entries (Index).Kind = Determinate then
            Largest := Long_Float'Max
              (Largest, Item.Entries (Index).Relative_Weight);
         end if;
      end loop;
      if Largest = 0.0 then
         return 0.0;
      end if;
      declare
         Total_Weight : Long_Float := 0.0;
         Total_Value  : Long_Float := 0.0;
      begin
         for Index in 1 .. Item.Count loop
            if Item.Entries (Index).Kind = Determinate
              and then Item.Entries (Index).Relative_Weight > 0.0
            then
               declare
                  Scaled : constant Long_Float :=
                    Item.Entries (Index).Relative_Weight / Largest;
               begin
                  Total_Weight := Total_Weight + Scaled;
                  Total_Value :=
                    Total_Value + Scaled * Item.Entries (Index).Current;
               end;
            end if;
         end loop;
         return Fraction (Total_Value / Total_Weight);
      end;
   end Weighted_Total;

   function Move
     (Item   : in out Model;
      Amount : Integer) return Boolean
   is
      Previous : constant Natural := Item.Selected;
   begin
      if Item.Count = 0 then
         return False;
      elsif Item.Selected = 0 then
         Item.Selected := 1;
      elsif Amount < 0 then
         for Step in 1 .. Natural'Min (Natural (-Amount), Item.Selected - 1)
         loop
            Item.Selected := Item.Selected - 1;
         end loop;
      elsif Amount > 0 then
         for Step in 1 .. Natural'Min
           (Natural (Amount), Item.Count - Item.Selected)
         loop
            Item.Selected := Item.Selected + 1;
         end loop;
      end if;
      return Item.Selected /= Previous;
   end Move;

   function Handle
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Terminal_Event)
      return Flyology_TUI.Components.Interactions.Update_Result
   is
      Result : Flyology_TUI.Components.Interactions.Update_Result;
   begin
      if Event.Kind /= Flyology_TUI.Events.Key_Press then
         return Result;
      end if;

      case Event.Key.Kind is
         when Flyology_TUI.Events.Arrow_Up_Key =>
            Result.Handled := True;
            Result.Changed := Move (Item, -1);
         when Flyology_TUI.Events.Arrow_Down_Key =>
            Result.Handled := True;
            Result.Changed := Move (Item, 1);
         when Flyology_TUI.Events.Home_Key =>
            Result.Handled := True;
            if Item.Count > 0 then
               Result.Changed := Item.Selected /= 1;
               Item.Selected := 1;
            end if;
         when Flyology_TUI.Events.End_Key =>
            Result.Handled := True;
            if Item.Count > 0 then
               Result.Changed := Item.Selected /= Item.Count;
               Item.Selected := Item.Count;
            end if;
         when Flyology_TUI.Events.Enter_Key =>
            Result.Handled := Item.Count > 0;
            Result.Activated := Item.Count > 0;
         when Flyology_TUI.Events.Text_Key =>
            declare
               Key : constant Wide_Wide_String :=
                 Flyology_TUI.Events.Text.To_Wide_Wide_String
                   (Event.Key.Value);
            begin
               if Key = "j" then
                  Result.Handled := True;
                  Result.Changed := Move (Item, 1);
               elsif Key = "k" then
                  Result.Handled := True;
                  Result.Changed := Move (Item, -1);
               end if;
            end;
         when others =>
            null;
      end case;
      return Result;
   end Handle;

   function Handle
     (Item  : in out Model;
      Event : Flyology_TUI.Mouse.Local_Event)
      return Flyology_TUI.Components.Interactions.Update_Result
   is
      Result : Flyology_TUI.Components.Interactions.Update_Result;
   begin
      if Event.Action = Flyology_TUI.Events.Mouse_Click
        and then Event.Button = Flyology_TUI.Events.Left_Button
        and then Event.X >= 0
        and then Event.X < Integer (Item.Columns)
        and then Event.Y >= 0
        and then Event.Y < Integer (Item.Count)
      then
         declare
            New_Index : constant Positive := Event.Y + 1;
         begin
            Result.Handled := True;
            Result.Focus_Requested := True;
            Result.Changed := Item.Selected /= New_Index;
            Item.Selected := New_Index;
         end;
      elsif Event.Action = Flyology_TUI.Events.Mouse_Wheel
        and then Event.Wheel_Y /= 0
      then
         Result.Handled := True;
         Result.Focus_Requested := True;
         Result.Changed := Move
           (Item,
            (if Event.Wheel_Y > 0 then -1 else 1));
      end if;
      return Result;
   end Handle;

   procedure Update
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Terminal_Event)
   is
      Discard : constant Flyology_TUI.Components.Interactions.Update_Result :=
        Handle (Item, Event);
      pragma Unreferenced (Discard);
   begin
      null;
   end Update;

   procedure Update
     (Item  : in out Model;
      Event : Flyology_TUI.Mouse.Local_Event)
   is
      Discard : constant Flyology_TUI.Components.Interactions.Update_Result :=
        Handle (Item, Event);
      pragma Unreferenced (Discard);
   begin
      null;
   end Update;

   function Label_Width (Item : Model) return Natural is
      Result : Natural := 0;
   begin
      for Index in 1 .. Item.Count loop
         Result := Natural'Max
           (Result,
            Flyology_TUI.Glyphs.Width_Of
              (Text.To_Wide_Wide_String (Item.Entries (Index).Label)));
      end loop;
      return Result;
   end Label_Width;

   function Render
     (Item       : Model;
      Appearance : Progress_Groups.Appearance := (others => <>))
      return Flyology_TUI.Surfaces.Surface
   is
      Result : Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.Create (Item.Columns, Item.Count);
      Labels : constant Natural := Label_Width (Item);
      Bar_Start : constant Natural :=
        (if Item.Columns <= 3 or else Labels >= Item.Columns - 3
         then Item.Columns
         else Labels + 3);
      Bar_Width : constant Natural := Item.Columns - Bar_Start;
   begin
      for Index in 1 .. Item.Count loop
         declare
            Row : constant Natural := Index - 1;
            Label_Style : constant Flyology_TUI.Styles.Style :=
              (if Index = Item.Selected
               then Appearance.Selected
               else Appearance.Label);
         begin
            Result.Write
              (0,
               Row,
               (if Index = Item.Selected then "› " else "  ")
               & Text.To_Wide_Wide_String (Item.Entries (Index).Label),
               Label_Style);

            if Bar_Width > 0 then
               if Item.Entries (Index).Kind = Determinate then
                  declare
                     Filled : constant Natural := Natural
                       (Long_Float'Floor
                          (Item.Entries (Index).Current
                           * Long_Float (Bar_Width)));
                  begin
                     for Offset in 0 .. Bar_Width - 1 loop
                        if Offset < Filled then
                           Result.Put
                             (Bar_Start + Offset,
                              Row,
                              "█",
                              Appearance.Complete);
                        else
                           Result.Put
                             (Bar_Start + Offset,
                              Row,
                              "░",
                              Appearance.Remaining);
                        end if;
                     end loop;
                  end;
               else
                  for Offset in 0 .. Bar_Width - 1 loop
                     Result.Put
                       (Bar_Start + Offset,
                        Row,
                        (if Offset = Item.Entries (Index).Phase mod Bar_Width
                         then "▓" else "░"),
                        (if Offset = Item.Entries (Index).Phase mod Bar_Width
                         then Appearance.Indeterminate
                         else Appearance.Remaining));
                  end loop;
               end if;
            end if;
         end;
      end loop;
      return Result;
   end Render;

   function Render
     (Item  : Model;
      Theme : Flyology_TUI.Themes.Theme)
      return Flyology_TUI.Surfaces.Surface
   is (Render (Item, From_Theme (Theme)));

   function Render_Segments
     (Item       : Model;
      Width      : Natural;
      Appearance : Progress_Groups.Appearance := (others => <>))
      return Flyology_TUI.Surfaces.Surface
   is
      Result : Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.Create (Width, 1);
      Largest : Long_Float := 0.0;
      Last_Positive : Natural := 0;
   begin
      if Width = 0 then
         return Result;
      end if;

      for Index in 1 .. Item.Count loop
         if Item.Entries (Index).Relative_Weight > 0.0 then
            Largest := Long_Float'Max
              (Largest, Item.Entries (Index).Relative_Weight);
            Last_Positive := Index;
         end if;
      end loop;
      if Last_Positive = 0 then
         return Result;
      end if;

      declare
         Total_Scaled : Long_Float := 0.0;
         Column : Natural := 0;
         Segment_Widths : array (1 .. Maximum_Items) of Natural :=
           (others => 0);
         Remainders : array (1 .. Maximum_Items) of Long_Float :=
           (others => 0.0);
         Awarded : array (1 .. Maximum_Items) of Boolean :=
           (others => False);
         Used : Natural := 0;
      begin
         for Index in 1 .. Item.Count loop
            if Item.Entries (Index).Relative_Weight > 0.0 then
               Total_Scaled := Total_Scaled
                 + Item.Entries (Index).Relative_Weight / Largest;
            end if;
         end loop;

         for Index in 1 .. Item.Count loop
            if Item.Entries (Index).Relative_Weight > 0.0 then
               declare
                  Exact : constant Long_Float :=
                    (Item.Entries (Index).Relative_Weight / Largest)
                    / Total_Scaled * Long_Float (Width);
                  Base : constant Natural := Natural'Min
                    (Width - Used,
                     Natural (Long_Float'Floor (Exact)));
               begin
                  Segment_Widths (Index) := Base;
                  Remainders (Index) := Exact - Long_Float (Base);
                  Used := Used + Base;
               end;
            end if;
         end loop;

         while Used < Width loop
            declare
               Candidate : Natural := 0;
            begin
               for Index in 1 .. Item.Count loop
                  if Item.Entries (Index).Relative_Weight > 0.0
                    and then not Awarded (Index)
                    and then
                      (Candidate = 0
                       or else Remainders (Index) > Remainders (Candidate))
                  then
                     Candidate := Index;
                  end if;
               end loop;
               if Candidate = 0 then
                  Candidate := Last_Positive;
               end if;
               Segment_Widths (Candidate) :=
                 Segment_Widths (Candidate) + 1;
               Awarded (Candidate) := True;
               Used := Used + 1;
            end;
         end loop;

         for Index in 1 .. Last_Positive loop
            if Item.Entries (Index).Relative_Weight > 0.0 then
               declare
                  Segment_Width : constant Natural := Segment_Widths (Index);
               begin
                  if Segment_Width > 0 then
                     if Item.Entries (Index).Kind = Determinate then
                        declare
                           Filled : constant Natural := Natural
                             (Long_Float'Floor
                                (Item.Entries (Index).Current
                                 * Long_Float (Segment_Width)));
                        begin
                           for Offset in 0 .. Segment_Width - 1 loop
                              Result.Put
                                (Column + Offset,
                                 0,
                                 (if Offset < Filled then "█" else "░"),
                                 (if Offset < Filled
                                  then Appearance.Complete
                                  else Appearance.Remaining));
                           end loop;
                        end;
                     else
                        for Offset in 0 .. Segment_Width - 1 loop
                           declare
                              Is_Marker : constant Boolean :=
                                Offset = Item.Entries (Index).Phase
                                  mod Segment_Width;
                           begin
                              Result.Put
                                (Column + Offset,
                                 0,
                                 (if Is_Marker then "▓" else "░"),
                                 (if Is_Marker
                                  then Appearance.Indeterminate
                                  else Appearance.Remaining));
                           end;
                        end loop;
                     end if;
                     Column := Column + Segment_Width;
                  end if;
               end;
            end if;
         end loop;
      end;
      return Result;
   end Render_Segments;

   function Render_Segments
     (Item  : Model;
      Width : Natural;
      Theme : Flyology_TUI.Themes.Theme)
      return Flyology_TUI.Surfaces.Surface
   is (Render_Segments (Item, Width, From_Theme (Theme)));

end Flyology_TUI.Components.Progress_Groups;
