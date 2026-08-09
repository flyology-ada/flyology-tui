with Flyology_TUI.Glyphs;

package body Flyology_TUI.Components.Trees is
   use type Flyology_TUI.Events.Key_Kind;
   use type Flyology_TUI.Events.Mouse_Action;
   use type Flyology_TUI.Events.Mouse_Button;
   use type Flyology_TUI.Events.Terminal_Event_Kind;

   function From_Theme
     (Theme : Flyology_TUI.Themes.Theme) return Appearance is
     (Normal     => Theme.Primary,
      Selected   => Theme.Selected,
      Focused    => Theme.Focused,
      Muted      => Theme.Muted,
      Disclosure => Theme.Border);

   procedure Validate (Values : Item_Array) is
      Previous_Depth : Natural := 0;
      First          : Boolean := True;
   begin
      if Values'Length > Capacity then
         raise Flyology_TUI.Components.Capacity_Error;
      end if;
      for Position in Values'Range loop
         if First then
            if Depth_Of (Values (Position)) /= 0 then
               raise Flyology_TUI.Components.Structure_Error;
            end if;
            First := False;
         elsif Depth_Of (Values (Position)) > Previous_Depth
           and then Depth_Of (Values (Position)) - Previous_Depth > 1
         then
            raise Flyology_TUI.Components.Structure_Error;
         end if;
         Previous_Depth := Depth_Of (Values (Position));
         for Other in Values'Range loop
            if Other > Position
              and then Id_Of (Values (Position)) = Id_Of (Values (Other))
            then
               raise Flyology_TUI.Components.Structure_Error;
            end if;
         end loop;
      end loop;
   end Validate;

   function Length (Item : Model) return Natural is
     (Natural (Item.Values.Length));
   function Is_Empty (Item : Model) return Boolean is (Item.Values.Is_Empty);
   function Is_Enabled (Item : Model) return Boolean is (Item.Enabled);
   function Viewport_Rows (Item : Model) return Natural is (Item.Rows);
   function Height (Item : Model) return Natural is (Item.Rows);

   function Find (Item : Model; Id : Id_Type) return Natural is
   begin
      if not Item.Values.Is_Empty then
         for Source in 0 .. Natural (Item.Values.Length) - 1 loop
            if Id_Of (Item.Values.Element (Source)) = Id then
               return Source + 1;
            end if;
         end loop;
      end if;
      return 0;
   end Find;

   function Has_Child (Item : Model; Source : Natural) return Boolean is
     (Source + 1 < Natural (Item.Values.Length)
      and then Depth_Of (Item.Values.Element (Source + 1)) =
        Depth_Of (Item.Values.Element (Source)) + 1);

   function Parent_Source (Item : Model; Source : Natural) return Natural is
      Depth : constant Natural := Depth_Of (Item.Values.Element (Source));
   begin
      if Depth = 0 or else Source = 0 then
         return Source;
      end if;
      for Candidate in reverse 0 .. Source - 1 loop
         if Depth_Of (Item.Values.Element (Candidate)) = Depth - 1 then
            return Candidate;
         end if;
      end loop;
      return Source;
   end Parent_Source;

   function Is_Visible_Source
     (Item : Model; Source : Natural) return Boolean
   is
      Current : Natural := Source;
   begin
      while Depth_Of (Item.Values.Element (Current)) > 0 loop
         Current := Parent_Source (Item, Current);
         if not Item.Expanded.Element (Current) then
            return False;
         end if;
      end loop;
      return True;
   end Is_Visible_Source;

   function Visible_Length (Item : Model) return Natural is
      Result : Natural := 0;
   begin
      if not Item.Values.Is_Empty then
         for Source in 0 .. Natural (Item.Values.Length) - 1 loop
            if Is_Visible_Source (Item, Source) then
               Result := Result + 1;
            end if;
         end loop;
      end if;
      return Result;
   end Visible_Length;

   function Source_At_Visible
     (Item : Model; Position : Positive) return Natural
   is
      Seen : Natural := 0;
   begin
      for Source in 0 .. Natural (Item.Values.Length) - 1 loop
         if Is_Visible_Source (Item, Source) then
            Seen := Seen + 1;
            if Seen = Position then
               return Source;
            end if;
         end if;
      end loop;
      raise Constraint_Error;
   end Source_At_Visible;

   function Visible_Position_Of
     (Item : Model; Source : Natural) return Natural
   is
      Seen : Natural := 0;
   begin
      if not Item.Values.Is_Empty then
         for Candidate in 0 .. Natural (Item.Values.Length) - 1 loop
            if Is_Visible_Source (Item, Candidate) then
               Seen := Seen + 1;
               if Candidate = Source then
                  return Seen;
               end if;
            end if;
         end loop;
      end if;
      return 0;
   end Visible_Position_Of;

   procedure Ensure_Selected_Visible (Item : in out Model) is
      Source : Natural;
   begin
      if Item.Values.Is_Empty then
         Item.Selected := 0;
         Item.First := 0;
         return;
      elsif Item.Selected = 0 or else Item.Selected > Length (Item) then
         Item.Selected := 1;
      end if;
      Source := Item.Selected - 1;
      while not Is_Visible_Source (Item, Source) loop
         Source := Parent_Source (Item, Source);
      end loop;
      Item.Selected := Source + 1;
      declare
         Position : constant Natural := Visible_Position_Of (Item, Source);
         Count    : constant Natural := Visible_Length (Item);
      begin
         if Item.Rows = 0 then
            Item.First := Position;
         else
            if Item.First = 0 then
               Item.First := 1;
            end if;
            if Position < Item.First then
               Item.First := Position;
            elsif Position >= Item.First + Item.Rows then
               Item.First := Position - Item.Rows + 1;
            end if;
            Item.First := Natural'Min
              (Item.First,
               (if Count > Item.Rows then Count - Item.Rows + 1 else 1));
         end if;
      end;
   end Ensure_Selected_Visible;

   procedure Set_Nodes (Item : in out Model; Values : Item_Array) is
      New_Values   : Item_Vectors.Vector;
      New_Expanded : Boolean_Vectors.Vector;
      New_Selected : Natural := 0;
   begin
      Validate (Values);
      for Value of Values loop
         New_Values.Append (Value);
         declare
            Old : constant Natural := Find (Item, Id_Of (Value));
         begin
            New_Expanded.Append
              (Old > 0 and then Item.Expanded.Element (Old - 1));
            if Item.Selected > 0
              and then Id_Of (Value) =
                Id_Of (Item.Values.Element (Item.Selected - 1))
            then
               New_Selected := Natural (New_Values.Length);
            end if;
         end;
      end loop;
      Item.Values := New_Values;
      Item.Expanded := New_Expanded;
      Item.Selected :=
        (if New_Selected > 0 then New_Selected
         elsif New_Values.Is_Empty then 0 else 1);
      Ensure_Selected_Visible (Item);
   end Set_Nodes;

   function Create
     (Values        : Item_Array;
      Viewport_Rows : Natural := 8;
      Enabled       : Boolean := True) return Model
   is
      Result : Model :=
        (Rows => Viewport_Rows, Enabled => Enabled, others => <>);
   begin
      Set_Nodes (Result, Values);
      return Result;
   end Create;

   procedure Set_Expanded
     (Item : in out Model; Id : Id_Type; Expanded : Boolean := True)
   is
      Position : constant Natural := Find (Item, Id);
   begin
      if Position = 0 then
         raise Flyology_TUI.Components.Structure_Error;
      end if;
      Item.Expanded.Replace_Element (Position - 1, Expanded);
      Ensure_Selected_Visible (Item);
   end Set_Expanded;

   function Is_Expanded (Item : Model; Id : Id_Type) return Boolean is
      Position : constant Natural := Find (Item, Id);
   begin
      if Position = 0 then
         raise Flyology_TUI.Components.Structure_Error;
      end if;
      return Item.Expanded.Element (Position - 1);
   end Is_Expanded;

   procedure Select_Id (Item : in out Model; Id : Id_Type) is
      Position : constant Natural := Find (Item, Id);
   begin
      if Position = 0 then
         raise Flyology_TUI.Components.Structure_Error;
      end if;
      Item.Selected := Position;
      Ensure_Selected_Visible (Item);
   end Select_Id;

   procedure Set_Viewport_Rows (Item : in out Model; Rows : Natural) is
   begin
      Item.Rows := Rows;
      Ensure_Selected_Visible (Item);
   end Set_Viewport_Rows;

   procedure Set_Maximum_Width (Item : in out Model; Width : Natural) is
   begin
      Item.Max_Width := Width;
   end Set_Maximum_Width;

   procedure Set_Enabled (Item : in out Model; Enabled : Boolean) is
   begin
      Item.Enabled := Enabled;
   end Set_Enabled;

   function Natural_Width (Item : Model) return Natural is
      Result : Natural := 0;
   begin
      for Value of Item.Values loop
         Result := Natural'Max
           (Result,
            Depth_Of (Value) * 2 + 2 +
              Flyology_TUI.Glyphs.Width_Of (Label (Value)));
      end loop;
      return Result;
   end Natural_Width;

   function Width (Item : Model) return Natural is
     (Natural'Min (Natural_Width (Item), Item.Max_Width));

   function First_Visible_Row (Item : Model) return Natural is
     (if Item.Rows = 0 then 0 else Item.First);

   function Visible_Row_Count (Item : Model) return Natural is
      Count : constant Natural := Visible_Length (Item);
   begin
      if Item.Rows = 0 or else Item.First = 0 then
         return 0;
      end if;
      return Natural'Min (Item.Rows, Count - Item.First + 1);
   end Visible_Row_Count;

   function Selected_Id (Item : Model) return Id_Type is
     (Id_Of (Item.Values.Element (Item.Selected - 1)));

   function Visible_Id
     (Item : Model; Position : Positive) return Id_Type is
     (Id_Of (Item.Values.Element (Source_At_Visible (Item, Position))));

   function Visible_Row_Region
     (Item : Model; Position : Positive)
      return Flyology_TUI.Geometry.Rectangle is
     ((X      => 0,
       Y      => Integer (Position - 1),
       Width  => Width (Item),
       Height => 1));

   function Disclosure_Region
     (Item : Model; Visible_Position : Positive)
      return Flyology_TUI.Geometry.Rectangle
   is
      Source : constant Natural :=
        Source_At_Visible (Item, Item.First + Visible_Position - 1);
   begin
      return
        (X      => Integer (Depth_Of (Item.Values.Element (Source)) * 2),
         Y      => Integer (Visible_Position - 1),
         Width  => 2,
         Height => 1);
   end Disclosure_Region;

   procedure Move_To_Visible
     (Item : in out Model; Target : Integer; Changed : out Boolean)
   is
      Before : constant Natural := Item.Selected;
      Count  : constant Natural := Visible_Length (Item);
      Position : Natural;
   begin
      if Count = 0 then
         Changed := False;
         return;
      end if;
      Position := Natural
        (Integer'Max (1, Integer'Min (Integer (Count), Target)));
      Item.Selected := Source_At_Visible (Item, Position) + 1;
      Ensure_Selected_Visible (Item);
      Changed := Before /= Item.Selected;
   end Move_To_Visible;

   function Handle
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Terminal_Event)
      return Flyology_TUI.Components.Interactions.Update_Result
   is
      Changed : Boolean := False;
      Source  : Natural;
      Current : Natural;
   begin
      if not Item.Enabled or else Item.Values.Is_Empty
        or else Event.Kind /= Flyology_TUI.Events.Key_Press
      then
         return Flyology_TUI.Components.Interactions.Ignored;
      end if;
      Source := Item.Selected - 1;
      Current := Visible_Position_Of (Item, Source);
      case Event.Key.Kind is
         when Flyology_TUI.Events.Arrow_Up_Key =>
            Move_To_Visible (Item, Integer (Current) - 1, Changed);
         when Flyology_TUI.Events.Arrow_Down_Key =>
            Move_To_Visible (Item, Integer (Current) + 1, Changed);
         when Flyology_TUI.Events.Page_Up_Key =>
            Move_To_Visible
              (Item, Integer (Current) - Integer (Natural'Max (1, Item.Rows)),
               Changed);
         when Flyology_TUI.Events.Page_Down_Key =>
            Move_To_Visible
              (Item, Integer (Current) + Integer (Natural'Max (1, Item.Rows)),
               Changed);
         when Flyology_TUI.Events.Home_Key =>
            Move_To_Visible (Item, 1, Changed);
         when Flyology_TUI.Events.End_Key =>
            Move_To_Visible (Item, Integer (Visible_Length (Item)), Changed);
         when Flyology_TUI.Events.Arrow_Left_Key =>
            if Has_Child (Item, Source)
              and then Item.Expanded.Element (Source)
            then
               Item.Expanded.Replace_Element (Source, False);
               Ensure_Selected_Visible (Item);
               Changed := True;
            elsif Depth_Of (Item.Values.Element (Source)) > 0 then
               Item.Selected := Parent_Source (Item, Source) + 1;
               Ensure_Selected_Visible (Item);
               Changed := True;
            end if;
         when Flyology_TUI.Events.Arrow_Right_Key =>
            if Has_Child (Item, Source)
              and then not Item.Expanded.Element (Source)
            then
               Item.Expanded.Replace_Element (Source, True);
               Changed := True;
            elsif Has_Child (Item, Source) then
               Item.Selected := Source + 2;
               Ensure_Selected_Visible (Item);
               Changed := True;
            end if;
         when Flyology_TUI.Events.Enter_Key =>
            return (Handled => True, Activated => True, others => <>);
         when others =>
            return Flyology_TUI.Components.Interactions.Ignored;
      end case;
      return (Handled => True, Changed => Changed, others => <>);
   end Handle;

   function Handle
     (Item  : in out Model;
      Event : Flyology_TUI.Mouse.Local_Event)
      return Flyology_TUI.Components.Interactions.Update_Result
   is
      Changed : Boolean := False;
   begin
      if not Item.Enabled or else Item.Values.Is_Empty
        or else Event.X < 0 or else Event.X >= Integer (Width (Item))
        or else Event.Y < 0 or else Event.Y >= Integer (Height (Item))
      then
         return Flyology_TUI.Components.Interactions.Ignored;
      elsif Event.Action = Flyology_TUI.Events.Mouse_Wheel
        and then Event.Wheel_Y /= 0
      then
         declare
            Current : constant Natural :=
              Visible_Position_Of (Item, Item.Selected - 1);
            Amount : constant Integer :=
              (if Event.Wheel_Y = Integer'First
               then Integer'Last else -Event.Wheel_Y);
            Target : constant Integer :=
              (if Amount = Integer'Last then Integer'Last
               else Integer (Current) + Amount);
         begin
            Move_To_Visible (Item, Target, Changed);
         end;
         return (Handled => True, Changed => Changed, others => <>);
      elsif Event.Action = Flyology_TUI.Events.Mouse_Click
        and then Event.Button = Flyology_TUI.Events.Left_Button
      then
         declare
            Slot : constant Natural := Natural (Event.Y) + 1;
         begin
            if Slot <= Visible_Row_Count (Item) then
               declare
                  Source : constant Natural :=
                    Source_At_Visible (Item, Item.First + Slot - 1);
                  Disclosure_X : constant Integer :=
                    Integer (Depth_Of (Item.Values.Element (Source)) * 2);
               begin
                  if Event.X >= Disclosure_X
                    and then Event.X < Disclosure_X + 2
                    and then Has_Child (Item, Source)
                  then
                     Item.Expanded.Replace_Element
                       (Source, not Item.Expanded.Element (Source));
                     Ensure_Selected_Visible (Item);
                     return
                       (Handled => True, Changed => True,
                        Focus_Requested => True, others => <>);
                  else
                     Changed := Item.Selected /= Source + 1;
                     Item.Selected := Source + 1;
                     Ensure_Selected_Visible (Item);
                     return
                       (Handled => True, Changed => Changed, Activated => True,
                        Focus_Requested => True, others => <>);
                  end if;
               end;
            end if;
         end;
      end if;
      return Flyology_TUI.Components.Interactions.Ignored;
   end Handle;

   procedure Update
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Terminal_Event)
   is
      Discard : constant Flyology_TUI.Components.Interactions.Update_Result :=
        Handle (Item, Event);
      pragma Unreferenced (Discard);
   begin null; end Update;

   procedure Update
     (Item  : in out Model;
      Event : Flyology_TUI.Mouse.Local_Event)
   is
      Discard : constant Flyology_TUI.Components.Interactions.Update_Result :=
        Handle (Item, Event);
      pragma Unreferenced (Discard);
   begin null; end Update;

   function Render
     (Item      : Model;
      Look      : Appearance;
      Has_Focus : Boolean := False) return Flyology_TUI.Surfaces.Surface
   is
      Result : Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.Create (Width (Item), Height (Item));
   begin
      for Slot in 1 .. Visible_Row_Count (Item) loop
         declare
            Source : constant Natural :=
              Source_At_Visible (Item, Item.First + Slot - 1);
            Depth  : constant Natural :=
              Depth_Of (Item.Values.Element (Source));
            Chosen : constant Boolean := Item.Selected = Source + 1;
            Style  : constant Flyology_TUI.Styles.Style :=
              (if not Item.Enabled then Look.Muted
               elsif Has_Focus and then Chosen then Look.Focused
               elsif Chosen then Look.Selected else Look.Normal);
            Marker : constant Wide_Wide_String :=
              (if not Has_Child (Item, Source) then "  "
               elsif Item.Expanded.Element (Source) then "▾ " else "▸ ");
         begin
            Result.Write (Depth * 2, Slot - 1, Marker, Look.Disclosure);
            Result.Write
              (Depth * 2 + 2, Slot - 1,
               Label (Item.Values.Element (Source)), Style);
         end;
      end loop;
      return Result;
   end Render;

   function Render
     (Item      : Model;
      Theme     : Flyology_TUI.Themes.Theme;
      Has_Focus : Boolean := False) return Flyology_TUI.Surfaces.Surface is
     (Render (Item, From_Theme (Theme), Has_Focus));

end Flyology_TUI.Components.Trees;
