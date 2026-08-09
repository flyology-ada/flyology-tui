package body Flyology_TUI.Components.Scrollbars is
   use type Flyology_TUI.Events.Key_Kind;
   use type Flyology_TUI.Events.Mouse_Action;
   use type Flyology_TUI.Events.Mouse_Button;
   use type Flyology_TUI.Events.Terminal_Event_Kind;
   use type Flyology_TUI.Layouts.Boxes.Direction;

   function From_Theme
     (Theme : Flyology_TUI.Themes.Theme) return Appearance
   is
     (Track         => Theme.Muted,
      Thumb         => Theme.Border,
      Focused_Thumb => Theme.Focused,
      Buttons       => Theme.Primary);

   function Create
     (Flow   : Orientation;
      Length : Natural) return Model
   is (Flow_Value => Flow, Length => Length, others => <>);

   function Maximum_First (Item : Model) return Natural is
     (if Item.Page >= Item.Total then 0 else Item.Total - Item.Page);

   procedure Clamp (Item : in out Model) is
   begin
      Item.First_Item := Natural'Min (Item.First_Item, Maximum_First (Item));
   end Clamp;

   procedure Resize (Item : in out Model; Length : Natural) is
   begin
      Item.Length := Length;
      if Length < 3 then
         Item.Dragging := False;
      end if;
   end Resize;

   procedure Configure
     (Item      : in out Model;
      Total     : Natural;
      Page_Size : Natural;
      First     : Natural)
   is
   begin
      Item.Total := Total;
      Item.Page := Page_Size;
      Item.First_Item := First;
      Clamp (Item);
      if Maximum_First (Item) = 0 then
         Item.Dragging := False;
      end if;
   end Configure;

   function First (Item : Model) return Natural is (Item.First_Item);

   function Region (Item : Model) return Flyology_TUI.Geometry.Rectangle is
     (if Item.Flow_Value = Flyology_TUI.Layouts.Boxes.Horizontal
      then (X => 0, Y => 0, Width => Item.Length,
            Height => (if Item.Length = 0 then 0 else 1))
      else
        (X      => 0,
         Y      => 0,
         Width  => (if Item.Length = 0 then 0 else 1),
         Height => Item.Length));

   function Track_Length (Item : Model) return Natural is
     (if Item.Length <= 2 then 0 else Item.Length - 2);

   function Thumb_Length (Item : Model) return Natural is
      Track : constant Natural := Track_Length (Item);
   begin
      if Track = 0 then
         return 0;
      elsif Maximum_First (Item) = 0 or else Item.Total = 0 then
         return Track;
      elsif Item.Page = 0 then
         return 1;
      else
         return Natural'Max
           (1, Natural'Min
             (Track,
              Natural
                ((Long_Long_Integer (Item.Page) * Long_Long_Integer (Track))
                 / Long_Long_Integer (Item.Total))));
      end if;
   end Thumb_Length;

   function Thumb_Start (Item : Model) return Natural is
      Thumb : constant Natural := Thumb_Length (Item);
      Travel : constant Natural := Track_Length (Item) - Thumb;
      Maximum : constant Natural := Maximum_First (Item);
   begin
      if Travel = 0 or else Maximum = 0 then
         return 1;
      end if;
      return 1 + Natural
        ((Long_Long_Integer (Item.First_Item) * Long_Long_Integer (Travel))
         / Long_Long_Integer (Maximum));
   end Thumb_Start;

   function Thumb_Region
     (Item : Model) return Flyology_TUI.Geometry.Rectangle
   is
      Start : constant Natural := Thumb_Start (Item);
      Size : constant Natural := Thumb_Length (Item);
   begin
      if Item.Flow_Value = Flyology_TUI.Layouts.Boxes.Horizontal then
         return (X => Integer (Start), Y => 0, Width => Size,
                 Height => (if Size = 0 then 0 else 1));
      else
         return (X => 0, Y => Integer (Start),
                 Width => (if Size = 0 then 0 else 1), Height => Size);
      end if;
   end Thumb_Region;

   procedure Focus (Item : in out Model) is
   begin
      Item.Has_Focus := True;
   end Focus;

   procedure Blur (Item : in out Model) is
   begin
      Item.Has_Focus := False;
   end Blur;

   function Focused (Item : Model) return Boolean is (Item.Has_Focus);

   procedure Move_By (Item : in out Model; Amount : Integer) is
      Maximum : constant Natural := Maximum_First (Item);
   begin
      if Amount >= 0 then
         if Natural (Amount) >=
           Maximum - Natural'Min (Item.First_Item, Maximum)
         then
            Item.First_Item := Maximum;
         else
            Item.First_Item := Item.First_Item + Natural (Amount);
         end if;
      elsif Amount = Integer'First
        or else Natural (-Amount) >= Item.First_Item
      then
         Item.First_Item := 0;
      else
         Item.First_Item := Item.First_Item - Natural (-Amount);
      end if;
   end Move_By;

   function Safe_Negate (Value : Integer) return Integer is
     (if Value = Integer'First then Integer'Last else -Value);

   function Axis
     (Item : Model; Event : Flyology_TUI.Mouse.Local_Event) return Integer is
     (if Item.Flow_Value = Flyology_TUI.Layouts.Boxes.Horizontal
      then Event.X else Event.Y);

   function Handle
     (Item  : in out Model;
      Event : Flyology_TUI.Mouse.Local_Event)
      return Flyology_TUI.Components.Interactions.Update_Result
   is
      Result : Flyology_TUI.Components.Interactions.Update_Result;
      Before : constant Natural := Item.First_Item;
      Point : constant Flyology_TUI.Geometry.Point := (Event.X, Event.Y);
      Position : constant Integer := Axis (Item, Event);
      Thumb : constant Flyology_TUI.Geometry.Rectangle := Thumb_Region (Item);
      Thumb_Pos : constant Integer :=
        (if Item.Flow_Value = Flyology_TUI.Layouts.Boxes.Horizontal
         then Thumb.X else Thumb.Y);
   begin
      if Event.Action = Flyology_TUI.Events.Mouse_Wheel
        and then Flyology_TUI.Geometry.Contains (Region (Item), Point)
      then
         if Item.Flow_Value = Flyology_TUI.Layouts.Boxes.Horizontal then
            if Event.Wheel_X /= 0 then
               Move_By (Item, Safe_Negate (Event.Wheel_X));
            else
               Move_By (Item, Safe_Negate (Event.Wheel_Y));
            end if;
         else
            Move_By (Item, Safe_Negate (Event.Wheel_Y));
         end if;
         Result.Handled := True;
      elsif Event.Action = Flyology_TUI.Events.Mouse_Click
        and then Event.Button = Flyology_TUI.Events.Left_Button
        and then Flyology_TUI.Geometry.Contains (Region (Item), Point)
      then
         Item.Has_Focus := True;
         Result.Handled := True;
         Result.Focus_Requested := True;
         if Flyology_TUI.Geometry.Contains (Thumb, Point)
           and then Maximum_First (Item) > 0
         then
            Item.Dragging := True;
            Item.Drag_Offset := Natural (Position - Thumb_Pos);
            Result.Capture :=
              Flyology_TUI.Components.Interactions.Acquire_Capture;
         elsif Position = 0 then
            Move_By (Item, -1);
         elsif Position = Integer (Item.Length - 1) then
            Move_By (Item, 1);
         elsif Position < Thumb_Pos then
            Move_By (Item, -Integer (Natural'Max (1, Item.Page)));
         else
            Move_By (Item, Integer (Natural'Max (1, Item.Page)));
         end if;
      elsif Event.Action = Flyology_TUI.Events.Mouse_Drag
        and then Event.Button = Flyology_TUI.Events.Left_Button
        and then Item.Dragging
      then
         declare
            Travel : constant Natural :=
              Track_Length (Item) - Thumb_Length (Item);
            Raw : Long_Long_Integer :=
              Long_Long_Integer (Position) - 1
              - Long_Long_Integer (Item.Drag_Offset);
         begin
            Raw :=
              Long_Long_Integer'Max
                (0,
                 Long_Long_Integer'Min
                   (Raw, Long_Long_Integer (Travel)));
            if Travel > 0 then
               Item.First_Item := Natural
                 ((Raw * Long_Long_Integer (Maximum_First (Item)))
                  / Long_Long_Integer (Travel));
            end if;
         end;
         Result.Handled := True;
      elsif Event.Action = Flyology_TUI.Events.Mouse_Release
        and then Item.Dragging
      then
         Item.Dragging := False;
         Result.Handled := True;
         Result.Capture :=
           Flyology_TUI.Components.Interactions.Release_Capture;
      end if;
      Result.Changed := Item.First_Item /= Before;
      return Result;
   end Handle;

   function Handle
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Terminal_Event)
      return Flyology_TUI.Components.Interactions.Update_Result
   is
      Result : Flyology_TUI.Components.Interactions.Update_Result;
      Before : constant Natural := Item.First_Item;
      Page_Delta : constant Natural := Natural'Max (1, Item.Page);
   begin
      if Event.Kind /= Flyology_TUI.Events.Key_Press then
         return Result;
      end if;
      case Event.Key.Kind is
         when Flyology_TUI.Events.Home_Key => Item.First_Item := 0;
         when Flyology_TUI.Events.End_Key =>
            Item.First_Item := Maximum_First (Item);
         when Flyology_TUI.Events.Page_Up_Key =>
            Move_By (Item, -Integer (Page_Delta));
         when Flyology_TUI.Events.Page_Down_Key =>
            Move_By (Item, Integer (Page_Delta));
         when Flyology_TUI.Events.Arrow_Left_Key =>
            if Item.Flow_Value /= Flyology_TUI.Layouts.Boxes.Horizontal then
               return Result;
            end if;
            Move_By (Item, -1);
         when Flyology_TUI.Events.Arrow_Right_Key =>
            if Item.Flow_Value /= Flyology_TUI.Layouts.Boxes.Horizontal then
               return Result;
            end if;
            Move_By (Item, 1);
         when Flyology_TUI.Events.Arrow_Up_Key =>
            if Item.Flow_Value /= Flyology_TUI.Layouts.Boxes.Vertical then
               return Result;
            end if;
            Move_By (Item, -1);
         when Flyology_TUI.Events.Arrow_Down_Key =>
            if Item.Flow_Value /= Flyology_TUI.Layouts.Boxes.Vertical then
               return Result;
            end if;
            Move_By (Item, 1);
         when others => return Result;
      end case;
      Result.Handled := True;
      Result.Changed := Item.First_Item /= Before;
      return Result;
   end Handle;

   procedure Update
     (Item  : in out Model;
      Event : Flyology_TUI.Mouse.Local_Event)
   is
      Discard : constant Flyology_TUI.Components.Interactions.Update_Result :=
        Handle (Item, Event);
   begin
      null;
   end Update;

   procedure Update
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Terminal_Event)
   is
      Discard : constant Flyology_TUI.Components.Interactions.Update_Result :=
        Handle (Item, Event);
   begin
      null;
   end Update;

   function Render
     (Item       : Model;
      Appearance : Scrollbars.Appearance)
      return Flyology_TUI.Surfaces.Surface
   is
      Result : Flyology_TUI.Surfaces.Surface :=
        (if Item.Flow_Value = Flyology_TUI.Layouts.Boxes.Horizontal
         then Flyology_TUI.Surfaces.Create
           (Item.Length,
            (if Item.Length = 0 then 0 else 1),
            Appearance.Track)
         else Flyology_TUI.Surfaces.Create
           ((if Item.Length = 0 then 0 else 1),
            Item.Length,
            Appearance.Track));
      Thumb : constant Flyology_TUI.Geometry.Rectangle := Thumb_Region (Item);
      Thumb_Style : constant Flyology_TUI.Styles.Style :=
        (if Item.Has_Focus
         then Appearance.Focused_Thumb
         else Appearance.Thumb);
   begin
      if Item.Length = 0 then
         return Result;
      end if;
      for Position in 0 .. Item.Length - 1 loop
         if Item.Flow_Value = Flyology_TUI.Layouts.Boxes.Horizontal then
            Result.Put
              (Position, 0,
               (if Position = 0 then "◀"
                elsif Position + 1 = Item.Length then "▶"
                elsif Flyology_TUI.Geometry.Contains
                  (Thumb, Integer (Position), 0)
                then "█"
                else "░"),
               (if Position = 0 or else Position + 1 = Item.Length
                then Appearance.Buttons
                elsif Flyology_TUI.Geometry.Contains
                  (Thumb, Integer (Position), 0)
                then Thumb_Style else Appearance.Track));
         else
            Result.Put
              (0, Position,
               (if Position = 0 then "▲"
                elsif Position + 1 = Item.Length then "▼"
                elsif Flyology_TUI.Geometry.Contains
                  (Thumb, 0, Integer (Position))
                then "█"
                else "░"),
               (if Position = 0 or else Position + 1 = Item.Length
                then Appearance.Buttons
                elsif Flyology_TUI.Geometry.Contains
                  (Thumb, 0, Integer (Position))
                then Thumb_Style else Appearance.Track));
         end if;
      end loop;
      return Result;
   end Render;

   function Render
     (Item  : Model;
      Theme : Flyology_TUI.Themes.Theme)
      return Flyology_TUI.Surfaces.Surface
   is (Render (Item, From_Theme (Theme)));

end Flyology_TUI.Components.Scrollbars;
